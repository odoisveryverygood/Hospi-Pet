"""Small adapters over backend-provided intelligence handoff fixtures.

These objects mirror CONTRACT.md and handoff/intelligence-fixtures. They are
display fixtures only; no frontend intelligence or clinical inference occurs.
"""

import from .multimodal { emptyBackendResponse }


glob:pub PREPARED_PATIENT: dict[str, str] = {
         "name": "Maya Rivera",
         "encounter_type": "Synthetic prepared consultation",
         "consultation_status": "Capture complete",
         "encounter_date": "July 26, 2026",
         "visit_id": "encounter-maya-001",
         "review_status": "Ready for clinician verification"
     };

glob:pub TRANSLATED_ROWS: list[dict[str, any]] = [
         {
             "id": "translation-demo-default-chunk-live-es-1-english-4",
             "original_chunk_id": "chunk-live-es-1",
             "capture_session_id": "capture-demo-default-2",
             "source_language": "Spanish",
             "target_language": "English",
             "original_text": "Me he sentido mareada durante tres días.",
             "translated_text": "I have felt dizzy for three days.",
             "speaker": "Patient",
             "sequence": 1,
             "status": "translated",
             "translation_mode": "deterministic",
             "fallback_used": False,
             "created_at": "2026-07-26T18:00:04Z"
         },
         {
             "id": "translation-demo-default-chunk-live-en-2-spanish-6",
             "original_chunk_id": "chunk-live-en-2",
             "capture_session_id": "capture-demo-default-2",
             "source_language": "English",
             "target_language": "Spanish",
             "original_text": "We will order a blood test to be completed this week.",
             "translated_text": "Pediremos un análisis de sangre para completar esta semana.",
             "speaker": "Doctor",
             "sequence": 2,
             "status": "translated",
             "translation_mode": "deterministic",
             "fallback_used": False,
             "created_at": "2026-07-26T18:00:06Z"
         }
     ];

glob:pub QUICK_SUMMARY: dict[str, any] = {
         "id": "quick-summary-demo-default-7",
         "encounter_id": "encounter-maya-001",
         "status": "completed",
         "summary": "Patient: I have felt dizzy for three days. Doctor: A blood test will be ordered this week.",
         "key_points": [
             "I have felt dizzy for three days.",
             "A blood test will be ordered this week."
         ],
         "source_chunk_ids": ["chunk-live-es-1", "chunk-live-en-2"],
         "unverified": True,
         "model_mode": "deterministic",
         "fallback_used": False,
         "generated_at": "2026-07-26T18:00:07Z"
     };

glob:pub VERIFIED_ANALYSIS: dict[str, any] = {
         "id": "analysis-demo-default-15-1",
         "encounter_id": "encounter-maya-001",
         "status": "completed",
         "graph_version": 15,
         "accepted_fact_ids": [
             "verified-candidate-lab",
             "verified-candidate-follow-up",
             "verified-candidate-medication",
             "verified-candidate-referral"
         ],
         "rejected_fact_ids_excluded": ["candidate-language"],
         "summary": {
             "id": "verified-summary-analysis-demo-default-15-1",
             "encounter_id": "encounter-maya-001",
             "summary": "Verified encounter information includes 1 accepted medication instruction(s), 1 laboratory order(s), 1 referral(s), 1 follow-up obligation(s).",
             "patient_concerns": [],
             "medications": [
                 "Continue your current medication exactly as it appears on your existing prescription."
             ],
             "allergies": [],
             "laboratory_orders": ["blood test; due this week"],
             "referrals": ["community nutrition counselor"],
             "follow_ups": ["two weeks"],
             "outstanding_tasks": [
                 "Coordinate blood test",
                 "Schedule follow-up appointment"
             ],
             "contradictions": [],
             "source_fact_ids": [
                 "verified-candidate-lab",
                 "verified-candidate-follow-up",
                 "verified-candidate-medication",
                 "verified-candidate-referral"
             ],
             "verified_only": True,
             "generated_at": "2026-07-26T18:00:15Z"
         },
         "insights": [],
         "questions": [],
         "care_gaps": [],
         "conflicts": [],
         "source_fact_ids": [
             "verified-candidate-lab",
             "verified-candidate-follow-up",
             "verified-candidate-medication",
             "verified-candidate-referral"
         ],
         "model_mode": "deterministic",
         "fallback_used": False,
         "created_at": "2026-07-26T18:00:15Z",
         "completed_at": "2026-07-26T18:00:15Z",
         "stale": False,
         "superseding_run_id": ""
     };

glob:pub SUGGESTED_QUESTIONS: list[dict[str, any]] = [
         {
             "id": "question-analysis-demo-default-15-1-gap-lab-owner-verified-candidate-lab",
             "question": "Who is responsible for coordinating the blood test?",
             "purpose": "confirm_responsibility",
             "explanation": "Generated because the accepted care obligation has a current documentation gap.",
             "source_fact_ids": ["verified-candidate-lab"],
             "related_gap_ids": ["gap-lab-owner-verified-candidate-lab"],
             "clinician_only": True,
             "status": "open"
         },
         {
             "id": "question-analysis-demo-default-15-1-gap-follow-up-date-verified-candidate-follow-up",
             "question": "Has a specific follow-up date been scheduled?",
             "purpose": "confirm_follow_up",
             "explanation": "Generated because the accepted care obligation has a current documentation gap.",
             "source_fact_ids": ["verified-candidate-follow-up"],
             "related_gap_ids": ["gap-follow-up-date-verified-candidate-follow-up"],
             "clinician_only": True,
             "status": "open"
         }
     ];

glob:pub CLINICIAN_NOTE: dict[str, any] = {
         "id": "note-demo-default-19",
         "encounter_id": "encounter-maya-001",
         "status": "draft",
         "patient_concerns": "Spanish",
         "confirmed_instructions": "blood test; due this week; return in two weeks",
         "medication_instructions": "continue existing prescription unchanged",
         "laboratory_orders": "blood test; due this week",
         "referrals": "community nutrition counselor",
         "follow_up": "return in two weeks",
         "unresolved_gaps": "No unresolved administrative care gaps.",
         "note_sections": [
             {
                 "id": "note-demo-default-19-04-laboratory_orders",
                 "section_type": "laboratory_orders",
                 "heading": "Laboratory orders",
                 "content": "blood test; due this week",
                 "source_fact_ids": ["verified-candidate-lab"],
                 "source_artifact_ids": [],
                 "manually_edited": False,
                 "approved": False
             }
         ],
         "source_fact_ids": [
             "verified-candidate-lab",
             "verified-candidate-follow-up",
             "verified-candidate-medication",
             "verified-candidate-referral"
         ],
         "generated_at": "2026-07-26T18:00:19Z",
         "edited_at": "",
         "approved_at": "",
         "approved_by": ""
     };

glob:pub APPROVED_CLINICIAN_NOTE: dict[str, any] = {
         "id": "note-demo-default-19",
         "encounter_id": "encounter-maya-001",
         "status": "approved",
         "patient_concerns": "Spanish",
         "confirmed_instructions": "blood test; due this week; return in two weeks",
         "medication_instructions": "continue existing prescription unchanged",
         "laboratory_orders": "Blood test remains due this week.",
         "referrals": "community nutrition counselor",
         "follow_up": "return in two weeks",
         "unresolved_gaps": "No unresolved administrative care gaps.",
         "note_sections": [
             {
                 "id": "note-demo-default-19-04-laboratory_orders",
                 "section_type": "laboratory_orders",
                 "heading": "Laboratory orders",
                 "content": "Blood test remains due this week.",
                 "source_fact_ids": ["verified-candidate-lab"],
                 "source_artifact_ids": [],
                 "manually_edited": True,
                 "approved": True
             }
         ],
         "source_fact_ids": [
             "verified-candidate-lab",
             "verified-candidate-follow-up",
             "verified-candidate-medication",
             "verified-candidate-referral"
         ],
         "generated_at": "2026-07-26T18:00:19Z",
         "edited_at": "2026-07-26T18:00:20Z",
         "approved_at": "2026-07-26T18:00:21Z",
         "approved_by": "demo-clinician"
     };

glob:pub SOURCE_TRACE: list[dict[str, any]] = [
         {
             "analysis_run_id": "analysis-demo-default-20-2",
             "item_id": "verified-summary-analysis-demo-default-20-2",
             "item_type": "verified_summary",
             "source_fact_ids": ["verified-candidate-lab"],
             "ordered_steps": [
                 {
                     "order": 1,
                     "walker_name": "MultimodalTraceProvenanceWalker",
                     "current_node_id": "verified-candidate-lab",
                     "current_node_type": "VerifiedFact",
                     "edge_type": "VerifiedFrom",
                     "action": "follow verification source",
                     "outcome": "candidate-lab",
                     "human_explanation": "Reached the clinician-approved fact's pending proposal."
                 },
                 {
                     "order": 2,
                     "walker_name": "MultimodalTraceProvenanceWalker",
                     "current_node_id": "candidate-lab",
                     "current_node_type": "CandidateFact",
                     "edge_type": "ExtractedFrom",
                     "action": "follow transcript evidence",
                     "outcome": "chunk-1",
                     "human_explanation": "Reached the exact speaker-labeled transcript chunk."
                 }
             ],
             "source_excerpt": "We will order a blood test to be completed this week.",
             "source_type": "transcript",
             "complete": True
         }
     ];

glob:pub PROVIDER_FALLBACK_STATUS: dict[str, any] = {
         "requested": True,
         "used": False,
         "fallback_used": True,
         "mode": "deterministic",
         "diagnostic_code": "TRANSLATION_PROVIDER_OR_VALIDATION_FAILED",
         "diagnostic_message": "Optional translation used a safe deterministic fallback."
     };

glob:pub FINAL_REVIEW: dict[str, any] = {
         "id": "final-packet-demo-default-20-1",
         "encounter_id": "encounter-maya-001",
         "verified_summary": {
             "id": "verified-summary-analysis-demo-default-20-2",
             "encounter_id": "encounter-maya-001",
             "summary": "Verified encounter information is organized from accepted facts.",
             "patient_concerns": [],
             "medications": [
                 "Continue your current medication exactly as it appears on your existing prescription."
             ],
             "allergies": [],
             "laboratory_orders": ["blood test; due this week; owner clinic-lab-team"],
             "referrals": ["community nutrition counselor"],
             "follow_ups": ["two weeks; appointment 2026-08-09"],
             "outstanding_tasks": [],
             "contradictions": [],
             "source_fact_ids": [
                 "verified-candidate-lab",
                 "verified-candidate-follow-up",
                 "verified-candidate-medication",
                 "verified-candidate-referral"
             ],
             "verified_only": True,
             "generated_at": "2026-07-26T18:00:20Z"
         },
         "clinician_note_id": "note-demo-default-17",
         "suggested_questions": [],
         "active_care_gaps": [],
         "conflicts": [],
         "patient_plan_id": "brief-demo-default-19",
         "english_patient_plan": {
             "patient_id": "patient-maya",
             "language": "English",
             "medications": [
                 {
                     "id": "checklist-demo-default-18-3",
                     "kind": "medication",
                     "text": "Continue your current medication exactly as it appears on your existing prescription.",
                     "owner": "patient",
                     "due_date": "Follow the timing on the existing prescription.",
                     "status": "active",
                     "source_fact_id": "verified-candidate-medication"
                 }
             ],
             "labs": [
                 {
                     "id": "checklist-demo-default-18-1",
                     "kind": "lab",
                     "text": "Complete the blood test this week.",
                     "owner": "clinic-lab-team",
                     "due_date": "this week",
                     "status": "ordered",
                     "source_fact_id": "verified-candidate-lab"
                 }
             ],
             "referrals": [
                 {
                     "id": "checklist-demo-default-18-4",
                     "kind": "referral",
                     "text": "Your referral is to a community nutrition counselor.",
                     "owner": "clinic-referral-team",
                     "due_date": "",
                     "status": "referred",
                     "source_fact_id": "verified-candidate-referral"
                 }
             ],
             "follow_ups": [
                 {
                     "id": "checklist-demo-default-18-2",
                     "kind": "follow_up",
                     "text": "Return in two weeks; appointment: 2026-08-09.",
                     "owner": "clinic-scheduling-team",
                     "due_date": "2026-08-09",
                     "status": "scheduled",
                     "source_fact_id": "verified-candidate-follow-up"
                 }
             ],
             "checklist": [
                 "Complete the blood test this week. [source: verified-candidate-lab]",
                 "Return in two weeks; appointment: 2026-08-09. [source: verified-candidate-follow-up]",
                 "Continue your current medication exactly as it appears on your existing prescription. [source: verified-candidate-medication]",
                 "Your referral is to a community nutrition counselor. [source: verified-candidate-referral]"
             ],
             "source_fact_ids": [
                 "verified-candidate-lab",
                 "verified-candidate-follow-up",
                 "verified-candidate-medication",
                 "verified-candidate-referral"
             ],
             "generated_at": "2026-07-26T18:00:18Z",
             "ai_enhanced": False,
             "translation_fallback_used": False,
             "simplification_fallback_used": False
         },
         "spanish_patient_plan": {
             "patient_id": "patient-maya",
             "language": "Spanish",
             "medications": [
                 {
                     "id": "checklist-demo-default-19-3",
                     "kind": "medication",
                     "text": "Continúe su medicamento actual exactamente como aparece en su receta existente.",
                     "owner": "patient",
                     "due_date": "Siga el horario de la receta existente.",
                     "status": "active",
                     "source_fact_id": "verified-candidate-medication"
                 }
             ],
             "labs": [
                 {
                     "id": "checklist-demo-default-19-1",
                     "kind": "lab",
                     "text": "Complete el análisis de sangre esta semana.",
                     "owner": "clinic-lab-team",
                     "due_date": "esta semana",
                     "status": "ordered",
                     "source_fact_id": "verified-candidate-lab"
                 }
             ],
             "referrals": [
                 {
                     "id": "checklist-demo-default-19-4",
                     "kind": "referral",
                     "text": "Su referencia es con un consejero comunitario de nutrición.",
                     "owner": "clinic-referral-team",
                     "due_date": "",
                     "status": "referred",
                     "source_fact_id": "verified-candidate-referral"
                 }
             ],
             "follow_ups": [
                 {
                     "id": "checklist-demo-default-19-2",
                     "kind": "follow_up",
                     "text": "Regrese en dos semanas; cita: 2026-08-09.",
                     "owner": "clinic-scheduling-team",
                     "due_date": "2026-08-09",
                     "status": "scheduled",
                     "source_fact_id": "verified-candidate-follow-up"
                 }
             ],
             "checklist": [
                 "Complete el análisis de sangre esta semana. [source: verified-candidate-lab]",
                 "Regrese en dos semanas; cita: 2026-08-09. [source: verified-candidate-follow-up]",
                 "Continúe su medicamento actual exactamente como aparece en su receta existente. [source: verified-candidate-medication]",
                 "Su referencia es con un consejero comunitario de nutrición. [source: verified-candidate-referral]"
             ],
             "source_fact_ids": [
                 "verified-candidate-lab",
                 "verified-candidate-follow-up",
                 "verified-candidate-medication",
                 "verified-candidate-referral"
             ],
             "generated_at": "2026-07-26T18:00:19Z",
             "ai_enhanced": False,
             "translation_fallback_used": False,
             "simplification_fallback_used": False
         },
         "encounter_timeline": [],
         "source_fact_ids": [
             "verified-candidate-lab",
             "verified-candidate-follow-up",
             "verified-candidate-medication",
             "verified-candidate-referral"
         ],
         "graph_version": 20,
         "generated_at": "2026-07-26T18:00:20Z",
         "verified_items": [
             "Verified encounter summary",
             "Approved English patient plan",
             "Approved Spanish patient plan"
         ],
         "requires_review_items": ["Clinician note draft requires review"],
         "unverified_items": ["AI conversation draft — not yet clinician verified."]
     };


def:pub intelligenceFixture(action: str, scenario: str) -> dict[str, any] {
    response: dict[str, any] = emptyBackendResponse();
    response["current_graph_version"] = 20;

    if scenario == "recoverable_error" {
        response["success"] = False;
        response["recoverable"] = True;
        response["error_code"] = (
            "NO_FINALIZED_TRANSCRIPT"
                if action in ["translation", "quick_note"]
                else "NO_VERIFIED_FACTS"
        );
        response["message"] = (
            "No finalized transcript is available for this action."
                if action in ["translation", "quick_note"]
                else "No accepted facts are available for verified analysis."
        );
        return response;
    } elif scenario == "empty" {
        response["message"] = "No fixture data is available for this view.";
        return response;
    }

    if scenario == "provider_fallback" {
        # Reuse the exact AIStatusDTO from provider_failure.json. The frontend
        # does not interpret or manufacture provider diagnostics.
        response["ai_status"] = PROVIDER_FALLBACK_STATUS;
    }

    if action == "translation" {
        response["translated_transcript"] = TRANSLATED_ROWS;
        if scenario == "provider_fallback" {
            response["translated_transcript"] = [TRANSLATED_ROWS[0].copy()];
            response["translated_transcript"][0]["status"] = "fallback";
            response["translated_transcript"][0]["fallback_used"] = True;
        }
    } elif action == "quick_note" {
        response["live_quick_summary"] = QUICK_SUMMARY;
        if scenario == "provider_fallback" {
            response["live_quick_summary"] = QUICK_SUMMARY.copy();
            response["live_quick_summary"]["fallback_used"] = True;
        }
    } elif action == "analysis" {
        response["analysis_run"] = VERIFIED_ANALYSIS;
        response["verified_encounter_summary"] = VERIFIED_ANALYSIS["summary"];
        response["suggested_questions"] = SUGGESTED_QUESTIONS;
        if scenario == "provider_fallback" {
            response["analysis_run"] = VERIFIED_ANALYSIS.copy();
            response["analysis_run"]["fallback_used"] = True;
        }
    } elif action == "trace" {
        response["analysis_provenance"] = SOURCE_TRACE;
    } elif action == "final_review" {
        response["final_review_packet"] = FINAL_REVIEW;
    }
    return response;
}


def:pub clinicianNoteFixture(action: str, scenario: str) -> dict[str, any] {
    response: dict[str, any] = emptyBackendResponse();
    response["current_graph_version"] = 21 if action == "approve" else 19;

    if scenario == "recoverable_error" {
        response["success"] = False;
        response["recoverable"] = True;
        response["error_code"] = (
            "UNRESOLVED_NOTE_CONFLICT" if action == "approve" else "NO_VERIFIED_FACTS"
        );
        response["message"] = (
            "The note has an unresolved conflict and cannot be approved."
                if action == "approve"
                else "No accepted facts are available for a clinician note."
        );
        return response;
    } elif scenario == "empty" {
        response["message"] = "No clinician note fixture is available.";
        return response;
    }

    response["success"] = True;
    response["message"] = (
        "Clinician note approved."
            if action == "approve"
            else "Clinician-review draft generated from verified facts only."
    );
    response["clinician_note"] = (
        APPROVED_CLINICIAN_NOTE if action == "approve" else CLINICIAN_NOTE
    );
    if scenario == "provider_fallback" {
        response["ai_status"] = PROVIDER_FALLBACK_STATUS;
    }
    return response;
}
