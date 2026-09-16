"""Visit-driven live translation and verified encounter intelligence."""

import from models {
    AIStatusDTO,
    AnalysisProvenanceDTO,
    AnalysisRunDTO,
    AnalysisStatus,
    BackendResponse,
    CandidateCategory,
    CandidateFact,
    CandidateStatus,
    CareGap,
    CareGapDTO,
    CareTask,
    ClinicianNoteDraft,
    Conflict,
    ConflictDTO,
    DemoSession,
    Encounter,
    EncounterTimelineEventDTO,
    FinalReviewPacketDTO,
    FollowUp,
    GapStatus,
    InsightItemDTO,
    LabOrder,
    LiveQuickSummaryDTO,
    MedicationInstruction,
    NoteStatus,
    Patient,
    PatientBrief,
    PatientPlanDTO,
    QuestionPurpose,
    Referral,
    SuggestedQuestionDTO,
    TimelineEvent,
    TranscriptChunk,
    TranslatedTranscriptChunkDTO,
    TranslationStatus,
    TraversalStepDTO,
    VerifiedEncounterSummaryDTO,
    VerifiedFact,
    HasBrief,
    HasCandidate,
    HasClinicianNote,
    HasConflict,
    HasEncounter,
    HasGap,
    HasPatient,
    HasTask,
    HasVerifiedFact,
    RepresentsFollowUp,
    RepresentsLabOrder,
    RepresentsMedication,
    RepresentsReferral,
    SessionOwns,
    brief_to_plan,
    conflict_to_dto,
    gap_to_dto,
}
import from intelligence_models {
    AnalysisRun,
    FinalReviewPacket,
    InsightItem,
    QuickSummaryDraft,
    SuggestedQuestion,
    TranslatedTranscriptChunk,
    TranslationSession,
    VerifiedEncounterSummary,
    AnalyzedFact,
    ClarifiesConflict,
    ClarifiesGap,
    ContainsAnalysis,
    ContainsNote,
    ContainsPlan,
    ContainsTimeline,
    HasAnalysisRun,
    HasFinalPacket,
    HasQuickSummary,
    HasTranslationSession,
    InsightSupportedBy,
    ProducedInsight,
    ProducedQuestion,
    ProducedSummary,
    QuestionAnsweredBy,
    QuestionBasedOn,
    RelatedToGap,
    SessionTranslatedChunk,
    SupportedByChunk,
    SupersedesAnalysis,
    SupersedesFinalPacket,
    SupersedesQuickSummary,
    SupersedesTranslation,
    TranslatedAs,
}
import from intelligence_ai {
    QuickSummaryAttempt,
    TranslationAttempt,
    configured_intelligence_mode,
    intelligence_ai_status,
    run_quick_summary,
    run_translation,
}
import from extraction { deterministic_timestamp, }
import from multimodal_walkers {
    capture_to_dto,
    find_capture,
    note_to_dto,
    provenance_steps_for_fact,
}
import from models {
    CaptureSession,
    ClinicianNoteDraftDTO,
    ContainsChunk,
    HasCaptureSession,
    HasTimelineEvent,
    MultimodalProvenanceDTO,
    ProducedChunk,
}
import from walkers {
    TraceableWalker,
    active_gaps,
    candidates_for_session,
    failure_response,
    fact_is_conflicted,
    find_session,
    own_node,
    session_encounter,
    session_patient,
    success_response,
    unresolved_conflicts,
    verified_facts_for_session,
}

def translated_chunk_to_dto(
    translated: TranslatedTranscriptChunk
) -> TranslatedTranscriptChunkDTO {
    return TranslatedTranscriptChunkDTO(
        id=translated.id,
        original_chunk_id=translated.original_chunk_id,
        capture_session_id=translated.capture_session_id,
        source_language=translated.source_language,
        target_language=translated.target_language,
        original_text=translated.original_text,
        translated_text=translated.translated_text,
        speaker=translated.speaker,
        sequence=translated.sequence,
        status=translated.status,
        translation_mode=translated.translation_mode,
        fallback_used=translated.fallback_used,
        created_at=translated.created_at
    );
}

def quick_summary_to_dto(summary: QuickSummaryDraft) -> LiveQuickSummaryDTO {
    return LiveQuickSummaryDTO(
        id=summary.id,
        encounter_id=summary.encounter_id,
        status=summary.status,
        summary=summary.summary,
        key_points=summary.key_points,
        source_chunk_ids=summary.source_chunk_ids,
        unverified=summary.unverified,
        model_mode=summary.model_mode,
        fallback_used=summary.fallback_used,
        generated_at=summary.generated_at
    );
}

def verified_summary_to_dto(
    summary: VerifiedEncounterSummary
) -> VerifiedEncounterSummaryDTO {
    return VerifiedEncounterSummaryDTO(
        id=summary.id,
        encounter_id=summary.encounter_id,
        summary=summary.summary,
        patient_concerns=summary.patient_concerns,
        medications=summary.medications,
        allergies=summary.allergies,
        laboratory_orders=summary.laboratory_orders,
        referrals=summary.referrals,
        follow_ups=summary.follow_ups,
        outstanding_tasks=summary.outstanding_tasks,
        contradictions=summary.contradictions,
        source_fact_ids=summary.source_fact_ids,
        verified_only=summary.verified_only,
        generated_at=summary.generated_at
    );
}

def insight_to_dto(insight: InsightItem) -> InsightItemDTO {
    return InsightItemDTO(
        id=insight.id,
        insight_type=insight.insight_type,
        title=insight.title,
        description=insight.description,
        severity=insight.severity,
        source_fact_ids=insight.source_fact_ids,
        related_gap_ids=insight.related_gap_ids,
        requires_clinician_review=insight.requires_clinician_review
    );
}

def suggested_question_to_dto(question: SuggestedQuestion) -> SuggestedQuestionDTO {
    return SuggestedQuestionDTO(
        id=question.id,
        question=question.question,
        purpose=question.purpose,
        explanation=question.explanation,
        source_fact_ids=question.source_fact_ids,
        related_gap_ids=question.related_gap_ids,
        clinician_only=question.clinician_only,
        status=question.status
    );
}

def analysis_is_stale(session: DemoSession, run: AnalysisRun) -> bool {
    return (
        run.graph_version != session.graph_version
        or not run.current
        or run.status == AnalysisStatus.SUPERSEDED
    );
}

def analysis_to_dto(session: DemoSession, run: AnalysisRun) -> AnalysisRunDTO {
    summaries: list[VerifiedEncounterSummary] = [run->:ProducedSummary:->];
    insights: list[InsightItem] = [run->:ProducedInsight:->];
    questions: list[SuggestedQuestion] = [run->:ProducedQuestion:->];
    return AnalysisRunDTO(
        id=run.id,
        encounter_id=run.encounter_id,
        status=(
            AnalysisStatus.SUPERSEDED if analysis_is_stale(session, run) else run.status
        ),
        graph_version=run.graph_version,
        accepted_fact_ids=run.accepted_fact_ids,
        rejected_fact_ids_excluded=run.rejected_fact_ids_excluded,
        summary=(verified_summary_to_dto(summaries[0]) if summaries else None),
        insights=[insight_to_dto(item) for item in insights],
        questions=[suggested_question_to_dto(item) for item in questions],
        care_gaps=[gap_to_dto(gap) for gap in active_gaps(session)],
        conflicts=[
            conflict_to_dto(conflict) for conflict in unresolved_conflicts(session)
        ],
        source_fact_ids=run.source_fact_ids,
        model_mode=run.model_mode,
        fallback_used=run.fallback_used,
        created_at=run.created_at,
        completed_at=run.completed_at,
        stale=analysis_is_stale(session, run),
        superseding_run_id=run.superseding_run_id
    );
}

def intelligence_response(session: DemoSession, message: str = "") -> BackendResponse {
    return success_response(session.graph_version, message);
}

def find_translation(
    session: DemoSession, translated_chunk_id: str
) -> TranslatedTranscriptChunk | None {
    matches: list[TranslatedTranscriptChunk] = [
        item
        for item in [session->:SessionOwns:->[?:TranslatedTranscriptChunk]]
        if item.id == translated_chunk_id
    ];
    return matches[0] if matches else None;
}

def find_analysis(session: DemoSession, analysis_run_id: str) -> AnalysisRun | None {
    encounter: Encounter | None = session_encounter(session);
    if encounter is None {
        return None;
    }
    matches: list[AnalysisRun] = [
        run
        for run in [(encounter as Encounter)->:HasAnalysisRun:->]
        if run.id == analysis_run_id
    ];
    return matches[0] if matches else None;
}

def find_suggested_question(
    session: DemoSession, question_id: str
) -> SuggestedQuestion | None {
    encounter: Encounter | None = session_encounter(session);
    if encounter is None {
        return None;
    }
    for run in [(encounter as Encounter)->:HasAnalysisRun:->] {
        matches: list[SuggestedQuestion] = [
            question
            for question in [run->:ProducedQuestion:->]
            if question.id == question_id
        ];
        if matches {
            return matches[0];
        }
    }
    return None;
}

def find_verified_fact(session: DemoSession, fact_id: str) -> VerifiedFact | None {
    matches: list[VerifiedFact] = [
        fact
        for fact in verified_facts_for_session(session)
        if fact.id == fact_id
    ];
    return matches[0] if matches else None;
}

walker TranslateTranscriptChunkWalker(TraceableWalker) {
    has transcript_chunk_id: str = "",
        target_language: str = "",
        session_id: str = "demo-default",
        requested_mode: str = "",
        reports: list[BackendResponse] = [];

    can locate with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        if session is None {
            report failure_response(
                "SESSION_NOT_FOUND", "The synthetic session was not found.", True, 0
            );
            disengage;
        }
        visit session;
    }

    can enter_session with DemoSession entry {
        self.trace(
            "TranslateTranscriptChunkWalker",
            here.id,
            "DemoSession",
            "HasPatient",
            "enter selected session",
            "queued",
            "Translation is scoped to one synthetic session."
        );
        visit [here->:HasPatient:->];
    }

    can enter_patient with Patient entry {
        visit [here->:HasEncounter:->];
    }

    can locate_chunk with Encounter entry {
        visit [here->:ContainsChunk:->[?:TranscriptChunk, id==self.transcript_chunk_id]] else {
            session: DemoSession = find_session(self.session_id) as DemoSession;
            response = failure_response(
                "TRANSCRIPT_CHUNK_NOT_FOUND",
                "The finalized transcript chunk was not found in this session.",
                True,
                session.graph_version
            );
            response.traversal_trace = self.traversal_trace;
            report response;
            disengage;
        }
    }

    can translate with TranscriptChunk entry {
        session: DemoSession = find_session(self.session_id) as DemoSession;
        if not here.finalized {
            report failure_response(
                "TRANSCRIPT_CHUNK_NOT_FINALIZED",
                "Only a finalized transcript chunk can be translated.",
                True,
                session.graph_version
            );
            disengage;
        }
        attempt: TranslationAttempt = run_translation(
            here.text, self.target_language, self.requested_mode
        );
        if attempt.diagnostic_code == "UNSUPPORTED_LANGUAGE" {
            report failure_response(
                "UNSUPPORTED_LANGUAGE",
                "Translation supports English and Spanish only.",
                True,
                session.graph_version
            );
            disengage;
        }
        existing: list[TranslatedTranscriptChunk] = [
            item
            for item in [here->:TranslatedAs:->]
            if (item.target_language == attempt.target_language and item.current)
        ];
        if existing
        and (
            existing[0].translated_text == attempt.translated_text
            and existing[0].status == attempt.status
            and existing[0].translation_mode == attempt.mode
        ) {
            response = intelligence_response(
                session, "Translation already exists; no duplicate was created."
            );
            response.translated_chunk = translated_chunk_to_dto(existing[0]);
            report response;
            disengage;
        }
        encounter: Encounter = session_encounter(session) as Encounter;
        capture_id: str = here.capture_session_id;
        translation_sessions: list[TranslationSession] = [
            item
            for item in [encounter->:HasTranslationSession:->]
            if (
                item.capture_session_id == capture_id
                and item.target_language == attempt.target_language
            )
        ];
        translation_session: TranslationSession;
        if translation_sessions {
            translation_session = translation_sessions[0];
        } else {
            translation_session = TranslationSession(
                session_id=self.session_id,
                id=(
                    f"translation-session-{self.session_id}-"
                    f"{capture_id or 'encounter'}-{attempt.target_language.lower()}"
                ),
                capture_session_id=capture_id,
                source_language=attempt.source_language,
                target_language=attempt.target_language,
                status=TranslationStatus.TRANSLATING,
                mode=attempt.mode,
                created_at=deterministic_timestamp(session.graph_version)
            );
            own_node(session, translation_session);
            encounter +>:HasTranslationSession():+> translation_session;
        }
        if translation_session.source_language != attempt.source_language {
            translation_session.source_language = "Mixed";
        }
        if translation_session.mode != attempt.mode {
            translation_session.mode = "mixed";
        }
        for old in existing {
            old.current = False;
        }
        session.graph_version += 1;
        translated = TranslatedTranscriptChunk(
            session_id=self.session_id,
            id=(
                f"translation-{self.session_id}-{here.id}-"
                f"{attempt.target_language.lower()}-{session.graph_version}"
            ),
            original_chunk_id=here.id,
            capture_session_id=capture_id,
            source_language=attempt.source_language,
            target_language=attempt.target_language,
            original_text=here.text,
            translated_text=attempt.translated_text,
            speaker=here.speaker,
            sequence=here.sequence,
            status=(
                TranslationStatus.FALLBACK
                    if attempt.status == "fallback"
                    else TranslationStatus.TRANSLATED
            ),
            translation_mode=attempt.mode,
            fallback_used=attempt.fallback_used,
            current=True,
            created_at=deterministic_timestamp(session.graph_version)
        );
        own_node(session, translated);
        here +>:TranslatedAs():+> translated;
        translation_session +>:SessionTranslatedChunk():+> translated;
        translation_session.status = translated.status;
        for old in existing {
            translated +>:SupersedesTranslation():+> old;
        }
        self.trace(
            "TranslateTranscriptChunkWalker",
            here.id,
            "TranscriptChunk",
            "TranslatedAs",
            "translate immutable evidence",
            translated.id,
            "Stored both original and literal translated text."
        );
        response = intelligence_response(session, "Transcript chunk translated.");
        response.translated_chunk = translated_chunk_to_dto(translated);
        response.ai_status = intelligence_ai_status(
            self.requested_mode not in ["", "disabled", "deterministic"],
            attempt.mode in ["mock", "cloud_model"],
            attempt.fallback_used,
            attempt.mode,
            attempt.diagnostic_code,
            (
                "Optional translation used a safe deterministic fallback."
                    if attempt.fallback_used
                    else ""
            )
        );
        response.created_graph_ids = [translated.id];
        response.traversal_trace = self.traversal_trace;
        report response;
    }
}

walker GetTranslatedTranscriptWalker(TraceableWalker) {
    has capture_session_id: str = "",
        target_language: str = "",
        session_id: str = "demo-default",
        reports: list[BackendResponse] = [];

    can locate with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        capture: CaptureSession | None = (
            find_capture(session as DemoSession, self.capture_session_id)
                if session is not None
                else None
        );
        if session is None or capture is None {
            report failure_response(
                "CAPTURE_NOT_FOUND",
                "The capture was not found in this session.",
                True,
                session.graph_version if session is not None else 0
            );
            disengage;
        }
        visit capture;
    }

    can collect with CaptureSession entry {
        session: DemoSession = find_session(self.session_id) as DemoSession;
        target: str = self.target_language.lower().strip();
        if target not in ["english", "spanish", "en", "es"] {
            report failure_response(
                "UNSUPPORTED_LANGUAGE",
                "Translation supports English and Spanish only.",
                True,
                session.graph_version
            );
            disengage;
        }
        output: list[TranslatedTranscriptChunkDTO] = [];
        for chunk in [here->:ProducedChunk:->] {
            matches: list[TranslatedTranscriptChunk] = [
                item
                for item in [chunk->:TranslatedAs:->]
                if (
                    item.current and item.target_language.lower().startswith(target[:2])
                )
            ];
            if matches {
                output.append(translated_chunk_to_dto(matches[-1]));
            }
        }
        output.sort(key=lambda (item: TranslatedTranscriptChunkDTO) { item.sequence; });
        response = intelligence_response(session, "Translated transcript loaded.");
        response.translated_transcript = output;
        report response;
    }
}

walker RetryTranslationWalker(TraceableWalker) {
    has translated_chunk_id: str = "",
        session_id: str = "demo-default",
        requested_mode: str = "",
        reports: list[BackendResponse] = [];

    can retry with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        translated: TranslatedTranscriptChunk | None = (
            find_translation(session as DemoSession, self.translated_chunk_id)
                if session is not None
                else None
        );
        if session is None or translated is None {
            report failure_response(
                "TRANSLATION_NOT_FOUND",
                "The translation was not found in this session.",
                True,
                session.graph_version if session is not None else 0
            );
            disengage;
        }
        if (translated as TranslatedTranscriptChunk).status not in [
            TranslationStatus.FALLBACK,
            TranslationStatus.FAILED
        ] {
            report failure_response(
                "TRANSLATION_NOT_RETRYABLE",
                "Only failed or fallback translations can be retried.",
                False,
                session.graph_version
            );
            disengage;
        }
        original: list[TranscriptChunk] = [(translated as TranslatedTranscriptChunk)<-:TranslatedAs:<-];
        if len(original) != 1 {
            report failure_response(
                "TRANSLATION_PROVENANCE_MISSING",
                "The original transcript provenance is incomplete.",
                False,
                session.graph_version
            );
            disengage;
        }
        result = root spawn TranslateTranscriptChunkWalker(
            transcript_chunk_id=original[0].id,
            target_language=(translated as TranslatedTranscriptChunk).target_language,
            session_id=self.session_id,
            requested_mode=self.requested_mode
        );
        if result.reports {
            report result.reports[0];
        }
    }
}

walker LiveQuickSummaryWalker(TraceableWalker) {
    has encounter_id: str = "",
        session_id: str = "demo-default",
        requested_mode: str = "",
        reports: list[BackendResponse] = [];

    can locate with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        if session is None {
            report failure_response(
                "SESSION_NOT_FOUND", "The synthetic session was not found.", True, 0
            );
            disengage;
        }
        visit session;
    }

    can enter_session with DemoSession entry {
        visit [here->:HasPatient:->];
    }

    can enter_patient with Patient entry {
        visit [here->:HasEncounter:->[?:Encounter, id==self.encounter_id]] else {
            session: DemoSession = find_session(self.session_id) as DemoSession;
            report failure_response(
                "ENCOUNTER_NOT_FOUND",
                "The encounter was not found in this session.",
                True,
                session.graph_version
            );
            disengage;
        }
    }

    can summarize with Encounter entry {
        session: DemoSession = find_session(self.session_id) as DemoSession;
        captures: list[CaptureSession] = [here->:HasCaptureSession:->];
        chunks: list[TranscriptChunk] = (
            [captures[-1]->:ProducedChunk:->] if captures else [here->:ContainsChunk:->]
        );
        chunks = [
            chunk
            for chunk in chunks
            if chunk.finalized
        ];
        chunks.sort(key=lambda (chunk: TranscriptChunk) { chunk.sequence; });
        if not chunks {
            report failure_response(
                "NO_FINALIZED_TRANSCRIPT",
                "No finalized transcript is available for an unverified quick summary.",
                True,
                session.graph_version
            );
            disengage;
        }
        attempt: QuickSummaryAttempt = run_quick_summary(
            [chunk.id for chunk in chunks],
            [chunk.speaker for chunk in chunks],
            [chunk.text for chunk in chunks],
            self.requested_mode
        );
        previous: list[QuickSummaryDraft] = [
            draft
            for draft in [here->:HasQuickSummary:->]
            if draft.current
        ];
        if previous
        and (
            previous[-1].summary == attempt.summary
            and previous[-1].source_chunk_ids == attempt.source_chunk_ids
            and previous[-1].model_mode == attempt.mode
        ) {
            response = intelligence_response(
                session, "Live quick summary already reflects current chunks."
            );
            response.live_quick_summary = quick_summary_to_dto(previous[-1]);
            report response;
            disengage;
        }
        for old in previous {
            old.current = False;
        }
        session.graph_version += 1;
        draft = QuickSummaryDraft(
            session_id=self.session_id,
            id=f"quick-summary-{self.session_id}-{session.graph_version}",
            encounter_id=here.id,
            status=AnalysisStatus.COMPLETED,
            summary=attempt.summary,
            key_points=attempt.key_points,
            source_chunk_ids=attempt.source_chunk_ids,
            unverified=True,
            model_mode=attempt.mode,
            fallback_used=attempt.fallback_used,
            current=True,
            generated_at=deterministic_timestamp(session.graph_version)
        );
        own_node(session, draft);
        here +>:HasQuickSummary():+> draft;
        for chunk in chunks {
            if chunk.id in attempt.source_chunk_ids {
                draft +>:SupportedByChunk():+> chunk;
            }
        }
        for old in previous {
            draft +>:SupersedesQuickSummary():+> old;
        }
        self.trace(
            "LiveQuickSummaryWalker",
            here.id,
            "Encounter",
            "HasQuickSummary/SupportedByChunk",
            "store unverified draft",
            draft.id,
            "Every quick-summary claim remains explicitly unverified."
        );
        response = intelligence_response(
            session, "Unverified live quick summary generated."
        );
        response.live_quick_summary = quick_summary_to_dto(draft);
        response.ai_status = intelligence_ai_status(
            self.requested_mode not in ["", "disabled", "deterministic"],
            attempt.mode in ["mock", "cloud_model"],
            attempt.fallback_used,
            attempt.mode,
            attempt.diagnostic_code,
            (
                "Optional summary used a safe deterministic fallback."
                    if attempt.fallback_used
                    else ""
            )
        );
        response.created_graph_ids = [draft.id];
        response.traversal_trace = self.traversal_trace;
        report response;
    }
}

walker GetLiveQuickSummaryWalker(TraceableWalker) {
    has encounter_id: str = "",
        session_id: str = "demo-default",
        reports: list[BackendResponse] = [];

    can get_summary with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        encounter: Encounter | None = (
            session_encounter(session as DemoSession) if session is not None else None
        );
        if (
            session is None
            or encounter is None
            or (encounter as Encounter).id != self.encounter_id
        ) {
            report failure_response(
                "ENCOUNTER_NOT_FOUND",
                "The encounter was not found in this session.",
                True,
                session.graph_version if session is not None else 0
            );
            disengage;
        }
        drafts: list[QuickSummaryDraft] = [
            item
            for item in [(encounter as Encounter)->:HasQuickSummary:->]
            if item.current
        ];
        if not drafts {
            report failure_response(
                "QUICK_SUMMARY_NOT_FOUND",
                "No live quick summary exists for this encounter.",
                True,
                session.graph_version
            );
            disengage;
        }
        response = intelligence_response(
            session as DemoSession, "Live quick summary loaded."
        );
        response.live_quick_summary = quick_summary_to_dto(drafts[-1]);
        report response;
    }
}

walker VerifiedEncounterAnalysisWalker(TraceableWalker) {
    has encounter_id: str = "",
        session_id: str = "demo-default",
        requested_mode: str = "",
        accepted_facts: list[VerifiedFact] = [],
        rejected_ids: list[str] = [],
        gaps: list[CareGap] = [],
        conflicts_found: list[Conflict] = [],
        medication_values: list[str] = [],
        lab_values: list[str] = [],
        referral_values: list[str] = [],
        follow_up_values: list[str] = [],
        outstanding_tasks: list[str] = [],
        reports: list[BackendResponse] = [];

    can locate with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        if session is None {
            report failure_response(
                "SESSION_NOT_FOUND", "The synthetic session was not found.", True, 0
            );
            disengage;
        }
        visit session;
    }

    can enter_session with DemoSession entry {
        visit [here->:HasPatient:->];
    }

    can enter_patient with Patient entry {
        visit [here->:HasEncounter:->[?:Encounter, id==self.encounter_id]] else {
            session: DemoSession = find_session(self.session_id) as DemoSession;
            report failure_response(
                "ENCOUNTER_NOT_FOUND",
                "The encounter was not found in this session.",
                True,
                session.graph_version
            );
            disengage;
        }
    }

    can traverse_encounter with Encounter entry {
        self.rejected_ids = [
            candidate.id
            for candidate in [here->:HasCandidate:->]
            if candidate.status == CandidateStatus.REJECTED
        ];
        self.trace(
            "VerifiedEncounterAnalysisWalker",
            here.id,
            "Encounter",
            "HasVerifiedFact/HasGap/HasConflict/HasTask",
            "traverse verified encounter",
            "queued",
            "Pending, rejected, quick-summary, and foreign-session nodes were excluded."
        );
        visit [here->:HasVerifiedFact:->];
        visit [here->:HasGap:->];
        visit [here->:HasConflict:->];
        visit [here->:HasTask:->];
    }

    can collect_fact with VerifiedFact entry {
        if here.session_id != self.session_id {
            skip;
        }
        self.accepted_facts.append(here);
        visit [here->:RepresentsMedication:->];
        visit [here->:RepresentsLabOrder:->];
        visit [here->:RepresentsReferral:->];
        visit [here->:RepresentsFollowUp:->];
    }

    can collect_medication with MedicationInstruction entry {
        session: DemoSession = find_session(self.session_id) as DemoSession;
        if not fact_is_conflicted(session, here.source_fact_id) {
            self.medication_values.append(here.instruction_text);
        }
    }

    can collect_lab with LabOrder entry {
        session: DemoSession = find_session(self.session_id) as DemoSession;
        if not fact_is_conflicted(session, here.source_fact_id) {
            text: str = here.test_name;
            if here.due_window {
                text += f"; due {here.due_window}";
            }
            if here.owner {
                text += f"; owner {here.owner}";
            }
            self.lab_values.append(text);
        }
    }

    can collect_referral with Referral entry {
        session: DemoSession = find_session(self.session_id) as DemoSession;
        if not fact_is_conflicted(session, here.source_fact_id) {
            text: str = (
                f"{here.destination}; owner {here.owner}"
                    if here.owner
                    else here.destination
            );
            self.referral_values.append(text);
        }
    }

    can collect_follow_up with FollowUp entry {
        session: DemoSession = find_session(self.session_id) as DemoSession;
        if not fact_is_conflicted(session, here.source_fact_id) {
            text: str = (
                f"{here.period_text}; appointment {here.appointment_date}"
                    if here.appointment_date
                    else here.period_text
            );
            self.follow_up_values.append(text);
        }
    }

    can collect_gap with CareGap entry {
        if here.session_id == self.session_id and not here.resolved {
            self.gaps.append(here);
        }
    }

    can collect_conflict with Conflict entry {
        if here.session_id == self.session_id and not here.resolved {
            self.conflicts_found.append(here);
        }
    }

    can collect_task with CareTask entry {
        if (
            here.session_id == self.session_id
            and here.status not in ["completed", "resolved", "scheduled", "assigned"]
        ) {
            self.outstanding_tasks.append(here.title);
        }
    }

    can finish with DemoSession exit {
        if not self.accepted_facts {
            response = failure_response(
                "NO_VERIFIED_FACTS",
                "No accepted facts are available for verified analysis.",
                True,
                here.graph_version
            );
            response.traversal_trace = self.traversal_trace;
            report response;
            disengage;
        }
        encounter: Encounter = session_encounter(here) as Encounter;
        previous: list[AnalysisRun] = [
            run
            for run in [encounter->:HasAnalysisRun:->]
            if run.current
        ];
        run_number: int = len([encounter->:HasAnalysisRun:->]) + 1;
        run_id: str = f"analysis-{self.session_id}-{here.graph_version}-{run_number}";
        for old in previous {
            old.current = False;
            old.status = AnalysisStatus.SUPERSEDED;
            old.superseding_run_id = run_id;
        }
        mode: str = (
            self.requested_mode.lower().strip()
                if self.requested_mode.strip()
                else configured_intelligence_mode()
        );
        actual_mode: str = "mock" if mode == "mock" else "deterministic";
        fallback_used: bool = mode in ["mock_malformed", "live", "cloud_model"];
        if mode in ["live", "cloud_model"] {
            actual_mode = "deterministic";
        }
        source_ids: list[str] = [fact.id for fact in self.accepted_facts];
        categories: list[str] = [];
        if self.medication_values {
            categories.append(
                f"{len(self.medication_values)} accepted medication instruction(s)"
            );
        }
        if self.lab_values {
            categories.append(f"{len(self.lab_values)} laboratory order(s)");
        }
        if self.referral_values {
            categories.append(f"{len(self.referral_values)} referral(s)");
        }
        if self.follow_up_values {
            categories.append(f"{len(self.follow_up_values)} follow-up obligation(s)");
        }
        summary_text: str = (
            "Verified encounter information includes " + ", ".join(categories) + "."
                if categories
                else "Verified encounter information is recorded in the graph."
        );
        run = AnalysisRun(
            session_id=self.session_id,
            id=run_id,
            encounter_id=encounter.id,
            status=AnalysisStatus.COMPLETED,
            graph_version=here.graph_version,
            accepted_fact_ids=source_ids,
            rejected_fact_ids_excluded=self.rejected_ids,
            source_fact_ids=source_ids,
            model_mode=actual_mode,
            fallback_used=fallback_used,
            current=True,
            created_at=deterministic_timestamp(here.graph_version),
            completed_at=deterministic_timestamp(here.graph_version)
        );
        own_node(here, run);
        encounter +>:HasAnalysisRun():+> run;
        for old in previous {
            run +>:SupersedesAnalysis():+> old;
        }
        summary = VerifiedEncounterSummary(
            session_id=self.session_id,
            id=f"verified-summary-{run_id}",
            encounter_id=encounter.id,
            summary=summary_text,
            patient_concerns=[],
            medications=self.medication_values,
            allergies=[],
            laboratory_orders=self.lab_values,
            referrals=self.referral_values,
            follow_ups=self.follow_up_values,
            outstanding_tasks=self.outstanding_tasks,
            contradictions=[conflict.explanation for conflict in self.conflicts_found],
            source_fact_ids=source_ids,
            verified_only=True,
            current=True,
            generated_at=deterministic_timestamp(here.graph_version)
        );
        own_node(here, summary);
        run +>:ProducedSummary():+> summary;
        for fact in self.accepted_facts {
            run +>:AnalyzedFact():+> fact;
        }
        created_ids: list[str] = [run.id, summary.id];
        for gap in self.gaps {
            insight = InsightItem(
                session_id=self.session_id,
                id=f"insight-{run.id}-{gap.id}",
                insight_type="care_gap",
                title="Documentation gap",
                description=gap.message,
                severity="review",
                source_fact_ids=gap.related_fact_ids,
                related_gap_ids=[gap.id],
                requires_clinician_review=True
            );
            own_node(here, insight);
            run +>:ProducedInsight():+> insight;
            insight +>:RelatedToGap():+> gap;
            for fact in self.accepted_facts {
                if fact.id in gap.related_fact_ids {
                    insight +>:InsightSupportedBy():+> fact;
                }
            }
            created_ids.append(insight.id);
        }
        for conflict in self.conflicts_found {
            insight = InsightItem(
                session_id=self.session_id,
                id=f"insight-{run.id}-{conflict.id}",
                insight_type="conflict",
                title="Contradictory approved information",
                description=conflict.explanation,
                severity="review",
                source_fact_ids=[conflict.left_fact_id, conflict.right_fact_id],
                related_gap_ids=[],
                requires_clinician_review=True
            );
            own_node(here, insight);
            run +>:ProducedInsight():+> insight;
            for fact in self.accepted_facts {
                if fact.id in insight.source_fact_ids {
                    insight +>:InsightSupportedBy():+> fact;
                }
            }
            created_ids.append(insight.id);
        }
        response = intelligence_response(
            here, "Verified encounter analysis completed."
        );
        response.analysis_run = analysis_to_dto(here, run);
        response.verified_encounter_summary = verified_summary_to_dto(summary);
        response.care_gaps = [gap_to_dto(gap) for gap in self.gaps];
        response.conflicts = [
            conflict_to_dto(conflict) for conflict in self.conflicts_found
        ];
        response.ai_status = intelligence_ai_status(
            mode not in ["disabled", "deterministic"],
            actual_mode == "mock",
            fallback_used,
            actual_mode,
            ("ANALYSIS_MODEL_FALLBACK" if fallback_used else ""),
            (
                "Verified graph organization used deterministic fallback."
                    if fallback_used
                    else ""
            )
        );
        response.created_graph_ids = created_ids;
        response.traversal_trace = self.traversal_trace;
        report response;
    }
}

walker GetVerifiedEncounterAnalysisWalker(TraceableWalker) {
    has analysis_run_id: str = "",
        session_id: str = "demo-default",
        reports: list[BackendResponse] = [];

    can get_analysis with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        run: AnalysisRun | None = (
            find_analysis(session as DemoSession, self.analysis_run_id)
                if session is not None
                else None
        );
        if session is None or run is None {
            report failure_response(
                "ANALYSIS_NOT_FOUND",
                "The analysis run was not found in this session.",
                True,
                session.graph_version if session is not None else 0
            );
            disengage;
        }
        response = intelligence_response(
            session as DemoSession,
            (
                "New verified information is available. Re-run analysis."
                    if analysis_is_stale(session as DemoSession, run as AnalysisRun)
                    else "Verified encounter analysis loaded."
            )
        );
        response.analysis_run = analysis_to_dto(
            session as DemoSession, run as AnalysisRun
        );
        summaries: list[VerifiedEncounterSummary] = [(run as AnalysisRun)->:ProducedSummary:->];
        response.verified_encounter_summary = (
            verified_summary_to_dto(summaries[0]) if summaries else None
        );
        report response;
    }
}

def question_for_gap(gap: CareGap) -> tuple[str, QuestionPurpose] {
    if gap.gap_type == "lab_owner_missing" {
        return (
            "Who is responsible for coordinating the blood test?",
            QuestionPurpose.CONFIRM_RESPONSIBILITY
        );
    }
    if gap.gap_type == "follow_up_date_missing" {
        return (
            "Has a specific follow-up date been scheduled?",
            QuestionPurpose.CONFIRM_FOLLOW_UP
        );
    }
    if gap.gap_type == "referral_owner_missing" {
        return (
            "Is the referral destination and responsible coordinator confirmed?",
            QuestionPurpose.CONFIRM_RESPONSIBILITY
        );
    }
    if gap.gap_type == "medication_documentation_missing" {
        return (
            "Is the accepted medication instruction complete enough for the patient plan?",
            QuestionPurpose.RESOLVE_DOCUMENTATION_GAP
        );
    }
    return (
        "Who is responsible for this unresolved care task?",
        QuestionPurpose.CLARIFY_MISSING_INFORMATION
    );
}

walker ClarifyingQuestionWalker(TraceableWalker) {
    has encounter_id: str = "",
        analysis_run_id: str = "",
        session_id: str = "demo-default",
        reports: list[BackendResponse] = [];

    can generate with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        run: AnalysisRun | None = (
            find_analysis(session as DemoSession, self.analysis_run_id)
                if session is not None
                else None
        );
        encounter: Encounter | None = (
            session_encounter(session as DemoSession) if session is not None else None
        );
        if (
            session is None
            or run is None
            or encounter is None
            or (encounter as Encounter).id != self.encounter_id
        ) {
            report failure_response(
                "ANALYSIS_NOT_FOUND",
                "The analysis run was not found in this encounter and session.",
                True,
                session.graph_version if session is not None else 0
            );
            disengage;
        }
        if analysis_is_stale(session as DemoSession, run as AnalysisRun) {
            report failure_response(
                "ANALYSIS_STALE",
                "New verified information is available. Re-run analysis.",
                True,
                session.graph_version
            );
            disengage;
        }
        created_ids: list[str] = [];
        existing: list[SuggestedQuestion] = [(run as AnalysisRun)->:ProducedQuestion:->];
        for gap in active_gaps(session as DemoSession) {
            question_id: str = f"question-{run.id}-{gap.id}";
            matches: list[SuggestedQuestion] = [
                item
                for item in existing
                if item.id == question_id
            ];
            if matches {
                continue;
            }
            wording: tuple[str, QuestionPurpose] = question_for_gap(gap);
            question = SuggestedQuestion(
                session_id=self.session_id,
                id=question_id,
                question=wording[0],
                purpose=wording[1],
                explanation=(
                    "Generated because the accepted care obligation has a "
                    "current documentation gap."
                ),
                source_fact_ids=gap.related_fact_ids,
                related_gap_ids=[gap.id],
                clinician_only=True,
                status="open"
            );
            own_node(session as DemoSession, question);
            (run as AnalysisRun) +>:ProducedQuestion():+> question;
            question +>:ClarifiesGap():+> gap;
            for fact_id in gap.related_fact_ids {
                fact: VerifiedFact | None = find_verified_fact(
                    session as DemoSession, fact_id
                );
                if fact is not None {
                    question +>:QuestionBasedOn():+> (fact as VerifiedFact);
                }
            }
            created_ids.append(question.id);
        }
        for conflict in unresolved_conflicts(session as DemoSession) {
            question_id = f"question-{run.id}-{conflict.id}";
            matches = [
                item
                for item in existing
                if item.id == question_id
            ];
            if matches {
                continue;
            }
            is_follow_up_conflict: bool = (
                conflict.conflict_type == "contradictory_follow_up_period"
            );
            conflict_question: str = (
                (
                    "Which follow-up instruction should be used: "
                    "two weeks or four weeks?"
                )
                    if is_follow_up_conflict
                    else (
                        "Do these two approved statements represent the same "
                        "care instruction?"
                    )
            );
            question = SuggestedQuestion(
                session_id=self.session_id,
                id=question_id,
                question=conflict_question,
                purpose=QuestionPurpose.RESOLVE_CONTRADICTION,
                explanation=(
                    (
                        "Generated because two accepted follow-up statements "
                        "conflict and neither may be selected automatically."
                    )
                        if is_follow_up_conflict
                        else (
                            "Generated because two accepted statements may "
                            "duplicate the same care instruction; neither is "
                            "changed automatically."
                        )
                ),
                source_fact_ids=[conflict.left_fact_id, conflict.right_fact_id],
                related_gap_ids=[],
                clinician_only=True,
                status="open"
            );
            own_node(session as DemoSession, question);
            (run as AnalysisRun) +>:ProducedQuestion():+> question;
            question +>:ClarifiesConflict():+> conflict;
            for fact_id in question.source_fact_ids {
                fact = find_verified_fact(session as DemoSession, fact_id);
                if fact is not None {
                    question +>:QuestionBasedOn():+> (fact as VerifiedFact);
                }
            }
            created_ids.append(question.id);
        }
        questions: list[SuggestedQuestion] = [(run as AnalysisRun)->:ProducedQuestion:->];
        response = intelligence_response(
            session as DemoSession, "Clarifying questions generated."
        );
        response.suggested_questions = [
            suggested_question_to_dto(item) for item in questions
        ];
        response.analysis_run = analysis_to_dto(
            session as DemoSession, run as AnalysisRun
        );
        response.created_graph_ids = created_ids;
        report response;
    }
}

walker DismissSuggestedQuestionWalker(TraceableWalker) {
    has question_id: str = "",
        clinician_id: str = "",
        session_id: str = "demo-default",
        reports: list[BackendResponse] = [];

    can dismiss with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        question: SuggestedQuestion | None = (
            find_suggested_question(session as DemoSession, self.question_id)
                if session is not None
                else None
        );
        if not self.clinician_id.strip() {
            report failure_response(
                "CLINICIAN_ID_REQUIRED",
                "clinician_id is required.",
                True,
                session.graph_version if session is not None else 0
            );
            disengage;
        }
        if session is None or question is None {
            report failure_response(
                "QUESTION_NOT_FOUND",
                "The suggested question was not found in this session.",
                True,
                session.graph_version if session is not None else 0
            );
            disengage;
        }
        if (question as SuggestedQuestion).status == "answered" {
            report failure_response(
                "QUESTION_ALREADY_ANSWERED",
                "An answered question cannot be dismissed.",
                False,
                session.graph_version
            );
            disengage;
        }
        (question as SuggestedQuestion).status = "dismissed";
        (question as SuggestedQuestion).reviewed_by = self.clinician_id;
        (question as SuggestedQuestion).reviewed_at = deterministic_timestamp(
            session.graph_version
        );
        response = intelligence_response(
            session as DemoSession, "Suggested question dismissed."
        );
        response.suggested_questions = [
            suggested_question_to_dto(question as SuggestedQuestion)
        ];
        report response;
    }
}

walker MarkSuggestedQuestionAnsweredWalker(TraceableWalker) {
    has question_id: str = "",
        answer_source_fact_id: str = "",
        clinician_id: str = "",
        session_id: str = "demo-default",
        reports: list[BackendResponse] = [];

    can mark_answered with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        question: SuggestedQuestion | None = (
            find_suggested_question(session as DemoSession, self.question_id)
                if session is not None
                else None
        );
        fact: VerifiedFact | None = (
            find_verified_fact(session as DemoSession, self.answer_source_fact_id)
                if session is not None
                else None
        );
        if not self.clinician_id.strip() {
            report failure_response(
                "CLINICIAN_ID_REQUIRED",
                "clinician_id is required.",
                True,
                session.graph_version if session is not None else 0
            );
            disengage;
        }
        if session is None or question is None {
            report failure_response(
                "QUESTION_NOT_FOUND",
                "The suggested question was not found in this session.",
                True,
                session.graph_version if session is not None else 0
            );
            disengage;
        }
        if fact is None {
            report failure_response(
                "VERIFIED_FACT_NOT_FOUND",
                "The answer source is not an accepted fact in this session.",
                True,
                session.graph_version
            );
            disengage;
        }
        active_question: SuggestedQuestion = question as SuggestedQuestion;
        active_question.status = "answered";
        active_question.reviewed_by = self.clinician_id;
        active_question.reviewed_at = deterministic_timestamp(session.graph_version);
        active_question.answer_source_fact_id = fact.id;
        if fact.id not in active_question.source_fact_ids {
            active_question.source_fact_ids.append(fact.id);
        }
        if fact not in [active_question->:QuestionAnsweredBy:->] {
            active_question +>:QuestionAnsweredBy():+> fact;
        }
        response = intelligence_response(
            session as DemoSession, "Suggested question marked answered."
        );
        response.suggested_questions = [suggested_question_to_dto(active_question)];
        report response;
    }
}

def latest_current_analysis(session: DemoSession) -> AnalysisRun | None {
    encounter: Encounter | None = session_encounter(session);
    if encounter is None {
        return None;
    }
    runs: list[AnalysisRun] = [
        run
        for run in [(encounter as Encounter)->:HasAnalysisRun:->]
        if run.current and not analysis_is_stale(session, run)
    ];
    return runs[-1] if runs else None;
}

def current_plan_node(session: DemoSession, language: str) -> PatientBrief | None {
    patient: Patient | None = session_patient(session);
    if patient is None {
        return None;
    }
    plans: list[PatientBrief] = [
        brief
        for brief in [(patient as Patient)->:HasBrief:->]
        if brief.current and brief.language.lower() == language.lower()
    ];
    return plans[-1] if plans else None;
}

def current_note_node(session: DemoSession) -> ClinicianNoteDraft | None {
    encounter: Encounter | None = session_encounter(session);
    if encounter is None {
        return None;
    }
    notes: list[ClinicianNoteDraft] = [
        note
        for note in [(encounter as Encounter)->:HasClinicianNote:->]
        if note.status != NoteStatus.SUPERSEDED
    ];
    return notes[-1] if notes else None;
}

def timeline_event_to_dto(event: TimelineEvent) -> EncounterTimelineEventDTO {
    return EncounterTimelineEventDTO(
        id=event.id,
        event_type=event.event_type,
        occurred_at=event.occurred_at,
        title=event.title,
        description=event.description,
        related_node_ids=event.related_node_ids,
        source_fact_ids=event.source_fact_ids,
        graph_version=event.graph_version
    );
}

def final_packet_to_dto(
    session: DemoSession, packet: FinalReviewPacket
) -> FinalReviewPacketDTO {
    analyses: list[AnalysisRun] = [packet->:ContainsAnalysis:->];
    notes: list[ClinicianNoteDraft] = [packet->:ContainsNote:->];
    plans: list[PatientBrief] = [packet->:ContainsPlan:->];
    english: PatientPlanDTO | None = None;
    spanish: PatientPlanDTO | None = None;
    patient_plan_id: str = "";
    for plan in plans {
        patient_plan_id = plan.id;
        if plan.language.lower() == "english" {
            english = brief_to_plan(plan);
        } elif plan.language.lower() == "spanish" {
            spanish = brief_to_plan(plan);
        }
    }
    run: AnalysisRun | None = analyses[0] if analyses else None;
    summaries: list[VerifiedEncounterSummary] = (
        [(run as AnalysisRun)->:ProducedSummary:->] if run is not None else []
    );
    questions: list[SuggestedQuestion] = (
        [(run as AnalysisRun)->:ProducedQuestion:->] if run is not None else []
    );
    return FinalReviewPacketDTO(
        id=packet.id,
        encounter_id=packet.encounter_id,
        verified_summary=(verified_summary_to_dto(summaries[0]) if summaries else None),
        clinician_note_id=notes[0].id if notes else "",
        suggested_questions=[
            suggested_question_to_dto(question) for question in questions
        ],
        active_care_gaps=[gap_to_dto(gap) for gap in active_gaps(session)],
        conflicts=[
            conflict_to_dto(conflict) for conflict in unresolved_conflicts(session)
        ],
        patient_plan_id=patient_plan_id,
        english_patient_plan=english,
        spanish_patient_plan=spanish,
        encounter_timeline=[
            timeline_event_to_dto(event) for event in [packet->:ContainsTimeline:->]
        ],
        source_fact_ids=packet.source_fact_ids,
        graph_version=packet.graph_version,
        generated_at=packet.generated_at,
        verified_items=packet.verified_items,
        requires_review_items=packet.requires_review_items,
        unverified_items=packet.unverified_items
    );
}

walker FinalReviewPacketWalker(TraceableWalker) {
    has encounter_id: str = "",
        session_id: str = "demo-default",
        reports: list[BackendResponse] = [];

    can generate with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        encounter: Encounter | None = (
            session_encounter(session as DemoSession) if session is not None else None
        );
        if (
            session is None
            or encounter is None
            or (encounter as Encounter).id != self.encounter_id
        ) {
            report failure_response(
                "ENCOUNTER_NOT_FOUND",
                "The encounter was not found in this session.",
                True,
                session.graph_version if session is not None else 0
            );
            disengage;
        }
        run: AnalysisRun | None = latest_current_analysis(session as DemoSession);
        if run is None {
            report failure_response(
                "CURRENT_ANALYSIS_NOT_FOUND",
                "Run verified encounter analysis before final review.",
                True,
                session.graph_version
            );
            disengage;
        }
        english: PatientBrief | None = current_plan_node(
            session as DemoSession, "English"
        );
        spanish: PatientBrief | None = current_plan_node(
            session as DemoSession, "Spanish"
        );
        if english is None or spanish is None {
            report failure_response(
                "PATIENT_PLAN_NOT_FOUND",
                "Generate current English and Spanish approved patient plans first.",
                True,
                session.graph_version
            );
            disengage;
        }
        current_packets: list[FinalReviewPacket] = [
            packet
            for packet in [(encounter as Encounter)->:HasFinalPacket:->]
            if packet.current
        ];
        for old in current_packets {
            old.current = False;
        }
        note: ClinicianNoteDraft | None = current_note_node(session as DemoSession);
        quick_drafts: list[QuickSummaryDraft] = [
            item
            for item in [(encounter as Encounter)->:HasQuickSummary:->]
            if item.current
        ];
        gaps: list[CareGap] = active_gaps(session as DemoSession);
        conflicts: list[Conflict] = unresolved_conflicts(session as DemoSession);
        questions: list[SuggestedQuestion] = [(run as AnalysisRun)->:ProducedQuestion:->];
        packet = FinalReviewPacket(
            session_id=self.session_id,
            id=(
                f"final-packet-{self.session_id}-"
                f"{session.graph_version}-{len(current_packets) + 1}"
            ),
            encounter_id=(encounter as Encounter).id,
            graph_version=session.graph_version,
            source_fact_ids=(run as AnalysisRun).source_fact_ids,
            verified_items=[
                "Verified encounter summary",
                "Approved English patient plan",
                "Approved Spanish patient plan"
            ],
            requires_review_items=(
                [f"{len(gaps)} active care gap(s)"] if gaps else []
            ) + ([f"{len(conflicts)} unresolved conflict(s)"] if conflicts else []) + (
                [
                    f"{len(
                        [
                            q
                            for q in questions
                            if q.status == 'open'
                        ]
                    )} "
                    "open clarification question(s)"
                ]
                    if any(q.status == "open" for q in questions)
                    else []
            ) + (
                ["Clinician note draft requires review"]
                    if note is not None
                    and (note as ClinicianNoteDraft).status != NoteStatus.APPROVED
                    else []
            ),
            unverified_items=(
                ["AI conversation draft — not yet clinician verified."]
                    if quick_drafts
                    else []
            ),
            current=True,
            generated_at=deterministic_timestamp(session.graph_version)
        );
        own_node(session as DemoSession, packet);
        (encounter as Encounter) +>:HasFinalPacket():+> packet;
        packet +>:ContainsAnalysis():+> (run as AnalysisRun);
        packet +>:ContainsPlan():+> (english as PatientBrief);
        packet +>:ContainsPlan():+> (spanish as PatientBrief);
        if note is not None {
            packet +>:ContainsNote():+> (note as ClinicianNoteDraft);
        }
        for event in [(encounter as Encounter)->:HasTimelineEvent:->] {
            packet +>:ContainsTimeline():+> event;
        }
        for old in current_packets {
            packet +>:SupersedesFinalPacket():+> old;
        }
        response = intelligence_response(
            session as DemoSession, "Final review packet generated."
        );
        response.final_review_packet = final_packet_to_dto(
            session as DemoSession, packet
        );
        response.created_graph_ids = [packet.id];
        report response;
    }
}

walker TraceAnalysisItemWalker(TraceableWalker) {
    has analysis_run_id: str = "",
        item_id: str = "",
        session_id: str = "demo-default",
        source_facts: list[VerifiedFact] = [],
        item_type: str = "",
        reports: list[BackendResponse] = [];

    can locate with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        run: AnalysisRun | None = (
            find_analysis(session as DemoSession, self.analysis_run_id)
                if session is not None
                else None
        );
        if session is None or run is None {
            report failure_response(
                "ANALYSIS_NOT_FOUND",
                "The analysis run was not found in this session.",
                True,
                session.graph_version if session is not None else 0
            );
            disengage;
        }
        visit run;
    }

    can locate_item with AnalysisRun entry {
        summaries: list[VerifiedEncounterSummary] = [here->:ProducedSummary:->[?:VerifiedEncounterSummary, id==self.item_id]];
        insights: list[InsightItem] = [here->:ProducedInsight:->[?:InsightItem, id==self.item_id]];
        questions: list[SuggestedQuestion] = [here->:ProducedQuestion:->[?:SuggestedQuestion, id==self.item_id]];
        if summaries {
            self.item_type = "verified_summary";
            visit [here->:AnalyzedFact:->];
        } elif insights {
            self.item_type = "insight";
            visit [insights[0]->:InsightSupportedBy:->];
        } elif questions {
            self.item_type = "suggested_question";
            visit [questions[0]->:QuestionBasedOn:->];
        } else {
            session: DemoSession = find_session(self.session_id) as DemoSession;
            report failure_response(
                "ANALYSIS_ITEM_NOT_FOUND",
                "The analysis item was not found in this run.",
                True,
                session.graph_version
            );
            disengage;
        }
    }

    can collect_source with VerifiedFact entry {
        if here.session_id == self.session_id {
            self.source_facts.append(here);
        }
    }

    can finish with AnalysisRun exit {
        session: DemoSession = find_session(self.session_id) as DemoSession;
        if not self.source_facts {
            report failure_response(
                "PROVENANCE_INCOMPLETE",
                "The analysis item does not have a complete current-session evidence chain.",
                False,
                session.graph_version
            );
            disengage;
        }
        output: list[AnalysisProvenanceDTO] = [];
        for fact in self.source_facts {
            provenance: MultimodalProvenanceDTO = provenance_steps_for_fact(
                fact, self.item_id
            );
            output.append(
                AnalysisProvenanceDTO(
                    analysis_run_id=self.analysis_run_id,
                    item_id=self.item_id,
                    item_type=self.item_type,
                    source_fact_ids=[fact.id],
                    ordered_steps=provenance.ordered_steps,
                    source_excerpt=provenance.source_excerpt,
                    source_type=provenance.source_type,
                    complete=provenance.complete
                )
            );
        }
        if any(not item.complete for item in output) {
            report failure_response(
                "PROVENANCE_INCOMPLETE",
                "The analysis item does not have a complete current-session evidence chain.",
                False,
                session.graph_version
            );
            disengage;
        }
        response = intelligence_response(session, "Analysis item provenance traced.");
        response.analysis_provenance = output;
        response.traversal_trace = self.traversal_trace;
        report response;
    }
}
