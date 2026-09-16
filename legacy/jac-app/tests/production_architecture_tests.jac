"""Canonical topology, provenance, trace, and session-boundary tests."""

import os;
import from endpoints {
    get_care_graph,
    verify_fact,
    run_care_gap_check,
    resolve_gap,
    generate_patient_plan,
    ask_patient_question,
    run_evidence_audit,
    trace_provenance,
    reset_demo,
    add_demo_contradiction,
}
import from models {
    BackendResponse,
    CareGapDTO,
    CareGraphDTO,
    DemoSession,
    Patient,
    Encounter,
    CandidateFact,
    VerifiedFact,
    VerificationEvent,
    LabOrder,
    CareTask,
    CareGap,
    GapResolutionEvent,
    PatientBrief,
    ChecklistItem,
    PatientQuestion,
    PatientAnswer,
    Conflict,
    HasSession,
    HasPatient,
    HasEncounter,
    HasCandidate,
    PromotedTo,
    HasVerificationEvent,
    RejectedFrom,
    HasVerifiedFact,
    RepresentsLabOrder,
    HasTask,
    DependsOn,
    HasGap,
    GapForFact,
    ResolvedBy,
    ResolutionUpdates,
    HasBrief,
    HasChecklistItem,
    SupportedBy,
    HasQuestion,
    HasAnswer,
    AnsweredFrom,
    HasConflict,
    ConflictEvidence,
}

def selected_session(session_id: str) -> DemoSession {
    sessions: list[DemoSession] = [root->:HasSession:->[?:DemoSession, id==session_id]];
    assert len(sessions) == 1;
    return sessions[0];
}

def selected_encounter(session_id: str) -> Encounter {
    session: DemoSession = selected_session(session_id);
    patients: list[Patient] = [session->:HasPatient:->];
    assert len(patients) == 1;
    encounters: list[Encounter] = [patients[0]->:HasEncounter:->];
    assert len(encounters) == 1;
    return encounters[0];
}

def accept_core(session_id: str) {
    for candidate_id in [
        "candidate-lab",
        "candidate-follow-up",
        "candidate-medication",
        "candidate-referral"
    ] {
        result: BackendResponse = verify_fact(
            candidate_id, "accept", "architecture-clinician", session_id
        );
        assert result.success , result.message;
    }
}

def find_gap(gaps: list[CareGapDTO], kind: str) -> CareGapDTO {
    matching: list[CareGapDTO] = [
        gap
        for gap in gaps
        if gap.gap_type == kind
    ];
    assert len(matching) == 1;
    return matching[0];
}

def prepare_resolved(session_id: str) {
    assert reset_demo(session_id).success;
    accept_core(session_id);
    assert verify_fact(
        "candidate-language", "reject", "architecture-clinician", session_id
    ).success;
    gap_response: BackendResponse = run_care_gap_check(session_id);
    lab_gap: CareGapDTO = find_gap(gap_response.care_gaps, "lab_owner_missing");
    follow_gap: CareGapDTO = find_gap(gap_response.care_gaps, "follow_up_date_missing");
    assert resolve_gap(
        lab_gap.id,
        "Assigned laboratory coordination",
        "clinic-lab-team",
        "this week",
        session_id
    ).success;
    assert resolve_gap(
        follow_gap.id,
        "Scheduled follow-up",
        "clinic-scheduling-team",
        "2026-08-09",
        session_id
    ).success;
}

test "canonical root patient encounter candidate path" {
    session_id = "architecture-topology";
    assert reset_demo(session_id).success;
    session: DemoSession = selected_session(session_id);
    patient: Patient = [session->:HasPatient:->][0];
    encounter: Encounter = [patient->:HasEncounter:->][0];
    candidates: list[CandidateFact] = [encounter->:HasCandidate:->];
    assert len(candidates) == 5;
    assert all(candidate.session_id == session_id for candidate in candidates);
}

test "acceptance creates decision promotion obligation and task paths" {
    session_id = "architecture-acceptance";
    assert reset_demo(session_id).success;
    result: BackendResponse = verify_fact(
        "candidate-lab", "accept", "architecture-clinician", session_id
    );
    assert result.success;
    encounter: Encounter = selected_encounter(session_id);
    candidates: list[CandidateFact] = [encounter->:HasCandidate:->[?:CandidateFact, id=="candidate-lab"]];
    assert len(candidates) == 1;
    promoted: list[VerifiedFact] = [candidates[0]->:PromotedTo:->];
    events: list[VerificationEvent] = [candidates[0]->:HasVerificationEvent:->];
    assert len(promoted) == 1;
    assert len(events) == 1;
    assert events[0].decision == "accept";
    assert promoted[0] in [encounter->:HasVerifiedFact:->];
    labs: list[LabOrder] = [promoted[0]->:RepresentsLabOrder:->];
    assert len(labs) == 1;
    tasks: list[CareTask] = [encounter->:HasTask:->];
    assert len(tasks) == 1;
    assert promoted[0] in [tasks[0]->:DependsOn:->];
}

test "rejection records event and has no promoted path" {
    session_id = "architecture-rejection";
    assert reset_demo(session_id).success;
    result: BackendResponse = verify_fact(
        "candidate-language", "reject", "architecture-clinician", session_id
    );
    assert result.success;
    encounter: Encounter = selected_encounter(session_id);
    candidates: list[CandidateFact] = [encounter->:HasCandidate:->[?:CandidateFact, id=="candidate-language"]];
    assert len(candidates) == 1;
    assert len([candidates[0]->:PromotedTo:->]) == 0;
    events: list[VerificationEvent] = [candidates[0]->:HasVerificationEvent:->];
    assert len(events) == 1;
    assert candidates[0] in [events[0]->:RejectedFrom:->];
}

test "care gaps and append only resolution are graph relationships" {
    session_id = "architecture-resolution";
    assert reset_demo(session_id).success;
    accept_core(session_id);
    result: BackendResponse = run_care_gap_check(session_id);
    lab_gap_dto: CareGapDTO = find_gap(result.care_gaps, "lab_owner_missing");
    encounter: Encounter = selected_encounter(session_id);
    gaps: list[CareGap] = [encounter->:HasGap:->[?:CareGap, id==lab_gap_dto.id]];
    assert len(gaps) == 1;
    assert len([gaps[0]->:GapForFact:->]) == 1;
    resolved: BackendResponse = resolve_gap(
        lab_gap_dto.id,
        "Assigned laboratory coordination",
        "clinic-lab-team",
        "this week",
        session_id
    );
    assert resolved.success;
    events: list[GapResolutionEvent] = [gaps[0]->:ResolvedBy:->];
    assert len(events) == 1;
    assert len([events[0]->:ResolutionUpdates:->]) == 1;
}

test "brief checklist items have traversable verified support" {
    session_id = "architecture-checklist";
    prepare_resolved(session_id);
    result: BackendResponse = generate_patient_plan("English", session_id);
    assert result.success;
    assert result.patient_plan is not None;
    session: DemoSession = selected_session(session_id);
    patient: Patient = [session->:HasPatient:->][0];
    briefs: list[PatientBrief] = [
        brief
        for brief in [patient->:HasBrief:->]
        if brief.current
    ];
    assert len(briefs) == 1;
    items: list[ChecklistItem] = [briefs[0]->:HasChecklistItem:->];
    assert len(items) == 4;
    assert all(item.current for item in items);
    assert all(len([item->:SupportedBy:->]) == 1 for item in items);
    assert all(
        plan_item.id
        for plan_item in (
            result.patient_plan.labs + result.patient_plan.follow_ups + result.patient_plan.medications + result.patient_plan.referrals
        )
    );
}

test "question and answer are separate nodes with approved evidence" {
    session_id = "architecture-answer";
    prepare_resolved(session_id);
    response: BackendResponse = ask_patient_question(
        "When is my blood test?", session_id
    );
    assert response.success;
    assert response.patient_answer is not None;
    assert response.patient_answer.id.startswith("answer-");
    session: DemoSession = selected_session(session_id);
    patient: Patient = [session->:HasPatient:->][0];
    questions: list[PatientQuestion] = [patient->:HasQuestion:->];
    assert len(questions) == 1;
    answers: list[PatientAnswer] = [questions[0]->:HasAnswer:->];
    assert len(answers) == 1;
    assert len([answers[0]->:AnsweredFrom:->]) == 1;
}

test "checklist provenance reaches immutable source evidence" {
    session_id = "architecture-plan-provenance";
    prepare_resolved(session_id);
    plan: BackendResponse = generate_patient_plan("English", session_id);
    assert plan.patient_plan is not None;
    output_id: str = plan.patient_plan.labs[0].id;
    traced: BackendResponse = trace_provenance(output_id, session_id);
    assert traced.success , traced.message;
    assert len(traced.provenance_chains) == 1;
    chain = traced.provenance_chains[0];
    assert chain.complete;
    assert chain.source_fact_id == "verified-candidate-lab";
    assert chain.candidate_fact_id == "candidate-lab";
    assert chain.transcript_chunk_id == "chunk-1";
    assert chain.encounter_id == "encounter-maya-001";
    assert chain.patient_id == "patient-maya";
    assert chain.source_text == (
        "We will order a blood test to be completed this week."
    );
}

test "answer provenance reaches immutable source evidence" {
    session_id = "architecture-answer-provenance";
    prepare_resolved(session_id);
    answer: BackendResponse = ask_patient_question(
        "When is my blood test?", session_id
    );
    assert answer.patient_answer is not None;
    traced: BackendResponse = trace_provenance(answer.patient_answer.id, session_id);
    assert traced.success , traced.message;
    assert len(traced.provenance_chains) == 1;
    assert traced.provenance_chains[0].complete;
}

test "cross session ids are rejected for mutation and provenance" {
    left = "architecture-cross-left";
    right = "architecture-cross-right";
    prepare_resolved(left);
    assert reset_demo(right).success;
    wrong_verify: BackendResponse = verify_fact(
        "candidate-lab", "accept", "architecture-clinician", "missing-session"
    );
    assert not wrong_verify.success;
    left_gaps: BackendResponse = run_care_gap_check(left);
    wrong_gap: BackendResponse = resolve_gap(
        (
            left_gaps.care_gaps[0].id
                if left_gaps.care_gaps
                else "gap-lab-owner-verified-candidate-lab"
        ),
        "cross session attempt",
        "wrong-owner",
        "tomorrow",
        right
    );
    assert not wrong_gap.success;
    left_plan: BackendResponse = generate_patient_plan("English", left);
    assert left_plan.patient_plan is not None;
    wrong_trace: BackendResponse = trace_provenance(
        left_plan.patient_plan.labs[0].id, right
    );
    assert not wrong_trace.success;
}

test "reset selected session preserves another session" {
    left = "architecture-reset-left";
    right = "architecture-reset-right";
    prepare_resolved(left);
    assert reset_demo(right).success;
    right_before: BackendResponse = get_care_graph(right);
    left_reset: BackendResponse = reset_demo(left);
    right_after: BackendResponse = get_care_graph(right);
    assert left_reset.success;
    assert right_before.care_graph is not None;
    assert right_after.care_graph is not None;
    assert right_before.care_graph.graph_version == right_after.care_graph.graph_version;
    assert len(right_after.care_graph.candidate_facts) == 5;
}

test "conflict has two role bearing evidence sides and invalidates brief" {
    session_id = "architecture-conflict";
    prepare_resolved(session_id);
    plan: BackendResponse = generate_patient_plan("English", session_id);
    assert plan.success;
    assert add_demo_contradiction(session_id).success;
    audit: BackendResponse = run_evidence_audit(session_id);
    assert audit.success;
    encounter: Encounter = selected_encounter(session_id);
    conflicts: list[Conflict] = [encounter->:HasConflict:->];
    assert len(conflicts) == 1;
    assert len([conflicts[0]->:ConflictEvidence:->]) == 2;
    session: DemoSession = selected_session(session_id);
    patient: Patient = [session->:HasPatient:->][0];
    briefs: list[PatientBrief] = [patient->:HasBrief:->];
    assert len(briefs) == 1;
    assert not briefs[0].current;
}

test "actual entry and edge trace is environment gated" {
    session_id = "architecture-trace";
    assert reset_demo(session_id).success;
    os.environ["DEMO_TRACE_ENABLED"] = "true";
    result: BackendResponse = reset_demo(session_id);
    os.environ["DEMO_TRACE_ENABLED"] = "false";
    assert result.success;
    assert len(result.traversal_trace) >= 2;
    assert result.traversal_trace[0].walker_name == "ResetDemoWalker";
    assert result.traversal_trace[0].edge_type == "HasSession";
    assert all(step.human_explanation.strip() for step in result.traversal_trace);
}

test "care graph exposes typed relationship projection" {
    session_id = "architecture-relationships";
    prepare_resolved(session_id);
    assert generate_patient_plan("English", session_id).success;
    graph_response: BackendResponse = get_care_graph(session_id);
    assert graph_response.care_graph is not None;
    graph: CareGraphDTO = graph_response.care_graph as CareGraphDTO;
    edge_types: list[str] = [
        relationship.edge_type for relationship in graph.relationships
    ];
    for required in [
        "HasSession",
        "HasPatient",
        "HasEncounter",
        "ContainsChunk",
        "HasCandidate",
        "PromotedTo",
        "HasVerifiedFact",
        "HasTask",
        "DependsOn",
        "HasBrief",
        "HasChecklistItem",
        "SupportedBy"
    ] {
        assert required in edge_types , required;
    }
}
