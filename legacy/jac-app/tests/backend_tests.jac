"""Backend invariant and P0 contract tests."""

import from endpoints {
    load_demo_encounter,
    get_candidate_facts,
    verify_fact,
    get_care_graph,
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
    CandidateFactDTO,
    CareGapDTO,
    CareGraphDTO,
    ConflictDTO,
    DemoStateDTO,
    PatientAnswerDTO,
    PatientPlanDTO,
    VerifiedFactDTO,
}
import from patient_agent { SAFE_FALLBACK }

def care_graph_of(response: BackendResponse) -> CareGraphDTO {
    assert response.success , response.message;
    assert response.care_graph is not None;
    return response.care_graph as CareGraphDTO;
}

def demo_state_of(response: BackendResponse) -> DemoStateDTO {
    assert response.success , response.message;
    assert response.demo_state is not None;
    return response.demo_state as DemoStateDTO;
}

def candidate_by_id(
    candidates: list[CandidateFactDTO], fact_id: str
) -> CandidateFactDTO | None {
    for candidate in candidates {
        if candidate.id == fact_id {
            return candidate;
        }
    }
    return None;
}

def gap_by_type(gaps: list[CareGapDTO], gap_type: str) -> CareGapDTO | None {
    for gap in gaps {
        if gap.gap_type == gap_type {
            return gap;
        }
    }
    return None;
}

def accept_core_facts(session_id: str) {
    for fact_id in [
        "candidate-lab",
        "candidate-follow-up",
        "candidate-medication",
        "candidate-referral"
    ] {
        response: BackendResponse = verify_fact(
            fact_id, "accept", "test-clinician", session_id
        );
        assert response.success , response.message;
    }
}

def prepare_verified_demo(session_id: str) {
    reset: BackendResponse = reset_demo(session_id);
    assert reset.success;
    accept_core_facts(session_id);
    rejected: BackendResponse = verify_fact(
        "candidate-language", "reject", "test-clinician", session_id
    );
    assert rejected.success;
}

def prepare_resolved_demo(session_id: str) {
    prepare_verified_demo(session_id);
    gaps: BackendResponse = run_care_gap_check(session_id);
    assert gaps.success;
    lab_gap: CareGapDTO | None = gap_by_type(gaps.care_gaps, "lab_owner_missing");
    follow_gap: CareGapDTO | None = gap_by_type(
        gaps.care_gaps, "follow_up_date_missing"
    );
    assert lab_gap is not None;
    assert follow_gap is not None;
    lab_result: BackendResponse = resolve_gap(
        (lab_gap as CareGapDTO).id,
        "Assigned blood-test coordination",
        "clinic-lab-team",
        "this week",
        session_id
    );
    assert lab_result.success;
    follow_result: BackendResponse = resolve_gap(
        (follow_gap as CareGapDTO).id,
        "Scheduled the follow-up appointment",
        "clinic-scheduling-team",
        "2026-08-09",
        session_id
    );
    assert follow_result.success;
}

test "1 demo consultation loads" {
    state: DemoStateDTO = demo_state_of(reset_demo("test-load"));
    assert state.patient is not None;
    assert state.patient.display_name == "Maya Rivera";
    assert state.patient.preferred_language == "Spanish";
    assert state.patient.synthetic;
    assert len(state.transcript) == 5;
    assert len(state.candidate_facts) == 5;
}

test "2 transcript chunks are ordered" {
    state: DemoStateDTO = demo_state_of(reset_demo("test-order"));
    assert [chunk.sequence for chunk in state.transcript] == [1, 2, 3, 4, 5];
    assert state.transcript[0].speaker == "Doctor";
    assert state.transcript[4].speaker == "Patient";
}

test "3 candidates retain exact provenance" {
    state: DemoStateDTO = demo_state_of(reset_demo("test-provenance"));
    lab: CandidateFactDTO | None = candidate_by_id(
        state.candidate_facts, "candidate-lab"
    );
    assert lab is not None;
    assert (lab as CandidateFactDTO).source_chunk_id == "chunk-1";
    assert (
        (lab as CandidateFactDTO).source_text == "We will order a blood test to be completed this week."
    );
}

test "4 accepting creates one verified record" {
    reset_demo("test-accept");
    accepted: BackendResponse = verify_fact(
        "candidate-lab", "accept", "test-clinician", "test-accept"
    );
    assert accepted.success;
    assert accepted.verified_fact is not None;
    graph: CareGraphDTO = care_graph_of(get_care_graph("test-accept"));
    assert len(graph.verified_facts) == 1;
    assert graph.verified_facts[0].id == "verified-candidate-lab";
}

test "5 repeated acceptance is idempotent" {
    reset_demo("test-idempotent-accept");
    first: BackendResponse = verify_fact(
        "candidate-lab", "accept", "test-clinician", "test-idempotent-accept"
    );
    second: BackendResponse = verify_fact(
        "candidate-lab", "accept", "test-clinician", "test-idempotent-accept"
    );
    assert first.success;
    assert second.success;
    assert second.current_graph_version == first.current_graph_version;
    graph: CareGraphDTO = care_graph_of(get_care_graph("test-idempotent-accept"));
    assert len(graph.verified_facts) == 1;
}

test "6 rejected candidate creates no verified record" {
    reset_demo("test-reject");
    rejected: BackendResponse = verify_fact(
        "candidate-language", "reject", "test-clinician", "test-reject"
    );
    assert rejected.success;
    assert rejected.verified_fact is None;
    graph: CareGraphDTO = care_graph_of(get_care_graph("test-reject"));
    assert len(graph.verified_facts) == 0;
}

test "7 rejected candidate never reaches patient brief" {
    prepare_resolved_demo("test-rejected-plan");
    plan_response: BackendResponse = generate_patient_plan(
        "English", "test-rejected-plan"
    );
    assert plan_response.success;
    assert plan_response.patient_plan is not None;
    plan: PatientPlanDTO = plan_response.patient_plan as PatientPlanDTO;
    assert "verified-candidate-language" not in plan.source_fact_ids;
    assert len(plan.source_fact_ids) == 4;
}

test "8 care gap check detects exactly prepared gaps" {
    prepare_verified_demo("test-gaps");
    result: BackendResponse = run_care_gap_check("test-gaps");
    assert result.success;
    assert len(result.care_gaps) == 2;
    assert sorted([gap.gap_type for gap in result.care_gaps]) == [
        "follow_up_date_missing",
        "lab_owner_missing"
    ];
}

test "9 repeated gap check does not duplicate gaps" {
    prepare_verified_demo("test-gap-idempotency");
    first: BackendResponse = run_care_gap_check("test-gap-idempotency");
    second: BackendResponse = run_care_gap_check("test-gap-idempotency");
    assert first.success;
    assert second.success;
    assert len(first.care_gaps) == 2;
    assert len(second.care_gaps) == 2;
    assert second.current_graph_version == first.current_graph_version;
    assert sorted([gap.id for gap in first.care_gaps]) == sorted(
        [gap.id for gap in second.care_gaps]
    );
}

test "10 resolving lab owner removes active lab gap" {
    prepare_verified_demo("test-lab-resolution");
    gaps: BackendResponse = run_care_gap_check("test-lab-resolution");
    lab_gap: CareGapDTO | None = gap_by_type(gaps.care_gaps, "lab_owner_missing");
    assert lab_gap is not None;
    resolved: BackendResponse = resolve_gap(
        (lab_gap as CareGapDTO).id,
        "Assigned blood-test coordination",
        "clinic-lab-team",
        "this week",
        "test-lab-resolution"
    );
    assert resolved.success;
    assert gap_by_type(resolved.care_gaps, "lab_owner_missing") is None;
    assert len(resolved.care_gaps) == 1;
}

test "11 resolving follow-up date updates patient plan" {
    prepare_resolved_demo("test-follow-plan");
    result: BackendResponse = generate_patient_plan("English", "test-follow-plan");
    assert result.success;
    assert result.patient_plan is not None;
    plan: PatientPlanDTO = result.patient_plan as PatientPlanDTO;
    assert len(plan.follow_ups) == 1;
    assert plan.follow_ups[0].due_date == "2026-08-09";
    assert "2026-08-09" in plan.follow_ups[0].text;
}

test "12 patient plan uses only verified facts" {
    prepare_resolved_demo("test-approved-only");
    result: BackendResponse = generate_patient_plan("English", "test-approved-only");
    assert result.patient_plan is not None;
    plan: PatientPlanDTO = result.patient_plan as PatientPlanDTO;
    graph: CareGraphDTO = care_graph_of(get_care_graph("test-approved-only"));
    verified_ids: list[str] = [fact.id for fact in graph.verified_facts];
    assert all(source_id in verified_ids for source_id in plan.source_fact_ids);
    assert all("[source: " in text for text in plan.checklist);
}

test "13 patient question returns source fact ids" {
    prepare_resolved_demo("test-grounded-question");
    response: BackendResponse = ask_patient_question(
        "When is my blood test?", "test-grounded-question"
    );
    assert response.success;
    assert response.patient_answer is not None;
    answer: PatientAnswerDTO = response.patient_answer as PatientAnswerDTO;
    assert answer.grounded;
    assert answer.source_fact_ids == ["verified-candidate-lab"];
    assert not answer.fallback_used;
}

test "14 unknown question uses exact safe fallback" {
    prepare_resolved_demo("test-fallback");
    response: BackendResponse = ask_patient_question(
        "What should I eat tomorrow?", "test-fallback"
    );
    assert response.success;
    assert response.patient_answer is not None;
    answer: PatientAnswerDTO = response.patient_answer as PatientAnswerDTO;
    assert answer.answer == SAFE_FALLBACK;
    assert not answer.grounded;
    assert answer.source_fact_ids == [];
    assert answer.fallback_used;
}

test "15 two-week four-week conflict is detected" {
    prepare_resolved_demo("test-conflict");
    contradiction: BackendResponse = add_demo_contradiction("test-conflict");
    assert contradiction.success;
    audit: BackendResponse = run_evidence_audit("test-conflict");
    assert audit.success;
    conflicts: list[ConflictDTO] = [
        conflict
        for conflict in audit.conflicts
        if conflict.conflict_type == "contradictory_follow_up_period"
    ];
    assert len(conflicts) == 1;
}

test "16 conflict does not overwrite either source" {
    prepare_resolved_demo("test-no-overwrite");
    add_demo_contradiction("test-no-overwrite");
    run_evidence_audit("test-no-overwrite");
    graph: CareGraphDTO = care_graph_of(get_care_graph("test-no-overwrite"));
    follow_ups: list[VerifiedFactDTO] = [
        fact
        for fact in graph.verified_facts
        if fact.category == "follow_up"
    ];
    assert len(follow_ups) == 2;
    assert sorted([fact.value for fact in follow_ups]) == [
        "return in four weeks",
        "return in two weeks"
    ];
    assert sorted([fact.source_chunk_id for fact in follow_ups]) == [
        "chunk-2",
        "chunk-6"
    ];
}

test "17 reset restores exact initial demo state" {
    prepare_resolved_demo("test-reset-exact");
    generate_patient_plan("English", "test-reset-exact");
    add_demo_contradiction("test-reset-exact");
    run_evidence_audit("test-reset-exact");
    state: DemoStateDTO = demo_state_of(reset_demo("test-reset-exact"));
    assert state.graph_version == 1;
    assert len(state.transcript) == 5;
    assert [chunk.id for chunk in state.transcript] == [
        "chunk-1",
        "chunk-2",
        "chunk-3",
        "chunk-4",
        "chunk-5"
    ];
    assert len(state.candidate_facts) == 5;
    assert all(candidate.status == "pending" for candidate in state.candidate_facts);
    assert state.verified_facts == [];
    assert state.care_gaps == [];
    assert state.conflicts == [];
    assert state.patient_plan is None;
}

test "18 synthetic sessions do not leak" {
    reset_demo("session-a");
    reset_demo("session-b");
    accepted: BackendResponse = verify_fact(
        "candidate-lab", "accept", "test-clinician", "session-a"
    );
    assert accepted.success;
    graph_a: CareGraphDTO = care_graph_of(get_care_graph("session-a"));
    graph_b: CareGraphDTO = care_graph_of(get_care_graph("session-b"));
    assert len(graph_a.verified_facts) == 1;
    assert len(graph_b.verified_facts) == 0;
    lab_b: CandidateFactDTO | None = candidate_by_id(
        graph_b.candidate_facts, "candidate-lab"
    );
    assert lab_b is not None;
    assert (lab_b as CandidateFactDTO).status == "pending";
}

test "19 actions return contract compliant objects" {
    load: BackendResponse = load_demo_encounter("test-contract");
    assert isinstance(load, BackendResponse);
    candidates: BackendResponse = get_candidate_facts("test-contract");
    assert candidates.success;
    assert len(candidates.candidate_facts) == 5;
    assert isinstance(candidates.candidate_facts[0], CandidateFactDTO);
    accepted: BackendResponse = verify_fact(
        "candidate-lab", "accept", "test-clinician", "test-contract"
    );
    assert isinstance(accepted.verified_fact, VerifiedFactDTO);
    graph: BackendResponse = get_care_graph("test-contract");
    assert isinstance(graph.care_graph, CareGraphDTO);
}

test "20 deterministic demo requires no model api key" {
    state: DemoStateDTO = demo_state_of(reset_demo("test-no-api-key"));
    assert len(state.candidate_facts) == 5;
    assert all(candidate.confidence == 1.0 for candidate in state.candidate_facts);
    assert state.graph_version == 1;
}
