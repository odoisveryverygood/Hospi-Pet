"""Frontend-only interaction implementations for Hospi-Pet Screen 1."""

impl app.loadDemo -> None {
    if not canLoadDemo(demo_loaded, is_transitioning) {
        return;
    }

    cancelSequence();
    resetIntelligence();
    current_screen = "verification";
    is_transitioning = True;
    demo_loaded = False;
    patient_data = {};
    transcript_data = [];
    candidate_facts = [];
    document_candidates = [];
    fact_decisions = blankFactDecisions();
    pending_fact_id = "";
    pending_fact_decision = "";
    insights_preparing = False;
    mascot_message_visible = False;
    highlighted_source_id = "";
    trace_message = "";
    note_status = "empty";
    note_error = "";
    note_edits = {};
    note_pending_action = "";
    note_pending_section = "";
    result_status = "missing";
    result_data = {};
    assistant_state = "listening";
    assistant_status = "Loading the synthetic encounter";
    assistant_message = "Connecting to the Jac demo session.";
    callBackendAction("reset_demo", {"session_id": "hospi-pet-frontend-demo"}).then(
        receiveDemoReset
    ).catch(
        failDemoLoad
    );
}


impl app.receiveDemoReset(response: any) -> None {
    if not response["success"] {
        failDemoLoad(response);
        return;
    }
    callBackendAction(
        "load_demo_encounter", {"session_id": "hospi-pet-frontend-demo"}
    ).then(
        receiveDemoEncounter
    ).catch(
        failDemoLoad
    );
}


impl app.receiveDemoEncounter(response: any) -> None {
    if not response["success"] {
        failDemoLoad(response);
        return;
    }
    state: any = response["demo_state"];
    patient_data = {
        "name": state["patient"]["display_name"],
        "encounter_type": "Synthetic live encounter",
        "consultation_status": state["encounter"]["status"],
        "encounter_date": state["encounter"]["occurred_at"],
        "visit_id": state["encounter"]["id"],
        "review_status": "Ready for clinician verification"
    };
    transcript_data = state["transcript"];
    candidate_facts = state["candidate_facts"];
    demo_loaded = True;
    is_transitioning = False;
    backend_connected = True;
    assistant_state = "complete";
    assistant_status = "Encounter ready for review";
    assistant_message = response["message"];
}


impl app.failDemoLoad(error: any) -> None {
    is_transitioning = False;
    demo_loaded = False;
    assistant_state = "idle";
    assistant_status = "Jac backend unavailable";
    assistant_message = (
        error["message"]
            if isinstance(error, dict) and "message" in error
            else "Start the integrated Jac server or use the labeled prepared voice fallback."
    );
}

impl app.resetDemo -> None {
    if backend_connected {
        callBackendAction(
            "reset_demo", {"session_id": "hospi-pet-frontend-demo"}
        ).catch(
            lambda (error: any) { None; }
        );
    }
    cancelSequence();
    cancelVoiceTimers();
    cancelDocumentTimer();
    cancelResultTimer();
    resetIntelligence();
    stopVoiceCapture();
    stopCameraCapture();
    cancelClinicianNoteTimer();
    if trace_timer is not None {
        clearTimeout(trace_timer);
        trace_timer = None;
    }
    current_screen = "verification";
    demo_loaded = False;
    is_transitioning = False;
    patient_data = {};
    transcript_data = [];
    candidate_facts = [];
    document_candidates = [];
    assistant_state = "idle";
    assistant_status = "Ready for an encounter";
    assistant_message = "Load the synthetic demo when you're ready.";
    fact_decisions = blankFactDecisions();
    pending_fact_id = "";
    pending_fact_decision = "";
    insights_preparing = False;
    mascot_message_visible = False;
    highlighted_source_id = "";
    trace_message = "";
    voice_permission = "not_requested";
    voice_status = "idle";
    voice_requesting = False;
    voice_recording = False;
    voice_stopping = False;
    voice_prepared_demo = False;
    voice_interim_text = "";
    voice_chunk_queue = [];
    voice_chunk_pending = False;
    voice_next_sequence = 1;
    voice_finalize_requested = False;
    recording_seconds = 0;
    document_permission = "not_requested";
    document_requesting = False;
    document_processing = False;
    document_stage = "idle";
    document_message = "";
    document_source_type = "";
    document_file_name = "";
    if len(document_preview_url) > 0 and document_preview_url.startswith("blob:") {
        browser_window: any = window;
        browser_url: any = browser_window.URL;
        browser_url.revokeObjectURL(document_preview_url);
    }
    document_preview_url = "";
    document_label = "";
    document_source_id = "";
    document_artifact_id = "";
    document_text = "";
    camera_active = False;
    document_stage_index = 0;
    note_status = "empty";
    note_error = "";
    note_edits = {};
    note_pending_action = "";
    note_pending_section = "";
    result_status = "missing";
    result_data = {};
}

impl app.activateAssistant -> None {
    mascot_message_visible = not mascot_message_visible;
}

impl app.beginAnalyzing -> None {
    sequence_timer = None;
    assistant_state = "analyzing";
    assistant_status = statusForState("analyzing");
    assistant_message = "Reviewing the conversation.";
    sequence_timer = setTimeout(revealFacts, sequenceDelayForState("analyzing"));
}

impl app.revealFacts -> None {
    sequence_timer = None;
    assistant_state = "idle";
    assistant_status = "Load the prepared encounter";
    assistant_message = "Candidate facts are created only by the Jac backend.";
    is_transitioning = False;
}

impl app.finishDemo -> None {
    sequence_timer = None;
    assistant_state = "complete";
    assistant_status = statusForState("complete");
    assistant_message = "I found a few details to verify.";
    is_transitioning = False;
}

impl app.finishInsightsPreparation -> None {
    sequence_timer = None;
    insights_preparing = False;
}

impl app.cancelSequence -> None {
    if sequence_timer is not None {
        clearTimeout(sequence_timer);
        sequence_timer = None;
    }
}

impl app.acceptFact(fact_id: str) -> None {
    verifyFact(fact_id, "accept");
}


impl app.rejectFact(fact_id: str) -> None {
    verifyFact(fact_id, "reject");
}


impl app.verifyFact(fact_id: str, decision: str) -> None {
    if len(pending_fact_id) > 0 {
        return;
    }
    previous_decision: str = (
        fact_decisions[fact_id] if fact_id in fact_decisions else "neutral"
    );
    pending_fact_id = fact_id;
    pending_fact_decision = decision;
    if analysisBecomesStale(
        analysis_status,
        previous_decision != ("accepted" if decision == "accept" else "rejected")
    ) {
        analysis_stale = True;
        final_review_status = "empty";
        final_review_data = {};
    }
    intelligence_pending_action = "verify";
    callBackendAction(
        "verify_fact",
        {
            "fact_id": fact_id,
            "decision": decision,
            "clinician_id": "demo-clinician",
            "session_id": "hospi-pet-frontend-demo"
        }
    ).then(
        lambda (response: any) { receiveFactDecision(response, fact_id, decision); }
    ).catch(
        failFactDecision
    );
}


impl app.receiveFactDecision(response: any, fact_id: str, decision: str) -> None {
    intelligence_pending_action = "";
    if response["success"] {
        fact_decisions = updateFactDecision(
            fact_decisions, fact_id, "accepted" if decision == "accept" else "rejected"
        );
        intelligence_error_message = "";
    } else {
        intelligence_error_message = response["message"];
    }
    pending_fact_id = "";
    pending_fact_decision = "";
}


impl app.failFactDecision(error: any) -> None {
    intelligence_pending_action = "";
    intelligence_error_message = "The verification action is unavailable. No decision was saved.";
    pending_fact_id = "";
    pending_fact_decision = "";
}

impl app.continueToInsights -> None {
    if canContinueToInsights(demo_loaded, is_transitioning, len(candidate_facts) > 0) {
        current_screen = "insights";
        insights_preparing = True;
        mascot_message_visible = False;
        sequence_timer = setTimeout(finishInsightsPreparation, 800.0);
        window.scrollTo(0, 0);
    }
}

impl app.backToVerification -> None {
    cancelSequence();
    cancelResultTimer();
    insights_preparing = False;
    current_screen = "verification";
    mascot_message_visible = False;
    window.scrollTo(0, 0);
}


impl app.continueToResults -> None {
    if insights_preparing {
        return;
    }

    cancelSequence();
    cancelResultTimer();
    current_screen = "results";
    mascot_message_visible = False;
    if (
        "id" in analysis_data and "id" not in final_review_data and not analysis_stale
    ) {
        prepareFinalReview();
    }
    window.scrollTo(0, 0);
}


impl app.finishResult -> None {
    result_timer = None;
}


impl app.retryResult -> None {
    prepareFinalReview();
}


impl app.backToInsights -> None {
    cancelResultTimer();
    result_status = "missing";
    result_data = {};
    current_screen = "insights";
    mascot_message_visible = False;
    window.scrollTo(0, 0);
}


impl app.cancelResultTimer -> None {
    if result_timer is not None {
        clearTimeout(result_timer);
        result_timer = None;
    }
}


impl app.loadTranslations -> None {
    if len(intelligence_pending_action) > 0 {
        return;
    }
    if not demo_loaded {
        translation_status = "recoverable_error";
        intelligence_error_message = "Load the prepared encounter first.";
        return;
    }
    cancelIntelligenceTimer();
    intelligence_pending_action = "translation";
    translation_status = "loading";
    intelligence_error_message = "";
    if len(transcript_data) > 0 {
        translation_chunk_index = 0;
        translateChunkAt(0, []);
    } elif len(capture_session_id) > 0 {
        callBackendAction(
            "get_translated_transcript",
            {
                "capture_session_id": capture_session_id,
                "target_language": "English",
                "session_id": "hospi-pet-frontend-demo"
            }
        ).then(
            lambda (response: any) { receiveIntelligenceResponse(
                response, "translation"
            ); }
        ).catch(
            failIntelligenceAction
        );
    } else {
        intelligence_pending_action = "";
        translation_status = "recoverable_error";
        intelligence_error_message = (
            "Record or load the prepared voice encounter before translating."
        );
    }
}


impl app.translateChunkAt(index: int, rows: list[dict[str, any]]) -> None {
    if index >= len(transcript_data) {
        translated_rows = rows;
        translation_chunk_index = index;
        translation_status = "success";
        intelligence_pending_action = "";
        return;
    }
    callBackendAction(
        "translate_transcript_chunk",
        {
            "transcript_chunk_id": transcript_data[index]["id"],
            "target_language": "English",
            "session_id": "hospi-pet-frontend-demo"
        }
    ).then(
        lambda (response: any) { receiveTranslationChunk(response, index, rows); }
    ).catch(
        failIntelligenceAction
    );
}


impl app.receiveTranslationChunk(
    response: any, index: int, rows: list[dict[str, any]]
) -> None {
    if not response["success"] {
        failIntelligenceAction(response);
        return;
    }
    next_rows: list[dict[str, any]] = [*rows, response["translated_chunk"]];
    translateChunkAt(index + 1, next_rows);
}


impl app.generateQuickNote -> None {
    if len(intelligence_pending_action) > 0 {
        return;
    }
    if not demo_loaded {
        quick_note_status = "recoverable_error";
        intelligence_error_message = "Load the prepared encounter first.";
        return;
    }
    cancelIntelligenceTimer();
    intelligence_pending_action = "quick_note";
    quick_note_status = "loading";
    intelligence_error_message = "";
    callBackendAction(
        "generate_live_quick_summary",
        {"encounter_id": "encounter-maya-001", "session_id": "hospi-pet-frontend-demo"}
    ).then(
        lambda (response: any) { receiveIntelligenceResponse(response, "quick_note"); }
    ).catch(
        failIntelligenceAction
    );
}


impl app.analyzeAcceptedInformation -> None {
    if (
        len(intelligence_pending_action) > 0
        or acceptedCandidateCount(fact_decisions) == 0
    ) {
        return;
    }
    cancelIntelligenceTimer();
    intelligence_pending_action = "analysis";
    analysis_status = "loading";
    intelligence_error_message = "";
    callBackendAction(
        "run_verified_encounter_analysis",
        {"encounter_id": "encounter-maya-001", "session_id": "hospi-pet-frontend-demo"}
    ).then(
        lambda (response: any) { receiveIntelligenceResponse(response, "analysis"); }
    ).catch(
        failIntelligenceAction
    );
}


impl app.loadAnalysisTrace -> None {
    if (len(intelligence_pending_action) > 0 or "id" not in analysis_data) {
        return;
    }
    cancelIntelligenceTimer();
    intelligence_pending_action = "trace";
    source_trace_status = "loading";
    intelligence_error_message = "";
    item_id: str = (
        analysis_data["summary"]["id"]
            if "summary" in analysis_data and analysis_data["summary"] is not None
            else analysis_data["id"]
    );
    callBackendAction(
        "trace_analysis_item",
        {
            "analysis_run_id": analysis_data["id"],
            "item_id": item_id,
            "session_id": "hospi-pet-frontend-demo"
        }
    ).then(
        lambda (response: any) { receiveIntelligenceResponse(response, "trace"); }
    ).catch(
        failIntelligenceAction
    );
}


impl app.prepareFinalReview -> None {
    if (
        len(intelligence_pending_action) > 0
        or "id" not in analysis_data
        or analysis_stale
    ) {
        return;
    }
    cancelIntelligenceTimer();
    intelligence_pending_action = "final_review";
    final_review_status = "loading";
    intelligence_error_message = "";
    callBackendAction(
        "generate_final_review_packet",
        {"encounter_id": "encounter-maya-001", "session_id": "hospi-pet-frontend-demo"}
    ).then(
        lambda (response: any) { receiveIntelligenceResponse(
            response, "final_review"
        ); }
    ).catch(
        failIntelligenceAction
    );
}


impl app.finishIntelligenceAction -> None {
    intelligence_timer = None;
    failIntelligenceAction(None);
}


impl app.receiveIntelligenceResponse(response: any, action: str) -> None {
    backend_connected = response["success"];
    intelligence_pending_action = "";
    intelligence_error_message = response["message"] if not response["success"] else "";

    if action == "translation" {
        next_translation_status: str = responseUiStatus(
            response, "translated_transcript"
        );
        translation_status = next_translation_status;
        translated_rows = (
            response["translated_transcript"]
                if next_translation_status in ["success", "provider_fallback"]
                else []
        );
    } elif action == "quick_note" {
        next_quick_note_status: str = responseUiStatus(response, "live_quick_summary");
        quick_note_status = next_quick_note_status;
        quick_note_data = (
            response["live_quick_summary"]
                if next_quick_note_status in ["success", "provider_fallback"]
                else {}
        );
    } elif action == "analysis" {
        next_analysis_status: str = responseUiStatus(response, "analysis_run");
        analysis_status = next_analysis_status;
        if next_analysis_status in ["success", "provider_fallback"] {
            analysis_run: dict[str, any] = response["analysis_run"];
            analysis_data = analysis_run;
            intelligence_questions = response["suggested_questions"];
            intelligence_question_states = {};
            analysis_stale = analysis_run["stale"];
            final_review_status = "empty";
            final_review_data = {};
            intelligence_pending_action = "questions";
            callBackendAction(
                "generate_clarifying_questions",
                {
                    "encounter_id": "encounter-maya-001",
                    "analysis_run_id": analysis_run["id"],
                    "session_id": "hospi-pet-frontend-demo"
                }
            ).then(
                receiveGeneratedQuestions
            ).catch(
                failIntelligenceAction
            );
        } else {
            analysis_data = {};
            clinician_note_data = {};
            intelligence_questions = [];
        }
    } elif action == "trace" {
        next_trace_status: str = responseUiStatus(response, "analysis_provenance");
        source_trace_status = next_trace_status;
        source_trace_data = (
            response["analysis_provenance"]
                if next_trace_status in ["success", "provider_fallback"]
                else []
        );
    } elif action == "final_review" {
        next_review_status: str = responseUiStatus(response, "final_review_packet");
        final_review_status = next_review_status;
        final_review_data = (
            response["final_review_packet"]
                if next_review_status in ["success", "provider_fallback"]
                else {}
        );
    }
}


impl app.receiveGeneratedQuestions(response: any) -> None {
    intelligence_pending_action = "";
    if response["success"] {
        intelligence_questions = response["suggested_questions"];
        intelligence_error_message = "";
    } else {
        intelligence_error_message = response["message"];
    }
}


impl app.checkCareGaps -> None {
    if len(intelligence_pending_action) > 0 {
        return;
    }
    intelligence_pending_action = "care_gaps";
    care_gap_status = "loading";
    intelligence_error_message = "";
    callBackendAction(
        "run_care_gap_check", {"session_id": "hospi-pet-frontend-demo"}
    ).then(
        receiveCareGaps
    ).catch(
        failIntelligenceAction
    );
}


impl app.receiveCareGaps(response: any) -> None {
    intelligence_pending_action = "";
    if response["success"] {
        care_gaps = response["care_gaps"];
        care_gap_status = "success";
        intelligence_error_message = "";
    } else {
        care_gap_status = "recoverable_error";
        intelligence_error_message = response["message"];
    }
}


impl app.resolveFirstGap -> None {
    if len(intelligence_pending_action) > 0 or len(care_gaps) == 0 {
        return;
    }
    intelligence_pending_action = "resolve_gap";
    care_gap_status = "loading";
    callBackendAction(
        "resolve_gap",
        {
            "gap_id": care_gaps[0]["id"],
            "resolution": "Assigned follow-through for the verified care task",
            "owner": "clinic-care-team",
            "due_date": "this week",
            "session_id": "hospi-pet-frontend-demo"
        }
    ).then(
        receiveGapResolution
    ).catch(
        failIntelligenceAction
    );
}


impl app.receiveGapResolution(response: any) -> None {
    intelligence_pending_action = "";
    if not response["success"] {
        care_gap_status = "recoverable_error";
        intelligence_error_message = response["message"];
        return;
    }
    analysis_stale = True;
    final_review_status = "empty";
    final_review_data = {};
    intelligence_pending_action = "care_gaps";
    care_gap_status = "loading";
    callBackendAction(
        "run_care_gap_check", {"session_id": "hospi-pet-frontend-demo"}
    ).then(
        receiveCareGaps
    ).catch(
        failIntelligenceAction
    );
}


impl app.generatePatientPlans -> None {
    if len(intelligence_pending_action) > 0 {
        return;
    }
    intelligence_pending_action = "plan_english";
    patient_plan_status = "loading";
    intelligence_error_message = "";
    callBackendAction(
        "generate_patient_plan",
        {
            "language": "English",
            "ai_mode": "disabled",
            "session_id": "hospi-pet-frontend-demo"
        }
    ).then(
        receiveEnglishPatientPlan
    ).catch(
        failIntelligenceAction
    );
}


impl app.receiveEnglishPatientPlan(response: any) -> None {
    if not response["success"] {
        intelligence_pending_action = "";
        patient_plan_status = "recoverable_error";
        intelligence_error_message = response["message"];
        return;
    }
    english_patient_plan = response["patient_plan"];
    intelligence_pending_action = "plan_spanish";
    callBackendAction(
        "generate_patient_plan",
        {
            "language": "Spanish",
            "ai_mode": "disabled",
            "session_id": "hospi-pet-frontend-demo"
        }
    ).then(
        receiveSpanishPatientPlan
    ).catch(
        failIntelligenceAction
    );
}


impl app.receiveSpanishPatientPlan(response: any) -> None {
    intelligence_pending_action = "";
    if response["success"] {
        spanish_patient_plan = response["patient_plan"];
        patient_plan_status = "success";
        intelligence_error_message = "";
    } else {
        patient_plan_status = "recoverable_error";
        intelligence_error_message = response["message"];
    }
}


impl app.generatePatientAudio -> None {
    if len(intelligence_pending_action) > 0 {
        return;
    }
    intelligence_pending_action = "patient_audio";
    patient_audio_status = "loading";
    callBackendAction(
        "generate_patient_audio_script",
        {"language": "Spanish", "session_id": "hospi-pet-frontend-demo"}
    ).then(
        receivePatientAudio
    ).catch(
        failIntelligenceAction
    );
}


impl app.receivePatientAudio(response: any) -> None {
    intelligence_pending_action = "";
    if response["success"] {
        patient_audio_script = response["patient_audio_script"];
        patient_audio_status = "success";
        intelligence_error_message = "";
    } else {
        patient_audio_status = "recoverable_error";
        intelligence_error_message = response["message"];
    }
}


impl app.playPatientAudio -> None {
    if "text" not in patient_audio_script {
        return;
    }
    browser_window: any = window;
    if "speechSynthesis" not in browser_window {
        patient_audio_status = "unsupported";
        return;
    }
    browser_window.speechSynthesis.cancel();
    utterance: any = new(
        browser_window.SpeechSynthesisUtterance, patient_audio_script["text"]
    );
    utterance.lang = "es-US";
    browser_window.speechSynthesis.speak(utterance);
}


impl app.runEvidenceAudit -> None {
    if len(intelligence_pending_action) > 0 {
        return;
    }
    intelligence_pending_action = "audit";
    audit_status = "loading";
    callBackendAction(
        "run_evidence_audit", {"session_id": "hospi-pet-frontend-demo"}
    ).then(
        receiveEvidenceAudit
    ).catch(
        failIntelligenceAction
    );
}


impl app.receiveEvidenceAudit(response: any) -> None {
    intelligence_pending_action = "";
    if response["success"] {
        audit_conflicts = response["conflicts"];
        audit_status = "success";
        intelligence_error_message = "";
    } else {
        audit_status = "recoverable_error";
        intelligence_error_message = response["message"];
    }
}


impl app.addDemoContradiction -> None {
    if len(intelligence_pending_action) > 0 {
        return;
    }
    intelligence_pending_action = "contradiction";
    audit_status = "loading";
    callBackendAction(
        "add_demo_contradiction", {"session_id": "hospi-pet-frontend-demo"}
    ).then(
        receiveDemoContradiction
    ).catch(
        failIntelligenceAction
    );
}


impl app.receiveDemoContradiction(response: any) -> None {
    intelligence_pending_action = "";
    if not response["success"] {
        audit_status = "recoverable_error";
        intelligence_error_message = response["message"];
        return;
    }
    intelligence_pending_action = "audit";
    audit_status = "loading";
    callBackendAction(
        "run_evidence_audit", {"session_id": "hospi-pet-frontend-demo"}
    ).then(
        receiveEvidenceAudit
    ).catch(
        failIntelligenceAction
    );
}


impl app.failIntelligenceAction(error: any) -> None {
    action: str = intelligence_pending_action;
    intelligence_pending_action = "";
    intelligence_error_message = (
        "The Jac backend action is temporarily unavailable. Retry this action."
    );
    if action == "translation" {
        translation_status = "recoverable_error";
    } elif action == "quick_note" {
        quick_note_status = "recoverable_error";
    } elif action == "analysis" {
        analysis_status = "recoverable_error";
    } elif action == "trace" {
        source_trace_status = "recoverable_error";
    } elif action == "final_review" {
        final_review_status = "recoverable_error";
    } elif action in ["care_gaps", "resolve_gap"] {
        care_gap_status = "recoverable_error";
    } elif action in ["plan_english", "plan_spanish"] {
        patient_plan_status = "recoverable_error";
    } elif action == "patient_audio" {
        patient_audio_status = "recoverable_error";
    } elif action in ["audit", "contradiction"] {
        audit_status = "recoverable_error";
    }
}


impl app.cancelIntelligenceTimer -> None {
    if intelligence_timer is not None {
        clearTimeout(intelligence_timer);
        intelligence_timer = None;
    }
    intelligence_pending_action = "";
}


impl app.resetIntelligence -> None {
    cancelIntelligenceTimer();
    cancelClinicianNoteTimer();
    translation_status = "empty";
    translation_chunk_index = 0;
    translated_rows = [];
    quick_note_status = "empty";
    quick_note_data = {};
    analysis_status = "empty";
    analysis_data = {};
    analysis_stale = False;
    clinician_note_data = {};
    intelligence_questions = [];
    intelligence_question_states = {};
    pending_question_id = "";
    pending_question_decision = "";
    detail_question_id = "";
    detail_mode = "";
    active_intelligence_tab = "summary";
    source_trace_status = "empty";
    source_trace_data = [];
    care_gap_status = "empty";
    care_gaps = [];
    patient_plan_status = "empty";
    english_patient_plan = {};
    spanish_patient_plan = {};
    patient_audio_status = "empty";
    patient_audio_script = {};
    audit_status = "empty";
    audit_conflicts = [];
    final_review_status = "empty";
    final_review_data = {};
    intelligence_error_message = "";
    clinician_note_data = {};
    note_status = "empty";
    note_error = "";
    note_edits = {};
    note_pending_action = "";
    note_pending_section = "";
}


impl app.setIntelligenceTab(tab_id: str) -> None {
    active_intelligence_tab = tab_id;
}


impl app.dismissIntelligenceQuestion(question_id: str) -> None {
    if len(intelligence_pending_action) > 0 {
        return;
    }
    intelligence_pending_action = "question";
    pending_question_id = question_id;
    pending_question_decision = "dismissed";
    intelligence_error_message = "";
    callBackendAction(
        "dismiss_suggested_question",
        {
            "question_id": question_id,
            "clinician_id": "demo-clinician",
            "session_id": "hospi-pet-frontend-demo"
        }
    ).then(
        lambda (response: any) { receiveQuestionResponse(response, question_id); }
    ).catch(
        failIntelligenceAction
    );
}


impl app.answerIntelligenceQuestion(question_id: str) -> None {
    if (
        len(intelligence_pending_action) > 0
        or acceptedCandidateCount(fact_decisions) == 0
    ) {
        return;
    }
    intelligence_pending_action = "question";
    pending_question_id = question_id;
    pending_question_decision = "answered";
    intelligence_error_message = "";
    if (
        "accepted_fact_ids" in analysis_data
        and len(analysis_data["accepted_fact_ids"]) > 0
    ) {
        callBackendAction(
            "mark_question_answered",
            {
                "question_id": question_id,
                "answer_source_fact_id": analysis_data["accepted_fact_ids"][0],
                "clinician_id": "demo-clinician",
                "session_id": "hospi-pet-frontend-demo"
            }
        ).then(
            lambda (response: any) { receiveQuestionResponse(response, question_id); }
        ).catch(
            failIntelligenceAction
        );
    } else {
        intelligence_pending_action = "";
        intelligence_error_message = "No accepted source fact is available for this answer.";
    }
}


impl app.finishIntelligenceQuestionAction -> None {
    intelligence_timer = None;
    intelligence_error_message = "The Jac backend did not return a question update.";
    intelligence_pending_action = "";
    pending_question_id = "";
    pending_question_decision = "";
}


impl app.receiveQuestionResponse(response: any, question_id: str) -> None {
    intelligence_timer = None;
    if not response["success"] {
        intelligence_error_message = response["message"];
    } else {
        updated_states: dict[str, str] = intelligence_question_states.copy();
        if len(response["suggested_questions"]) > 0 {
            updated_states[question_id] = response["suggested_questions"][0]["status"];
        }
        intelligence_question_states = updated_states;
        intelligence_error_message = "";
    }
    intelligence_pending_action = "";
    pending_question_id = "";
    pending_question_decision = "";
}


impl app.toggleIntelligenceQuestionDetail(question_id: str, mode: str) -> None {
    if detail_question_id == question_id and detail_mode == mode {
        detail_question_id = "";
        detail_mode = "";
    } else {
        detail_question_id = question_id;
        detail_mode = mode;
    }
}


impl app.changeVoiceScenario(e: any) -> None {
    voice_scenario = e.target.value;
}


impl app.changeVoiceSpeaker(e: any) -> None {
    voice_speaker = e.target.value;
}


impl app.startRecording -> None {
    if voice_requesting or voice_recording or voice_stopping {
        return;
    }

    cancelVoiceTimers();
    stopVoiceCapture();
    voice_requesting = True;
    voice_status = "permission_required";
    voice_permission = "requesting";
    voice_prepared_demo = False;
    voice_interim_text = "";
    voice_chunk_queue = [];
    voice_chunk_pending = False;
    voice_next_sequence = 1;
    voice_finalize_requested = False;
    recording_seconds = 0;
    assistant_state = "analyzing";
    assistant_status = "Preparing the microphone";
    assistant_message = "Waiting for browser permission.";
    mascot_message_visible = False;

    if voice_scenario == "permission_denied" {
        voice_sequence_timer = setTimeout(simulateVoiceDenied, 280.0);
        return;
    } elif voice_scenario == "unsupported" {
        voice_sequence_timer = setTimeout(simulateVoiceUnsupported, 280.0);
        return;
    } elif voice_scenario == "recoverable_error" {
        voice_sequence_timer = setTimeout(simulateVoiceError, 280.0);
        return;
    }

    if not demo_loaded {
        callBackendAction("reset_demo", {"session_id": "hospi-pet-frontend-demo"}).then(
            receiveVoiceBootstrap
        ).catch(
            failCaptureStart
        );
        return;
    }
    startLiveCapture();
}


impl app.receiveVoiceBootstrap(response: any) -> None {
    if not response["success"] {
        failCaptureStart(response);
        return;
    }
    state: any = response["demo_state"];
    patient_data = {
        "name": state["patient"]["display_name"],
        "encounter_type": "Synthetic live encounter",
        "consultation_status": state["encounter"]["status"],
        "encounter_date": state["encounter"]["occurred_at"],
        "visit_id": state["encounter"]["id"],
        "review_status": "Live capture in progress"
    };
    transcript_data = [];
    candidate_facts = [];
    demo_loaded = True;
    backend_connected = True;
    startLiveCapture();
}


impl app.startLiveCapture -> None {
    callBackendAction(
        "start_capture_session",
        {
            "encounter_id": "encounter-maya-001",
            "input_source": "live_voice",
            "session_id": "hospi-pet-frontend-demo"
        }
    ).then(
        receiveCaptureStart
    ).catch(
        failCaptureStart
    );
}


impl app.receiveCaptureStart(response: any) -> None {
    if not response["success"] {
        voice_requesting = False;
        voice_permission = "recoverable_error";
        voice_status = "failed";
        assistant_state = "idle";
        assistant_status = "Recording could not start";
        assistant_message = response["message"];
        return;
    }
    backend_connected = True;
    new_capture_id: str = response["capture_session"]["id"];
    capture_session_id = new_capture_id;
    sessionStorage.setItem("hospi-pet-active-capture", new_capture_id);
    voice_runtime["capture_id"] = new_capture_id;
    voice_runtime["queue"] = [];
    voice_runtime["pending"] = False;
    voice_runtime["sequence"] = 1;
    voice_runtime["finalize"] = False;
    voice_runtime["rows"] = [];
    voice_runtime["seconds"] = 0;
    requestBrowserMicrophone(new_capture_id);
}


impl app.failCaptureStart(error: any) -> None {
    voice_requesting = False;
    voice_permission = "recoverable_error";
    voice_status = "failed";
    assistant_state = "idle";
    assistant_status = "Backend unavailable";
    assistant_message = "Retry recording or load the prepared voice fallback.";
}


impl app.requestBrowserMicrophone(capture_id: str) -> None {
    nav: any = navigator;
    if not nav.mediaDevices or not nav.mediaDevices.getUserMedia {
        simulateVoiceUnsupported();
        return;
    }

    sessionStorage.setItem("hospi-pet-microphone-request", capture_id);
    voice_sequence_timer = setTimeout(
        lambda() { voicePermissionTimedOut(capture_id); }, 12000.0
    );
    nav.mediaDevices.getUserMedia({"audio": True}).then(
        lambda (stream: any) { voicePermissionGranted(stream, capture_id); }
    ).catch(
        lambda (error: any) { voicePermissionFailed(error, capture_id); }
    );
}


impl app.voicePermissionGranted(stream: any, capture_id: str) -> None {
    if sessionStorage.getItem("hospi-pet-microphone-request") != capture_id {
        for track in stream.getTracks() {
            track.stop();
        }
        return;
    }
    sessionStorage.removeItem("hospi-pet-microphone-request");
    voice_sequence_timer = None;
    voice_runtime["stream"] = stream;
    voice_stream = stream;
    voice_requesting = False;
    voice_permission = "granted";
    voice_status = "recording";
    voice_recording = True;
    recording_seconds = 0;
    voice_timer = setInterval(incrementRecordingTimer, 1000.0);
    assistant_state = "listening";
    assistant_status = "Listening to the encounter";
    assistant_message = "Microphone active locally. Final transcript text follows the documented Jac action.";
    startBrowserTranscription();
}


impl app.voicePermissionFailed(error: any, capture_id: str) -> None {
    if sessionStorage.getItem("hospi-pet-microphone-request") != capture_id {
        return;
    }
    sessionStorage.removeItem("hospi-pet-microphone-request");
    voice_sequence_timer = None;
    voice_requesting = False;
    voice_recording = False;
    stopVoiceCapture();
    callBackendAction(
        "cancel_capture_session",
        {"capture_session_id": capture_id, "session_id": "hospi-pet-frontend-demo"}
    );
    voice_runtime["capture_id"] = "";
    capture_session_id = "";
    if error and error.name == "NotAllowedError" {
        voice_permission = "denied";
        voice_status = "failed";
        assistant_status = "Microphone permission denied";
        assistant_message = "Enable access or use the prepared voice demo.";
    } else {
        voice_permission = "recoverable_error";
        voice_status = "failed";
        assistant_status = "Microphone unavailable";
        assistant_message = "The microphone request can be tried again.";
    }
    assistant_state = "idle";
}


impl app.voicePermissionTimedOut(capture_id: str) -> None {
    if sessionStorage.getItem("hospi-pet-microphone-request") != capture_id {
        return;
    }
    sessionStorage.removeItem("hospi-pet-microphone-request");
    voice_sequence_timer = None;
    voice_requesting = False;
    voice_recording = False;
    voice_permission = "recoverable_error";
    voice_status = "failed";
    assistant_state = "idle";
    assistant_status = "Microphone request timed out";
    assistant_message = "Try again or use the prepared voice demo.";
    callBackendAction(
        "cancel_capture_session",
        {"capture_session_id": capture_id, "session_id": "hospi-pet-frontend-demo"}
    );
    voice_runtime["capture_id"] = "";
    capture_session_id = "";
}


impl app.startBrowserTranscription -> None {
    browser_window: any = window;
    speech_constructor: any = (
        browser_window.SpeechRecognition
            if browser_window.SpeechRecognition
            else browser_window.webkitSpeechRecognition
    );
    if not speech_constructor {
        voice_status = "recording";
        assistant_message = (
            "Microphone active, but browser live transcription is unavailable. " + "Use the prepared voice demo for transcript content."
        );
        return;
    }

    try {
        recognition: any = browser_window.Reflect.construct(speech_constructor, []);
        recognition.continuous = True;
        recognition.interimResults = True;
        recognition.lang = "en-US";
        recognition.onresult = handleSpeechResult;
        recognition.onerror = handleSpeechError;
        voice_runtime["recognition"] = recognition;
        voice_recognition = recognition;
        recognition.start();
    } except Exception as error {
        voice_permission = "recoverable_error";
        voice_status = "fallback";
        assistant_status = "Live transcription unavailable";
        assistant_message = "Use the prepared voice demo in this browser.";
    }
}


impl app.handleSpeechResult(event: any) -> None {
    interim: str = "";
    for index in range(event.resultIndex, len(event.results)) {
        result: any = event.results[index];
        text: str = str(result[0].transcript).strip();
        if result.isFinal {
            if len(text) > 0 {
                queueFinalTranscript(text);
            }
        } else {
            interim += (" " if len(interim) > 0 else "") + text;
        }
    }
    voice_interim_text = interim;
}


impl app.handleSpeechError(event: any) -> None {
    voice_interim_text = "";
    if event.error != "no-speech" and event.error != "aborted" {
        assistant_message = (
            "Live browser transcription paused. The recording can be retried " + "or replaced with the prepared fallback."
        );
    }
}


impl app.queueFinalTranscript(text: str) -> None {
    queued: list[dict[str, str]] = list(voice_runtime["queue"]);
    queued.append({"speaker": voice_speaker, "text": text});
    voice_runtime["queue"] = queued;
    voice_chunk_queue = queued;
    flushVoiceRuntimeQueue();
}


impl app.flushVoiceRuntimeQueue -> None {
    queued: list[dict[str, str]] = list(voice_runtime["queue"]);
    capture_id: str = str(voice_runtime["capture_id"]);
    if voice_runtime["pending"] or len(queued) == 0 or len(capture_id) == 0 {
        if (
            voice_runtime["finalize"]
            and not voice_runtime["pending"]
            and len(queued) == 0
            and len(capture_id) > 0
        ) {
            beginFinalizeCaptureById(capture_id);
        }
        return;
    }
    current_chunk: dict[str, str] = queued[0];
    voice_runtime["pending"] = True;
    voice_chunk_pending = True;
    callBackendAction(
        "append_transcript_chunk",
        {
            "capture_session_id": capture_id,
            "sequence": int(voice_runtime["sequence"]),
            "speaker": current_chunk["speaker"],
            "text": current_chunk["text"],
            "confidence": 1.0,
            "session_id": "hospi-pet-frontend-demo"
        }
    ).then(
        receiveRuntimeTranscriptChunk
    ).catch(
        failRuntimeTranscriptChunk
    );
}


impl app.receiveRuntimeTranscriptChunk(response: any) -> None {
    voice_runtime["pending"] = False;
    voice_chunk_pending = False;
    if not response["success"] {
        failRuntimeTranscriptChunk(response);
        return;
    }
    rows: list[dict[str, any]] = list(voice_runtime["rows"]);
    rows.append(response["transcript_chunk"]);
    voice_runtime["rows"] = rows;
    transcript_data = rows;
    demo_loaded = True;
    voice_runtime["sequence"] = int(voice_runtime["sequence"]) + 1;
    queued: list[dict[str, str]] = list(voice_runtime["queue"]);
    if len(queued) > 0 {
        queued = queued[1:];
    }
    voice_runtime["queue"] = queued;
    voice_chunk_queue = queued;
    voice_next_sequence = int(voice_runtime["sequence"]);
    flushVoiceRuntimeQueue();
}


impl app.failRuntimeTranscriptChunk(error: any) -> None {
    voice_runtime["pending"] = False;
    voice_runtime["finalize"] = False;
    voice_chunk_pending = False;
    voice_finalize_requested = False;
    voice_stopping = False;
    voice_status = "failed";
    assistant_state = "idle";
    assistant_status = "Transcript chunk needs retry";
    assistant_message = (
        error["message"]
            if isinstance(error, dict) and "message" in error
            else "The finalized speech could not be added. Cancel and retry or use the prepared fallback."
    );
}


impl app.sendNextTranscriptChunk -> None {
    if (
        voice_chunk_pending
        or len(voice_chunk_queue) == 0
        or len(capture_session_id) == 0
    ) {
        return;
    }
    voice_chunk_pending = True;
    current_chunk: dict[str, str] = voice_chunk_queue[0];
    callBackendAction(
        "append_transcript_chunk",
        {
            "capture_session_id": capture_session_id,
            "sequence": voice_next_sequence,
            "speaker": current_chunk["speaker"],
            "text": current_chunk["text"],
            "confidence": 1.0,
            "session_id": "hospi-pet-frontend-demo"
        }
    ).then(
        receiveTranscriptChunk
    ).catch(
        failTranscriptChunk
    );
}


impl app.receiveTranscriptChunk(response: any) -> None {
    voice_chunk_pending = False;
    if not response["success"] {
        failTranscriptChunk(response);
        return;
    }
    rows: list[dict[str, any]] = list(transcript_data);
    rows.append(response["transcript_chunk"]);
    transcript_data = rows;
    demo_loaded = True;
    voice_next_sequence += 1;
    voice_chunk_queue = voice_chunk_queue[1:];
    if len(voice_chunk_queue) > 0 {
        sendNextTranscriptChunk();
    } elif voice_finalize_requested {
        beginFinalizeCapture();
    }
}


impl app.failTranscriptChunk(error: any) -> None {
    voice_chunk_pending = False;
    voice_finalize_requested = False;
    voice_stopping = False;
    voice_status = "failed";
    assistant_state = "idle";
    assistant_status = "Transcript chunk needs retry";
    assistant_message = (
        error["message"]
            if isinstance(error, dict) and "message" in error
            else "The finalized speech could not be added. Cancel and retry or use the prepared fallback."
    );
}


impl app.simulateVoiceDenied -> None {
    voice_sequence_timer = None;
    voice_requesting = False;
    voice_permission = "denied";
    voice_status = "failed";
    assistant_state = "idle";
    assistant_status = "Microphone permission denied";
    assistant_message = "Enable access or use the prepared voice demo.";
}


impl app.simulateVoiceUnsupported -> None {
    voice_sequence_timer = None;
    voice_requesting = False;
    voice_permission = "unsupported";
    voice_status = "fallback";
    assistant_state = "idle";
    assistant_status = "Microphone unavailable";
    assistant_message = "Use the prepared voice demo in this browser.";
}


impl app.simulateVoiceError -> None {
    voice_sequence_timer = None;
    voice_requesting = False;
    voice_permission = "recoverable_error";
    voice_status = "failed";
    assistant_state = "idle";
    assistant_status = "Microphone request interrupted";
    assistant_message = "Try again or use the prepared voice demo.";
}


impl app.incrementRecordingTimer -> None {
    voice_runtime["seconds"] = int(voice_runtime["seconds"]) + 1;
    recording_seconds = int(voice_runtime["seconds"]);
}


impl app.stopRecording -> None {
    if not voice_recording or voice_stopping {
        return;
    }
    voice_stopping = True;
    voice_status = "transcribing";
    assistant_state = "analyzing";
    assistant_status = "Finishing the recording";
    assistant_message = "Stopping local microphone capture.";
    if voice_timer is not None {
        clearInterval(voice_timer);
        voice_timer = None;
    }
    voice_runtime["finalize"] = True;
    voice_finalize_requested = True;
    active_capture_id: str = str(
        sessionStorage.getItem("hospi-pet-active-capture") or capture_session_id
    );
    recognition: any = voice_runtime["recognition"];
    stream: any = voice_runtime["stream"];
    if stream is not None {
        for track in stream.getTracks() {
            track.stop();
        }
        voice_runtime["stream"] = None;
        voice_stream = None;
    }
    if recognition is not None {
        recognition.onend = lambda() { forceFinishVoiceRecognition(
            active_capture_id
        ); };
        voice_sequence_timer = setTimeout(
            lambda() { forceFinishVoiceRecognition(active_capture_id); }, 1500.0
        );
        try {
            recognition.stop();
        } except Exception {
            forceFinishVoiceRecognition(active_capture_id);
        }
    } else {
        forceFinishVoiceRecognition(active_capture_id);
    }
}


impl app.finishVoiceRecognition -> None {
    if voice_sequence_timer is not None {
        clearTimeout(voice_sequence_timer);
        voice_sequence_timer = None;
    }
    recognition: any = voice_runtime["recognition"];
    if recognition is not None {
        recognition.onresult = None;
        recognition.onerror = None;
        recognition.onend = None;
    }
    voice_runtime["recognition"] = None;
    voice_recognition = None;
    voice_interim_text = "";
    flushVoiceRuntimeQueue();
}


impl app.forceFinishVoiceRecognition(capture_id: str) -> None {
    if len(capture_id) == 0 {
        return;
    }
    recognition: any = voice_runtime["recognition"];
    if recognition is not None {
        recognition.onresult = None;
        recognition.onerror = None;
        recognition.onend = None;
    }
    voice_runtime["recognition"] = None;
    voice_recognition = None;
    voice_interim_text = "";
    voice_recording = False;
    beginFinalizeCaptureById(capture_id);
}


impl app.beginFinalizeCaptureById(capture_id: str) -> None {
    sessionStorage.removeItem("hospi-pet-active-capture");
    voice_runtime["finalize"] = False;
    voice_finalize_requested = False;
    callBackendAction(
        "finalize_capture_session",
        {"capture_session_id": capture_id, "session_id": "hospi-pet-frontend-demo"}
    ).then(
        receiveCaptureFinalized
    ).catch(
        failPreparedVoiceDemo
    );
}


impl app.beginFinalizeCapture -> None {
    voice_finalize_requested = False;
    if len(capture_session_id) > 0 {
        beginFinalizeCaptureById(capture_session_id);
    } else {
        voice_sequence_timer = setTimeout(finishStopRecording, 240.0);
    }
}


impl app.finishStopRecording -> None {
    voice_sequence_timer = None;
    voice_recording = False;
    voice_stopping = False;
    sessionStorage.removeItem("hospi-pet-active-capture");
    voice_status = "completed";
    assistant_state = "complete";
    assistant_status = "Recording complete — ready for review";
    assistant_message = "No transcription service is connected. Use the prepared demo for a contract-shaped transcript.";
}


impl app.receiveCaptureFinalized(response: any) -> None {
    if not response["success"] {
        failPreparedVoiceDemo(response);
        return;
    }
    voice_recording = False;
    voice_stopping = False;
    voice_runtime["capture_id"] = "";
    voice_runtime["pending"] = False;
    voice_runtime["finalize"] = False;
    voice_runtime["queue"] = [];
    voice_status = response["capture_session"]["status"];
    voice_interim_text = "";
    candidate_facts = response["candidate_facts"];
    assistant_state = "complete";
    assistant_status = "Recording complete — ready for review";
    assistant_message = response["message"];
}


impl app.loadPreparedVoiceDemo -> None {
    if voice_recording or voice_stopping {
        return;
    }
    pending_capture_id: str = str(voice_runtime["capture_id"]);
    if voice_requesting and len(pending_capture_id) > 0 {
        callBackendAction(
            "cancel_capture_session",
            {
                "capture_session_id": pending_capture_id,
                "session_id": "hospi-pet-frontend-demo"
            }
        );
        capture_session_id = "";
    }
    resetIntelligence();
    cancelVoiceTimers();
    stopVoiceCapture();
    voice_requesting = True;
    voice_prepared_demo = True;
    voice_interim_text = "";
    voice_chunk_queue = [];
    voice_chunk_pending = False;
    voice_next_sequence = 1;
    voice_finalize_requested = False;
    voice_permission = "not_requested";
    voice_status = "recording";
    assistant_state = "listening";
    assistant_status = "Listening to the prepared encounter";
    assistant_message = "Prepared demo audio is being represented by contract-shaped transcript data.";
    callBackendAction("reset_demo", {"session_id": "hospi-pet-frontend-demo"}).then(
        receivePreparedDemoReset
    ).catch(
        failPreparedVoiceDemo
    );
}


impl app.receivePreparedDemoReset(response: any) -> None {
    if not response["success"] {
        failPreparedVoiceDemo(response);
        return;
    }
    callBackendAction(
        "load_demo_encounter", {"session_id": "hospi-pet-frontend-demo"}
    ).then(
        receivePreparedEncounter
    ).catch(
        failPreparedVoiceDemo
    );
}


impl app.receivePreparedEncounter(response: any) -> None {
    if not response["success"] {
        failPreparedVoiceDemo(response);
        return;
    }
    demo_state: any = response["demo_state"];
    transcript_data = demo_state["transcript"];
    candidate_facts = response["candidate_facts"];
    fact_decisions = blankFactDecisions();
    callBackendAction(
        "load_prepared_voice_demo",
        {"encounter_id": "encounter-maya-001", "session_id": "hospi-pet-frontend-demo"}
    ).then(
        receivePreparedVoiceDemo
    ).catch(
        failPreparedVoiceDemo
    );
}


impl app.finishPreparedVoiceDemo -> None {
    failPreparedVoiceDemo(None);
}


impl app.receivePreparedVoiceDemo(response: any) -> None {
    voice_sequence_timer = None;
    voice_requesting = False;
    if not response["success"] {
        voice_status = "failed";
        assistant_state = "idle";
        assistant_status = "Prepared demo unavailable";
        assistant_message = response["message"];
        return;
    }

    capture_session: dict[str, any] = response["capture_session"];
    capture_session_id = capture_session["id"];
    patient_data = {
        "name": "Maya Rivera",
        "encounter_type": "Prepared synthetic encounter",
        "consultation_status": capture_session["status"].replace("_", " "),
        "encounter_date": "July 26, 2026",
        "visit_id": capture_session["encounter_id"],
        "review_status": "Ready for review"
    };
    if len(response["transcript_chunks"]) > 0 {
        transcript_data = response["transcript_chunks"];
    }
    demo_loaded = True;
    if len(response["candidate_facts"]) > 0 {
        candidate_facts = response["candidate_facts"];
    }
    fact_decisions = blankFactDecisions();
    voice_status = "completed";
    assistant_state = "complete";
    assistant_status = "Recording complete — ready for review";
    assistant_message = "Prepared voice-demo facts are ready for clinician verification.";
}


impl app.failPreparedVoiceDemo(error: any) -> None {
    voice_requesting = False;
    voice_recording = False;
    voice_stopping = False;
    voice_status = "failed";
    assistant_state = "idle";
    assistant_status = "Prepared demo unavailable";
    assistant_message = (
        error["message"]
            if isinstance(error, dict) and "message" in error
            else "The backend action failed: " + str(error)
    );
}


impl app.cancelAndRetryVoice -> None {
    active_capture_id: str = str(voice_runtime["capture_id"]);
    if len(active_capture_id) > 0 and voice_status != "completed" {
        callBackendAction(
            "cancel_capture_session",
            {
                "capture_session_id": active_capture_id,
                "session_id": "hospi-pet-frontend-demo"
            }
        );
    }
    cancelVoiceTimers();
    stopVoiceCapture();
    voice_requesting = False;
    voice_recording = False;
    voice_stopping = False;
    voice_permission = "not_requested";
    voice_status = "idle";
    voice_interim_text = "";
    voice_chunk_queue = [];
    voice_chunk_pending = False;
    voice_next_sequence = 1;
    voice_finalize_requested = False;
    recording_seconds = 0;
    capture_session_id = "";

    if voice_prepared_demo {
        voice_prepared_demo = False;
        if (
            demo_loaded
            and len(transcript_data) > 0
            and transcript_data[0]["id"] == "chunk-1"
        ) {
            demo_loaded = False;
            patient_data = {};
            transcript_data = [];
            candidate_facts = [];
            fact_decisions = blankFactDecisions();
            resetIntelligence();
        }
    }

    assistant_state = "idle";
    assistant_status = "Voice attempt cancelled — ready to retry";
    assistant_message = "Select Start Recording or use the prepared fallback.";
}


impl app.discardRecording -> None {
    if (
        (voice_recording or voice_prepared_demo)
        and not window.confirm("Discard the current voice encounter?")
    ) {
        return;
    }
    active_capture_id: str = str(voice_runtime["capture_id"]);
    if len(active_capture_id) > 0 and voice_status != "completed" {
        callBackendAction(
            "cancel_capture_session",
            {
                "capture_session_id": active_capture_id,
                "session_id": "hospi-pet-frontend-demo"
            }
        );
    }
    cancelVoiceTimers();
    resetIntelligence();
    stopVoiceCapture();
    voice_requesting = False;
    voice_recording = False;
    voice_stopping = False;
    voice_prepared_demo = False;
    voice_permission = "not_requested";
    voice_status = "idle";
    voice_interim_text = "";
    voice_chunk_queue = [];
    voice_chunk_pending = False;
    voice_next_sequence = 1;
    voice_finalize_requested = False;
    recording_seconds = 0;
    capture_session_id = "";
    if demo_loaded
    and len(transcript_data) > 0
    and transcript_data[0]["id"] == "chunk-1" {
        demo_loaded = False;
        patient_data = {};
        transcript_data = [];
        candidate_facts = [];
        fact_decisions = blankFactDecisions();
    }
    assistant_state = "idle";
    assistant_status = "Ready for an encounter";
    assistant_message = "Start recording or load the prepared voice demo.";
}


impl app.stopVoiceCapture -> None {
    sessionStorage.removeItem("hospi-pet-microphone-request");
    sessionStorage.removeItem("hospi-pet-active-capture");
    recognition: any = voice_runtime["recognition"];
    if recognition is not None {
        recognition.onresult = None;
        recognition.onerror = None;
        recognition.onend = None;
        recognition.stop();
    }
    stream: any = voice_runtime["stream"];
    if stream is not None {
        for track in stream.getTracks() {
            track.stop();
        }
        voice_runtime["recognition"] = None;
        voice_runtime["stream"] = None;
        voice_runtime["capture_id"] = "";
        voice_runtime["queue"] = [];
        voice_runtime["pending"] = False;
        voice_runtime["sequence"] = 1;
        voice_runtime["finalize"] = False;
        voice_runtime["rows"] = [];
        voice_runtime["seconds"] = 0;
        voice_recognition = None;
        voice_stream = None;
    }
}


impl app.cancelVoiceTimers -> None {
    if voice_timer is not None {
        clearInterval(voice_timer);
        voice_timer = None;
    }
    if voice_sequence_timer is not None {
        clearTimeout(voice_sequence_timer);
        voice_sequence_timer = None;
    }
}


impl app.changeDocumentScenario(e: any) -> None {
    document_scenario = e.target.value;
    clearDocumentResults();
}


impl app.openCamera -> None {
    if document_requesting or document_processing or camera_active {
        return;
    }
    document_requesting = True;
    document_permission = "requesting";
    document_message = "Requesting browser camera permission.";
    assistant_state = "analyzing";
    assistant_status = "Preparing document capture";
    assistant_message = "Waiting for browser permission.";

    nav: any = navigator;
    browser_window: any = window;
    browser_crypto: any = browser_window.crypto;
    request_token: str = str(browser_crypto.randomUUID());
    sessionStorage.setItem("hospi-pet-camera-request", request_token);
    if not nav.mediaDevices or not nav.mediaDevices.getUserMedia {
        sessionStorage.removeItem("hospi-pet-camera-request");
        document_requesting = False;
        document_permission = "unsupported";
        document_message = "Camera capture is unsupported. Upload a synthetic image instead.";
        assistant_state = "idle";
        assistant_status = "Camera unavailable";
        assistant_message = "Upload a synthetic document instead.";
        return;
    }

    nav.mediaDevices.getUserMedia(
        {"video": {"facingMode": "environment"}, "audio": False}
    ).then(
        lambda (stream: any) { cameraPermissionGranted(stream, request_token); }
    ).catch(
        lambda (error: any) { cameraPermissionFailed(error, request_token); }
    );
    document_timer = setTimeout(
        lambda() { cameraPermissionTimedOut(request_token); }, 5000.0
    );
}


impl app.cameraPermissionGranted(stream: any, request_token: str) -> None {
    if sessionStorage.getItem("hospi-pet-camera-request") != request_token {
        for track in stream.getTracks() {
            track.stop();
        }
        return;
    }
    sessionStorage.removeItem("hospi-pet-camera-request");
    cancelDocumentTimer();
    camera_stream = stream;
    camera_active = True;
    document_requesting = False;
    document_permission = "granted";
    document_source_type = "Camera";
    document_message = "Camera ready. Take a photo when the synthetic document is framed.";
    assistant_state = "idle";
    assistant_status = "Document camera ready";
    assistant_message = "Take a photo when the synthetic document is in view.";
    setTimeout(lambda() { attachCameraStream(stream); }, 50.0);
}


impl app.cameraPermissionFailed(error: any, request_token: str) -> None {
    if sessionStorage.getItem("hospi-pet-camera-request") != request_token {
        return;
    }
    sessionStorage.removeItem("hospi-pet-camera-request");
    cancelDocumentTimer();
    document_requesting = False;
    stopCameraCapture();
    if error and error.name == "NotAllowedError" {
        document_permission = "denied";
        document_message = "Camera permission denied. Upload a synthetic image or try again.";
    } else {
        document_permission = "recoverable_error";
        document_message = "The camera request failed. Try again or upload an image.";
    }
    assistant_state = "idle";
    assistant_status = "Camera unavailable";
    assistant_message = "Use a synthetic upload or try camera access again.";
}


impl app.cameraPermissionTimedOut(request_token: str) -> None {
    if sessionStorage.getItem("hospi-pet-camera-request") != request_token {
        return;
    }
    sessionStorage.removeItem("hospi-pet-camera-request");
    document_timer = None;
    document_requesting = False;
    document_permission = "recoverable_error";
    document_message = "The camera permission request timed out. Upload a synthetic image or try again.";
    assistant_state = "idle";
    assistant_status = "Camera unavailable";
    assistant_message = "Use a synthetic upload or try camera access again.";
}


impl app.attachCameraStream(stream: any) -> None {
    video: any = document.getElementById("document-camera-video");
    if video is not None {
        video.srcObject = stream;
    }
}


impl app.handleDocumentUpload(e: any) -> None {
    if document_processing {
        return;
    }
    if document_requesting {
        document_requesting = False;
        sessionStorage.removeItem("hospi-pet-camera-request");
    }
    files: any = e.target.files;
    if files is None or len(files) == 0 {
        document_stage = "validation_error";
        document_message = "Select an image file before continuing.";
        return;
    }
    file: any = files[0];
    if not (
        file.type == "image/jpeg"
        or file.type == "image/png"
        or file.type == "image/webp"
    ) {
        document_stage = "validation_error";
        document_message = "Unsupported file type. Use JPEG, PNG, or WebP.";
        return;
    }
    if file.size <= 0 or file.size > 1048576 {
        document_stage = "validation_error";
        document_message = "The image must be larger than zero bytes and no more than 1 MiB.";
        return;
    }

    stopCameraCapture();
    clearDocumentResults();
    browser_window: any = window;
    browser_url: any = browser_window.URL;
    if len(document_preview_url) > 0 and document_preview_url.startswith("blob:") {
        browser_url.revokeObjectURL(document_preview_url);
    }
    document_preview_url = str(browser_url.createObjectURL(file));
    document_file = file;
    document_source_type = "Upload";
    document_file_name = file.name;
    document_label = "Synthetic clinical document";
    document_stage = "preview_ready";
    document_message = "Image preview ready. Select Analyze Document when ready.";
    document_permission = "not_requested";
}


impl app.takePhoto -> None {
    if not camera_active or camera_stream is None {
        return;
    }
    video: any = document.getElementById("document-camera-video");
    if video is None or video.videoWidth <= 0 {
        document_permission = "recoverable_error";
        document_message = "The camera frame is not ready. Try again.";
        return;
    }
    canvas: any = document.createElement("canvas");
    max_edge: float = 1280.0;
    scale: float = min(1.0, max_edge / max(video.videoWidth, video.videoHeight));
    canvas.width = int(video.videoWidth * scale);
    canvas.height = int(video.videoHeight * scale);
    context: any = canvas.getContext("2d");
    context.drawImage(video, 0, 0, canvas.width, canvas.height);
    document_preview_url = canvas.toDataURL("image/jpeg", 0.75);
    document_file = None;
    document_source_type = "Camera";
    document_file_name = "captured-synthetic-document.jpg";
    document_label = "Captured synthetic document";
    document_stage = "preview_ready";
    document_message = "Captured frame ready for synthetic document analysis.";
    stopCameraCapture();
}


impl app.retakeDocument -> None {
    stopCameraCapture();
    cancelDocumentTimer();
    if len(document_preview_url) > 0 and document_preview_url.startswith("blob:") {
        browser_window: any = window;
        browser_url: any = browser_window.URL;
        browser_url.revokeObjectURL(document_preview_url);
    }
    document_preview_url = "";
    document_file = None;
    document_file_name = "";
    document_source_type = "";
    clearDocumentResults();
    document_stage = "idle";
    document_message = "Capture or upload another synthetic document.";
}


impl app.analyzeDocument -> None {
    if len(document_preview_url) == 0 or document_processing {
        document_stage = "validation_error";
        document_message = "Select or capture a synthetic document before analysis.";
        return;
    }
    cancelDocumentTimer();
    document_processing = True;
    document_stage_index = 0;
    document_stage = "preparing_image";
    document_message = "Preparing the synthetic image.";
    document_candidates = [];
    document_text = "";
    document_source_id = "";
    assistant_state = "analyzing";
    assistant_status = "Reviewing the document";
    assistant_message = "Reading the synthetic document through the Jac document action.";
    if document_scenario == "unsupported_document" {
        document_processing = False;
        document_stage = "validation_error";
        document_message = "DOCUMENT_TYPE_INVALID — use a lab order, referral, appointment card, or after-visit summary.";
        assistant_state = "idle";
        assistant_status = "I couldn’t read that document. Let’s try again.";
        assistant_message = "This frontend validation state is recoverable.";
    } elif document_scenario == "unreadable_document" {
        document_processing = False;
        document_stage = "validation_error";
        document_message = "IMAGE_CORRUPT — the synthetic image is unreadable. Retake it with clearer framing and contrast.";
        assistant_state = "idle";
        assistant_status = "I couldn’t read that document. Let’s try again.";
        assistant_message = "Retake or upload a clearer synthetic image.";
    } elif document_scenario in [
        "lab_success",
        "referral_success",
        "conflict_success"
    ] {
        document_stage = "reading_document";
        document_message = "Reading the synthetic document.";
        if document_file is not None {
            sendDocumentForm(document_file);
        } else {
            fetch(document_preview_url).then(
                lambda (response: any) { return response.blob(); }
            ).then(
                receiveCapturedDocumentBlob
            ).catch(
                failDocumentAnalysis
            );
        }
    } else {
        document_processing = False;
        document_stage = "validation_error";
        document_message = "Select a supported synthetic document scenario.";
    }
}


impl app.advanceDocumentStage -> None {
    document_timer = None;
    document_stage_index += 1;
    if document_stage_index == 1 {
        document_stage = "reading_document";
        document_message = "Reading the synthetic document.";
        document_timer = setTimeout(advanceDocumentStage, 360.0);
    } elif document_stage_index == 2 {
        document_stage = "creating_candidates";
        document_message = "Creating unverified candidates.";
        document_timer = setTimeout(finishDocumentAnalysis, 360.0);
    }
}


impl app.finishDocumentAnalysis -> None {
    document_timer = None;

    if document_scenario == "unsupported_document" {
        document_processing = False;
        document_stage = "validation_error";
        document_message = "DOCUMENT_TYPE_INVALID — use a lab order, referral, appointment card, or after-visit summary.";
        assistant_state = "idle";
        assistant_status = "I couldn’t read that document. Let’s try again.";
        assistant_message = "This frontend validation state is recoverable.";
        return;
    } elif document_scenario == "unreadable_document" {
        document_stage = "validation_error";
        document_message = "IMAGE_CORRUPT — the synthetic image is unreadable. Retake it with clearer framing and contrast.";
        assistant_state = "idle";
        assistant_status = "I couldn’t read that document. Let’s try again.";
        assistant_message = "Retake or upload a clearer synthetic image.";
        document_processing = False;
        return;
    }

    if document_scenario in ["lab_success", "referral_success", "conflict_success"] {
        if document_file is not None {
            sendDocumentForm(document_file);
        } else {
            fetch(document_preview_url).then(
                lambda (response: any) { return response.blob(); }
            ).then(
                receiveCapturedDocumentBlob
            ).catch(
                failDocumentAnalysis
            );
        }
        return;
    }

    document_processing = False;
    document_stage = "validation_error";
    document_message = "Select a supported synthetic document scenario.";
}


impl app.receiveCapturedDocumentBlob(blob: any) -> None {
    sendDocumentForm(blob);
}


impl app.sendDocumentForm(image_input: any) -> None {
    browser_window: any = window;
    form: any = new(browser_window.FormData);
    document_type: str = (
        "referral_document"
            if document_scenario == "referral_success"
            else (
                "appointment_card"
                    if document_scenario == "conflict_success"
                    else "lab_document"
            )
    );
    mime_type: str = (
        image_input.type
            if image_input.type in ["image/jpeg", "image/png", "image/webp"]
            else "image/jpeg"
    );
    form.append("encounter_id", "encounter-maya-001");
    form.append("document_type", document_type);
    form.append(
        "filename",
        document_file_name
            if len(document_file_name) > 0
            else "captured-synthetic-document.jpg"
    );
    form.append("mime_type", mime_type);
    form.append(
        "image_input",
        image_input,
        document_file_name
            if len(document_file_name) > 0
            else "captured-synthetic-document.jpg"
    );
    form.append("synthetic", "true");
    form.append("session_id", "hospi-pet-frontend-demo");
    form.append("extraction_mode", "deterministic");
    callDocumentIngest(form).then(receiveDocumentAnalysis).catch(failDocumentAnalysis);
}


impl app.receiveDocumentAnalysis(response: any) -> None {
    document_processing = False;
    if not response["success"] {
        document_stage = "recoverable_error";
        document_message = str(response["message"]) + " (" + str(
            response["error_code"]
        ) + ")";
        assistant_state = "idle";
        assistant_status = "I couldn’t read that document. Let’s try again.";
        assistant_message = response["message"];
        return;
    }

    document_candidates = response["multimodal_candidates"];
    text_block: dict[str, any] = response["document_text_blocks"][0];
    source_artifact: dict[str, any] = response["source_artifact"];
    document_text = text_block["text"];
    document_source_id = text_block["id"];
    document_artifact_id = source_artifact["id"];
    document_label = source_artifact["display_name"];
    document_stage = "ready_for_review";
    document_message = response["message"];
    assistant_state = "complete";
    assistant_status = "Document details ready for review";
    assistant_message = "Review the extracted text and verify each candidate.";
    document_file = None;
    backend_connected = True;
    refreshDocumentExtraction();
}


impl app.refreshDocumentExtraction -> None {
    if len(document_artifact_id) == 0 {
        return;
    }
    callBackendAction(
        "get_document_extraction",
        {
            "source_artifact_id": document_artifact_id,
            "session_id": "hospi-pet-frontend-demo"
        }
    ).then(
        receiveDocumentExtraction
    ).catch(
        failDocumentAnalysis
    );
}


impl app.receiveDocumentExtraction(response: any) -> None {
    if not response["success"] {
        failDocumentAnalysis(response);
        return;
    }
    document_candidates = response["multimodal_candidates"];
    if len(response["document_text_blocks"]) > 0 {
        document_text = response["document_text_blocks"][0]["text"];
        document_source_id = response["document_text_blocks"][0]["id"];
    }
    document_stage = "ready_for_review";
    document_message = "Document extraction reloaded from the Jac graph.";
}


impl app.failDocumentAnalysis(error: any) -> None {
    document_processing = False;
    document_stage = "recoverable_error";
    document_message = "The Jac document action is unavailable. Retake the image or retry analysis.";
    assistant_state = "idle";
    assistant_status = "I couldn’t read that document. Let’s try again.";
    assistant_message = "The document remains in the browser so this action can be retried.";
}


impl app.cancelDocumentTimer -> None {
    if document_timer is not None {
        clearTimeout(document_timer);
        document_timer = None;
    }
}


impl app.stopCameraCapture -> None {
    sessionStorage.removeItem("hospi-pet-camera-request");
    if camera_stream is not None {
        for track in camera_stream.getTracks() {
            track.stop();
        }
        camera_stream = None;
    }
    camera_active = False;
}


impl app.clearDocumentResults -> None {
    cancelDocumentTimer();
    document_processing = False;
    document_stage_index = 0;
    document_text = "";
    document_label = "";
    document_source_id = "";
    document_artifact_id = "";
    document_candidates = [];
    document_file = None;
    document_message = "";
}


impl app.traceSource(source_id: str) -> None {
    if len(source_id) == 0 {
        trace_message = "No source reference is available for this candidate.";
        return;
    }
    if (
        "id" in clinician_note_data
        and source_id in [
            "patient_concerns",
            "confirmed_instructions",
            "medication_instructions",
            "laboratory_orders",
            "referrals",
            "follow_up",
            "unresolved_gaps",
            "source_evidence",
            "review_status"
        ]
    ) {
        section_id: str = noteSectionId(clinician_note_data, source_id);
        if len(section_id) == 0 {
            trace_message = "No backend source mapping exists for this section.";
            return;
        }
        trace_message = "Loading source provenance…";
        callBackendAction(
            "trace_output_to_source",
            {
                "output_type": "note_section",
                "output_id": clinician_note_data["id"],
                "section_id": section_id,
                "session_id": "hospi-pet-frontend-demo"
            }
        ).then(
            receiveNoteTrace
        ).catch(
            failNoteTrace
        );
        return;
    }
    highlighted_source_id = source_id;
    trace_message = "Opening the linked backend source.";
    if trace_timer is not None {
        clearTimeout(trace_timer);
    }
    setTimeout(
        lambda() {
            target: any = document.getElementById("source-" + source_id);
            if target is not None {
                target.focus();
                target.scrollIntoView({"behavior": "auto", "block": "center"});
            } else {
                trace_message = "The source reference is valid but is not currently open on this screen.";
            }
        },
        0.0
    );
    trace_timer = setTimeout(clearTrace, 2200.0);
}


impl app.receiveNoteTrace(response: any) -> None {
    if not response["success"] {
        trace_message = response["message"];
    } elif len(response["multimodal_provenance"]) == 0 {
        trace_message = "No source chain was returned for this note section.";
    } else {
        chain: any = response["multimodal_provenance"][0];
        trace_message = (
            str(chain["source_type"]) + " · " + str(chain["verification_status"]) + " · " + str(
                chain["source_excerpt"]
            )
        );
    }
}


impl app.failNoteTrace(error: any) -> None {
    trace_message = "The source-trace action is temporarily unavailable.";
}


impl app.clearTrace -> None {
    trace_timer = None;
    highlighted_source_id = "";
    trace_message = "";
}


impl app.changeClinicianNoteSection(section_key: str, value: str) -> None {
    if len(note_pending_action) > 0 or "id" not in clinician_note_data {
        return;
    }
    updated_edits: dict[str, str] = note_edits.copy();
    updated_edits[section_key] = value;
    note_edits = updated_edits;
}


impl app.generateClinicianNote -> None {
    if (len(note_pending_action) > 0 or acceptedCandidateCount(fact_decisions) == 0) {
        return;
    }
    cancelClinicianNoteTimer();
    note_pending_action = "generate";
    note_status = "loading";
    note_error = "";
    assistant_state = "analyzing";
    assistant_status = "Organizing the verified details";
    assistant_message = "Preparing the clinician-review note from accepted facts.";
    callBackendAction(
        "generate_clinician_note_draft",
        {
            "encounter_id": "encounter-maya-001",
            "clinician_hints": "",
            "session_id": "hospi-pet-frontend-demo"
        }
    ).then(
        lambda (response: any) { receiveClinicianNoteResponse(response, "generate"); }
    ).catch(
        failClinicianNoteAction
    );
}


impl app.saveClinicianNoteSection(section_key: str) -> None {
    if (
        len(note_pending_action) > 0
        or "id" not in clinician_note_data
        or clinician_note_data["status"] == "approved"
    ) {
        return;
    }
    note_pending_action = "save";
    note_pending_section = section_key;
    note_status = "loading";
    note_error = "";
    section_id: str = noteSectionId(clinician_note_data, section_key);
    if len(section_id) == 0 {
        failClinicianNoteAction(None);
        return;
    }
    content: str = note_edits[section_key] if section_key in note_edits else "";
    callBackendAction(
        "update_note_section",
        {
            "note_id": clinician_note_data["id"],
            "section_id": section_id,
            "content": content,
            "clinician_id": "demo-clinician",
            "session_id": "hospi-pet-frontend-demo"
        }
    ).then(
        lambda (response: any) { receiveClinicianNoteResponse(response, "save"); }
    ).catch(
        failClinicianNoteAction
    );
}


impl app.approveClinicianNote -> None {
    if (
        len(note_pending_action) > 0
        or "id" not in clinician_note_data
        or clinician_note_data["status"] == "approved"
    ) {
        return;
    }
    cancelClinicianNoteTimer();
    note_pending_action = "approve";
    note_status = "loading";
    note_error = "";
    assistant_state = "analyzing";
    assistant_status = "Preparing note approval";
    assistant_message = "Submitting the current draft for backend validation.";
    callBackendAction(
        "approve_clinician_note",
        {
            "note_id": clinician_note_data["id"],
            "clinician_id": "demo-clinician",
            "session_id": "hospi-pet-frontend-demo"
        }
    ).then(
        lambda (response: any) { receiveClinicianNoteResponse(response, "approve"); }
    ).catch(
        failClinicianNoteAction
    );
}


impl app.finishClinicianNoteAction -> None {
    note_timer = None;
    action: str = note_pending_action;

    if action == "save" {
        updated_note: dict[str, any] = clinician_note_data.copy();
        if note_pending_section in note_edits {
            updated_note[note_pending_section] = note_edits[note_pending_section];
        }
        updated_note["status"] = "edited";
        clinician_note_data = updated_note;
        note_status = "success";
        note_error = "";
    } else {
        failClinicianNoteAction(None);
        return;
    }

    note_pending_action = "";
    note_pending_section = "";
}


impl app.receiveClinicianNoteResponse(response: any, action: str) -> None {
    note_result_status: str = responseUiStatus(response, "clinician_note");
    note_status = note_result_status;
    note_error = response["message"] if not response["success"] else "";
    if note_result_status in ["success", "provider_fallback"] {
        clinician_note_data = response["clinician_note"];
        note_edits = {};
        assistant_state = "complete";
        assistant_status = (
            "Clinician note approved"
                if action == "approve"
                else "Clinician-review draft ready"
        );
        assistant_message = response["message"];
        backend_connected = True;
    } else {
        assistant_state = "idle";
        assistant_status = "Clinician note needs attention";
        assistant_message = response["message"];
    }
    note_pending_action = "";
    note_pending_section = "";
}


impl app.failClinicianNoteAction(error: any) -> None {
    note_status = "recoverable_error";
    note_error = "The clinician-note backend action is unavailable. Your current draft remains visible.";
    assistant_state = "idle";
    assistant_status = "Clinician note needs attention";
    assistant_message = note_error;
    note_pending_action = "";
    note_pending_section = "";
}


impl app.cancelClinicianNoteTimer -> None {
    if note_timer is not None {
        clearTimeout(note_timer);
        note_timer = None;
    }
    note_pending_action = "";
    note_pending_section = "";
}
