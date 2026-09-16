"""Stable public adapters for translation and verified intelligence."""

import from models { BackendResponse, }
import from walkers { failure_response, }
import from intelligence_walkers {
    ClarifyingQuestionWalker,
    DismissSuggestedQuestionWalker,
    FinalReviewPacketWalker,
    GetLiveQuickSummaryWalker,
    GetTranslatedTranscriptWalker,
    GetVerifiedEncounterAnalysisWalker,
    LiveQuickSummaryWalker,
    MarkSuggestedQuestionAnsweredWalker,
    RetryTranslationWalker,
    TraceAnalysisItemWalker,
    TranslateTranscriptChunkWalker,
    VerifiedEncounterAnalysisWalker,
}

def intelligence_first_response(
    reports: list[BackendResponse], operation: str
) -> BackendResponse {
    if reports {
        return reports[0];
    }
    return failure_response(
        "WALKER_NO_RESPONSE",
        f"{operation} completed without a structured response.",
        True,
        0
    );
}

def:pub translate_transcript_chunk(
    transcript_chunk_id: str, target_language: str, session_id: str = "demo-default"
) -> BackendResponse {
    result = root spawn TranslateTranscriptChunkWalker(
        transcript_chunk_id=transcript_chunk_id,
        target_language=target_language,
        session_id=session_id
    );
    return intelligence_first_response(result.reports, "translate_transcript_chunk");
}

def:pub get_translated_transcript(
    capture_session_id: str, target_language: str, session_id: str = "demo-default"
) -> BackendResponse {
    result = root spawn GetTranslatedTranscriptWalker(
        capture_session_id=capture_session_id,
        target_language=target_language,
        session_id=session_id
    );
    return intelligence_first_response(result.reports, "get_translated_transcript");
}

def:pub retry_translation(
    translated_chunk_id: str, session_id: str = "demo-default"
) -> BackendResponse {
    result = root spawn RetryTranslationWalker(
        translated_chunk_id=translated_chunk_id, session_id=session_id
    );
    return intelligence_first_response(result.reports, "retry_translation");
}

def:pub generate_live_quick_summary(
    encounter_id: str, session_id: str = "demo-default"
) -> BackendResponse {
    result = root spawn LiveQuickSummaryWalker(
        encounter_id=encounter_id, session_id=session_id
    );
    return intelligence_first_response(result.reports, "generate_live_quick_summary");
}

def:pub get_live_quick_summary(
    encounter_id: str, session_id: str = "demo-default"
) -> BackendResponse {
    result = root spawn GetLiveQuickSummaryWalker(
        encounter_id=encounter_id, session_id=session_id
    );
    return intelligence_first_response(result.reports, "get_live_quick_summary");
}

def:pub run_verified_encounter_analysis(
    encounter_id: str, session_id: str = "demo-default"
) -> BackendResponse {
    result = root spawn VerifiedEncounterAnalysisWalker(
        encounter_id=encounter_id, session_id=session_id
    );
    return intelligence_first_response(
        result.reports, "run_verified_encounter_analysis"
    );
}

def:pub get_verified_encounter_analysis(
    analysis_run_id: str, session_id: str = "demo-default"
) -> BackendResponse {
    result = root spawn GetVerifiedEncounterAnalysisWalker(
        analysis_run_id=analysis_run_id, session_id=session_id
    );
    return intelligence_first_response(
        result.reports, "get_verified_encounter_analysis"
    );
}

def:pub generate_clarifying_questions(
    encounter_id: str, analysis_run_id: str, session_id: str = "demo-default"
) -> BackendResponse {
    result = root spawn ClarifyingQuestionWalker(
        encounter_id=encounter_id,
        analysis_run_id=analysis_run_id,
        session_id=session_id
    );
    return intelligence_first_response(result.reports, "generate_clarifying_questions");
}

def:pub dismiss_suggested_question(
    question_id: str, clinician_id: str, session_id: str = "demo-default"
) -> BackendResponse {
    result = root spawn DismissSuggestedQuestionWalker(
        question_id=question_id, clinician_id=clinician_id, session_id=session_id
    );
    return intelligence_first_response(result.reports, "dismiss_suggested_question");
}

def:pub mark_question_answered(
    question_id: str,
    answer_source_fact_id: str,
    clinician_id: str,
    session_id: str = "demo-default"
) -> BackendResponse {
    result = root spawn MarkSuggestedQuestionAnsweredWalker(
        question_id=question_id,
        answer_source_fact_id=answer_source_fact_id,
        clinician_id=clinician_id,
        session_id=session_id
    );
    return intelligence_first_response(result.reports, "mark_question_answered");
}

def:pub generate_final_review_packet(
    encounter_id: str, session_id: str = "demo-default"
) -> BackendResponse {
    result = root spawn FinalReviewPacketWalker(
        encounter_id=encounter_id, session_id=session_id
    );
    return intelligence_first_response(result.reports, "generate_final_review_packet");
}

def:pub trace_analysis_item(
    analysis_run_id: str, item_id: str, session_id: str = "demo-default"
) -> BackendResponse {
    result = root spawn TraceAnalysisItemWalker(
        analysis_run_id=analysis_run_id, item_id=item_id, session_id=session_id
    );
    return intelligence_first_response(result.reports, "trace_analysis_item");
}
