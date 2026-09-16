"""Three-mode, nine-cycle live translation and intelligence acceptance demo."""

import os;
import base64;
import from endpoints {
    add_demo_contradiction,
    generate_patient_plan,
    reset_demo,
    resolve_gap,
    run_care_gap_check,
    run_evidence_audit,
    verify_fact,
}
import from multimodal_endpoints {
    _ingest_document_image_data_url,
    append_transcript_chunk,
    generate_clinician_note_draft,
    start_capture_session,
}
import from intelligence_endpoints {
    generate_clarifying_questions,
    generate_final_review_packet,
    generate_live_quick_summary,
    get_verified_encounter_analysis,
    run_verified_encounter_analysis,
    trace_analysis_item,
    translate_transcript_chunk,
}
import from models {
    AnalysisRunDTO,
    BackendResponse,
    CaptureSessionDTO,
    CareGapDTO,
    FinalReviewPacketDTO,
    LiveQuickSummaryDTO,
    TranscriptChunkDTO,
    TranslatedTranscriptChunkDTO,
    VerifiedEncounterSummaryDTO,
}

def synthetic_image_data_url -> str {
    path: str = os.path.join(
        os.path.dirname(__file__), "..", "demo_assets", "synthetic_lab_order.png"
    );
    with open(path, "rb") as source {
        return "data:image/png;base64," + base64.b64encode(source.read()).decode();
    }
}

def gap_by_type(gaps: list[CareGapDTO], gap_type: str) -> CareGapDTO | None {
    for gap in gaps {
        if gap.gap_type == gap_type {
            return gap;
        }
    }
    return None;
}

def run_intelligence_cycle(mode: str, cycle: int) {
    session_id: str = f"intelligence-{mode}-{cycle}";
    os.environ["PA_CO_INTELLIGENCE_MODE"] = mode;

    # 1. Reset the selected synthetic session.
    assert reset_demo(session_id).success;

    # 2–4. Load the bilingual consultation and append Spanish patient speech.
    started: BackendResponse = start_capture_session(
        "encounter-maya-001", "typed_text", session_id
    );
    capture: CaptureSessionDTO = started.capture_session as CaptureSessionDTO;
    patient_chunk_response: BackendResponse = append_transcript_chunk(
        capture.id,
        1,
        "Patient",
        "Me he sentido mareada durante tres días.",
        "2026-07-26T18:10:01Z",
        "2026-07-26T18:10:02Z",
        1.0,
        session_id
    );
    patient_chunk: TranscriptChunkDTO = (
        patient_chunk_response.transcript_chunk as TranscriptChunkDTO
    );

    # 5. Display a safe English translation paired with the original.
    patient_translation: BackendResponse = translate_transcript_chunk(
        patient_chunk.id, "English", session_id
    );
    assert patient_translation.success;
    assert (
        patient_translation.translated_chunk as TranslatedTranscriptChunkDTO
    ).translated_text == "I have felt dizzy for three days.";

    # 6–7. Append English clinician speech and display Spanish translation.
    clinician_chunk_response: BackendResponse = append_transcript_chunk(
        capture.id,
        2,
        "Doctor",
        "We will order a blood test to be completed this week.",
        "2026-07-26T18:10:03Z",
        "2026-07-26T18:10:04Z",
        1.0,
        session_id
    );
    clinician_chunk: TranscriptChunkDTO = (
        clinician_chunk_response.transcript_chunk as TranscriptChunkDTO
    );
    clinician_translation: BackendResponse = translate_transcript_chunk(
        clinician_chunk.id, "Spanish", session_id
    );
    assert clinician_translation.success;
    assert (
        clinician_translation.translated_chunk as TranslatedTranscriptChunkDTO
    ).translated_text == (
        "Pediremos un análisis de sangre para completar esta semana."
    );

    # 8–9. Generate a source-grounded summary and prove it is unverified.
    quick: BackendResponse = generate_live_quick_summary(
        "encounter-maya-001", session_id
    );
    assert quick.success;
    assert (quick.live_quick_summary as LiveQuickSummaryDTO).unverified;

    # 10–12. Use existing deterministic proposals, accept four, reject one.
    for fact_id in [
        "candidate-lab",
        "candidate-follow-up",
        "candidate-medication",
        "candidate-referral"
    ] {
        assert verify_fact(fact_id, "accept", "demo-clinician", session_id).success;
    }
    assert verify_fact(
        "candidate-language", "reject", "demo-clinician", session_id
    ).success;

    # Add one accepted synthetic document fact for document provenance.
    document_mode: str = (
        "mock"
            if mode == "mock"
            else ("mock_malformed" if mode == "mock_malformed" else "deterministic")
    );
    document: BackendResponse = _ingest_document_image_data_url(
        "encounter-maya-001",
        "lab_document",
        f"synthetic_intelligence_{mode}_{cycle}.png",
        "image/png",
        synthetic_image_data_url(),
        True,
        session_id,
        document_mode
    );
    assert document.success;
    document_candidate_id: str = document.multimodal_candidates[0].id;
    assert verify_fact(
        document_candidate_id, "accept", "demo-clinician", session_id
    ).success;

    # 13–16. Analyze accepted facts only and return the two prepared gaps.
    gaps_response: BackendResponse = run_care_gap_check(session_id);
    assert gaps_response.success and len(gaps_response.care_gaps) == 2;
    analysis: BackendResponse = run_verified_encounter_analysis(
        "encounter-maya-001", session_id
    );
    assert analysis.success;
    run: AnalysisRunDTO = analysis.analysis_run as AnalysisRunDTO;
    summary: VerifiedEncounterSummaryDTO = (
        analysis.verified_encounter_summary as VerifiedEncounterSummaryDTO
    );
    assert "candidate-language" in run.rejected_fact_ids_excluded;
    assert summary.verified_only;
    assert len(analysis.care_gaps) == 2;

    # 17–18. Generate only evidence/gap-bound clinician questions.
    questions: BackendResponse = generate_clarifying_questions(
        "encounter-maya-001", run.id, session_id
    );
    assert questions.success and len(questions.suggested_questions) == 2;
    assert all(
        question.source_fact_ids and question.related_gap_ids
        for question in questions.suggested_questions
    );

    # 19–20. Resolve one gap and prove the old analysis is stale.
    lab_gap: CareGapDTO = gap_by_type(
        gaps_response.care_gaps, "lab_owner_missing"
    ) as CareGapDTO;
    follow_gap: CareGapDTO = gap_by_type(
        gaps_response.care_gaps, "follow_up_date_missing"
    ) as CareGapDTO;
    assert resolve_gap(
        lab_gap.id,
        "Assigned blood-test coordination",
        "clinic-lab-team",
        "this week",
        session_id
    ).success;
    stale: BackendResponse = get_verified_encounter_analysis(run.id, session_id);
    assert stale.success and (stale.analysis_run as AnalysisRunDTO).stale;
    assert stale.message == ("New verified information is available. Re-run analysis.");

    # 21–22. Resolve the second gap, re-run, and confirm updated output.
    assert resolve_gap(
        follow_gap.id,
        "Scheduled follow-up appointment",
        "clinic-scheduling-team",
        "2026-08-09",
        session_id
    ).success;
    updated: BackendResponse = run_verified_encounter_analysis(
        "encounter-maya-001", session_id
    );
    assert updated.success and not updated.care_gaps;

    # 23–25. Generate review note and both approved patient plans.
    assert generate_clinician_note_draft("encounter-maya-001", "", session_id).success;
    assert generate_patient_plan("English", session_id, "disabled").success;
    assert generate_patient_plan("Spanish", session_id, "disabled").success;

    # Re-run after derived graph artifacts so the packet is current.
    current: BackendResponse = run_verified_encounter_analysis(
        "encounter-maya-001", session_id
    );
    assert current.success;
    current_run: AnalysisRunDTO = current.analysis_run as AnalysisRunDTO;
    current_summary: VerifiedEncounterSummaryDTO = (
        current.verified_encounter_summary as VerifiedEncounterSummaryDTO
    );

    # 26. Generate a packet with separate verified/review/unverified sections.
    packet_response: BackendResponse = generate_final_review_packet(
        "encounter-maya-001", session_id
    );
    assert packet_response.success , packet_response.message;
    packet: FinalReviewPacketDTO = (
        packet_response.final_review_packet as FinalReviewPacketDTO
    );
    assert packet.verified_items;
    assert (
        "AI conversation draft — not yet clinician verified." in packet.unverified_items
    );

    # 27–28. One trace reaches transcript evidence and one document evidence.
    trace: BackendResponse = trace_analysis_item(
        current_run.id, current_summary.id, session_id
    );
    assert trace.success;
    assert any(item.source_type == "transcript" for item in trace.analysis_provenance);
    assert any(item.source_type == "document" for item in trace.analysis_provenance);

    # 29–32. Add contradiction, re-run, and never select a correct instruction.
    assert add_demo_contradiction(session_id).success;
    audit: BackendResponse = run_evidence_audit(session_id);
    assert audit.success;
    assert any(
        conflict.conflict_type == "contradictory_follow_up_period"
        for conflict in audit.conflicts
    );
    conflicted: BackendResponse = run_verified_encounter_analysis(
        "encounter-maya-001", session_id
    );
    assert conflicted.success;
    conflict_summary: VerifiedEncounterSummaryDTO = (
        conflicted.verified_encounter_summary as VerifiedEncounterSummaryDTO
    );
    assert conflict_summary.contradictions;
    assert not conflict_summary.follow_ups;
    conflict_questions: BackendResponse = generate_clarifying_questions(
        "encounter-maya-001", (conflicted.analysis_run as AnalysisRunDTO).id, session_id
    );
    assert any(
        question.purpose == "resolve_contradiction"
        for question in conflict_questions.suggested_questions
    );

    # 33–34. Reset and prove the exact clean synthetic starting state.
    reset_again: BackendResponse = reset_demo(session_id);
    assert reset_again.success;
    assert reset_again.demo_state is not None;
    assert len(reset_again.demo_state.candidate_facts) == 5;
    assert not reset_again.demo_state.verified_facts;
    assert not reset_again.demo_state.care_gaps;
    print(f"intelligence {mode} cycle {cycle} passed");
}

with entry:__main__ {
    for mode in ["disabled", "mock", "mock_malformed"] {
        for cycle in range(1, 4) {
            run_intelligence_cycle(mode, cycle);
        }
    }
    print("9/9 complete intelligence acceptance cycles passed");
}
