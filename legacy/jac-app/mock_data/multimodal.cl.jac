"""Contract-shaped frontend mocks for the multimodal demo.

Browser capture remains local in this checkout. The mock responses mirror the
frozen multimodal BackendResponse fields and DTOs without calling or
duplicating the backend walkers.
"""

glob:pub PREPARED_VOICE_TRANSCRIPT: list[dict[str, any]] = [
         {
             "id": "chunk-1",
             "encounter_id": "encounter-maya-001",
             "capture_session_id": "capture-demo-default-2",
             "sequence": 1,
             "speaker": "Doctor",
             "text": "We will order a blood test to be completed this week.",
             "started_at": "",
             "ended_at": "",
             "confidence": 1.0,
             "source_type": "prepared_transcript",
             "finalized": True
         },
         {
             "id": "chunk-2",
             "encounter_id": "encounter-maya-001",
             "capture_session_id": "capture-demo-default-2",
             "sequence": 2,
             "speaker": "Doctor",
             "text": "Please return in two weeks so we can review the results.",
             "started_at": "",
             "ended_at": "",
             "confidence": 1.0,
             "source_type": "prepared_transcript",
             "finalized": True
         },
         {
             "id": "chunk-3",
             "encounter_id": "encounter-maya-001",
             "capture_session_id": "capture-demo-default-2",
             "sequence": 3,
             "speaker": "Doctor",
             "text": "Continue your current medication exactly as it appears on your existing prescription.",
             "started_at": "",
             "ended_at": "",
             "confidence": 1.0,
             "source_type": "prepared_transcript",
             "finalized": True
         },
         {
             "id": "chunk-4",
             "encounter_id": "encounter-maya-001",
             "capture_session_id": "capture-demo-default-2",
             "sequence": 4,
             "speaker": "Doctor",
             "text": "I am referring you to a community nutrition counselor.",
             "started_at": "",
             "ended_at": "",
             "confidence": 1.0,
             "source_type": "prepared_transcript",
             "finalized": True
         },
         {
             "id": "chunk-5",
             "encounter_id": "encounter-maya-001",
             "capture_session_id": "capture-demo-default-2",
             "sequence": 5,
             "speaker": "Patient",
             "text": "Can someone explain the instructions to me in Spanish?",
             "started_at": "",
             "ended_at": "",
             "confidence": 1.0,
             "source_type": "prepared_transcript",
             "finalized": True
         }
     ];

glob:pub PREPARED_VOICE_CANDIDATES: list[dict[str, any]] = [
         {
             "id": "candidate-lab",
             "category": "lab_order",
             "value": "blood test; due this week",
             "source_chunk_id": "chunk-1",
             "source_text": "We will order a blood test to be completed this week.",
             "confidence": 1.0,
             "status": "pending",
             "created_at": "2026-07-26T18:00:01Z"
         },
         {
             "id": "candidate-follow-up",
             "category": "follow_up",
             "value": "return in two weeks",
             "source_chunk_id": "chunk-2",
             "source_text": "Please return in two weeks so we can review the results.",
             "confidence": 1.0,
             "status": "pending",
             "created_at": "2026-07-26T18:00:02Z"
         },
         {
             "id": "candidate-medication",
             "category": "medication_instruction",
             "value": "continue existing prescription unchanged",
             "source_chunk_id": "chunk-3",
             "source_text": "Continue your current medication exactly as it appears on your existing prescription.",
             "confidence": 1.0,
             "status": "pending",
             "created_at": "2026-07-26T18:00:03Z"
         },
         {
             "id": "candidate-referral",
             "category": "referral",
             "value": "community nutrition counselor",
             "source_chunk_id": "chunk-4",
             "source_text": "I am referring you to a community nutrition counselor.",
             "confidence": 1.0,
             "status": "pending",
             "created_at": "2026-07-26T18:00:04Z"
         },
         {
             "id": "candidate-language",
             "category": "language_preference",
             "value": "Spanish",
             "source_chunk_id": "chunk-5",
             "source_text": "Can someone explain the instructions to me in Spanish?",
             "confidence": 1.0,
             "status": "pending",
             "created_at": "2026-07-26T18:00:05Z"
         }
     ];

glob:pub SOURCE_METADATA: dict[str, dict[str, str]] = {
         "chunk-1": {
             "source_type": "Prepared voice demo",
             "source_label": "Prepared transcript · line 1",
             "target_kind": "transcript"
         },
         "chunk-2": {
             "source_type": "Prepared voice demo",
             "source_label": "Prepared transcript · line 2",
             "target_kind": "transcript"
         },
         "chunk-3": {
             "source_type": "Prepared voice demo",
             "source_label": "Prepared transcript · line 3",
             "target_kind": "transcript"
         },
         "chunk-4": {
             "source_type": "Prepared voice demo",
             "source_label": "Prepared transcript · line 4",
             "target_kind": "transcript"
         },
         "chunk-5": {
             "source_type": "Prepared voice demo",
             "source_label": "Prepared transcript · line 5",
             "target_kind": "transcript"
         },
         "block-demo-default-lab-1": {
             "source_type": "Synthetic document text block",
             "source_label": "Lab Order Sheet",
             "target_kind": "document"
         },
         "block-demo-default-referral-1": {
             "source_type": "Synthetic document text block",
             "source_label": "Referral Sheet",
             "target_kind": "document"
         },
         "block-demo-default-after-visit-1": {
             "source_type": "Synthetic document text block",
             "source_label": "After-Visit Summary",
             "target_kind": "document"
         }
     };


def:pub emptyBackendResponse -> dict[str, any] {
    return {
        "success": True,
        "error_code": "",
        "message": "",
        "recoverable": False,
        "current_graph_version": 0,
        "ai_status": None,
        "extracted_candidates": [],
        "demo_state": None,
        "candidate_facts": [],
        "verified_fact": None,
        "care_graph": None,
        "care_gaps": [],
        "patient_plan": None,
        "patient_answer": None,
        "conflicts": [],
        "created_graph_ids": [],
        "traversal_trace": [],
        "provenance_chains": [],
        "capture_session": None,
        "transcript_chunk": None,
        "transcript_chunks": [],
        "source_artifact": None,
        "document_text_blocks": [],
        "multimodal_candidates": [],
        "clinician_note": None,
        "timeline": [],
        "patient_audio_script": None,
        "multimodal_provenance": []
    };
}


def:pub preparedVoiceResponse -> dict[str, any] {
    response: dict[str, any] = emptyBackendResponse();
    response["current_graph_version"] = 1;
    response["message"] = "Prepared synthetic encounter loaded.";
    response["capture_session"] = {
        "id": "capture-demo-default-2",
        "encounter_id": "encounter-maya-001",
        "session_id": "demo-default",
        "input_source": "prepared_transcript",
        "status": "completed",
        "extraction_mode": "deterministic",
        "started_at": "2026-07-26T18:00:00Z",
        "completed_at": "2026-07-26T18:00:06Z",
        "fallback_used": False,
        "chunk_count": 5,
        "error_code": "",
        "recoverable": False
    };
    response["transcript_chunks"] = PREPARED_VOICE_TRANSCRIPT;
    response["candidate_facts"] = PREPARED_VOICE_CANDIDATES;
    return response;
}


def:pub documentResponse(scenario: str) -> dict[str, any] {
    response: dict[str, any] = emptyBackendResponse();
    response["current_graph_version"] = 1;

    if scenario == "lab_success" {
        response["message"] = "Synthetic lab-order candidates are ready for review.";
        response["source_artifact"] = {
            "id": "artifact-demo-default-lab-document",
            "encounter_id": "encounter-maya-001",
            "artifact_type": "lab_document",
            "display_name": "Lab Order Sheet",
            "mime_type": "image/png",
            "synthetic": True,
            "extraction_mode": "deterministic",
            "extraction_status": "completed",
            "created_at": "2026-07-26T18:10:00Z",
            "temporary_content_deleted": True
        };
        response["document_text_blocks"] = [
            {
                "id": "block-demo-default-lab-1",
                "source_artifact_id": "artifact-demo-default-lab-document",
                "sequence": 1,
                "text": "SYNTHETIC LAB ORDER\nPatient: Demo Patient\nOrder: Complete blood count\nTiming: This week\nReview required before use.",
                "confidence": 0.96,
                "page_number": 1,
                "bounding_region": "0,0,100,20",
                "source_hash": "mock-lab-source-hash"
            }
        ];
        response["multimodal_candidates"] = [
            {
                "id": "candidate-document-lab",
                "category": "lab_order",
                "value": "complete blood count; due this week",
                "confidence": 0.96,
                "status": "pending",
                "source_kind": "document",
                "source_artifact_id": "artifact-demo-default-lab-document",
                "source_chunk_id": "",
                "source_text_block_id": "block-demo-default-lab-1",
                "source_text": "Order: Complete blood count\nTiming: This week",
                "source_region": "0,0,100,20",
                "created_at": "2026-07-26T18:10:01Z"
            }
        ];
    } elif scenario == "referral_success" {
        response["message"] = "Synthetic referral candidates are ready for review.";
        response["source_artifact"] = {
            "id": "artifact-demo-default-referral-document",
            "encounter_id": "encounter-maya-001",
            "artifact_type": "referral_document",
            "display_name": "Referral Sheet",
            "mime_type": "image/png",
            "synthetic": True,
            "extraction_mode": "deterministic",
            "extraction_status": "completed",
            "created_at": "2026-07-26T18:10:00Z",
            "temporary_content_deleted": True
        };
        response["document_text_blocks"] = [
            {
                "id": "block-demo-default-referral-1",
                "source_artifact_id": "artifact-demo-default-referral-document",
                "sequence": 1,
                "text": "SYNTHETIC REFERRAL SHEET\nReferral: Community nutrition counselor\nReason: Nutrition support\nScheduling status: Not specified",
                "confidence": 0.94,
                "page_number": 1,
                "bounding_region": "0,0,100,24",
                "source_hash": "mock-referral-source-hash"
            }
        ];
        response["multimodal_candidates"] = [
            {
                "id": "candidate-document-referral",
                "category": "referral",
                "value": "community nutrition counselor",
                "confidence": 0.94,
                "status": "pending",
                "source_kind": "document",
                "source_artifact_id": "artifact-demo-default-referral-document",
                "source_chunk_id": "",
                "source_text_block_id": "block-demo-default-referral-1",
                "source_text": "Referral: Community nutrition counselor\nReason: Nutrition support",
                "source_region": "0,0,100,24",
                "created_at": "2026-07-26T18:10:02Z"
            }
        ];
    } elif scenario == "conflict_success" {
        response["message"] = "A conflicting source requires clinician review.";
        response["source_artifact"] = {
            "id": "artifact-demo-default-after-visit-document",
            "encounter_id": "encounter-maya-001",
            "artifact_type": "after_visit_document",
            "display_name": "After-Visit Summary",
            "mime_type": "image/png",
            "synthetic": True,
            "extraction_mode": "deterministic",
            "extraction_status": "completed",
            "created_at": "2026-07-26T18:10:00Z",
            "temporary_content_deleted": True
        };
        response["document_text_blocks"] = [
            {
                "id": "block-demo-default-after-visit-1",
                "source_artifact_id": "artifact-demo-default-after-visit-document",
                "sequence": 1,
                "text": "SYNTHETIC AFTER-VISIT SUMMARY\nFollow-up instruction: Return in four weeks to review results.\nClinician verification required.",
                "confidence": 0.91,
                "page_number": 1,
                "bounding_region": "0,0,100,18",
                "source_hash": "mock-after-visit-source-hash"
            }
        ];
        response["multimodal_candidates"] = [
            {
                "id": "candidate-document-follow-up-conflict",
                "category": "follow_up",
                "value": "return in four weeks",
                "confidence": 0.91,
                "status": "pending",
                "source_kind": "document",
                "source_artifact_id": "artifact-demo-default-after-visit-document",
                "source_chunk_id": "",
                "source_text_block_id": "block-demo-default-after-visit-1",
                "source_text": "Follow-up instruction: Return in four weeks to review results.",
                "source_region": "0,0,100,18",
                "created_at": "2026-07-26T18:10:03Z"
            }
        ];
    } elif scenario == "recoverable_error" {
        response["success"] = False;
        response["recoverable"] = True;
        response["error_code"] = "IMAGE_READ_FAILED";
        response["message"] = "Document processing is temporarily unavailable. Try again.";
    }

    return response;
}
