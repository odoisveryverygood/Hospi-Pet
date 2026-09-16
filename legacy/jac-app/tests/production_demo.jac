"""Twenty-cycle production-shaped acceptance run across four AI modes."""

import from endpoints {
    load_demo_encounter,
    get_care_graph,
    verify_fact,
    run_care_gap_check,
    resolve_gap,
    generate_patient_plan,
    ask_patient_question,
    run_evidence_audit,
    reset_demo,
    add_demo_contradiction,
}
import from models {
    BackendResponse,
    CareGapDTO,
    CareGraphDTO,
    PatientAnswerDTO,
    PatientPlanDTO,
}
import from patient_agent { SAFE_FALLBACK }

def find_gap(gaps: list[CareGapDTO], kind: str) -> CareGapDTO {
    matching: list[CareGapDTO] = [
        gap
        for gap in gaps
        if gap.gap_type == kind
    ];
    assert len(matching) == 1;
    return matching[0];
}

def run_production_cycle(mode: str, cycle: int) {
    session_id: str = f"production-{mode}-{cycle}";
    steps: int = 0;

    reset: BackendResponse = reset_demo(session_id);
    steps += 1;
    assert reset.success;

    loaded: BackendResponse = load_demo_encounter(session_id, mode);
    steps += 1;
    assert loaded.success , loaded.message;
    steps += 1;
    assert len(loaded.candidate_facts) == 5;
    steps += 1;
    assert loaded.demo_state is not None;
    assert len(loaded.demo_state.transcript) == 5;
    steps += 1;
    assert [chunk.sequence for chunk in loaded.demo_state.transcript] == [
        1,
        2,
        3,
        4,
        5
    ];
    steps += 1;
    assert loaded.candidate_facts[0].source_chunk_id == "chunk-1";
    assert loaded.candidate_facts[0].source_text == (
        "We will order a blood test to be completed this week."
    );

    lab: BackendResponse = verify_fact(
        "candidate-lab", "accept", "production-clinician", session_id
    );
    steps += 1;
    assert lab.success;
    follow: BackendResponse = verify_fact(
        "candidate-follow-up", "accept", "production-clinician", session_id
    );
    steps += 1;
    assert follow.success;
    medication: BackendResponse = verify_fact(
        "candidate-medication", "accept", "production-clinician", session_id
    );
    steps += 1;
    assert medication.success;
    referral: BackendResponse = verify_fact(
        "candidate-referral", "accept", "production-clinician", session_id
    );
    steps += 1;
    assert referral.success;
    language: BackendResponse = verify_fact(
        "candidate-language", "reject", "production-clinician", session_id
    );
    steps += 1;
    assert language.success;

    graph_response: BackendResponse = get_care_graph(session_id);
    steps += 1;
    assert graph_response.success;
    assert graph_response.care_graph is not None;
    graph: CareGraphDTO = graph_response.care_graph as CareGraphDTO;
    steps += 1;
    assert len(graph.verified_facts) == 4;
    steps += 1;
    assert "verified-candidate-language" not in [
        fact.id for fact in graph.verified_facts
    ];

    gaps: BackendResponse = run_care_gap_check(session_id);
    steps += 1;
    assert gaps.success;
    steps += 1;
    assert len(gaps.care_gaps) == 2;
    lab_gap: CareGapDTO = find_gap(gaps.care_gaps, "lab_owner_missing");
    steps += 1;
    assert lab_gap.id.startswith("gap-lab-owner-");
    follow_gap: CareGapDTO = find_gap(gaps.care_gaps, "follow_up_date_missing");
    steps += 1;
    assert follow_gap.id.startswith("gap-follow-up-date-");
    repeated_gaps: BackendResponse = run_care_gap_check(session_id);
    steps += 1;
    assert repeated_gaps.current_graph_version == gaps.current_graph_version;

    lab_resolution: BackendResponse = resolve_gap(
        lab_gap.id,
        "Assigned laboratory coordination",
        "clinic-lab-team",
        "this week",
        session_id
    );
    steps += 1;
    assert lab_resolution.success;
    steps += 1;
    assert len(lab_resolution.care_gaps) == 1;
    follow_resolution: BackendResponse = resolve_gap(
        follow_gap.id,
        "Scheduled follow-up",
        "clinic-scheduling-team",
        "2026-08-09",
        session_id
    );
    steps += 1;
    assert follow_resolution.success;
    steps += 1;
    assert follow_resolution.care_gaps == [];

    plan_response: BackendResponse = generate_patient_plan("English", session_id, mode);
    steps += 1;
    assert plan_response.success;
    assert plan_response.patient_plan is not None;
    plan: PatientPlanDTO = plan_response.patient_plan as PatientPlanDTO;
    steps += 1;
    assert len(plan.source_fact_ids) == 4;
    steps += 1;
    assert all(
        item.id
        for item in (plan.labs + plan.follow_ups + plan.medications + plan.referrals)
    );

    answer_response: BackendResponse = ask_patient_question(
        "When is my blood test?", session_id, mode
    );
    steps += 1;
    assert answer_response.success;
    assert answer_response.patient_answer is not None;
    answer: PatientAnswerDTO = answer_response.patient_answer as PatientAnswerDTO;
    steps += 1;
    assert answer.grounded;
    steps += 1;
    assert answer.source_fact_ids == ["verified-candidate-lab"];

    unknown_response: BackendResponse = ask_patient_question(
        "What should I eat tomorrow?", session_id, mode
    );
    steps += 1;
    assert unknown_response.patient_answer is not None;
    unknown: PatientAnswerDTO = unknown_response.patient_answer as PatientAnswerDTO;
    steps += 1;
    assert unknown.answer == SAFE_FALLBACK;

    contradiction: BackendResponse = add_demo_contradiction(session_id);
    steps += 1;
    assert contradiction.success;
    audit: BackendResponse = run_evidence_audit(session_id);
    steps += 1;
    assert audit.success;
    steps += 1;
    assert len(
        [
            conflict
            for conflict in audit.conflicts
            if conflict.conflict_type == "contradictory_follow_up_period"
        ]
    ) == 1;
    conflicted_graph_response: BackendResponse = get_care_graph(session_id);
    assert conflicted_graph_response.care_graph is not None;
    conflicted_graph: CareGraphDTO = (
        conflicted_graph_response.care_graph as CareGraphDTO
    );
    steps += 1;
    assert sorted(
        [
            fact.value
            for fact in conflicted_graph.verified_facts
            if fact.category == "follow_up"
        ]
    ) == ["return in four weeks", "return in two weeks"];

    final_reset: BackendResponse = reset_demo(session_id);
    steps += 1;
    assert final_reset.success;
    assert final_reset.current_graph_version == 1;
    assert final_reset.demo_state is not None;
    assert len(final_reset.demo_state.candidate_facts) == 5;
    assert final_reset.demo_state.verified_facts == [];

    assert steps == 36 , f"{mode} cycle {cycle} completed {steps} steps";
    print(f"production acceptance passed: mode={mode}, cycle={cycle}, steps={steps}");
}

with entry {
    for mode in ["disabled", "test-no-key", "mock", "mock_malformed"] {
        for cycle in range(1, 6) {
            run_production_cycle(mode, cycle);
        }
    }
    print("Pa-Co production acceptance passed 20 full cycles (720 checked steps).");
}
