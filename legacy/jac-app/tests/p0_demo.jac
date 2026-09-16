"""Executable deterministic P0 acceptance flow."""

import from endpoints {
    reset_demo,
    verify_fact,
    get_care_graph,
    run_care_gap_check,
    resolve_gap,
    generate_patient_plan,
    ask_patient_question,
    add_demo_contradiction,
    run_evidence_audit,
}
import from models { BackendResponse, CareGapDTO, CareGraphDTO, VerifiedFactDTO, }

def find_gap_id(gaps: list[CareGapDTO], gap_type: str) -> str {
    for gap in gaps {
        if gap.gap_type == gap_type {
            return gap.id;
        }
    }
    return "";
}

def run_p0_cycle(session_id: str) -> bool {
    reset: BackendResponse = reset_demo(session_id);
    assert reset.success;
    assert reset.demo_state is not None;
    assert len(reset.demo_state.candidate_facts) == 5;
    assert len(reset.demo_state.verified_facts) == 0;

    for fact_id in [
        "candidate-lab",
        "candidate-follow-up",
        "candidate-medication",
        "candidate-referral"
    ] {
        verification: BackendResponse = verify_fact(
            fact_id, "accept", "clinician-1", session_id
        );
        assert verification.success , verification.message;
        assert verification.verified_fact is not None;
    }
    rejection: BackendResponse = verify_fact(
        "candidate-language", "reject", "clinician-1", session_id
    );
    assert rejection.success;
    assert rejection.verified_fact is None;

    graph: BackendResponse = get_care_graph(session_id);
    assert graph.success;
    assert graph.care_graph is not None;
    assert len(graph.care_graph.verified_facts) == 4;
    assert all(
        fact.id != "verified-candidate-language"
        for fact in graph.care_graph.verified_facts
    );

    gap_check: BackendResponse = run_care_gap_check(session_id);
    assert gap_check.success;
    assert len(gap_check.care_gaps) == 2;
    lab_gap_id: str = find_gap_id(gap_check.care_gaps, "lab_owner_missing");
    follow_up_gap_id: str = find_gap_id(gap_check.care_gaps, "follow_up_date_missing");
    assert lab_gap_id;
    assert follow_up_gap_id;

    lab_resolution: BackendResponse = resolve_gap(
        lab_gap_id,
        "Assigned blood-test coordination",
        "clinic-lab-team",
        "this week",
        session_id
    );
    assert lab_resolution.success;
    assert len(lab_resolution.care_gaps) == 1;

    follow_up_resolution: BackendResponse = resolve_gap(
        follow_up_gap_id,
        "Scheduled the follow-up appointment",
        "clinic-scheduling-team",
        "2026-08-09",
        session_id
    );
    assert follow_up_resolution.success;
    assert len(follow_up_resolution.care_gaps) == 0;

    plan_response: BackendResponse = generate_patient_plan("English", session_id);
    assert plan_response.success , plan_response.message;
    assert plan_response.patient_plan is not None;
    assert len(plan_response.patient_plan.source_fact_ids) == 4;
    assert all("[source: " in item for item in plan_response.patient_plan.checklist);

    answer_response: BackendResponse = ask_patient_question(
        "When is my blood test?", session_id
    );
    assert answer_response.success;
    assert answer_response.patient_answer is not None;
    assert answer_response.patient_answer.grounded;
    assert answer_response.patient_answer.source_fact_ids == ["verified-candidate-lab"];

    contradiction: BackendResponse = add_demo_contradiction(session_id);
    assert contradiction.success , contradiction.message;
    audit: BackendResponse = run_evidence_audit(session_id);
    assert audit.success;
    follow_up_conflicts = [
        conflict
        for conflict in audit.conflicts
        if conflict.conflict_type == "contradictory_follow_up_period"
    ];
    assert len(follow_up_conflicts) == 1;

    final_graph: BackendResponse = get_care_graph(session_id);
    assert final_graph.success;
    assert final_graph.care_graph is not None;
    final_care_graph: CareGraphDTO = final_graph.care_graph as CareGraphDTO;
    follow_up_facts: list[VerifiedFactDTO] = [
        fact
        for fact in final_care_graph.verified_facts
        if fact.category == "follow_up"
    ];
    assert len(follow_up_facts) == 2;
    assert sorted([fact.value for fact in follow_up_facts]) == [
        "return in four weeks",
        "return in two weeks"
    ];
    return True;
}

with entry:__main__ {
    for cycle in range(1, 4) {
        session_id: str = f"manual-p0-{cycle}";
        assert run_p0_cycle(session_id);
        print(f"P0 cycle {cycle} passed for {session_id}");
    }
    print("Pa-Co deterministic P0 acceptance flow passed three times.");
}
