"""Full backend demo flow across optional AI operating modes."""

import from endpoints {
    add_demo_contradiction,
    ask_patient_question,
    generate_patient_plan,
    get_care_graph,
    load_demo_encounter,
    reset_demo,
    resolve_gap,
    run_care_gap_check,
    run_evidence_audit,
    verify_fact,
}
import from models { BackendResponse, CareGapDTO, CareGraphDTO, DemoStateDTO, }

def gap_by_type(gaps: list[CareGapDTO], gap_type: str) -> CareGapDTO | None {
    for gap in gaps {
        if gap.gap_type == gap_type {
            return gap;
        }
    }
    return None;
}

def run_mode(session_id: str, ai_mode: str) {
    if ai_mode == "disabled" {
        assert reset_demo(session_id).success;
    }
    loaded: BackendResponse = load_demo_encounter(session_id, ai_mode);
    assert loaded.success , loaded.message;
    assert len(loaded.candidate_facts) == 5;
    print(f"{session_id} load AI status: {loaded.ai_status}");
    if ai_mode == "mock" {
        assert loaded.ai_status is not None;
        assert loaded.ai_status.used;
        assert not loaded.ai_status.fallback_used;
    } elif ai_mode == "live" {
        assert loaded.ai_status is not None;
        assert loaded.ai_status.fallback_used;
        assert loaded.ai_status.diagnostic_code == "AI_CREDENTIALS_MISSING";
    }

    for fact_id in [
        "candidate-lab",
        "candidate-follow-up",
        "candidate-medication",
        "candidate-referral"
    ] {
        accepted: BackendResponse = verify_fact(
            fact_id, "accept", "mode-test-clinician", session_id
        );
        assert accepted.success , accepted.message;
    }
    rejected: BackendResponse = verify_fact(
        "candidate-language", "reject", "mode-test-clinician", session_id
    );
    assert rejected.success;

    graph_before_gaps: BackendResponse = get_care_graph(session_id);
    assert graph_before_gaps.care_graph is not None;
    assert len((graph_before_gaps.care_graph as CareGraphDTO).verified_facts) == 4;

    gap_response: BackendResponse = run_care_gap_check(session_id);
    assert gap_response.success;
    assert len(gap_response.care_gaps) == 2;
    lab_gap: CareGapDTO | None = gap_by_type(
        gap_response.care_gaps, "lab_owner_missing"
    );
    follow_gap: CareGapDTO | None = gap_by_type(
        gap_response.care_gaps, "follow_up_date_missing"
    );
    assert lab_gap is not None;
    assert follow_gap is not None;
    assert resolve_gap(
        (lab_gap as CareGapDTO).id,
        "Assigned blood-test coordination",
        "clinic-lab-team",
        "this week",
        session_id
    ).success;
    assert resolve_gap(
        (follow_gap as CareGapDTO).id,
        "Scheduled the follow-up appointment",
        "clinic-scheduling-team",
        "2026-08-09",
        session_id
    ).success;

    plan: BackendResponse = generate_patient_plan(
        "English" if ai_mode == "disabled" else "Spanish", session_id, ai_mode
    );
    assert plan.success , plan.message;
    assert plan.patient_plan is not None;
    assert len(plan.patient_plan.source_fact_ids) == 4;

    answer: BackendResponse = ask_patient_question(
        "When is my blood test?", session_id, ai_mode
    );
    assert answer.success , answer.message;
    assert answer.patient_answer is not None;
    assert answer.patient_answer.grounded;
    assert answer.patient_answer.source_fact_ids == ["verified-candidate-lab"];

    assert add_demo_contradiction(session_id).success;
    audit: BackendResponse = run_evidence_audit(session_id);
    assert audit.success;
    assert any(
        conflict.conflict_type == "contradictory_follow_up_period"
        for conflict in audit.conflicts
    );
    final_graph: BackendResponse = get_care_graph(session_id);
    assert final_graph.care_graph is not None;
    follow_up_values: list[str] = [
        fact.value
        for fact in (final_graph.care_graph as CareGraphDTO).verified_facts
        if fact.category == "follow_up"
    ];
    assert sorted(follow_up_values) == ["return in four weeks", "return in two weeks"];

    reset: BackendResponse = reset_demo(session_id);
    assert reset.success;
    assert reset.demo_state is not None;
    reset_state: DemoStateDTO = reset.demo_state as DemoStateDTO;
    assert len(reset_state.candidate_facts) == 5;
    assert reset_state.verified_facts == [];
    assert reset_state.conflicts == [];
    print(f"{session_id}: {ai_mode} full flow passed");
}

with entry:__main__ {
    run_mode("mode-ai-enabled", "mock");
    run_mode("mode-ai-disabled", "disabled");
    run_mode("mode-invalid-credentials", "live");
    run_mode("mode-mock-output", "mock");
    print("All four optional-AI backend modes preserved the complete demo.");
}
