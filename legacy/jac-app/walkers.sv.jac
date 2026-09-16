"""Canonical graph walkers and deterministic projections for Pa-Co CareGraph."""

import os;
import from models {
    AIStatusDTO,
    BackendResponse,
    CandidateCategory,
    CandidateFactDTO,
    CandidateStatus,
    CareGapDTO,
    CareGraphDTO,
    ConflictDTO,
    ConflictType,
    DemoStateDTO,
    EncounterDTO,
    GapStatus,
    GapType,
    GraphRelationshipDTO,
    PatientDTO,
    PatientPlanDTO,
    PlanItemDTO,
    ProvenanceChainDTO,
    TranscriptChunkDTO,
    TraversalStepDTO,
    VerificationDecision,
    VerifiedFactDTO,
    ExtractedCandidate,
    CareNode,
    DemoSession,
    Patient,
    Encounter,
    TranscriptChunk,
    CandidateFact,
    VerifiedFact,
    ClinicianIdentity,
    VerificationEvent,
    MedicationInstruction,
    LabOrder,
    Referral,
    FollowUp,
    CareOwner,
    CareTask,
    CareGap,
    GapResolutionEvent,
    Conflict,
    PatientBrief,
    ChecklistItem,
    PatientQuestion,
    PatientAnswer,
    CaptureSession,
    AudioMetadata,
    SourceArtifact,
    DocumentImage,
    DocumentTextBlock,
    ClinicianNoteDraft,
    NoteSection,
    NoteApprovalEvent,
    NoteEditEvent,
    TimelineEvent,
    PatientAudioScript,
    HasSession,
    SessionOwns,
    HasPatient,
    HasEncounter,
    ContainsChunk,
    HasCandidate,
    ExtractedFrom,
    ExtractedFromDocument,
    PromotedTo,
    HasVerifiedFact,
    VerifiedFrom,
    VerifiedBy,
    HasClinician,
    HasVerificationEvent,
    RejectedFrom,
    DecisionBy,
    RepresentsMedication,
    RepresentsLabOrder,
    RepresentsReferral,
    RepresentsFollowUp,
    RequiresFollowUp,
    HasTask,
    HasLabTask,
    HasFollowUpTask,
    HasReferralTask,
    HasMedicationTask,
    HasOwner,
    AssignedTo,
    DependsOn,
    HasGap,
    GapForFact,
    ResolvedBy,
    ResolutionUpdates,
    Supersedes,
    Contradicts,
    HasConflict,
    ConflictEvidence,
    CandidateConflictEvidence,
    HasBrief,
    GeneratedFrom,
    HasChecklistItem,
    SupportedBy,
    VisibleToPatient,
    HasQuestion,
    HasAnswer,
    AnsweredFrom,
    HasCaptureSession,
    ProducedChunk,
    HasAudioMetadata,
    HasSourceArtifact,
    RepresentsDocument,
    ContainsTextBlock,
    HasClinicianNote,
    NoteGeneratedFrom,
    ContainsSection,
    NoteSupportedBy,
    ApprovedByEvent,
    HasNoteEdit,
    SupersedesNote,
    HasTimelineEvent,
    HasAudioScript,
    AudioGeneratedFrom,
    AudioSupportedBy,
    candidate_to_dto,
    verified_to_dto,
    gap_to_dto,
    conflict_to_dto,
    patient_to_dto,
    encounter_to_dto,
    transcript_to_dto,
    brief_to_plan,
}
import from extraction {
    SeedTranscriptChunk,
    SeedCandidateFact,
    deterministic_timestamp,
    prepared_transcript,
    prepared_candidates,
    prepared_contradiction_chunk,
    prepared_contradiction_candidate,
}

def failure_response(
    error_code: str, message: str, recoverable: bool, graph_version: int
) -> BackendResponse {
    return BackendResponse(
        success=False,
        error_code=error_code,
        message=message,
        recoverable=recoverable,
        current_graph_version=graph_version
    );
}

def success_response(graph_version: int, message: str = "") -> BackendResponse {
    return BackendResponse(
        success=True, message=message, current_graph_version=graph_version
    );
}

def trace_enabled -> bool {
    value: str | None = os.getenv("DEMO_TRACE_ENABLED");
    return (value is not None and value.lower().strip() in ["1", "true", "yes", "on"]);
}

walker TraceableWalker {
    has traversal_trace: list[TraversalStepDTO] = [],
        trace_order: int = 0;

    def trace(
        walker_name: str,
        current_node_id: str,
        current_node_type: str,
        edge_type: str,
        action: str,
        outcome: str,
        explanation: str
    ) {
        if trace_enabled() {
            self.trace_order += 1;
            self.traversal_trace.append(
                TraversalStepDTO(
                    order=self.trace_order,
                    walker_name=walker_name,
                    current_node_id=current_node_id,
                    current_node_type=current_node_type,
                    edge_type=edge_type,
                    action=action,
                    outcome=outcome,
                    human_explanation=explanation
                )
            );
        }
    }
}

def find_session(session_id: str) -> DemoSession | None {
    sessions: list[DemoSession] = [root->:HasSession:->[?:DemoSession, id==session_id]];
    return sessions[0] if sessions else None;
}

def session_patient(session: DemoSession) -> Patient | None {
    patients: list[Patient] = [session->:HasPatient:->];
    return patients[0] if len(patients) == 1 else None;
}

def patient_encounter(patient: Patient) -> Encounter | None {
    encounters: list[Encounter] = [patient->:HasEncounter:->];
    return encounters[0] if len(encounters) == 1 else None;
}

def session_encounter(session: DemoSession) -> Encounter | None {
    patient: Patient | None = session_patient(session);
    return patient_encounter(patient as Patient) if patient is not None else None;
}

def verified_facts_for_session(session: DemoSession) -> list[VerifiedFact] {
    encounter: Encounter | None = session_encounter(session);
    if encounter is None {
        return [];
    }
    return [(encounter as Encounter)->:HasVerifiedFact:->];
}

def candidates_for_session(session: DemoSession) -> list[CandidateFact] {
    encounter: Encounter | None = session_encounter(session);
    if encounter is None {
        return [];
    }
    return [(encounter as Encounter)->:HasCandidate:->];
}

def own_node(session: DemoSession, item: CareNode) {
    session +>:SessionOwns():+> item;
}

def candidate_category(value: str) -> CandidateCategory | None {
    if value == CandidateCategory.LAB_ORDER {
        return CandidateCategory.LAB_ORDER;
    }
    if value == CandidateCategory.FOLLOW_UP {
        return CandidateCategory.FOLLOW_UP;
    }
    if value == CandidateCategory.MEDICATION_INSTRUCTION {
        return CandidateCategory.MEDICATION_INSTRUCTION;
    }
    if value == CandidateCategory.REFERRAL {
        return CandidateCategory.REFERRAL;
    }
    if value == CandidateCategory.LANGUAGE_PREFERENCE {
        return CandidateCategory.LANGUAGE_PREFERENCE;
    }
    return None;
}

def candidate_sequence(candidate: CandidateFact) -> int {
    chunks: list[TranscriptChunk] = [candidate->:ExtractedFrom:->];
    return chunks[0].sequence if chunks else 0;
}

def active_gaps(session: DemoSession) -> list[CareGap] {
    encounter: Encounter | None = session_encounter(session);
    if encounter is None {
        return [];
    }
    return [
        gap
        for gap in [(encounter as Encounter)->:HasGap:->]
        if gap.status == GapStatus.OPEN and not gap.resolved
    ];
}

def unresolved_conflicts(session: DemoSession) -> list[Conflict] {
    encounter: Encounter | None = session_encounter(session);
    if encounter is None {
        return [];
    }
    return [
        conflict
        for conflict in [(encounter as Encounter)->:HasConflict:->]
        if not conflict.resolved
    ];
}

def fact_is_conflicted(session: DemoSession, fact_id: str) -> bool {
    for conflict in unresolved_conflicts(session) {
        if conflict.left_fact_id == fact_id or conflict.right_fact_id == fact_id {
            return True;
        }
    }
    return False;
}

def has_competing_follow_up(session: DemoSession, fact: VerifiedFact) -> bool {
    if fact.category != CandidateCategory.FOLLOW_UP {
        return False;
    }
    return any(
        other.id != fact.id
        and other.category == CandidateCategory.FOLLOW_UP
        and other.value != fact.value for other in verified_facts_for_session(session)
    );
}

def ensure_owner(
    session: DemoSession, encounter: Encounter, owner_id: str
) -> CareOwner {
    owners: list[CareOwner] = [encounter->:HasOwner:->[?:CareOwner, id==owner_id]];
    if owners {
        return owners[0];
    }
    owner = CareOwner(session_id=session.id, id=owner_id, display_name=owner_id);
    own_node(session, owner);
    encounter +>:HasOwner():+> owner;
    return owner;
}

def assign_task(task: CareTask, owner: CareOwner) {
    for relation in [edge task->:AssignedTo:->] {
        del relation;
    }
    task +>:AssignedTo():+> owner;
    task.owner = owner.id;
}

def invalidate_current_outputs(session: DemoSession) {
    patient: Patient | None = session_patient(session);
    if patient is None {
        return;
    }
    for brief in [(patient as Patient)->:HasBrief:->] {
        if brief.current {
            brief.current = False;
            for item in [brief->:HasChecklistItem:->] {
                item.current = False;
            }
        }
    }
    for question in [(patient as Patient)->:HasQuestion:->] {
        question.current = False;
        for answer in [question->:HasAnswer:->] {
            answer.current = False;
        }
    }
}

def latest_plan(session: DemoSession) -> PatientPlanDTO | None {
    patient: Patient | None = session_patient(session);
    if patient is None {
        return None;
    }
    briefs: list[PatientBrief] = [
        brief
        for brief in [(patient as Patient)->:HasBrief:->]
        if brief.current
    ];
    return brief_to_plan(briefs[-1]) if briefs else None;
}

def seed_transcript_graph(session: DemoSession) {
    patients: list[Patient] = [session->:HasPatient:->];
    if patients {
        return;
    }
    patient = Patient(
        session_id=session.id,
        id="patient-maya",
        display_name="Maya Rivera",
        preferred_language="Spanish",
        synthetic=True
    );
    own_node(session, patient);
    session +>:HasPatient():+> patient;
    encounter = Encounter(
        session_id=session.id,
        id="encounter-maya-001",
        occurred_at="2026-07-26T18:00:00Z",
        status="candidate_review"
    );
    own_node(session, encounter);
    patient +>:HasEncounter():+> encounter;
    for seed in prepared_transcript() {
        chunk = TranscriptChunk(
            session_id=session.id,
            id=seed.id,
            encounter_id=encounter.id,
            sequence=seed.sequence,
            speaker=seed.speaker,
            text=seed.text,
            source_type="prepared_transcript",
            finalized=True
        );
        own_node(session, chunk);
        encounter +>:ContainsChunk():+> chunk;
    }
}

def seed_prepared_candidate_graph(session: DemoSession) -> bool {
    encounter: Encounter | None = session_encounter(session);
    if encounter is None {
        return False;
    }
    active_encounter: Encounter = encounter as Encounter;
    chunks: list[TranscriptChunk] = [active_encounter->:ContainsChunk:->];
    created_any: bool = False;
    for seed in prepared_candidates() {
        existing: list[CandidateFact] = [active_encounter->:HasCandidate:->[?:CandidateFact, id==seed.id]];
        if existing {
            continue;
        }
        sources: list[TranscriptChunk] = [
            chunk
            for chunk in chunks
            if chunk.id == seed.source_chunk_id
        ];
        if not sources {
            continue;
        }
        candidate = CandidateFact(
            session_id=session.id,
            id=seed.id,
            category=seed.category,
            value=seed.value,
            confidence=seed.confidence,
            status=CandidateStatus.PENDING,
            source_chunk_id=seed.source_chunk_id,
            source_kind="transcript",
            source_text=sources[0].text,
            created_at=seed.created_at
        );
        own_node(session, candidate);
        active_encounter +>:HasCandidate():+> candidate;
        candidate +>:ExtractedFrom():+> sources[0];
        created_any = True;
    }
    return created_any;
}

def seed_session_graph(session: DemoSession, include_candidates: bool = True) {
    session.schema_version = 2;
    session.graph_version = 1;
    seed_transcript_graph(session);
    if include_candidates {
        _ = seed_prepared_candidate_graph(session);
    }
}

def seed_state_is_valid(session: DemoSession) -> bool {
    patients: list[Patient] = [session->:HasPatient:->];
    if len(patients) != 1 {
        return False;
    }
    encounters: list[Encounter] = [patients[0]->:HasEncounter:->];
    if len(encounters) != 1 {
        return False;
    }
    chunks: list[TranscriptChunk] = [encounters[0]->:ContainsChunk:->];
    if len(chunks) < 5 {
        return False;
    }
    for seed in prepared_transcript() {
        matches: list[TranscriptChunk] = [
            chunk
            for chunk in chunks
            if (
                chunk.id == seed.id
                and chunk.sequence == seed.sequence
                and chunk.speaker == seed.speaker
                and chunk.text == seed.text
            )
        ];
        if len(matches) != 1 {
            return False;
        }
    }
    return True;
}

def add_contradiction_candidate(session: DemoSession) -> bool {
    encounter: Encounter | None = session_encounter(session);
    if encounter is None {
        return False;
    }
    active_encounter: Encounter = encounter as Encounter;
    existing: list[CandidateFact] = [active_encounter->:HasCandidate:->[?:CandidateFact, id=="candidate-follow-up-4-weeks"]];
    if existing {
        return False;
    }
    chunk_seed: SeedTranscriptChunk = prepared_contradiction_chunk();
    chunk = TranscriptChunk(
        session_id=session.id,
        id=chunk_seed.id,
        encounter_id=active_encounter.id,
        sequence=chunk_seed.sequence,
        speaker=chunk_seed.speaker,
        text=chunk_seed.text,
        source_type="prepared_transcript",
        finalized=True
    );
    own_node(session, chunk);
    active_encounter +>:ContainsChunk():+> chunk;
    candidate_seed: SeedCandidateFact = prepared_contradiction_candidate();
    candidate = CandidateFact(
        session_id=session.id,
        id=candidate_seed.id,
        category=candidate_seed.category,
        value=candidate_seed.value,
        confidence=candidate_seed.confidence,
        status=CandidateStatus.PENDING,
        source_chunk_id=candidate_seed.source_chunk_id,
        source_kind="transcript",
        source_text=chunk.text,
        created_at=candidate_seed.created_at
    );
    own_node(session, candidate);
    active_encounter +>:HasCandidate():+> candidate;
    candidate +>:ExtractedFrom():+> chunk;
    session.graph_version += 1;
    return True;
}

def relationship(
    source_id: str, edge_type: str, target_id: str, role: str = ""
) -> GraphRelationshipDTO {
    return GraphRelationshipDTO(
        from_id=source_id, edge_type=edge_type, to_id=target_id, role=role
    );
}

def build_relationships(session: DemoSession) -> list[GraphRelationshipDTO] {
    output: list[GraphRelationshipDTO] = [
        relationship("root", "HasSession", session.id)
    ];
    patient: Patient | None = session_patient(session);
    if patient is None {
        return output;
    }
    active_patient: Patient = patient as Patient;
    output.append(relationship(session.id, "HasPatient", active_patient.id));
    encounter: Encounter | None = patient_encounter(active_patient);
    if encounter is None {
        return output;
    }
    active_encounter: Encounter = encounter as Encounter;
    output.append(relationship(active_patient.id, "HasEncounter", active_encounter.id));
    for chunk in [active_encounter->:ContainsChunk:->] {
        output.append(relationship(active_encounter.id, "ContainsChunk", chunk.id));
    }
    for candidate in [active_encounter->:HasCandidate:->] {
        output.append(relationship(active_encounter.id, "HasCandidate", candidate.id));
        for chunk in [candidate->:ExtractedFrom:->] {
            output.append(relationship(candidate.id, "ExtractedFrom", chunk.id));
        }
        for block in [candidate->:ExtractedFromDocument:->] {
            output.append(
                relationship(candidate.id, "ExtractedFromDocument", block.id)
            );
        }
        for verified in [candidate->:PromotedTo:->] {
            output.append(relationship(candidate.id, "PromotedTo", verified.id));
        }
    }
    for fact in [active_encounter->:HasVerifiedFact:->] {
        output.append(relationship(active_encounter.id, "HasVerifiedFact", fact.id));
        for candidate in [fact->:VerifiedFrom:->] {
            output.append(relationship(fact.id, "VerifiedFrom", candidate.id));
        }
        for item in [fact->:RepresentsLabOrder:->] {
            output.append(relationship(fact.id, "RepresentsLabOrder", item.id));
        }
        for item in [fact->:RepresentsFollowUp:->] {
            output.append(relationship(fact.id, "RepresentsFollowUp", item.id));
        }
        for item in [fact->:RepresentsMedication:->] {
            output.append(relationship(fact.id, "RepresentsMedication", item.id));
        }
        for item in [fact->:RepresentsReferral:->] {
            output.append(relationship(fact.id, "RepresentsReferral", item.id));
        }
    }
    for task in [active_encounter->:HasTask:->] {
        output.append(relationship(active_encounter.id, "HasTask", task.id));
        for fact in [task->:DependsOn:->] {
            output.append(relationship(task.id, "DependsOn", fact.id));
        }
        for owner in [task->:AssignedTo:->] {
            output.append(relationship(task.id, "AssignedTo", owner.id));
        }
    }
    for gap in [active_encounter->:HasGap:->] {
        output.append(relationship(active_encounter.id, "HasGap", gap.id));
        for fact in [gap->:GapForFact:->] {
            output.append(relationship(gap.id, "GapForFact", fact.id));
        }
        for event in [gap->:ResolvedBy:->] {
            output.append(relationship(gap.id, "ResolvedBy", event.id));
        }
    }
    for conflict in [active_encounter->:HasConflict:->] {
        output.append(relationship(active_encounter.id, "HasConflict", conflict.id));
        for target in [conflict->:ConflictEvidence:->] {
            role: str = (
                "approved"
                    if conflict.conflict_type == ConflictType.UNVERIFIED_ATTEMPTED_CHANGE
                    else ("left" if target.id == conflict.left_fact_id else "right")
            );
            output.append(
                relationship(conflict.id, "ConflictEvidence", target.id, role)
            );
        }
        for target in [conflict->:CandidateConflictEvidence:->] {
            output.append(
                relationship(
                    conflict.id, "CandidateConflictEvidence", target.id, "unverified"
                )
            );
        }
    }
    for brief in [active_patient->:HasBrief:->] {
        output.append(relationship(active_patient.id, "HasBrief", brief.id));
        for item in [brief->:HasChecklistItem:->] {
            output.append(relationship(brief.id, "HasChecklistItem", item.id));
            for fact in [item->:SupportedBy:->] {
                output.append(relationship(item.id, "SupportedBy", fact.id));
            }
        }
    }
    for question in [active_patient->:HasQuestion:->] {
        output.append(relationship(active_patient.id, "HasQuestion", question.id));
        for answer in [question->:HasAnswer:->] {
            output.append(relationship(question.id, "HasAnswer", answer.id));
            for fact in [answer->:AnsweredFrom:->] {
                output.append(relationship(answer.id, "AnsweredFrom", fact.id));
            }
        }
    }
    for capture in [active_encounter->:HasCaptureSession:->] {
        output.append(
            relationship(active_encounter.id, "HasCaptureSession", capture.id)
        );
        for chunk in [capture->:ProducedChunk:->] {
            output.append(relationship(capture.id, "ProducedChunk", chunk.id));
        }
        for metadata in [capture->:HasAudioMetadata:->] {
            output.append(relationship(capture.id, "HasAudioMetadata", metadata.id));
        }
    }
    for artifact in [active_encounter->:HasSourceArtifact:->] {
        output.append(
            relationship(active_encounter.id, "HasSourceArtifact", artifact.id)
        );
        for document in [artifact->:RepresentsDocument:->] {
            output.append(relationship(artifact.id, "RepresentsDocument", document.id));
            for block in [document->:ContainsTextBlock:->] {
                output.append(relationship(document.id, "ContainsTextBlock", block.id));
            }
        }
    }
    for note in [active_encounter->:HasClinicianNote:->] {
        output.append(relationship(active_encounter.id, "HasClinicianNote", note.id));
        for encounter in [note->:NoteGeneratedFrom:->] {
            output.append(relationship(note.id, "NoteGeneratedFrom", encounter.id));
        }
        for section in [note->:ContainsSection:->] {
            output.append(relationship(note.id, "ContainsSection", section.id));
            for fact in [section->:NoteSupportedBy:->] {
                output.append(relationship(section.id, "NoteSupportedBy", fact.id));
            }
        }
        for event in [note->:ApprovedByEvent:->] {
            output.append(relationship(note.id, "ApprovedByEvent", event.id));
        }
        for event in [note->:HasNoteEdit:->] {
            output.append(relationship(note.id, "HasNoteEdit", event.id));
        }
        for prior_note in [note->:SupersedesNote:->] {
            output.append(relationship(note.id, "SupersedesNote", prior_note.id));
        }
    }
    for event in [active_encounter->:HasTimelineEvent:->] {
        output.append(relationship(active_encounter.id, "HasTimelineEvent", event.id));
    }
    for script in [active_patient->:HasAudioScript:->] {
        output.append(relationship(active_patient.id, "HasAudioScript", script.id));
        for brief in [script->:AudioGeneratedFrom:->] {
            output.append(relationship(script.id, "AudioGeneratedFrom", brief.id));
        }
        for fact in [script->:AudioSupportedBy:->] {
            output.append(relationship(script.id, "AudioSupportedBy", fact.id));
        }
    }
    return output;
}

def build_demo_state(session: DemoSession) -> DemoStateDTO {
    patient_dto: PatientDTO | None = None;
    encounter_dto: EncounterDTO | None = None;
    transcript_dtos: list[TranscriptChunkDTO] = [];
    candidate_dtos: list[CandidateFactDTO] = [];
    verified_dtos: list[VerifiedFactDTO] = [];
    patient: Patient | None = session_patient(session);
    if patient is not None {
        active_patient: Patient = patient as Patient;
        patient_dto = patient_to_dto(active_patient);
        encounter: Encounter | None = patient_encounter(active_patient);
        if encounter is not None {
            active_encounter: Encounter = encounter as Encounter;
            encounter_dto = encounter_to_dto(active_encounter);
            chunks: list[TranscriptChunk] = [active_encounter->:ContainsChunk:->];
            chunks.sort(key=lambda (chunk: TranscriptChunk) { chunk.sequence; });
            transcript_dtos = [transcript_to_dto(chunk) for chunk in chunks];
            candidates: list[CandidateFact] = [active_encounter->:HasCandidate:->];
            candidates.sort(
                key=lambda (candidate: CandidateFact) { candidate_sequence(candidate); }
            );
            candidate_dtos = [candidate_to_dto(candidate) for candidate in candidates];
            verified_dtos = [
                verified_to_dto(fact)
                for fact in [active_encounter->:HasVerifiedFact:->]
            ];
        }
    }
    return DemoStateDTO(
        patient=patient_dto,
        encounter=encounter_dto,
        transcript=transcript_dtos,
        candidate_facts=candidate_dtos,
        verified_facts=verified_dtos,
        care_gaps=[gap_to_dto(gap) for gap in active_gaps(session)],
        patient_plan=latest_plan(session),
        conflicts=[
            conflict_to_dto(conflict) for conflict in unresolved_conflicts(session)
        ],
        graph_version=session.graph_version
    );
}

def build_care_graph(session: DemoSession) -> CareGraphDTO {
    state: DemoStateDTO = build_demo_state(session);
    return CareGraphDTO(
        patient=state.patient,
        encounter=state.encounter,
        transcript=state.transcript,
        candidate_facts=state.candidate_facts,
        verified_facts=state.verified_facts,
        care_gaps=state.care_gaps,
        patient_plan=state.patient_plan,
        conflicts=state.conflicts,
        relationships=build_relationships(session),
        graph_version=state.graph_version
    );
}

def link_lab_to_follow_up(encounter: Encounter) {
    labs: list[LabOrder] = [];
    follow_ups: list[FollowUp] = [];
    for fact in [encounter->:HasVerifiedFact:->] {
        labs.extend([fact->:RepresentsLabOrder:->]);
        follow_ups.extend([fact->:RepresentsFollowUp:->]);
    }
    if not labs or not follow_ups {
        return;
    }
    for lab in labs {
        if not [lab->:RequiresFollowUp:->] {
            lab +>:RequiresFollowUp():+> follow_ups[0];
        }
    }
}

walker ConsultationIngestWalker(TraceableWalker) {
    has session_id: str = "demo-default",
        include_contradiction: bool = False,
        reports: list[BackendResponse] = [];

    can locate with Root entry {
        if not self.session_id.strip() {
            report failure_response(
                "INVALID_SESSION_ID", "session_id must not be empty.", True, 0
            );
            disengage;
        }
        self.trace(
            "ConsultationIngestWalker",
            "root",
            "Root",
            "HasSession",
            "locate session",
            "queued",
            "Located or created the selected synthetic session."
        );
        visit [root->:HasSession:->[?:DemoSession, id==self.session_id]] else {
            fresh = DemoSession(
                id=self.session_id, synthetic=True, schema_version=2, graph_version=1
            );
            root +>:HasSession():+> fresh;
            visit fresh;
        }
    }

    can enter_session with DemoSession entry {
        self.trace(
            "ConsultationIngestWalker",
            here.id,
            "DemoSession",
            "HasSession",
            "inspect session",
            "entered",
            "Entered the selected synthetic session."
        );
        patients: list[Patient] = [here->:HasPatient:->];
        if len(patients) > 1 {
            response = failure_response(
                "DEMO_STATE_MISMATCH",
                "The session contains more than one patient.",
                False,
                here.graph_version
            );
            response.traversal_trace = self.traversal_trace;
            report response;
            disengage;
        }
        if not patients {
            patient = Patient(
                session_id=here.id,
                id="patient-maya",
                display_name="Maya Rivera",
                preferred_language="Spanish",
                synthetic=True
            );
            own_node(here, patient);
            here +>:HasPatient():+> patient;
            visit patient;
        } else {
            visit patients[0];
        }
    }

    can enter_patient with Patient entry {
        self.trace(
            "ConsultationIngestWalker",
            here.id,
            "Patient",
            "HasPatient",
            "inspect patient",
            "entered",
            "Entered Maya Rivera's synthetic patient node."
        );
        if (
            here.id != "patient-maya"
            or here.display_name != "Maya Rivera"
            or not here.synthetic
        ) {
            session: DemoSession | None = find_session(self.session_id);
            response = failure_response(
                "DEMO_STATE_MISMATCH",
                "Existing patient data does not match the prepared synthetic seed.",
                False,
                session.graph_version if session is not None else 0
            );
            response.traversal_trace = self.traversal_trace;
            report response;
            disengage;
        }
        encounters: list[Encounter] = [here->:HasEncounter:->];
        if len(encounters) > 1 {
            session = find_session(self.session_id);
            response = failure_response(
                "DEMO_STATE_MISMATCH",
                "The synthetic patient contains more than one encounter.",
                False,
                session.graph_version if session is not None else 0
            );
            response.traversal_trace = self.traversal_trace;
            report response;
            disengage;
        }
        session = find_session(self.session_id);
        if session is None {
            report failure_response(
                "DEMO_NOT_LOADED", "The synthetic session disappeared.", False, 0
            );
            disengage;
        }
        if not encounters {
            encounter = Encounter(
                session_id=self.session_id,
                id="encounter-maya-001",
                occurred_at="2026-07-26T18:00:00Z",
                status="candidate_review"
            );
            own_node(session as DemoSession, encounter);
            here +>:HasEncounter():+> encounter;
            visit encounter;
        } else {
            visit encounters[0];
        }
    }

    can enter_encounter with Encounter entry {
        self.trace(
            "ConsultationIngestWalker",
            here.id,
            "Encounter",
            "HasEncounter",
            "seed evidence and candidates",
            "entered",
            "Entered the encounter that owns transcript evidence and candidates."
        );
        session: DemoSession | None = find_session(self.session_id);
        if session is None {
            report failure_response(
                "DEMO_NOT_LOADED", "The synthetic session disappeared.", False, 0
            );
            disengage;
        }
        active_session: DemoSession = session as DemoSession;
        chunks: list[TranscriptChunk] = [here->:ContainsChunk:->];
        if not chunks {
            for seed in prepared_transcript() {
                chunk = TranscriptChunk(
                    session_id=self.session_id,
                    id=seed.id,
                    sequence=seed.sequence,
                    speaker=seed.speaker,
                    text=seed.text
                );
                own_node(active_session, chunk);
                here +>:ContainsChunk():+> chunk;
            }
        } elif not seed_state_is_valid(active_session) {
            response = failure_response(
                "DEMO_STATE_MISMATCH",
                "Existing transcript evidence differs from the immutable prepared seed.",
                False,
                active_session.graph_version
            );
            response.traversal_trace = self.traversal_trace;
            report response;
            disengage;
        }
        _ = seed_prepared_candidate_graph(active_session);
        if self.include_contradiction
        and not add_contradiction_candidate(active_session) {
            response = failure_response(
                "CONTRADICTION_ALREADY_ADDED",
                "The prepared four-week statement already exists.",
                False,
                active_session.graph_version
            );
            response.traversal_trace = self.traversal_trace;
            report response;
            disengage;
        }
        state: DemoStateDTO = build_demo_state(active_session);
        response = success_response(
            active_session.graph_version, "Synthetic consultation loaded."
        );
        response.demo_state = state;
        response.candidate_facts = state.candidate_facts;
        response.traversal_trace = self.traversal_trace;
        report response;
    }
}

walker AIConsultationIngestWalker(TraceableWalker) {
    has session_id: str = "demo-ai",
        reports: list[BackendResponse] = [];

    can locate with Root entry {
        if not self.session_id.strip() {
            report failure_response(
                "INVALID_SESSION_ID", "session_id must not be empty.", True, 0
            );
            disengage;
        }
        visit [root->:HasSession:->[?:DemoSession, id==self.session_id]] else {
            fresh = DemoSession(
                id=self.session_id, synthetic=True, schema_version=2, graph_version=1
            );
            root +>:HasSession():+> fresh;
            visit fresh;
        }
    }

    can ingest_transcript_only with DemoSession entry {
        self.trace(
            "AIConsultationIngestWalker",
            here.id,
            "DemoSession",
            "HasSession",
            "prepare transcript",
            "entered",
            "Prepared an isolated transcript-only session for optional extraction."
        );
        if candidates_for_session(here) or verified_facts_for_session(here) {
            response = failure_response(
                "AI_SESSION_ALREADY_INITIALIZED",
                "Use a fresh synthetic session for optional AI ingestion.",
                True,
                here.graph_version
            );
            response.traversal_trace = self.traversal_trace;
            report response;
            disengage;
        }
        seed_session_graph(here, include_candidates=False);
        state: DemoStateDTO = build_demo_state(here);
        response = success_response(
            here.graph_version,
            "Synthetic transcript loaded for optional typed extraction."
        );
        response.demo_state = state;
        response.traversal_trace = self.traversal_trace;
        report response;
    }
}

def canonical_candidate_id(candidate: ExtractedCandidate) -> str {
    if candidate.category == CandidateCategory.LAB_ORDER {
        return "candidate-lab";
    }
    if candidate.category == CandidateCategory.FOLLOW_UP {
        return "candidate-follow-up";
    }
    if candidate.category == CandidateCategory.MEDICATION_INSTRUCTION {
        return "candidate-medication";
    }
    if candidate.category == CandidateCategory.REFERRAL {
        return "candidate-referral";
    }
    if candidate.category == CandidateCategory.LANGUAGE_PREFERENCE {
        return "candidate-language";
    }
    return f"candidate-{candidate.source_chunk_id}";
}

def candidate_created_at(candidate: ExtractedCandidate) -> str {
    mapping: dict[str, str] = {
        "chunk-1": "2026-07-26T18:00:01Z",
        "chunk-2": "2026-07-26T18:00:02Z",
        "chunk-3": "2026-07-26T18:00:03Z",
        "chunk-4": "2026-07-26T18:00:04Z",
        "chunk-5": "2026-07-26T18:00:05Z"
    };
    return mapping.get(candidate.source_chunk_id, "2026-07-26T18:00:06Z");
}

walker CandidateProposalWalker(TraceableWalker) {
    has session_id: str = "demo-ai",
        proposals: list[ExtractedCandidate] = [],
        created_any: bool = False,
        reports: list[BackendResponse] = [];

    can locate with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        if session is None {
            report failure_response(
                "DEMO_NOT_LOADED",
                "Load the synthetic transcript before adding proposals.",
                True,
                0
            );
            disengage;
        }
        visit session;
    }

    can enter_session with DemoSession entry {
        self.trace(
            "CandidateProposalWalker",
            here.id,
            "DemoSession",
            "HasSession",
            "follow patient relationship",
            "queued",
            "Traversed into the selected session before locating its patient."
        );
        visit [here->:HasPatient:->] else {
            report failure_response(
                "PATIENT_NOT_FOUND",
                "The synthetic patient is missing.",
                False,
                here.graph_version
            );
            disengage;
        }
    }

    can enter_patient with Patient entry {
        self.trace(
            "CandidateProposalWalker",
            here.id,
            "Patient",
            "HasPatient",
            "follow encounter relationship",
            "queued",
            "Traversed from patient to the current encounter."
        );
        visit [here->:HasEncounter:->] else {
            session = find_session(self.session_id);
            report failure_response(
                "ENCOUNTER_NOT_FOUND",
                "The synthetic encounter is missing.",
                False,
                session.graph_version if session is not None else 0
            );
            disengage;
        }
    }

    can add_pending_candidates with Encounter entry {
        self.trace(
            "CandidateProposalWalker",
            here.id,
            "Encounter",
            "HasEncounter",
            "validate and persist proposals",
            "entered",
            "Persisted only validated proposals as unverified candidate nodes."
        );
        session: DemoSession | None = find_session(self.session_id);
        if session is None {
            report failure_response(
                "DEMO_NOT_LOADED", "The synthetic session disappeared.", False, 0
            );
            disengage;
        }
        active_session: DemoSession = session as DemoSession;
        chunks: list[TranscriptChunk] = [here->:ContainsChunk:->];
        for proposal in self.proposals {
            category: CandidateCategory | None = candidate_category(proposal.category);
            if category is None {
                response = failure_response(
                    "AI_UNSUPPORTED_CATEGORY",
                    "A proposal category is outside the allow-list.",
                    True,
                    active_session.graph_version
                );
                response.traversal_trace = self.traversal_trace;
                report response;
                disengage;
            }
            duplicates: list[CandidateFact] = [
                candidate
                for candidate in [here->:HasCandidate:->]
                if (
                    candidate.category == proposal.category
                    and candidate.value == proposal.value
                    and candidate.source_chunk_id == proposal.source_chunk_id
                )
            ];
            if duplicates {
                continue;
            }
            sources: list[TranscriptChunk] = [
                chunk
                for chunk in chunks
                if (
                    chunk.id == proposal.source_chunk_id
                    and proposal.source_text in chunk.text
                )
            ];
            if not sources {
                response = failure_response(
                    "AI_SOURCE_EVIDENCE_MISSING",
                    "A proposal lost transcript provenance before persistence.",
                    True,
                    active_session.graph_version
                );
                response.traversal_trace = self.traversal_trace;
                report response;
                disengage;
            }
            base_id: str = canonical_candidate_id(proposal);
            collision: list[CandidateFact] = [here->:HasCandidate:->[?:CandidateFact, id==base_id]];
            candidate_id: str = (
                f"{base_id}-{proposal.source_chunk_id}" if collision else base_id
            );
            candidate = CandidateFact(
                session_id=self.session_id,
                id=candidate_id,
                category=category as CandidateCategory,
                value=proposal.value,
                confidence=proposal.confidence,
                status=CandidateStatus.PENDING,
                source_chunk_id=proposal.source_chunk_id,
                source_kind="transcript",
                source_text=proposal.source_text,
                created_at=candidate_created_at(proposal)
            );
            own_node(active_session, candidate);
            here +>:HasCandidate():+> candidate;
            candidate +>:ExtractedFrom():+> sources[0];
            self.created_any = True;
        }
        if self.created_any {
            active_session.graph_version += 1;
        }
        state: DemoStateDTO = build_demo_state(active_session);
        response = success_response(
            active_session.graph_version,
            "Validated proposals were stored only as pending candidate facts."
        );
        response.demo_state = state;
        response.candidate_facts = state.candidate_facts;
        response.extracted_candidates = self.proposals;
        response.traversal_trace = self.traversal_trace;
        report response;
    }
}

def create_task(
    session: DemoSession, encounter: Encounter, fact: VerifiedFact, task: CareTask
) -> CareTask {
    own_node(session, task);
    encounter +>:HasTask():+> task;
    task +>:DependsOn():+> fact;
    if task.owner.strip() {
        owner: CareOwner = ensure_owner(session, encounter, task.owner);
        task +>:AssignedTo():+> owner;
    }
    return task;
}

walker VerificationWalker(TraceableWalker) {
    has session_id: str = "demo-default",
        fact_id: str = "",
        decision: str = "",
        clinician_id: str = "",
        reports: list[BackendResponse] = [];

    can locate_session with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        if session is None {
            report failure_response(
                "DEMO_NOT_LOADED",
                "Load the synthetic encounter before verifying facts.",
                True,
                0
            );
            disengage;
        }
        if self.decision.lower() not in [
            VerificationDecision.ACCEPT,
            VerificationDecision.REJECT
        ] {
            report failure_response(
                "INVALID_DECISION",
                "decision must be 'accept' or 'reject'.",
                True,
                session.graph_version
            );
            disengage;
        }
        if not self.clinician_id.strip() {
            report failure_response(
                "INVALID_CLINICIAN_ID",
                "clinician_id must not be empty.",
                True,
                session.graph_version
            );
            disengage;
        }
        visit session;
    }

    can enter_session with DemoSession entry {
        self.trace(
            "VerificationWalker",
            here.id,
            "DemoSession",
            "HasSession",
            "follow patient",
            "queued",
            "Entered only the selected session before verification."
        );
        visit [here->:HasPatient:->] else {
            report failure_response(
                "PATIENT_NOT_FOUND",
                "The selected session has no patient.",
                False,
                here.graph_version
            );
            disengage;
        }
    }

    can enter_patient with Patient entry {
        self.trace(
            "VerificationWalker",
            here.id,
            "Patient",
            "HasPatient",
            "follow encounter",
            "queued",
            "Traversed to the patient's encounter."
        );
        visit [here->:HasEncounter:->] else {
            session = find_session(self.session_id);
            report failure_response(
                "ENCOUNTER_NOT_FOUND",
                "The selected patient has no encounter.",
                False,
                session.graph_version if session is not None else 0
            );
            disengage;
        }
    }

    can locate_candidate with Encounter entry {
        self.trace(
            "VerificationWalker",
            here.id,
            "Encounter",
            "HasEncounter",
            "locate candidate",
            "queued",
            "Searched only candidates connected to this encounter."
        );
        visit [here->:HasCandidate:->[?:CandidateFact, id==self.fact_id]] else {
            session = find_session(self.session_id);
            response = failure_response(
                "FACT_NOT_FOUND",
                f"Candidate fact '{self.fact_id}' was not found in this session.",
                True,
                session.graph_version if session is not None else 0
            );
            response.traversal_trace = self.traversal_trace;
            report response;
            disengage;
        }
    }

    can decide with CandidateFact entry {
        self.trace(
            "VerificationWalker",
            here.id,
            "CandidateFact",
            "HasCandidate",
            "apply clinician decision",
            "entered",
            "Reached the exact candidate through the selected encounter."
        );
        session: DemoSession | None = find_session(self.session_id);
        if session is None {
            report failure_response(
                "DEMO_NOT_LOADED", "The synthetic session disappeared.", False, 0
            );
            disengage;
        }
        active_session: DemoSession = session as DemoSession;
        encounters: list[Encounter] = [here<-:HasCandidate:<-];
        sources: list[TranscriptChunk] = [here->:ExtractedFrom:->];
        source_blocks: list[DocumentTextBlock] = [here->:ExtractedFromDocument:->];
        if (
            len(encounters) != 1
            or encounters[0].session_id != self.session_id
            or (len(sources) + len(source_blocks)) != 1
        ) {
            response = failure_response(
                "PROVENANCE_MISSING",
                "The candidate cannot be verified without one session-local source.",
                False,
                active_session.graph_version
            );
            response.traversal_trace = self.traversal_trace;
            report response;
            disengage;
        }
        encounter: Encounter = encounters[0];
        source_text: str = sources[0].text if sources else source_blocks[0].text;
        normalized: str = self.decision.lower();
        if here.status == CandidateStatus.ACCEPTED {
            if normalized == VerificationDecision.ACCEPT {
                existing: list[VerifiedFact] = [here->:PromotedTo:->];
                response = success_response(
                    active_session.graph_version,
                    "Candidate was already accepted; no duplicate was created."
                );
                if existing {
                    response.verified_fact = verified_to_dto(existing[0]);
                }
                response.traversal_trace = self.traversal_trace;
                report response;
            } else {
                response = failure_response(
                    "FACT_ALREADY_DECIDED",
                    "An accepted candidate cannot later be rejected.",
                    False,
                    active_session.graph_version
                );
                response.traversal_trace = self.traversal_trace;
                report response;
            }
            disengage;
        }
        if here.status == CandidateStatus.REJECTED {
            if normalized == VerificationDecision.REJECT {
                response = success_response(
                    active_session.graph_version,
                    "Candidate was already rejected; no graph change was made."
                );
            } else {
                response = failure_response(
                    "FACT_ALREADY_DECIDED",
                    "A rejected candidate cannot later be accepted.",
                    False,
                    active_session.graph_version
                );
            }
            response.traversal_trace = self.traversal_trace;
            report response;
            disengage;
        }
        clinicians: list[ClinicianIdentity] = [active_session->:HasClinician:->[?:ClinicianIdentity, id==self.clinician_id]];
        clinician: ClinicianIdentity;
        created_ids: list[str] = [];
        if clinicians {
            clinician = clinicians[0];
        } else {
            clinician = ClinicianIdentity(
                session_id=self.session_id, id=self.clinician_id
            );
            own_node(active_session, clinician);
            active_session +>:HasClinician():+> clinician;
            created_ids.append(clinician.id);
        }
        active_session.graph_version += 1;
        event = VerificationEvent(
            session_id=self.session_id,
            id=f"verification-{here.id}",
            candidate_id=here.id,
            decision=(
                VerificationDecision.ACCEPT
                    if normalized == VerificationDecision.ACCEPT
                    else VerificationDecision.REJECT
            ),
            clinician_id=self.clinician_id,
            decided_at=deterministic_timestamp(active_session.graph_version)
        );
        own_node(active_session, event);
        here +>:HasVerificationEvent():+> event;
        event +>:DecisionBy():+> clinician;
        created_ids.append(event.id);
        if normalized == VerificationDecision.REJECT {
            event +>:RejectedFrom():+> here;
            here.status = CandidateStatus.REJECTED;
            response = success_response(
                active_session.graph_version,
                "Candidate rejected; no verified record was created."
            );
            response.created_graph_ids = created_ids;
            response.traversal_trace = self.traversal_trace;
            report response;
            disengage;
        }
        verified = VerifiedFact(
            session_id=self.session_id,
            id=f"verified-{here.id}",
            category=here.category,
            value=here.value,
            verified_by=self.clinician_id,
            verified_at=deterministic_timestamp(active_session.graph_version),
            visible_to_patient=True,
            source_chunk_id=here.source_chunk_id,
            source_kind=here.source_kind,
            source_artifact_id=here.source_artifact_id,
            source_text_block_id=here.source_text_block_id,
            source_region=here.source_region,
            source_text=source_text
        );
        own_node(active_session, verified);
        encounter +>:HasVerifiedFact():+> verified;
        here +>:PromotedTo():+> verified;
        verified +>:VerifiedFrom():+> here;
        verified +>:VerifiedBy():+> clinician;
        created_ids.append(verified.id);
        if here.category == CandidateCategory.LAB_ORDER {
            parts: list[str] = here.value.split(";");
            test_name: str = parts[0].strip();
            due_window: str = (
                parts[1].strip().removeprefix("due ").strip() if len(parts) > 1 else ""
            );
            lab_owner: str = (
                "clinic-lab-team" if here.source_kind == "document" else ""
            );
            lab = LabOrder(
                session_id=self.session_id,
                id=f"lab-{verified.id}",
                test_name=test_name,
                due_window=due_window,
                owner=lab_owner,
                status="ordered",
                source_fact_id=verified.id
            );
            own_node(active_session, lab);
            verified +>:RepresentsLabOrder():+> lab;
            task: CareTask = create_task(
                active_session,
                encounter,
                verified,
                CareTask(
                    session_id=self.session_id,
                    id=f"task-{verified.id}",
                    task_type="lab_coordination",
                    title=f"Coordinate {test_name}",
                    owner=lab_owner,
                    due_date=due_window,
                    status="open"
                )
            );
            lab +>:HasLabTask():+> task;
            created_ids.extend([lab.id, task.id]);
        } elif here.category == CandidateCategory.FOLLOW_UP {
            period: str = here.value.removeprefix("return in ").strip();
            follow_up = FollowUp(
                session_id=self.session_id,
                id=f"follow-up-{verified.id}",
                period_text=period,
                appointment_date="",
                owner="clinic-follow-up-team",
                status="pending",
                source_fact_id=verified.id
            );
            own_node(active_session, follow_up);
            verified +>:RepresentsFollowUp():+> follow_up;
            task = create_task(
                active_session,
                encounter,
                verified,
                CareTask(
                    session_id=self.session_id,
                    id=f"task-{verified.id}",
                    task_type="follow_up_scheduling",
                    title="Schedule follow-up appointment",
                    owner="clinic-follow-up-team",
                    due_date="",
                    status="open"
                )
            );
            follow_up +>:HasFollowUpTask():+> task;
            created_ids.extend([follow_up.id, task.id]);
        } elif here.category == CandidateCategory.MEDICATION_INSTRUCTION {
            medication = MedicationInstruction(
                session_id=self.session_id,
                id=f"medication-{verified.id}",
                instruction_text=source_text,
                timing_text="Follow the timing on the existing prescription.",
                active=True,
                source_fact_id=verified.id
            );
            own_node(active_session, medication);
            verified +>:RepresentsMedication():+> medication;
            task = create_task(
                active_session,
                encounter,
                verified,
                CareTask(
                    session_id=self.session_id,
                    id=f"task-{verified.id}",
                    task_type="medication_documentation",
                    title="Follow the existing prescription",
                    owner="patient",
                    due_date="",
                    status="documented"
                )
            );
            medication +>:HasMedicationTask():+> task;
            created_ids.extend([medication.id, task.id]);
        } elif here.category == CandidateCategory.REFERRAL {
            referral = Referral(
                session_id=self.session_id,
                id=f"referral-{verified.id}",
                destination=here.value,
                owner="clinic-referral-team",
                status="referred",
                source_fact_id=verified.id
            );
            own_node(active_session, referral);
            verified +>:RepresentsReferral():+> referral;
            task = create_task(
                active_session,
                encounter,
                verified,
                CareTask(
                    session_id=self.session_id,
                    id=f"task-{verified.id}",
                    task_type="referral_coordination",
                    title=f"Coordinate referral to {here.value}",
                    owner="clinic-referral-team",
                    due_date="",
                    status="open"
                )
            );
            referral +>:HasReferralTask():+> task;
            created_ids.extend([referral.id, task.id]);
        }
        here.status = CandidateStatus.ACCEPTED;
        link_lab_to_follow_up(encounter);
        invalidate_current_outputs(active_session);
        response = success_response(
            active_session.graph_version,
            "Candidate accepted and promoted by VerificationWalker."
        );
        response.verified_fact = verified_to_dto(verified);
        response.created_graph_ids = created_ids;
        response.traversal_trace = self.traversal_trace;
        report response;
    }
}

def ensure_gap(
    session: DemoSession,
    encounter: Encounter,
    gap_id: str,
    gap_type: GapType,
    message: str,
    fact: VerifiedFact
) -> bool {
    existing: list[CareGap] = [encounter->:HasGap:->[?:CareGap, id==gap_id]];
    if existing {
        return False;
    }
    gap = CareGap(
        session_id=session.id,
        id=gap_id,
        gap_type=gap_type,
        status=GapStatus.OPEN,
        message=message,
        related_fact_ids=[fact.id],
        resolved=False
    );
    own_node(session, gap);
    encounter +>:HasGap():+> gap;
    gap +>:GapForFact():+> fact;
    return True;
}

walker CareGapWalker(TraceableWalker) {
    has session_id: str = "demo-default",
        created_any: bool = False,
        specific_owner_missing_fact_ids: list[str] = [],
        reports: list[BackendResponse] = [];

    can locate with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        if session is None {
            report failure_response(
                "DEMO_NOT_LOADED",
                "Load the synthetic encounter before checking care gaps.",
                True,
                0
            );
            disengage;
        }
        visit session;
    }

    can enter_session with DemoSession entry {
        self.trace(
            "CareGapWalker",
            here.id,
            "DemoSession",
            "HasSession",
            "follow patient",
            "queued",
            "Entered the selected session and followed its patient relationship."
        );
        visit [here->:HasPatient:->];
    }

    can enter_patient with Patient entry {
        self.trace(
            "CareGapWalker",
            here.id,
            "Patient",
            "HasPatient",
            "follow encounter",
            "queued",
            "Entered Maya Rivera and followed HasEncounter."
        );
        visit [here->:HasEncounter:->];
    }

    can enter_encounter with Encounter entry {
        self.trace(
            "CareGapWalker",
            here.id,
            "Encounter",
            "HasEncounter",
            "follow verified facts",
            "queued",
            "Entered the encounter and traversed only verified obligations."
        );
        visit [here->:HasVerifiedFact:->] else {
            session = find_session(self.session_id);
            response = failure_response(
                "NO_VERIFIED_FACTS",
                "Verify at least one candidate before checking care gaps.",
                True,
                session.graph_version if session is not None else 0
            );
            response.traversal_trace = self.traversal_trace;
            report response;
            disengage;
        }
    }

    can enter_fact with VerifiedFact entry {
        self.trace(
            "CareGapWalker",
            here.id,
            "VerifiedFact",
            "HasVerifiedFact",
            "follow specialized obligation",
            "queued",
            "Reached a clinician-approved fact and followed its typed obligation edge."
        );
        visit [here->:RepresentsLabOrder:->];
        visit [here->:RepresentsFollowUp:->];
        visit [here->:RepresentsReferral:->];
        visit [here->:RepresentsMedication:->];
    }

    can check_lab with LabOrder entry {
        tasks: list[CareTask] = [here->:HasLabTask:->];
        assigned: bool = bool(tasks and [tasks[0]->:AssignedTo:->]);
        self.trace(
            "CareGapWalker",
            here.id,
            "LabOrder",
            "RepresentsLabOrder",
            "inspect owner relationship",
            "assigned" if assigned else "missing",
            (
                "The lab task has an AssignedTo relationship."
                    if assigned
                    else "No responsible owner relationship was found for the lab."
            )
        );
        facts: list[VerifiedFact] = [here<-:RepresentsLabOrder:<-];
        session: DemoSession | None = find_session(self.session_id);
        encounter: Encounter | None = session_encounter(session as DemoSession)
            if session is not None
            else None;
        if not assigned and facts and session is not None and encounter is not None {
            self.specific_owner_missing_fact_ids.append(facts[0].id);
            self.created_any = ensure_gap(
                session as DemoSession,
                encounter as Encounter,
                f"gap-lab-owner-{facts[0].id}",
                GapType.LAB_OWNER_MISSING,
                "The blood test does not have a responsible owner.",
                facts[0]
            )
            or self.created_any;
        }
        visit tasks;
    }

    can check_follow_up with FollowUp entry {
        missing: bool = not here.appointment_date.strip();
        self.trace(
            "CareGapWalker",
            here.id,
            "FollowUp",
            "RepresentsFollowUp",
            "inspect appointment date",
            "missing" if missing else "scheduled",
            (
                "The follow-up has no scheduled appointment date."
                    if missing
                    else "The follow-up appointment date is recorded."
            )
        );
        facts: list[VerifiedFact] = [here<-:RepresentsFollowUp:<-];
        session: DemoSession | None = find_session(self.session_id);
        encounter: Encounter | None = session_encounter(session as DemoSession)
            if session is not None
            else None;
        if missing and facts and session is not None and encounter is not None {
            self.created_any = ensure_gap(
                session as DemoSession,
                encounter as Encounter,
                f"gap-follow-up-date-{facts[0].id}",
                GapType.FOLLOW_UP_DATE_MISSING,
                "The follow-up period is recorded but no appointment date is scheduled.",
                facts[0]
            )
            or self.created_any;
        }
        visit [here->:HasFollowUpTask:->];
    }

    can check_referral with Referral entry {
        tasks: list[CareTask] = [here->:HasReferralTask:->];
        assigned: bool = bool(tasks and [tasks[0]->:AssignedTo:->]);
        self.trace(
            "CareGapWalker",
            here.id,
            "Referral",
            "RepresentsReferral",
            "inspect assignment",
            "assigned" if assigned else "missing",
            "Checked the referral task's AssignedTo relationship."
        );
        facts: list[VerifiedFact] = [here<-:RepresentsReferral:<-];
        session: DemoSession | None = find_session(self.session_id);
        encounter: Encounter | None = session_encounter(session as DemoSession)
            if session is not None
            else None;
        if not assigned and facts and session is not None and encounter is not None {
            self.specific_owner_missing_fact_ids.append(facts[0].id);
            self.created_any = ensure_gap(
                session as DemoSession,
                encounter as Encounter,
                f"gap-referral-owner-{facts[0].id}",
                GapType.REFERRAL_OWNER_MISSING,
                "The referral does not have a responsible owner.",
                facts[0]
            )
            or self.created_any;
        }
        visit tasks;
    }

    can check_medication with MedicationInstruction entry {
        missing: bool = (
            not here.instruction_text.strip() or not here.timing_text.strip()
        );
        self.trace(
            "CareGapWalker",
            here.id,
            "MedicationInstruction",
            "RepresentsMedication",
            "inspect documentation",
            "missing" if missing else "complete",
            "Checked required existing-prescription documentation fields."
        );
        facts: list[VerifiedFact] = [here<-:RepresentsMedication:<-];
        session: DemoSession | None = find_session(self.session_id);
        encounter: Encounter | None = session_encounter(session as DemoSession)
            if session is not None
            else None;
        if missing and facts and session is not None and encounter is not None {
            self.created_any = ensure_gap(
                session as DemoSession,
                encounter as Encounter,
                f"gap-medication-documentation-{facts[0].id}",
                GapType.MEDICATION_DOCUMENTATION_MISSING,
                "The approved medication instruction is missing documentation fields.",
                facts[0]
            )
            or self.created_any;
        }
        visit [here->:HasMedicationTask:->];
    }

    can check_task with CareTask entry {
        owners: list[CareOwner] = [here->:AssignedTo:->];
        facts: list[VerifiedFact] = [here->:DependsOn:->];
        source_id: str = facts[0].id if facts else "";
        missing: bool = (
            here.status not in ["resolved", "documented"]
            and not owners
            and source_id not in self.specific_owner_missing_fact_ids
        );
        self.trace(
            "CareGapWalker",
            here.id,
            "CareTask",
            "Has*Task",
            "inspect task owner",
            "missing" if missing else "complete-or-covered",
            "Checked the task owner without duplicating an obligation-specific gap."
        );
        session: DemoSession | None = find_session(self.session_id);
        encounter: Encounter | None = session_encounter(session as DemoSession)
            if session is not None
            else None;
        if missing and facts and session is not None and encounter is not None {
            self.created_any = ensure_gap(
                session as DemoSession,
                encounter as Encounter,
                f"gap-task-owner-{here.id}",
                GapType.TASK_OWNER_MISSING,
                "An unresolved care task does not have an owner.",
                facts[0]
            )
            or self.created_any;
        }
    }

    can finish with DemoSession exit {
        if self.created_any {
            here.graph_version += 1;
            invalidate_current_outputs(here);
        }
        response = success_response(
            here.graph_version, "Documentation completeness check completed."
        );
        response.care_gaps = [gap_to_dto(gap) for gap in active_gaps(here)];
        response.traversal_trace = self.traversal_trace;
        report response;
    }
}

def resolve_task_and_gap(
    session: DemoSession,
    encounter: Encounter,
    gap: CareGap,
    task: CareTask,
    resolution: str,
    owner_id: str,
    due_date: str
) -> GapResolutionEvent {
    owner: CareOwner = ensure_owner(session, encounter, owner_id);
    assign_task(task, owner);
    task.due_date = due_date;
    task.status = "resolved";
    session.graph_version += 1;
    event = GapResolutionEvent(
        session_id=session.id,
        id=f"resolution-{gap.id}-{session.graph_version}",
        gap_id=gap.id,
        resolution=resolution,
        owner=owner_id,
        due_date=due_date,
        recorded_at=deterministic_timestamp(session.graph_version)
    );
    own_node(session, event);
    gap +>:ResolvedBy():+> event;
    event +>:ResolutionUpdates():+> task;
    gap.status = GapStatus.RESOLVED;
    gap.resolved = True;
    gap.resolution = resolution;
    gap.owner = owner_id;
    gap.due_date = due_date;
    invalidate_current_outputs(session);
    return event;
}

walker GapResolutionWalker(TraceableWalker) {
    has session_id: str = "demo-default",
        gap_id: str = "",
        resolution: str = "",
        owner: str = "",
        due_date: str = "",
        selected_gap: CareGap | None = None,
        reports: list[BackendResponse] = [];

    can locate with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        if session is None {
            report failure_response(
                "DEMO_NOT_LOADED",
                "Load the synthetic encounter before resolving gaps.",
                True,
                0
            );
            disengage;
        }
        if not self.resolution.strip() {
            report failure_response(
                "INVALID_RESOLUTION",
                "resolution must not be empty.",
                True,
                session.graph_version
            );
            disengage;
        }
        if not self.owner.strip() {
            report failure_response(
                "INVALID_OWNER", "owner must not be empty.", True, session.graph_version
            );
            disengage;
        }
        if not self.due_date.strip() {
            report failure_response(
                "INVALID_DUE_DATE",
                "due_date must not be empty.",
                True,
                session.graph_version
            );
            disengage;
        }
        visit session;
    }

    can enter_session with DemoSession entry {
        self.trace(
            "GapResolutionWalker",
            here.id,
            "DemoSession",
            "HasSession",
            "follow patient",
            "queued",
            "Entered only the selected session."
        );
        visit [here->:HasPatient:->];
    }

    can enter_patient with Patient entry {
        self.trace(
            "GapResolutionWalker",
            here.id,
            "Patient",
            "HasPatient",
            "follow encounter",
            "queued",
            "Traversed to the selected patient's encounter."
        );
        visit [here->:HasEncounter:->];
    }

    can locate_gap with Encounter entry {
        self.trace(
            "GapResolutionWalker",
            here.id,
            "Encounter",
            "HasEncounter",
            "locate gap",
            "queued",
            "Searched only care gaps connected to this encounter."
        );
        visit [here->:HasGap:->[?:CareGap, id==self.gap_id]] else {
            session = find_session(self.session_id);
            response = failure_response(
                "GAP_NOT_FOUND",
                f"Care gap '{self.gap_id}' was not found in this session.",
                True,
                session.graph_version if session is not None else 0
            );
            response.traversal_trace = self.traversal_trace;
            report response;
            disengage;
        }
    }

    can enter_gap with CareGap entry {
        self.trace(
            "GapResolutionWalker",
            here.id,
            "CareGap",
            "HasGap",
            "follow supporting fact",
            "queued",
            "Located the persisted gap and followed its supporting verified fact."
        );
        session: DemoSession | None = find_session(self.session_id);
        if here.resolved {
            same: bool = (
                here.resolution == self.resolution
                and here.owner == self.owner
                and here.due_date == self.due_date
            );
            response = (
                success_response(
                    session.graph_version if session is not None else 0,
                    "The care gap was already resolved with the same values."
                )
                    if same
                    else failure_response(
                        "GAP_ALREADY_RESOLVED",
                        "The care gap is already resolved with different values.",
                        False,
                        session.graph_version if session is not None else 0
                    )
            );
            response.traversal_trace = self.traversal_trace;
            report response;
            disengage;
        }
        self.selected_gap = here;
        visit [here->:GapForFact:->] else {
            response = failure_response(
                "GAP_PROVENANCE_MISSING",
                "The care gap has no supporting verified fact.",
                False,
                session.graph_version if session is not None else 0
            );
            response.traversal_trace = self.traversal_trace;
            report response;
            disengage;
        }
    }

    can enter_fact with VerifiedFact entry {
        self.trace(
            "GapResolutionWalker",
            here.id,
            "VerifiedFact",
            "GapForFact",
            "follow affected obligation",
            "queued",
            "Followed the gap to its exact approved obligation."
        );
        if self.selected_gap is None {
            disengage;
        }
        gap: CareGap = self.selected_gap as CareGap;
        if gap.gap_type == GapType.LAB_OWNER_MISSING {
            visit [here->:RepresentsLabOrder:->];
        } elif gap.gap_type == GapType.FOLLOW_UP_DATE_MISSING {
            visit [here->:RepresentsFollowUp:->];
        } elif gap.gap_type == GapType.REFERRAL_OWNER_MISSING {
            visit [here->:RepresentsReferral:->];
        } elif gap.gap_type == GapType.MEDICATION_DOCUMENTATION_MISSING {
            visit [here->:RepresentsMedication:->];
        } else {
            tasks: list[CareTask] = [here<-:DependsOn:<-];
            if tasks {
                self.finish_resolution(tasks[0], here);
            }
        }
    }

    def finish_resolution(task: CareTask, fact: VerifiedFact) {
        session: DemoSession | None = find_session(self.session_id);
        encounter: Encounter | None = session_encounter(session as DemoSession)
            if session is not None
            else None;
        if (
            session is None
            or encounter is None
            or self.selected_gap is None
            or fact.session_id != self.session_id
        ) {
            response = failure_response(
                "CROSS_SESSION_RESOURCE",
                "The gap or supporting resource is outside the selected session.",
                False,
                session.graph_version if session is not None else 0
            );
            response.traversal_trace = self.traversal_trace;
            report response;
            disengage;
        }
        event: GapResolutionEvent = resolve_task_and_gap(
            session as DemoSession,
            encounter as Encounter,
            self.selected_gap as CareGap,
            task,
            self.resolution,
            self.owner,
            self.due_date
        );
        response = success_response(
            (session as DemoSession).graph_version,
            "Care gap resolved with an append-only graph event."
        );
        response.demo_state = build_demo_state(session as DemoSession);
        response.care_gaps = [
            gap_to_dto(gap) for gap in active_gaps(session as DemoSession)
        ];
        response.created_graph_ids = [event.id, task.id];
        response.traversal_trace = self.traversal_trace;
        report response;
        disengage;
    }

    can resolve_lab with LabOrder entry {
        self.trace(
            "GapResolutionWalker",
            here.id,
            "LabOrder",
            "RepresentsLabOrder",
            "assign lab task",
            "updated",
            "Updated the actual lab obligation and its assigned task."
        );
        here.owner = self.owner;
        tasks: list[CareTask] = [here->:HasLabTask:->];
        facts: list[VerifiedFact] = [here<-:RepresentsLabOrder:<-];
        if tasks and facts {
            self.finish_resolution(tasks[0], facts[0]);
        }
    }

    can resolve_follow_up with FollowUp entry {
        self.trace(
            "GapResolutionWalker",
            here.id,
            "FollowUp",
            "RepresentsFollowUp",
            "schedule follow-up",
            "updated",
            "Recorded the appointment date on the actual follow-up obligation."
        );
        here.appointment_date = self.due_date;
        here.owner = self.owner;
        here.status = "scheduled";
        tasks: list[CareTask] = [here->:HasFollowUpTask:->];
        facts: list[VerifiedFact] = [here<-:RepresentsFollowUp:<-];
        if tasks and facts {
            self.finish_resolution(tasks[0], facts[0]);
        }
    }

    can resolve_referral with Referral entry {
        self.trace(
            "GapResolutionWalker",
            here.id,
            "Referral",
            "RepresentsReferral",
            "assign referral task",
            "updated",
            "Assigned the actual referral obligation."
        );
        here.owner = self.owner;
        tasks: list[CareTask] = [here->:HasReferralTask:->];
        facts: list[VerifiedFact] = [here<-:RepresentsReferral:<-];
        if tasks and facts {
            self.finish_resolution(tasks[0], facts[0]);
        }
    }

    can resolve_medication with MedicationInstruction entry {
        self.trace(
            "GapResolutionWalker",
            here.id,
            "MedicationInstruction",
            "RepresentsMedication",
            "complete documentation",
            "updated",
            "Completed only the missing documentation field without changing treatment."
        );
        here.timing_text = self.resolution;
        tasks: list[CareTask] = [here->:HasMedicationTask:->];
        facts: list[VerifiedFact] = [here<-:RepresentsMedication:<-];
        if tasks and facts {
            self.finish_resolution(tasks[0], facts[0]);
        }
    }
}

def checklist_text(text: str, source_fact_id: str) -> str {
    return f"{text} [source: {source_fact_id}]";
}

def localized_due_window(due_window: str, language: str) -> str {
    if language.lower() == "spanish" and due_window == "this week" {
        return "esta semana";
    }
    return due_window;
}

walker PatientPlanWalker(TraceableWalker) {
    has session_id: str = "demo-default",
        language: str = "English",
        medications: list[PlanItemDTO] = [],
        labs: list[PlanItemDTO] = [],
        referrals: list[PlanItemDTO] = [],
        follow_ups: list[PlanItemDTO] = [],
        ordered_items: list[PlanItemDTO] = [],
        checklist: list[str] = [],
        source_fact_ids: list[str] = [],
        reports: list[BackendResponse] = [];

    can locate with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        if session is None {
            report failure_response(
                "DEMO_NOT_LOADED",
                "Load the synthetic encounter before generating a plan.",
                True,
                0
            );
            disengage;
        }
        if self.language.lower() not in ["english", "spanish"] {
            report failure_response(
                "UNSUPPORTED_LANGUAGE",
                "P0 supports English and Spanish only.",
                True,
                session.graph_version
            );
            disengage;
        }
        visit session;
    }

    can enter_session with DemoSession entry {
        self.trace(
            "PatientPlanWalker",
            here.id,
            "DemoSession",
            "HasSession",
            "check active gaps",
            "clear" if not active_gaps(here) else "blocked",
            "Checked the selected session for unresolved administrative gaps."
        );
        if active_gaps(here) {
            response = failure_response(
                "ACTIVE_CARE_GAPS",
                "Resolve active documentation gaps before generating the plan.",
                True,
                here.graph_version
            );
            response.traversal_trace = self.traversal_trace;
            report response;
            disengage;
        }
        visit [here->:HasPatient:->];
    }

    can enter_patient with Patient entry {
        self.trace(
            "PatientPlanWalker",
            here.id,
            "Patient",
            "HasPatient",
            "follow encounter",
            "queued",
            "Entered the patient and followed the encounter containing approved facts."
        );
        visit [here->:HasEncounter:->];
    }

    can enter_encounter with Encounter entry {
        self.trace(
            "PatientPlanWalker",
            here.id,
            "Encounter",
            "HasEncounter",
            "follow verified facts",
            "queued",
            "Traversed only facts connected through HasVerifiedFact."
        );
        visit [here->:HasVerifiedFact:->];
    }

    can enter_fact with VerifiedFact entry {
        session: DemoSession | None = find_session(self.session_id);
        allowed: bool = (
            session is not None
            and here.visible_to_patient
            and not fact_is_conflicted(session as DemoSession, here.id)
            and not has_competing_follow_up(session as DemoSession, here)
        );
        self.trace(
            "PatientPlanWalker",
            here.id,
            "VerifiedFact",
            "HasVerifiedFact",
            "apply patient visibility filter",
            "included" if allowed else "excluded",
            "Included only approved, visible, non-conflicting evidence."
        );
        if not allowed {
            skip;
        }
        visit [here->:RepresentsLabOrder:->];
        visit [here->:RepresentsFollowUp:->];
        visit [here->:RepresentsMedication:->];
        visit [here->:RepresentsReferral:->];
    }

    def add_item(item: PlanItemDTO) {
        self.ordered_items.append(item);
        self.checklist.append(checklist_text(item.text, item.source_fact_id));
        if item.source_fact_id not in self.source_fact_ids {
            self.source_fact_ids.append(item.source_fact_id);
        }
    }

    can collect_lab with LabOrder entry {
        facts: list[VerifiedFact] = [here<-:RepresentsLabOrder:<-];
        if not facts {
            skip;
        }
        tasks: list[CareTask] = [here->:HasLabTask:->];
        owners: list[CareOwner] = [tasks[0]->:AssignedTo:->] if tasks else [];
        owner: str = owners[0].display_name if owners else here.owner;
        due: str = localized_due_window(here.due_window, self.language);
        text: str = (
            f"Complete the {here.test_name} {due}."
                if self.language.lower() == "english"
                else f"Complete el análisis de sangre {due}."
        );
        item = PlanItemDTO(
            kind="lab",
            text=text,
            owner=owner,
            due_date=here.due_window,
            status=here.status,
            source_fact_id=facts[0].id
        );
        self.labs.append(item);
        self.add_item(item);
        self.trace(
            "PatientPlanWalker",
            here.id,
            "LabOrder",
            "RepresentsLabOrder",
            "build checklist item",
            "added",
            "Built the laboratory instruction from stored obligation fields."
        );
    }

    can collect_follow_up with FollowUp entry {
        facts: list[VerifiedFact] = [here<-:RepresentsFollowUp:<-];
        if not facts {
            skip;
        }
        text: str = (
            f"Return in {here.period_text}; appointment: {here.appointment_date}."
                if self.language.lower() == "english"
                else f"Regrese en {here.period_text}; cita: {here.appointment_date}."
        );
        item = PlanItemDTO(
            kind="follow_up",
            text=text,
            owner=here.owner,
            due_date=here.appointment_date,
            status=here.status,
            source_fact_id=facts[0].id
        );
        self.follow_ups.append(item);
        self.add_item(item);
        self.trace(
            "PatientPlanWalker",
            here.id,
            "FollowUp",
            "RepresentsFollowUp",
            "build checklist item",
            "added",
            "Built the follow-up instruction from stored period and appointment fields."
        );
    }

    can collect_medication with MedicationInstruction entry {
        facts: list[VerifiedFact] = [here<-:RepresentsMedication:<-];
        if not facts {
            skip;
        }
        text: str = (
            here.instruction_text
                if self.language.lower() == "english"
                else (
                    "Continúe su medicamento actual exactamente como aparece "
                    "en su receta existente."
                )
        );
        item = PlanItemDTO(
            kind="medication",
            text=text,
            owner="patient",
            due_date=here.timing_text,
            status="active" if here.active else "inactive",
            source_fact_id=facts[0].id
        );
        self.medications.append(item);
        self.add_item(item);
        self.trace(
            "PatientPlanWalker",
            here.id,
            "MedicationInstruction",
            "RepresentsMedication",
            "build checklist item",
            "added",
            "Copied the approved existing-prescription instruction without alteration."
        );
    }

    can collect_referral with Referral entry {
        facts: list[VerifiedFact] = [here<-:RepresentsReferral:<-];
        if not facts {
            skip;
        }
        text: str = (
            f"Your referral is to a {here.destination}."
                if self.language.lower() == "english"
                else "Su remisión es a un consejero comunitario de nutrición."
        );
        item = PlanItemDTO(
            kind="referral",
            text=text,
            owner=here.owner,
            due_date="",
            status=here.status,
            source_fact_id=facts[0].id
        );
        self.referrals.append(item);
        self.add_item(item);
        self.trace(
            "PatientPlanWalker",
            here.id,
            "Referral",
            "RepresentsReferral",
            "build checklist item",
            "added",
            "Built the referral instruction from the approved destination."
        );
    }

    can finish with DemoSession exit {
        if not self.source_fact_ids {
            response = failure_response(
                "NO_VISIBLE_FACTS",
                "No approved, patient-visible facts are available.",
                True,
                here.graph_version
            );
            response.traversal_trace = self.traversal_trace;
            report response;
            disengage;
        }
        patient: Patient | None = session_patient(here);
        encounter: Encounter | None = session_encounter(here);
        if patient is None or encounter is None {
            response = failure_response(
                "PATIENT_NOT_FOUND",
                "The synthetic patient or encounter is missing.",
                False,
                here.graph_version
            );
            response.traversal_trace = self.traversal_trace;
            report response;
            disengage;
        }
        for old_brief in [(patient as Patient)->:HasBrief:->] {
            if old_brief.language.lower() == self.language.lower() {
                old_brief.current = False;
                for old_item in [old_brief->:HasChecklistItem:->] {
                    old_item.current = False;
                }
            }
        }
        here.graph_version += 1;
        for index in range(len(self.ordered_items)) {
            self.ordered_items[index].id = (
                f"checklist-{here.id}-{here.graph_version}-{index + 1}"
            );
        }
        brief = PatientBrief(
            session_id=here.id,
            id=f"brief-{here.id}-{here.graph_version}",
            patient_id=(patient as Patient).id,
            language=self.language,
            medications=self.medications,
            labs=self.labs,
            referrals=self.referrals,
            follow_ups=self.follow_ups,
            checklist=self.checklist,
            source_fact_ids=self.source_fact_ids,
            approved_only=True,
            current=True,
            created_at=deterministic_timestamp(here.graph_version)
        );
        own_node(here, brief);
        (patient as Patient) +>:HasBrief():+> brief;
        brief +>:GeneratedFrom():+> (encounter as Encounter);
        created_ids: list[str] = [brief.id];
        for index in range(len(self.ordered_items)) {
            item: PlanItemDTO = self.ordered_items[index];
            checklist_item = ChecklistItem(
                session_id=here.id,
                id=item.id,
                kind=item.kind,
                text=item.text,
                order=index + 1,
                source_fact_id=item.source_fact_id,
                current=True
            );
            own_node(here, checklist_item);
            brief +>:HasChecklistItem():+> checklist_item;
            facts: list[VerifiedFact] = [(encounter as Encounter)->:HasVerifiedFact:->[?:VerifiedFact, id==item.source_fact_id]];
            if facts {
                checklist_item +>:SupportedBy():+> facts[0];
                facts[0] +>:VisibleToPatient():+> brief;
            }
            created_ids.append(checklist_item.id);
        }
        response = success_response(
            here.graph_version, "Patient brief generated from approved graph evidence."
        );
        response.patient_plan = brief_to_plan(brief);
        response.created_graph_ids = created_ids;
        response.traversal_trace = self.traversal_trace;
        report response;
    }
}

def ensure_verified_conflict(
    session: DemoSession,
    encounter: Encounter,
    spec: ConflictDTO,
    left: VerifiedFact,
    right: VerifiedFact
) -> bool {
    existing: list[Conflict] = [encounter->:HasConflict:->[?:Conflict, id==spec.id]];
    if existing {
        return False;
    }
    kind: ConflictType = (
        ConflictType.CONTRADICTORY_FOLLOW_UP_PERIOD
            if spec.conflict_type == ConflictType.CONTRADICTORY_FOLLOW_UP_PERIOD
            else (
                ConflictType.DUPLICATE_VERIFIED_FACT
                    if spec.conflict_type == ConflictType.DUPLICATE_VERIFIED_FACT
                    else ConflictType.SUPERSEDED_INSTRUCTION
            )
    );
    conflict = Conflict(
        session_id=session.id,
        id=spec.id,
        left_fact_id=spec.left_fact_id,
        right_fact_id=spec.right_fact_id,
        conflict_type=kind,
        explanation=spec.explanation,
        resolved=False,
        left_source_text=spec.left_source_text,
        right_source_text=spec.right_source_text
    );
    own_node(session, conflict);
    encounter +>:HasConflict():+> conflict;
    conflict +>:ConflictEvidence(role="left"):+> left;
    conflict +>:ConflictEvidence(role="right"):+> right;
    return True;
}

def ensure_candidate_conflict(
    session: DemoSession,
    encounter: Encounter,
    spec: ConflictDTO,
    left: VerifiedFact,
    right: CandidateFact
) -> bool {
    existing: list[Conflict] = [encounter->:HasConflict:->[?:Conflict, id==spec.id]];
    if existing {
        return False;
    }
    conflict = Conflict(
        session_id=session.id,
        id=spec.id,
        left_fact_id=spec.left_fact_id,
        right_fact_id=spec.right_fact_id,
        conflict_type=ConflictType.UNVERIFIED_ATTEMPTED_CHANGE,
        explanation=spec.explanation,
        resolved=False,
        left_source_text=spec.left_source_text,
        right_source_text=spec.right_source_text
    );
    own_node(session, conflict);
    encounter +>:HasConflict():+> conflict;
    conflict +>:ConflictEvidence(role="approved"):+> left;
    conflict +>:CandidateConflictEvidence(role="unverified"):+> right;
    return True;
}

walker EvidenceAuditWalker(TraceableWalker) {
    has session_id: str = "demo-default",
        facts: list[VerifiedFact] = [],
        candidates: list[CandidateFact] = [],
        created_any: bool = False,
        reports: list[BackendResponse] = [];

    can locate with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        if session is None {
            report failure_response(
                "DEMO_NOT_LOADED",
                "Load the synthetic encounter before running an audit.",
                True,
                0
            );
            disengage;
        }
        visit session;
    }

    can enter_session with DemoSession entry {
        self.trace(
            "EvidenceAuditWalker",
            here.id,
            "DemoSession",
            "HasSession",
            "follow patient",
            "queued",
            "Entered only the selected session."
        );
        visit [here->:HasPatient:->];
    }

    can enter_patient with Patient entry {
        self.trace(
            "EvidenceAuditWalker",
            here.id,
            "Patient",
            "HasPatient",
            "follow encounter",
            "queued",
            "Traversed to the encounter containing evidence."
        );
        visit [here->:HasEncounter:->];
    }

    can scan with Encounter entry {
        self.trace(
            "EvidenceAuditWalker",
            here.id,
            "Encounter",
            "HasEncounter",
            "scan verified and candidate evidence",
            "queued",
            "Queued only evidence nodes connected to this encounter."
        );
        visit [here->:HasVerifiedFact:->];
        visit [here->:HasCandidate:->];
    }

    can collect_verified with VerifiedFact entry {
        self.facts.append(here);
        self.trace(
            "EvidenceAuditWalker",
            here.id,
            "VerifiedFact",
            "HasVerifiedFact",
            "collect approved evidence",
            "collected",
            "Collected an approved fact for same-obligation comparison."
        );
    }

    can collect_candidate with CandidateFact entry {
        self.candidates.append(here);
    }

    can finish with Encounter exit {
        session: DemoSession | None = find_session(self.session_id);
        if session is None {
            report failure_response(
                "DEMO_NOT_LOADED", "The synthetic session disappeared.", False, 0
            );
            disengage;
        }
        active_session: DemoSession = session as DemoSession;
        for left_index in range(len(self.facts)) {
            for right_index in range(left_index + 1, len(self.facts)) {
                left: VerifiedFact = self.facts[left_index];
                right: VerifiedFact = self.facts[right_index];
                if left.category != right.category {
                    continue;
                }
                if left.value == right.value {
                    self.created_any = ensure_verified_conflict(
                        active_session,
                        here,
                        ConflictDTO(
                            id=f"duplicate-{left.id}-{right.id}",
                            left_fact_id=left.id,
                            right_fact_id=right.id,
                            conflict_type=ConflictType.DUPLICATE_VERIFIED_FACT,
                            explanation="Two approved facts duplicate the same instruction.",
                            left_source_text=left.source_text,
                            right_source_text=right.source_text
                        ),
                        left,
                        right
                    )
                    or self.created_any;
                } elif left.category == CandidateCategory.FOLLOW_UP {
                    self.created_any = ensure_verified_conflict(
                        active_session,
                        here,
                        ConflictDTO(
                            id=f"conflict-{left.id}-{right.id}",
                            left_fact_id=left.id,
                            right_fact_id=right.id,
                            conflict_type=ConflictType.CONTRADICTORY_FOLLOW_UP_PERIOD,
                            explanation="Two approved follow-up periods differ; neither was overwritten.",
                            left_source_text=left.source_text,
                            right_source_text=right.source_text
                        ),
                        left,
                        right
                    )
                    or self.created_any;
                    if right not in [left->:Contradicts:->] {
                        left +>:Contradicts():+> right;
                    }
                }
            }
        }
        for candidate in self.candidates {
            if candidate.status != CandidateStatus.PENDING {
                continue;
            }
            for fact in self.facts {
                if (
                    candidate.category == fact.category
                    and candidate.value != fact.value
                ) {
                    self.created_any = ensure_candidate_conflict(
                        active_session,
                        here,
                        ConflictDTO(
                            id=f"unverified-change-{fact.id}-{candidate.id}",
                            left_fact_id=fact.id,
                            right_fact_id=candidate.id,
                            conflict_type=ConflictType.UNVERIFIED_ATTEMPTED_CHANGE,
                            explanation="An unverified attempted change differs from an approved fact and was not applied.",
                            left_source_text=fact.source_text,
                            right_source_text=candidate_to_dto(candidate).source_text
                        ),
                        fact,
                        candidate
                    )
                    or self.created_any;
                }
            }
        }
        for fact in self.facts {
            for older in [fact->:Supersedes:->] {
                self.created_any = ensure_verified_conflict(
                    active_session,
                    here,
                    ConflictDTO(
                        id=f"superseded-{fact.id}-{older.id}",
                        left_fact_id=fact.id,
                        right_fact_id=older.id,
                        conflict_type=ConflictType.SUPERSEDED_INSTRUCTION,
                        explanation="A fact is explicitly superseded; both records remain.",
                        left_source_text=fact.source_text,
                        right_source_text=older.source_text
                    ),
                    fact,
                    older
                )
                or self.created_any;
            }
        }
        if self.created_any {
            active_session.graph_version += 1;
            invalidate_current_outputs(active_session);
        }
        self.trace(
            "EvidenceAuditWalker",
            here.id,
            "Encounter",
            "HasConflict",
            "persist conflict evidence",
            "created" if self.created_any else "idempotent",
            "Preserved both statements without selecting a clinical winner."
        );
        response = success_response(
            active_session.graph_version,
            "Evidence audit completed without selecting a clinical winner."
        );
        response.conflicts = [
            conflict_to_dto(conflict)
            for conflict in unresolved_conflicts(active_session)
        ];
        response.traversal_trace = self.traversal_trace;
        report response;
    }
}

walker ProvenancePathWalker(TraceableWalker) {
    has output_id: str = "",
        output_type: str = "",
        chain: ProvenanceChainDTO | None = None;

    can start with VerifiedFact entry {
        self.chain = ProvenanceChainDTO(
            output_id=self.output_id,
            output_type=self.output_type,
            source_fact_id=here.id
        );
        self.trace(
            "TraceProvenanceWalker",
            here.id,
            "VerifiedFact",
            "SupportedBy/AnsweredFrom",
            "follow verification provenance",
            "queued",
            "Reached the approved fact supporting the patient-facing output."
        );
        visit [here->:VerifiedFrom:->];
    }

    can candidate with CandidateFact entry {
        if self.chain is not None {
            (self.chain as ProvenanceChainDTO).candidate_fact_id = here.id;
        }
        self.trace(
            "TraceProvenanceWalker",
            here.id,
            "CandidateFact",
            "VerifiedFrom",
            "follow source evidence",
            "queued",
            "Traversed from the verified fact to its original unverified proposition."
        );
        visit [here->:ExtractedFrom:->];
    }

    can chunk with TranscriptChunk entry {
        if self.chain is not None {
            (self.chain as ProvenanceChainDTO).transcript_chunk_id = here.id;
            (self.chain as ProvenanceChainDTO).source_text = here.text;
        }
        self.trace(
            "TraceProvenanceWalker",
            here.id,
            "TranscriptChunk",
            "ExtractedFrom",
            "follow containing encounter",
            "queued",
            "Reached the immutable transcript sentence."
        );
        visit [here<-:ContainsChunk:<-];
    }

    can encounter with Encounter entry {
        if self.chain is not None {
            (self.chain as ProvenanceChainDTO).encounter_id = here.id;
        }
        self.trace(
            "TraceProvenanceWalker",
            here.id,
            "Encounter",
            "ContainsChunk",
            "follow patient",
            "queued",
            "Traversed from source evidence to its encounter."
        );
        visit [here<-:HasEncounter:<-];
    }

    can patient with Patient entry {
        if self.chain is not None {
            chain: ProvenanceChainDTO = self.chain as ProvenanceChainDTO;
            chain.patient_id = here.id;
            chain.complete = bool(
                chain.output_id
                and chain.source_fact_id
                and chain.candidate_fact_id
                and chain.transcript_chunk_id
                and chain.encounter_id
                and chain.patient_id
                and chain.source_text
            );
        }
        self.trace(
            "TraceProvenanceWalker",
            here.id,
            "Patient",
            "HasEncounter",
            "complete provenance chain",
            "complete"
                if self.chain is not None
                and (self.chain as ProvenanceChainDTO).complete
                else "incomplete",
            "Completed the backward chain at the synthetic patient."
        );
    }
}

walker TraceProvenanceWalker(TraceableWalker) {
    has session_id: str = "demo-default",
        output_id: str = "",
        found_output: bool = False,
        provenance_chains: list[ProvenanceChainDTO] = [],
        reports: list[BackendResponse] = [];

    can locate with Root entry {
        if not self.output_id.strip() {
            report failure_response(
                "INVALID_OUTPUT_ID", "output_id must not be empty.", True, 0
            );
            disengage;
        }
        session: DemoSession | None = find_session(self.session_id);
        if session is None {
            report failure_response(
                "DEMO_NOT_LOADED",
                "Load the synthetic encounter before tracing provenance.",
                True,
                0
            );
            disengage;
        }
        visit session;
    }

    can session with DemoSession entry {
        self.trace(
            "TraceProvenanceWalker",
            here.id,
            "DemoSession",
            "HasSession",
            "follow patient",
            "queued",
            "Entered only the selected session."
        );
        visit [here->:HasPatient:->];
    }

    can patient with Patient entry {
        self.trace(
            "TraceProvenanceWalker",
            here.id,
            "Patient",
            "HasPatient",
            "locate patient-facing output",
            "queued",
            "Searched only briefs and answers connected to this patient."
        );
        visit [here->:HasBrief:->];
        visit [here->:HasQuestion:->];
    }

    can brief with PatientBrief entry {
        if not here.current {
            skip;
        }
        visit [here->:HasChecklistItem:->[?:ChecklistItem, id==self.output_id]];
    }

    can question with PatientQuestion entry {
        if not here.current {
            skip;
        }
        visit [here->:HasAnswer:->[?:PatientAnswer, id==self.output_id]];
    }

    def collect_paths(output_id: str, output_type: str, facts: list[VerifiedFact]) {
        self.found_output = True;
        for fact in facts {
            path = fact spawn ProvenancePathWalker(
                output_id=output_id, output_type=output_type
            );
            if path.chain is not None {
                self.provenance_chains.append(path.chain as ProvenanceChainDTO);
            }
            if trace_enabled() {
                for step in path.traversal_trace {
                    self.trace_order += 1;
                    self.traversal_trace.append(
                        TraversalStepDTO(
                            order=self.trace_order,
                            walker_name=step.walker_name,
                            current_node_id=step.current_node_id,
                            current_node_type=step.current_node_type,
                            edge_type=step.edge_type,
                            action=step.action,
                            outcome=step.outcome,
                            human_explanation=step.human_explanation
                        )
                    );
                }
            }
        }
    }

    can checklist_item with ChecklistItem entry {
        self.trace(
            "TraceProvenanceWalker",
            here.id,
            "ChecklistItem",
            "HasChecklistItem",
            "follow supporting facts",
            "queued",
            "Located the current checklist item and followed SupportedBy."
        );
        self.collect_paths(here.id, "ChecklistItem", [here->:SupportedBy:->]);
    }

    can answer with PatientAnswer entry {
        self.trace(
            "TraceProvenanceWalker",
            here.id,
            "PatientAnswer",
            "HasAnswer",
            "follow answer evidence",
            "queued",
            "Located the current answer and followed AnsweredFrom."
        );
        self.collect_paths(here.id, "PatientAnswer", [here->:AnsweredFrom:->]);
    }

    can finish with DemoSession exit {
        response: BackendResponse;
        if not self.found_output {
            response = failure_response(
                "OUTPUT_NOT_FOUND",
                f"Current patient-facing output '{self.output_id}' was not found in this session.",
                True,
                here.graph_version
            );
        } elif not self.provenance_chains
        or any(not chain.complete for chain in self.provenance_chains) {
            response = failure_response(
                "PROVENANCE_INCOMPLETE",
                "The patient-facing output does not have a complete evidence chain.",
                False,
                here.graph_version
            );
            response.provenance_chains = self.provenance_chains;
        } else {
            response = success_response(
                here.graph_version,
                "Patient-facing output traced to immutable transcript evidence."
            );
            response.provenance_chains = self.provenance_chains;
        }
        response.traversal_trace = self.traversal_trace;
        report response;
    }
}

walker ResetDemoWalker(TraceableWalker) {
    has session_id: str = "demo-default",
        reports: list[BackendResponse] = [];

    can reset with Root entry {
        if not self.session_id.strip() {
            report failure_response(
                "INVALID_SESSION_ID", "session_id must not be empty.", True, 0
            );
            disengage;
        }
        sessions: list[DemoSession] = [root->:HasSession:->[?:DemoSession, id==self.session_id]];
        fresh: DemoSession;
        if sessions {
            fresh = sessions[0];
            if not fresh.synthetic {
                report failure_response(
                    "NON_SYNTHETIC_SESSION",
                    "ResetDemoWalker can reset synthetic sessions only.",
                    False,
                    fresh.graph_version
                );
                disengage;
            }
            self.trace(
                "ResetDemoWalker",
                fresh.id,
                "DemoSession",
                "HasSession",
                "delete selected synthetic graph",
                "selected",
                "Selected only the named synthetic session for reset."
            );
            owned: list[CareNode] = [fresh->:SessionOwns:->];
            for item in owned {
                del item;
            }
        } else {
            fresh = DemoSession(
                id=self.session_id, synthetic=True, schema_version=2, graph_version=1
            );
            root +>:HasSession():+> fresh;
        }
        seed_session_graph(fresh);
        self.trace(
            "ResetDemoWalker",
            fresh.id,
            "DemoSession",
            "HasSession",
            "recreate deterministic graph",
            "complete",
            "Recreated exactly one clean synthetic demonstration graph."
        );
        state: DemoStateDTO = build_demo_state(fresh);
        response = success_response(
            fresh.graph_version,
            "Synthetic demo reset to the exact prepared initial state."
        );
        response.demo_state = state;
        response.candidate_facts = state.candidate_facts;
        response.traversal_trace = self.traversal_trace;
        report response;
    }
}
