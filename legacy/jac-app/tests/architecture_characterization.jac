"""Characterization tests protecting the stable pre-upgrade contract."""

import from endpoints {
    get_candidate_facts,
    get_care_graph,
    load_demo_encounter,
    reset_demo,
    verify_fact,
}
import from models {
    BackendResponse,
    CandidateFact,
    CareGraphDTO,
    DemoSession,
    Encounter,
    Patient,
    SessionOwns,
    HasPatient,
    HasEncounter,
    HasCandidate,
}

test "characterization deterministic load and reset agree" {
    loaded: BackendResponse = load_demo_encounter("characterization-load");
    reset: BackendResponse = reset_demo("characterization-load");
    assert loaded.success;
    assert reset.success;
    assert len(reset.candidate_facts) == 5;
    assert [item.id for item in loaded.candidate_facts] == [
        item.id for item in reset.candidate_facts
    ];
    assert [item.value for item in loaded.candidate_facts] == [
        item.value for item in reset.candidate_facts
    ];
    assert [item.source_chunk_id for item in loaded.candidate_facts] == [
        item.source_chunk_id for item in reset.candidate_facts
    ];
    assert all(item.status == "pending" for item in reset.candidate_facts);
    assert reset.current_graph_version == 1;
}

test "characterization read actions preserve graph version" {
    reset: BackendResponse = reset_demo("characterization-read-version");
    candidates: BackendResponse = get_candidate_facts("characterization-read-version");
    graph: BackendResponse = get_care_graph("characterization-read-version");
    assert reset.current_graph_version == candidates.current_graph_version;
    assert candidates.current_graph_version == graph.current_graph_version;
}

test "characterization domain path reaches candidates" {
    _ = reset_demo("characterization-topology");
    sessions: list[DemoSession] = [root-->[?:DemoSession, id=="characterization-topology"]];
    assert len(sessions) == 1;
    patients: list[Patient] = [sessions[0]->:HasPatient:->];
    assert len(patients) == 1;
    encounters: list[Encounter] = [patients[0]->:HasEncounter:->];
    assert len(encounters) == 1;
    candidates: list[CandidateFact] = [encounters[0]->:HasCandidate:->];
    assert len(candidates) == 5;
}

test "characterization ownership index matches one session" {
    _ = reset_demo("characterization-ownership");
    sessions: list[DemoSession] = [root-->[?:DemoSession, id=="characterization-ownership"]];
    assert len(sessions) == 1;
    owned: list[CandidateFact] = [sessions[0]->:SessionOwns:->[?:CandidateFact]];
    assert len(owned) == 5;
    assert all(item.session_id == "characterization-ownership" for item in owned);
}

test "characterization verification keeps response contract" {
    _ = reset_demo("characterization-contract");
    accepted: BackendResponse = verify_fact(
        "candidate-lab",
        "accept",
        "characterization-clinician",
        "characterization-contract"
    );
    assert accepted.success;
    assert accepted.verified_fact is not None;
    graph_response: BackendResponse = get_care_graph("characterization-contract");
    assert graph_response.care_graph is not None;
    graph: CareGraphDTO = graph_response.care_graph as CareGraphDTO;
    assert len(graph.verified_facts) == 1;
    assert graph.verified_facts[0].id == "verified-candidate-lab";
}
