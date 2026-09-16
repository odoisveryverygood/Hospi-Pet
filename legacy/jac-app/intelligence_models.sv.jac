"""Persistent graph schema for live translation and verified intelligence."""

import from models {
    AnalysisSourceScope,
    AnalysisStatus,
    CareGap,
    CareNode,
    ClinicianNoteDraft,
    Conflict,
    Encounter,
    PatientBrief,
    QuestionPurpose,
    TimelineEvent,
    TranscriptChunk,
    TranslationStatus,
    VerifiedFact,
}

node TranslationSession(CareNode) {
    has id: str = "",
        capture_session_id: str = "",
        source_language: str = "",
        target_language: str = "",
        status: TranslationStatus = TranslationStatus.PENDING,
        mode: str = "deterministic",
        created_at: str = "";
}

node TranslatedTranscriptChunk(CareNode) {
    has id: str = "",
        original_chunk_id: str = "",
        capture_session_id: str = "",
        source_language: str = "",
        target_language: str = "",
        original_text: str = "",
        translated_text: str = "",
        speaker: str = "",
        sequence: int = 0,
        status: TranslationStatus = TranslationStatus.PENDING,
        translation_mode: str = "deterministic",
        fallback_used: bool = False,
        current: bool = True,
        created_at: str = "";
}

node QuickSummaryDraft(CareNode) {
    has id: str = "",
        encounter_id: str = "",
        status: AnalysisStatus = AnalysisStatus.CREATED,
        summary: str = "",
        key_points: list[str] = [],
        source_chunk_ids: list[str] = [],
        unverified: bool = True,
        source_scope: AnalysisSourceScope = (AnalysisSourceScope.UNVERIFIED_TRANSCRIPT),
        model_mode: str = "deterministic",
        fallback_used: bool = False,
        current: bool = True,
        generated_at: str = "";
}

node AnalysisRun(CareNode) {
    has id: str = "",
        encounter_id: str = "",
        status: AnalysisStatus = AnalysisStatus.CREATED,
        source_scope: AnalysisSourceScope = AnalysisSourceScope.VERIFIED_GRAPH,
        graph_version: int = 0,
        accepted_fact_ids: list[str] = [],
        rejected_fact_ids_excluded: list[str] = [],
        source_fact_ids: list[str] = [],
        model_mode: str = "deterministic",
        fallback_used: bool = False,
        current: bool = True,
        superseding_run_id: str = "",
        created_at: str = "",
        completed_at: str = "";
}

node VerifiedEncounterSummary(CareNode) {
    has id: str = "",
        encounter_id: str = "",
        summary: str = "",
        patient_concerns: list[str] = [],
        medications: list[str] = [],
        allergies: list[str] = [],
        laboratory_orders: list[str] = [],
        referrals: list[str] = [],
        follow_ups: list[str] = [],
        outstanding_tasks: list[str] = [],
        contradictions: list[str] = [],
        source_fact_ids: list[str] = [],
        verified_only: bool = True,
        current: bool = True,
        generated_at: str = "";
}

node InsightItem(CareNode) {
    has id: str = "",
        insight_type: str = "",
        title: str = "",
        description: str = "",
        severity: str = "review",
        source_fact_ids: list[str] = [],
        related_gap_ids: list[str] = [],
        requires_clinician_review: bool = True;
}

node SuggestedQuestion(CareNode) {
    has id: str = "",
        question: str = "",
        purpose: QuestionPurpose = (QuestionPurpose.CLARIFY_MISSING_INFORMATION),
        explanation: str = "",
        source_fact_ids: list[str] = [],
        related_gap_ids: list[str] = [],
        clinician_only: bool = True,
        status: str = "open",
        reviewed_by: str = "",
        answer_source_fact_id: str = "",
        reviewed_at: str = "";
}

node FinalReviewPacket(CareNode) {
    has id: str = "",
        encounter_id: str = "",
        graph_version: int = 0,
        source_fact_ids: list[str] = [],
        verified_items: list[str] = [],
        requires_review_items: list[str] = [],
        unverified_items: list[str] = [],
        current: bool = True,
        generated_at: str = "";
}

sem TranslationSession = "A session-local grouping of finalized chunk translations for one target language.";
sem TranslatedTranscriptChunk.original_text = "An immutable copy of exact source evidence. Translation never replaces it.";
sem TranslatedTranscriptChunk.translated_text = "Literal translation only. Preserve numbers, dates, names, negation, uncertainty, and instruction strength.";
sem QuickSummaryDraft = "Unverified conversation draft. It has no path to verification, patient plans, or approved notes.";
sem AnalysisRun = "A versioned traversal of accepted facts only. AI cannot create verification or resolve graph state.";
sem VerifiedEncounterSummary = "A verified-only organization of graph facts, not a diagnosis or treatment recommendation.";
sem InsightItem = "A documentation gap, missing administrative field, or contradiction with traversable evidence.";
sem SuggestedQuestion = "A clinician-only care-coordination question based on an existing gap or conflict.";
sem FinalReviewPacket = "A packet preserving separate verified, review-required, and unverified sections.";

edge HasTranslationSession: Encounter --> TranslationSession {}
edge SessionTranslatedChunk: TranslationSession --> TranslatedTranscriptChunk {}

edge TranslatedAs: TranscriptChunk --> TranslatedTranscriptChunk {}
edge SupersedesTranslation: TranslatedTranscriptChunk --> TranslatedTranscriptChunk {}

edge HasQuickSummary: Encounter --> QuickSummaryDraft {}
edge SupportedByChunk: QuickSummaryDraft --> TranscriptChunk {}
edge SupersedesQuickSummary: QuickSummaryDraft --> QuickSummaryDraft {}

edge HasAnalysisRun: Encounter --> AnalysisRun {}
edge AnalyzedFact: AnalysisRun --> VerifiedFact {}
edge ProducedSummary: AnalysisRun --> VerifiedEncounterSummary {}
edge ProducedInsight: AnalysisRun --> InsightItem {}
edge ProducedQuestion: AnalysisRun --> SuggestedQuestion {}
edge InsightSupportedBy: InsightItem --> VerifiedFact {}
edge RelatedToGap: InsightItem --> CareGap {}
edge QuestionBasedOn: SuggestedQuestion --> VerifiedFact {}
edge ClarifiesGap: SuggestedQuestion --> CareGap {}
edge ClarifiesConflict: SuggestedQuestion --> Conflict {}
edge QuestionAnsweredBy: SuggestedQuestion --> VerifiedFact {}
edge SupersedesAnalysis: AnalysisRun --> AnalysisRun {}

edge HasFinalPacket: Encounter --> FinalReviewPacket {}
edge ContainsAnalysis: FinalReviewPacket --> AnalysisRun {}
edge ContainsNote: FinalReviewPacket --> ClinicianNoteDraft {}
edge ContainsPlan: FinalReviewPacket --> PatientBrief {}
edge ContainsTimeline: FinalReviewPacket --> TimelineEvent {}
edge SupersedesFinalPacket: FinalReviewPacket --> FinalReviewPacket {}
