"""Small browser adapter for Jac generated-function endpoints."""

import from "@jac/runtime" { __getApiBaseUrl, __getLocalStorage, jacLogin, jacSignup }

sv import from ..endpoints {
    add_demo_contradiction,
    generate_patient_plan,
    load_demo_encounter,
    reset_demo,
    resolve_gap,
    run_care_gap_check,
    run_evidence_audit,
    verify_fact
}
sv import from ..multimodal_endpoints {
    append_transcript_chunk,
    approve_clinician_note,
    cancel_capture_session,
    finalize_capture_session,
    generate_clinician_note_draft,
    generate_patient_audio_script,
    get_document_extraction,
    load_prepared_voice_demo,
    start_capture_session,
    trace_output_to_source,
    update_note_section
}
sv import from ..intelligence_endpoints {
    dismiss_suggested_question,
    generate_clarifying_questions,
    generate_final_review_packet,
    generate_live_quick_summary,
    get_translated_transcript,
    mark_question_answered,
    run_verified_encounter_analysis,
    trace_analysis_item,
    translate_transcript_chunk
}


def unwrapBackendEnvelope(payload: any) -> dict[str, any] {
    envelope: any = payload;
    if Array.isArray(payload) and len(payload) > 0 {
        envelope = payload[0];
    }
    if envelope is not None and "data" in envelope {
        data: any = envelope["data"];
        if data is not None and "result" in data {
            return data["result"];
        }
    }
    if envelope is not None and "result" in envelope {
        return envelope["result"];
    }
    return envelope;
}


async def ensureDemoLogin -> None {
    storage_key: str = "hospi-pet-demo-account";
    browser_storage: any = localStorage;
    browser_crypto: any = crypto;
    stored: any = browser_storage.getItem(storage_key);
    credentials: dict[str, str] = {};
    signup_result: dict | None = None;
    login_ok: bool = False;
    if stored is not None {
        parsed: any = JSON.parse(stored);
        credentials = {
            "email": str(parsed["email"]),
            "password": str(parsed["password"])
        };
    } else {
        nonce: str = str(browser_crypto.randomUUID());
        credentials = {
            "email": "hospi-pet-" + nonce + "@example.invalid",
            "password": "synthetic-" + str(browser_crypto.randomUUID())
        };
        browser_storage.setItem(storage_key, JSON.stringify(credentials));
    }
    signup_result = await jacSignup(credentials["email"], credentials["password"]);
    login_ok = await jacLogin(credentials["email"], credentials["password"]);
    if not login_ok {
        raise Error("Synthetic demo session login failed.");
    }
}


async def callWalkerEndpoint(walker_name: str, walker_payload: dict[str, any]) -> any {
    token: any = __getLocalStorage("jac_token");
    response: any = await fetch(
        __getApiBaseUrl() + "/walker/" + walker_name,
        {
            "method": "POST",
            "headers": {
                "Authorization": "Bearer " + str(token),
                "Content-Type": "application/json"
            },
            "body": JSON.stringify(walker_payload)
        }
    );
    if not response.ok {
        raise Error("Jac walker request failed with HTTP " + str(response.status));
    }
    envelope: any = await response.json();
    reports: any = envelope["data"]["result"]["reports"];
    if len(reports) == 0 {
        raise Error("Jac walker completed without a structured report.");
    }
    return reports[0];
}


async def dispatchBackendAction(action: str, payload: dict[str, any]) -> any {
    if action == "load_prepared_voice_demo" {
        return await load_prepared_voice_demo(
            payload["encounter_id"], payload["session_id"]
        );
    }
    if action == "get_document_extraction" {
        return await get_document_extraction(
            payload["source_artifact_id"], payload["session_id"]
        );
    }
    walker_names: dict[str, str] = {
        "reset_demo": "ResetDemoWalker",
        "load_demo_encounter": "ConsultationIngestWalker",
        "verify_fact": "VerificationWalker",
        "run_care_gap_check": "CareGapWalker",
        "resolve_gap": "GapResolutionWalker",
        "generate_patient_plan": "PatientPlanWalker",
        "run_evidence_audit": "EvidenceAuditWalker",
        "add_demo_contradiction": "ConsultationIngestWalker",
        "start_capture_session": "StartCaptureSessionWalker",
        "append_transcript_chunk": "AppendTranscriptChunkWalker",
        "finalize_capture_session": "FinalizeCaptureSessionWalker",
        "cancel_capture_session": "CancelCaptureSessionWalker",
        "generate_clinician_note_draft": "GenerateClinicianNoteDraftWalker",
        "update_note_section": "UpdateNoteSectionWalker",
        "approve_clinician_note": "ApproveClinicianNoteWalker",
        "trace_output_to_source": "MultimodalTraceProvenanceWalker",
        "generate_patient_audio_script": "PatientAudioScriptWalker",
        "translate_transcript_chunk": "TranslateTranscriptChunkWalker",
        "get_translated_transcript": "GetTranslatedTranscriptWalker",
        "generate_live_quick_summary": "LiveQuickSummaryWalker",
        "run_verified_encounter_analysis": "VerifiedEncounterAnalysisWalker",
        "generate_clarifying_questions": "ClarifyingQuestionWalker",
        "dismiss_suggested_question": "DismissSuggestedQuestionWalker",
        "mark_question_answered": "MarkSuggestedQuestionAnsweredWalker",
        "generate_final_review_packet": "FinalReviewPacketWalker",
        "trace_analysis_item": "TraceAnalysisItemWalker"
    };
    if action not in walker_names {
        raise Error("Unsupported Jac backend action: " + action);
    }
    walker_payload: dict[str, any] = payload;
    if action == "load_demo_encounter" {
        walker_payload = {"session_id": payload["session_id"]};
    } elif action == "generate_patient_plan" {
        walker_payload = {
            "language": payload["language"],
            "session_id": payload["session_id"]
        };
    } elif action == "resolve_gap" {
        walker_payload = {
            "gap_id": payload["gap_id"],
            "resolution": payload["resolution"],
            "owner": payload["owner"],
            "due_date": payload["due_date"],
            "selected_gap": None,
            "session_id": payload["session_id"]
        };
    } elif action == "add_demo_contradiction" {
        walker_payload = {
            "session_id": payload["session_id"],
            "include_contradiction": True
        };
    }
    return await callWalkerEndpoint(walker_names[action], walker_payload);
}


def:pub callBackendAction(action: str, payload: dict[str, any]) -> any {
    login_promise: any = ensureDemoLogin();
    return login_promise.then(
        lambda (_ignored: any) { return dispatchBackendAction(action, payload); }
    );
}


async def dispatchDocumentIngest(form: any) -> any {
    file: any = form.get("image_input");
    image_input: any = await new(
        Promise,
        lambda (resolve: any, reject: any) {
            reader: any = new(FileReader);
            reader.onload = lambda (_event: any) { resolve(reader.result); };
            reader.onerror = lambda (_event: any) { reject(
                Error("The synthetic image could not be read.")
            ); };
            reader.readAsDataURL(file);
        }
    );
    return await callWalkerEndpoint(
        "DocumentIngestWalker",
        {
            "encounter_id": str(form.get("encounter_id")),
            "document_type": str(form.get("document_type")),
            "filename": str(form.get("filename")),
            "mime_type": str(form.get("mime_type")),
            "image_input": str(image_input),
            "synthetic": True,
            "session_id": str(form.get("session_id")),
            "extraction_mode": str(form.get("extraction_mode"))
        }
    );
}


def:pub callDocumentIngest(form: any) -> any {
    login_promise: any = ensureDemoLogin();
    return login_promise.then(
        lambda (_ignored: any) { return dispatchDocumentIngest(form); }
    );
}
