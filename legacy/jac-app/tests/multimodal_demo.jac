"""Nine-cycle deterministic multimodal acceptance runner for Prompt 3 gating."""

import os;
import base64;
import from endpoints {
    add_demo_contradiction,
    ask_patient_question,
    generate_patient_plan,
    get_care_graph,
    reset_demo,
    resolve_gap,
    run_care_gap_check,
    run_evidence_audit,
    verify_fact,
}
import from multimodal_endpoints {
    approve_clinician_note,
    finalize_capture_session,
    generate_clinician_note_draft,
    generate_patient_audio_script,
    get_capture_session,
    get_document_extraction,
    get_encounter_timeline,
    _ingest_document_image_data_url,
    load_prepared_voice_demo,
    trace_output_to_source,
    update_note_section,
}
import from models {
    BackendResponse,
    CaptureSessionDTO,
    CareGraphDTO,
    ClinicianNoteDraftDTO,
    DemoStateDTO,
    PatientAnswerDTO,
    PatientAudioScriptDTO,
    PatientPlanDTO,
    SourceArtifactDTO,
}

def image_data_url -> str {
    path: str = os.path.join(
        os.path.dirname(__file__), "..", "demo_assets", "synthetic_lab_order.png"
    );
    with open(path, "rb") as source {
        return ("data:image/png;base64," + base64.b64encode(source.read()).decode());
    }
}

def capture_of(response: BackendResponse) -> CaptureSessionDTO {
    assert response.success , response.message;
    assert response.capture_session is not None;
    return response.capture_session as CaptureSessionDTO;
}

def note_of(response: BackendResponse) -> ClinicianNoteDraftDTO {
    assert response.success , response.message;
    assert response.clinician_note is not None;
    return response.clinician_note as ClinicianNoteDraftDTO;
}

def artifact_of(response: BackendResponse) -> SourceArtifactDTO {
    assert response.success , response.message;
    assert response.source_artifact is not None;
    return response.source_artifact as SourceArtifactDTO;
}

def state_of(response: BackendResponse) -> DemoStateDTO {
    assert response.demo_state is not None , response.message;
    return response.demo_state as DemoStateDTO;
}

def graph_of(response: BackendResponse) -> CareGraphDTO {
    assert response.care_graph is not None , response.message;
    return response.care_graph as CareGraphDTO;
}

def plan_of(response: BackendResponse) -> PatientPlanDTO {
    assert response.patient_plan is not None , response.message;
    return response.patient_plan as PatientPlanDTO;
}

def answer_of(response: BackendResponse) -> PatientAnswerDTO {
    assert response.patient_answer is not None , response.message;
    return response.patient_answer as PatientAnswerDTO;
}

def audio_of(response: BackendResponse) -> PatientAudioScriptDTO {
    assert response.patient_audio_script is not None , response.message;
    return response.patient_audio_script as PatientAudioScriptDTO;
}

def run_multimodal_cycle(mode: str, cycle: int) {
    session_id: str = f"multimodal-{mode}-{cycle}";

    # 1–8: reset, normal capture stream, ordering/speakers, finalize, proposals.
    reset: BackendResponse = reset_demo(session_id);
    assert reset.success;
    assert len(state_of(reset).candidate_facts) == 5;
    streamed: BackendResponse = load_prepared_voice_demo(
        "encounter-maya-001", session_id
    );
    capture: CaptureSessionDTO = capture_of(streamed);
    assert capture.status == "recording";
    assert capture.chunk_count == 5;
    assert [chunk.sequence for chunk in streamed.transcript_chunks] == [1, 2, 3, 4, 5];
    assert [chunk.speaker for chunk in streamed.transcript_chunks] == [
        "Doctor",
        "Doctor",
        "Doctor",
        "Doctor",
        "Patient"
    ];
    finalized: BackendResponse = finalize_capture_session(capture.id, session_id);
    assert finalized.success;
    assert capture_of(finalized).status == "completed";
    assert len(finalized.candidate_facts) == 5;

    # 9–10: voice provenance and clinician verification.
    for fact_id in [
        "candidate-lab",
        "candidate-follow-up",
        "candidate-medication",
        "candidate-referral",
        "candidate-language"
    ] {
        verified: BackendResponse = verify_fact(
            fact_id, "accept", "demo-clinician", session_id
        );
        assert verified.success , verified.message;
    }
    voice_trace: BackendResponse = trace_output_to_source(
        "candidate", "candidate-lab", "", session_id
    );
    assert voice_trace.success;
    assert voice_trace.multimodal_provenance[0].source_type == "transcript";

    # 11–16: real PNG validation, deterministic/Mock/missing-key extraction,
    # pending document fact, region trace after clinician acceptance.
    extraction_mode: str = (
        "deterministic"
            if mode == "deterministic"
            else ("cloud_model" if mode == "missing-key" else "mock")
    );
    document: BackendResponse = _ingest_document_image_data_url(
        "encounter-maya-001",
        "lab_document",
        f"synthetic_lab_order_{mode}_{cycle}.png",
        "image/png",
        image_data_url(),
        True,
        session_id,
        extraction_mode
    );
    assert document.success , document.message;
    assert len(document.document_text_blocks) == 5;
    assert len(document.multimodal_candidates) == 1;
    assert document.multimodal_candidates[0].status == "pending";
    if mode == "missing-key" {
        assert document.recoverable;
        assert document.ai_status is not None;
        assert document.ai_status.fallback_used;
    } elif mode == "mock" {
        assert document.ai_status is not None;
        assert document.ai_status.used;
    }
    document_candidate_id: str = document.multimodal_candidates[0].id;
    accepted_document: BackendResponse = verify_fact(
        document_candidate_id, "accept", "demo-clinician", session_id
    );
    assert accepted_document.success;
    document_trace: BackendResponse = trace_output_to_source(
        "candidate", document_candidate_id, "", session_id
    );
    assert document_trace.success;
    assert document_trace.multimodal_provenance[0].source_type == "document";
    assert document_trace.multimodal_provenance[0].source_excerpt == (
        "Order: blood test; complete this week."
    );

    # 17–18: only the two prepared administrative gaps and both resolutions.
    gaps: BackendResponse = run_care_gap_check(session_id);
    assert gaps.success;
    assert len(gaps.care_gaps) == 2;
    assert sorted([gap.gap_type for gap in gaps.care_gaps]) == [
        "follow_up_date_missing",
        "lab_owner_missing"
    ];
    for gap in gaps.care_gaps {
        resolved: BackendResponse;
        if gap.gap_type == "lab_owner_missing" {
            resolved = resolve_gap(
                gap.id,
                "Assigned blood-test coordination",
                "clinic-lab-team",
                "this week",
                session_id
            );
        } else {
            resolved = resolve_gap(
                gap.id,
                "Scheduled follow-up appointment",
                "clinic-scheduling-team",
                "2026-08-09",
                session_id
            );
        }
        assert resolved.success;
    }
    assert len(run_care_gap_check(session_id).care_gaps) == 0;

    # 19–24: verified-only note, clinician edit/approval, voice and document traces.
    draft_response: BackendResponse = generate_clinician_note_draft(
        "encounter-maya-001", "", session_id
    );
    draft: ClinicianNoteDraftDTO = note_of(draft_response);
    assert len(draft.note_sections) == 9;
    assert all(section.source_fact_ids for section in draft.note_sections);
    lab_section_id: str = "";
    follow_section_id: str = "";
    for section in draft.note_sections {
        if section.section_type == "laboratory_orders" {
            lab_section_id = section.id;
        } elif section.section_type == "follow_up" {
            follow_section_id = section.id;
        }
    }
    edited_response: BackendResponse = update_note_section(
        draft.id,
        lab_section_id,
        "Blood test remains due this week.",
        "demo-clinician",
        session_id
    );
    edited: ClinicianNoteDraftDTO = note_of(edited_response);
    assert edited.status == "edited";
    approved_response: BackendResponse = approve_clinician_note(
        edited.id, "demo-clinician", session_id
    );
    approved: ClinicianNoteDraftDTO = note_of(approved_response);
    assert approved.status == "approved";
    voice_note_trace: BackendResponse = trace_output_to_source(
        "note_section", approved.id, follow_section_id, session_id
    );
    assert voice_note_trace.success;
    assert any(
        chain.source_type == "transcript"
        for chain in voice_note_trace.multimodal_provenance
    );
    document_note_trace: BackendResponse = trace_output_to_source(
        "note_section", approved.id, lab_section_id, session_id
    );
    assert document_note_trace.success;
    assert any(
        chain.source_type == "document"
        for chain in document_note_trace.multimodal_provenance
    );

    # 25–30: graph-derived timeline, bilingual briefs/scripts, grounded answer.
    timeline: BackendResponse = get_encounter_timeline(
        "encounter-maya-001", session_id
    );
    assert timeline.success;
    assert len(timeline.timeline) >= 10;
    english_plan: BackendResponse = generate_patient_plan(
        "English", session_id, "disabled"
    );
    spanish_plan: BackendResponse = generate_patient_plan(
        "Spanish", session_id, "disabled"
    );
    assert english_plan.success and spanish_plan.success;
    english_audio: BackendResponse = generate_patient_audio_script(
        "English", session_id
    );
    spanish_audio: BackendResponse = generate_patient_audio_script(
        "Spanish", session_id
    );
    assert english_audio.success and spanish_audio.success;
    assert "2026-08-09" in audio_of(english_audio).text;
    assert "2026-08-09" in audio_of(spanish_audio).text;
    answer: BackendResponse = ask_patient_question(
        "When is my blood test?", session_id, "disabled"
    );
    assert answer.success;
    assert answer_of(answer).grounded;
    assert answer_of(answer).source_fact_ids;

    # 31–34: contradiction is preserved and removed from later patient output.
    contradiction: BackendResponse = add_demo_contradiction(session_id);
    assert contradiction.success;
    audit: BackendResponse = run_evidence_audit(session_id);
    assert audit.success;
    assert any(
        conflict.conflict_type == "contradictory_follow_up_period"
        for conflict in audit.conflicts
    );
    graph: BackendResponse = get_care_graph(session_id);
    follow_values: list[str] = [
        fact.value
        for fact in graph_of(graph).verified_facts
        if fact.category == "follow_up"
    ];
    assert "return in two weeks" in follow_values;
    assert "return in four weeks" in follow_values;
    safe_plan: BackendResponse = generate_patient_plan(
        "English", session_id, "disabled"
    );
    assert safe_plan.success;
    assert "verified-candidate-follow-up" not in plan_of(safe_plan).source_fact_ids;
    assert "verified-candidate-follow-up-4-weeks" not in plan_of(
        safe_plan
    ).source_fact_ids;

    # 35–36: selected synthetic session returns to exact clean initial state.
    reset_again: BackendResponse = reset_demo(session_id);
    assert reset_again.success;
    reset_state: DemoStateDTO = state_of(reset_again);
    assert len(reset_state.candidate_facts) == 5;
    assert not reset_state.verified_facts;
    assert not reset_state.care_gaps;
    assert not reset_state.conflicts;
    assert not get_capture_session(capture.id, session_id).success;
    assert not get_document_extraction(artifact_of(document).id, session_id).success;
}

with entry {
    for mode in ["deterministic", "missing-key", "mock"] {
        for cycle in range(1, 4) {
            run_multimodal_cycle(mode, cycle);
            print(f"multimodal {mode} cycle {cycle} passed");
        }
    }
    print("9/9 complete multimodal acceptance cycles passed");
}
