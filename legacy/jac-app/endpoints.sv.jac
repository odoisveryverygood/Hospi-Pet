"""Stable Jac-native public actions consumed by the Pa-Co frontend."""

import from models {
    AIStatusDTO,
    BackendResponse,
    CandidateFact,
    DemoSession,
    PatientPlanDTO,
    VerifiedFact,
    VerifiedFactReference,
}
import from walkers {
    AIConsultationIngestWalker,
    CandidateProposalWalker,
    ConsultationIngestWalker,
    VerificationWalker,
    CareGapWalker,
    GapResolutionWalker,
    PatientPlanWalker,
    EvidenceAuditWalker,
    TraceProvenanceWalker,
    ResetDemoWalker,
    failure_response,
    find_session,
    fact_is_conflicted,
    candidates_for_session,
    verified_facts_for_session,
    build_demo_state,
    build_care_graph,
}
import from patient_agent { PatientQuestionWalker }
import from ai {
    BriefEnhancementAttempt,
    CandidateExtractionAttempt,
    QuestionMatchAttempt,
    run_brief_enhancement,
    run_candidate_extraction,
    run_question_match,
}

def first_response(reports: list[BackendResponse], operation: str) -> BackendResponse {
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

def valid_ai_mode(mode: str) -> bool {
    return mode.lower().strip() in [
        "disabled",
        "live",
        "mock",
        "mock_malformed",
        "test-no-key",
        "test-api-error",
        "test-timeout",
        "test-empty"
    ];
}

def mark_recoverable_ai_fallback(
    response: BackendResponse, status: AIStatusDTO | None
) {
    response.ai_status = status;
    if status is not None and status.fallback_used {
        response.recoverable = True;
        response.error_code = status.diagnostic_code;
    }
}

def:pub load_demo_encounter(
    session_id: str = "demo-default", ai_mode: str = "disabled"
) -> BackendResponse {
    if not valid_ai_mode(ai_mode) {
        return failure_response(
            "AI_MODE_INVALID",
            "ai_mode must be disabled, live, mock, or mock_malformed.",
            True,
            0
        );
    }
    if ai_mode.lower().strip() == "disabled" {
        result = root spawn ConsultationIngestWalker(session_id=session_id);
        return first_response(result.reports, "load_demo_encounter");
    }

    existing_session: DemoSession | None = find_session(session_id);
    transcript_response: BackendResponse;
    if existing_session is not None {
        existing_state = build_demo_state(existing_session as DemoSession);
        if existing_state.verified_facts {
            return failure_response(
                "AI_SESSION_ALREADY_INITIALIZED",
                "Reset the synthetic session before running optional AI extraction.",
                True,
                existing_session.graph_version
            );
        }
        transcript_response = BackendResponse(
            success=True,
            message="Existing reset transcript selected for optional extraction.",
            current_graph_version=existing_session.graph_version,
            demo_state=existing_state
        );
    } else {
        transcript_result = root spawn AIConsultationIngestWalker(
            session_id=session_id
        );
        transcript_response = first_response(
            transcript_result.reports, "load_demo_encounter.transcript"
        );
    }
    if not transcript_response.success or transcript_response.demo_state is None {
        return transcript_response;
    }
    extraction: CandidateExtractionAttempt = run_candidate_extraction(
        transcript_response.demo_state.transcript, ai_mode
    );
    proposal_result = root spawn CandidateProposalWalker(
        session_id=session_id, proposals=extraction.candidates
    );
    response: BackendResponse = first_response(
        proposal_result.reports, "load_demo_encounter.proposals"
    );
    mark_recoverable_ai_fallback(response, extraction.ai_status);
    if extraction.ai_status is not None and extraction.ai_status.fallback_used {
        response.message = (
            "Optional AI extraction was unavailable or invalid; the prepared "
            "deterministic candidates were loaded safely."
        );
    }
    return response;
}

def:pub get_candidate_facts(session_id: str = "demo-default") -> BackendResponse {
    session: DemoSession | None = find_session(session_id);
    if session is None {
        return failure_response(
            "DEMO_NOT_LOADED",
            "Load the synthetic encounter before reading candidates.",
            True,
            0
        );
    }
    state = build_demo_state(session);
    return BackendResponse(
        success=True,
        message="Candidate facts loaded.",
        current_graph_version=session.graph_version,
        candidate_facts=state.candidate_facts
    );
}

def:pub verify_fact(
    fact_id: str, decision: str, clinician_id: str, session_id: str = "demo-default"
) -> BackendResponse {
    result = root spawn VerificationWalker(
        session_id=session_id,
        fact_id=fact_id,
        decision=decision,
        clinician_id=clinician_id
    );
    return first_response(result.reports, "verify_fact");
}

def:pub get_care_graph(session_id: str = "demo-default") -> BackendResponse {
    session: DemoSession | None = find_session(session_id);
    if session is None {
        return failure_response(
            "DEMO_NOT_LOADED",
            "Load the synthetic encounter before reading the care graph.",
            True,
            0
        );
    }
    return BackendResponse(
        success=True,
        message="Care graph loaded.",
        current_graph_version=session.graph_version,
        care_graph=build_care_graph(session)
    );
}

def:pub run_care_gap_check(session_id: str = "demo-default") -> BackendResponse {
    result = root spawn CareGapWalker(session_id=session_id);
    return first_response(result.reports, "run_care_gap_check");
}

def:pub resolve_gap(
    gap_id: str,
    resolution: str,
    owner: str,
    due_date: str,
    session_id: str = "demo-default"
) -> BackendResponse {
    result = root spawn GapResolutionWalker(
        session_id=session_id,
        gap_id=gap_id,
        resolution=resolution,
        owner=owner,
        due_date=due_date
    );
    return first_response(result.reports, "resolve_gap");
}

def:pub generate_patient_plan(
    language: str, session_id: str = "demo-default", ai_mode: str = "disabled"
) -> BackendResponse {
    if not valid_ai_mode(ai_mode) {
        return failure_response(
            "AI_MODE_INVALID",
            "ai_mode must be disabled, live, mock, or mock_malformed.",
            True,
            0
        );
    }
    if ai_mode.lower().strip() == "disabled" {
        result = root spawn PatientPlanWalker(session_id=session_id, language=language);
        return first_response(result.reports, "generate_patient_plan");
    }

    english_result = root spawn PatientPlanWalker(
        session_id=session_id, language="English"
    );
    response: BackendResponse = first_response(
        english_result.reports, "generate_patient_plan.english"
    );
    if not response.success or response.patient_plan is None {
        return response;
    }
    if language.lower() == "english" {
        response.message = (
            "Approved English patient brief generated; no translation was needed."
        );
        return response;
    }
    if language.lower() != "spanish" {
        return failure_response(
            "UNSUPPORTED_LANGUAGE",
            "P0 supports English and Spanish only.",
            True,
            response.current_graph_version
        );
    }
    enhancement: BriefEnhancementAttempt = run_brief_enhancement(
        response.patient_plan as PatientPlanDTO, ai_mode, "translate"
    );
    response.patient_plan = enhancement.plan;
    mark_recoverable_ai_fallback(response, enhancement.ai_status);
    response.message = (
        "Approved patient brief translated to Spanish."
            if enhancement.ai_status is not None and enhancement.ai_status.used
            else "Translation fell back to the approved English patient brief."
    );
    return response;
}

def:pub simplify_patient_plan(
    session_id: str = "demo-default", ai_mode: str = "live"
) -> BackendResponse {
    if not valid_ai_mode(ai_mode) or ai_mode.lower().strip() == "disabled" {
        return failure_response(
            "AI_MODE_INVALID",
            "simplify_patient_plan requires live, mock, or mock_malformed mode.",
            True,
            0
        );
    }
    english_result = root spawn PatientPlanWalker(
        session_id=session_id, language="English"
    );
    response: BackendResponse = first_response(
        english_result.reports, "simplify_patient_plan.english"
    );
    if not response.success or response.patient_plan is None {
        return response;
    }
    enhancement: BriefEnhancementAttempt = run_brief_enhancement(
        response.patient_plan as PatientPlanDTO, ai_mode, "simplify"
    );
    response.patient_plan = enhancement.plan;
    mark_recoverable_ai_fallback(response, enhancement.ai_status);
    response.message = (
        "Approved patient brief simplified without changing source facts."
            if enhancement.ai_status is not None and enhancement.ai_status.used
            else "Simplification fell back to the approved English patient brief."
    );
    return response;
}

def:pub ask_patient_question(
    question: str, session_id: str = "demo-default", ai_mode: str = "disabled"
) -> BackendResponse {
    if not valid_ai_mode(ai_mode) {
        return failure_response(
            "AI_MODE_INVALID",
            "ai_mode must be disabled, live, mock, or mock_malformed.",
            True,
            0
        );
    }
    if ai_mode.lower().strip() == "disabled" {
        result = root spawn PatientQuestionWalker(
            session_id=session_id, question=question
        );
        return first_response(result.reports, "ask_patient_question");
    }

    session: DemoSession | None = find_session(session_id);
    if session is None {
        return failure_response(
            "DEMO_NOT_LOADED",
            "Load the synthetic encounter before asking a question.",
            True,
            0
        );
    }
    active_session: DemoSession = session as DemoSession;
    references: list[VerifiedFactReference] = [
        VerifiedFactReference(id=fact.id, category=fact.category, value=fact.value)
        for fact in verified_facts_for_session(active_session)
        if (fact.visible_to_patient and not fact_is_conflicted(active_session, fact.id))
    ];
    match_attempt: QuestionMatchAttempt = run_question_match(
        question, references, ai_mode
    );
    status: AIStatusDTO | None = match_attempt.ai_status;
    restrict_ids: bool = (
        status is not None
        and (status.used or status.diagnostic_code.startswith("AI_MATCH_"))
    );
    result = root spawn PatientQuestionWalker(
        session_id=session_id,
        question=question,
        restrict_to_fact_ids=restrict_ids,
        allowed_fact_ids=match_attempt.matched_fact_ids,
        ai_matching_used=status is not None and status.used
    );
    response: BackendResponse = first_response(result.reports, "ask_patient_question");
    mark_recoverable_ai_fallback(response, status);
    return response;
}

def:pub run_evidence_audit(session_id: str = "demo-default") -> BackendResponse {
    result = root spawn EvidenceAuditWalker(session_id=session_id);
    return first_response(result.reports, "run_evidence_audit");
}

def:pub trace_provenance(
    output_id: str, session_id: str = "demo-default"
) -> BackendResponse {
    result = root spawn TraceProvenanceWalker(
        session_id=session_id, output_id=output_id
    );
    return first_response(result.reports, "trace_provenance");
}

def:pub reset_demo(session_id: str = "demo-default") -> BackendResponse {
    result = root spawn ResetDemoWalker(session_id=session_id);
    return first_response(result.reports, "reset_demo");
}

def:pub add_demo_contradiction(session_id: str = "demo-default") -> BackendResponse {
    session: DemoSession | None = find_session(session_id);
    if session is None {
        return failure_response(
            "DEMO_NOT_LOADED",
            "Load the synthetic encounter before adding the contradiction.",
            True,
            0
        );
    }
    base_follow_up: list[VerifiedFact] = [
        fact
        for fact in verified_facts_for_session(session as DemoSession)
        if fact.id == "verified-candidate-follow-up"
    ];
    if not base_follow_up {
        return failure_response(
            "BASE_FOLLOW_UP_NOT_VERIFIED",
            "Accept the prepared two-week follow-up before the audit demo.",
            True,
            session.graph_version
        );
    }
    existing: list[CandidateFact] = [
        candidate
        for candidate in candidates_for_session(session as DemoSession)
        if candidate.id == "candidate-follow-up-4-weeks"
    ];
    if existing {
        return failure_response(
            "CONTRADICTION_ALREADY_ADDED",
            "The prepared four-week statement already exists.",
            False,
            session.graph_version
        );
    }

    ingest_result = root spawn ConsultationIngestWalker(
        session_id=session_id, include_contradiction=True
    );
    ingest_response: BackendResponse = first_response(
        ingest_result.reports, "add_demo_contradiction.ingest"
    );
    if not ingest_response.success {
        return ingest_response;
    }

    verification_result = root spawn VerificationWalker(
        session_id=session_id,
        fact_id="candidate-follow-up-4-weeks",
        decision="accept",
        clinician_id="demo-clinician"
    );
    return first_response(verification_result.reports, "add_demo_contradiction.verify");
}
