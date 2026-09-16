"""Graph-grounded patient questions with a deterministic safe fallback."""

import from models {
    BackendResponse,
    CandidateCategory,
    PatientAnswerDTO,
    DemoSession,
    Patient,
    Encounter,
    VerifiedFact,
    LabOrder,
    FollowUp,
    MedicationInstruction,
    Referral,
    CareTask,
    CareOwner,
    PatientQuestion,
    PatientAnswer,
    HasPatient,
    HasEncounter,
    HasVerifiedFact,
    RepresentsLabOrder,
    RepresentsFollowUp,
    RepresentsMedication,
    RepresentsReferral,
    HasLabTask,
    AssignedTo,
    HasQuestion,
    HasAnswer,
    AnsweredFrom,
    answer_to_dto,
}
import from extraction { deterministic_timestamp }
import from walkers {
    TraceableWalker,
    failure_response,
    success_response,
    find_session,
    session_patient,
    own_node,
    fact_is_conflicted,
}

glob SAFE_FALLBACK: str = (
         "This is not recorded in your approved care plan. "
         "Please contact your clinic."
     );

def question_matches_category(question: str, category: CandidateCategory) -> bool {
    normalized: str = question.lower();
    if category == CandidateCategory.LAB_ORDER {
        return ("lab" in normalized or "blood" in normalized or "test" in normalized);
    }
    if category == CandidateCategory.FOLLOW_UP {
        return (
            "follow" in normalized
            or "return" in normalized
            or "appointment" in normalized
            or "review" in normalized
        );
    }
    if category == CandidateCategory.MEDICATION_INSTRUCTION {
        return "medication" in normalized or "prescription" in normalized;
    }
    if category == CandidateCategory.REFERRAL {
        return (
            "referral" in normalized
            or "nutrition" in normalized
            or "counselor" in normalized
        );
    }
    if category == CandidateCategory.LANGUAGE_PREFERENCE {
        return "language" in normalized or "spanish" in normalized;
    }
    return False;
}

walker PatientQuestionWalker(TraceableWalker) {
    has session_id: str = "demo-default",
        question: str = "",
        restrict_to_fact_ids: bool = False,
        allowed_fact_ids: list[str] = [],
        ai_matching_used: bool = False,
        answer: str = "",
        grounded: bool = False,
        source_fact_ids: list[str] = [],
        reports: list[BackendResponse] = [];

    can locate with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        if session is None {
            report failure_response(
                "DEMO_NOT_LOADED",
                "Load the synthetic encounter before asking a question.",
                True,
                0
            );
            disengage;
        }
        if not self.question.strip() {
            report failure_response(
                "INVALID_QUESTION",
                "question must not be empty.",
                True,
                session.graph_version
            );
            disengage;
        }
        visit session;
    }

    can enter_session with DemoSession entry {
        self.trace(
            "PatientQuestionWalker",
            here.id,
            "DemoSession",
            "HasSession",
            "follow patient",
            "queued",
            "Entered only the selected synthetic session."
        );
        visit [here->:HasPatient:->];
    }

    can enter_patient with Patient entry {
        self.trace(
            "PatientQuestionWalker",
            here.id,
            "Patient",
            "HasPatient",
            "follow encounter",
            "queued",
            "Located the selected patient's approved encounter."
        );
        visit [here->:HasEncounter:->];
    }

    can enter_encounter with Encounter entry {
        self.trace(
            "PatientQuestionWalker",
            here.id,
            "Encounter",
            "HasEncounter",
            "follow approved facts",
            "queued",
            "Queued only facts connected through HasVerifiedFact."
        );
        visit [here->:HasVerifiedFact:->];
    }

    can answer_from_fact with VerifiedFact entry {
        if self.grounded {
            skip;
        }
        session: DemoSession | None = find_session(self.session_id);
        allowed: bool = (
            session is not None
            and here.session_id == self.session_id
            and here.visible_to_patient
            and not fact_is_conflicted(session as DemoSession, here.id)
            and (not self.restrict_to_fact_ids or here.id in self.allowed_fact_ids)
            and question_matches_category(self.question, here.category)
        );
        self.trace(
            "PatientQuestionWalker",
            here.id,
            "VerifiedFact",
            "HasVerifiedFact",
            "apply approved evidence filter",
            "eligible" if allowed else "excluded",
            "Used only current-session, verified, visible, non-conflicting evidence."
        );
        if not allowed {
            skip;
        }
        if here.category == CandidateCategory.LAB_ORDER {
            labs: list[LabOrder] = [here->:RepresentsLabOrder:->];
            if labs {
                tasks: list[CareTask] = [labs[0]->:HasLabTask:->];
                owners: list[CareOwner] = [tasks[0]->:AssignedTo:->] if tasks else [];
                if (
                    tasks
                    and tasks[0].status == "resolved"
                    and labs[0].due_window.strip()
                    and owners
                ) {
                    self.answer = (
                        f"Your {labs[0].test_name} is due "
                        f"{labs[0].due_window} and is assigned to "
                        f"{owners[0].display_name}."
                    );
                }
            }
        } elif here.category == CandidateCategory.FOLLOW_UP {
            follow_ups: list[FollowUp] = [here->:RepresentsFollowUp:->];
            if follow_ups and follow_ups[0].appointment_date.strip() {
                self.answer = (
                    "Your follow-up is scheduled for "
                    f"{follow_ups[0].appointment_date}."
                );
            }
        } elif here.category == CandidateCategory.MEDICATION_INSTRUCTION {
            medications: list[MedicationInstruction] = [here->:RepresentsMedication:->];
            if medications and medications[0].instruction_text.strip() {
                self.answer = medications[0].instruction_text;
            }
        } elif here.category == CandidateCategory.REFERRAL {
            referrals: list[Referral] = [here->:RepresentsReferral:->];
            if referrals and referrals[0].destination.strip() {
                self.answer = (
                    "Your approved referral is to " f"{referrals[0].destination}."
                );
            }
        } elif here.category == CandidateCategory.LANGUAGE_PREFERENCE {
            self.answer = f"Your approved language preference is {here.value}.";
        }

        if self.answer.strip() {
            self.grounded = True;
            self.source_fact_ids = [here.id];
            self.trace(
                "PatientQuestionWalker",
                here.id,
                "VerifiedFact",
                "Represents*",
                "assemble deterministic answer",
                "grounded",
                "Assembled the answer only from stored graph fields."
            );
        }
    }

    can finish with DemoSession exit {
        fallback_used: bool = not self.grounded;
        if fallback_used {
            self.answer = SAFE_FALLBACK;
            self.source_fact_ids = [];
        }
        patient: Patient | None = session_patient(here);
        if patient is None {
            response = failure_response(
                "PATIENT_NOT_FOUND",
                "The synthetic patient is missing.",
                False,
                here.graph_version
            );
            response.traversal_trace = self.traversal_trace;
            report response;
            disengage;
        }

        here.graph_version += 1;
        question_node = PatientQuestion(
            session_id=here.id,
            id=f"question-{here.id}-{here.graph_version}",
            question=self.question,
            answer=self.answer,
            grounded=self.grounded,
            source_fact_ids=self.source_fact_ids,
            fallback_used=fallback_used,
            current=True,
            created_at=deterministic_timestamp(here.graph_version)
        );
        answer_node = PatientAnswer(
            session_id=here.id,
            id=f"answer-{here.id}-{here.graph_version}",
            answer=self.answer,
            grounded=self.grounded,
            source_fact_ids=self.source_fact_ids,
            fallback_used=fallback_used,
            ai_matching_used=self.ai_matching_used,
            current=True,
            created_at=deterministic_timestamp(here.graph_version)
        );
        own_node(here, question_node);
        own_node(here, answer_node);
        (patient as Patient) +>:HasQuestion():+> question_node;
        question_node +>:HasAnswer():+> answer_node;
        for fact_id in self.source_fact_ids {
            encounter: Encounter | None = (
                [(patient as Patient)->:HasEncounter:->][0]
                    if [(patient as Patient)->:HasEncounter:->]
                    else None
            );
            facts: list[VerifiedFact] = (
                [(encounter as Encounter)->:HasVerifiedFact:->[?:VerifiedFact, id==fact_id]]
                    if encounter is not None
                    else []
            );
            if facts {
                answer_node +>:AnsweredFrom():+> facts[0];
            }
        }

        response = success_response(
            here.graph_version,
            (
                "Question answered from approved graph evidence."
                    if self.grounded
                    else "No approved graph evidence answered the question."
            )
        );
        response.patient_answer = answer_to_dto(answer_node);
        response.created_graph_ids = [question_node.id, answer_node.id];
        response.traversal_trace = self.traversal_trace;
        report response;
    }
}
