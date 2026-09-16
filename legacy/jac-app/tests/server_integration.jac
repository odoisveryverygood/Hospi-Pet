"""Generated endpoint, persistence, and authenticated-root integration tests."""

import shutil;
import tempfile;
import from jaclang.runtimelib.testing { JacTestClient }

def close_client(client: JacTestClient, base_path: str) {
    client.close();
    shutil.rmtree(base_path, ignore_errors=True);
}

def verify_generated_function_contract_and_reload_persistence {
    base_path: str = tempfile.mkdtemp(prefix="pa-co-endpoint-");
    client: JacTestClient = JacTestClient.from_file("main.jac", base_path=base_path);
    try {
        reset = client.post(
            "/function/reset_demo", json={"session_id": "server-contract"}
        );
        assert reset.ok;
        payload = reset.json();
        assert payload["ok"];
        assert "data" in payload;
        result = payload["data"]["result"];
        assert result["success"];
        assert result["demo_state"]["patient"]["display_name"] == "Maya Rivera";
        assert len(result["candidate_facts"]) == 5;

        candidates = client.post(
            "/function/get_candidate_facts", json={"session_id": "server-contract"}
        );
        assert candidates.ok;
        assert candidates.data["result"]["success"];
        assert len(candidates.data["result"]["candidate_facts"]) == 5;

        trace = client.post(
            "/function/trace_provenance",
            json={"output_id": "not-created", "session_id": "server-contract"}
        );
        assert trace.ok;
        assert not trace.data["result"]["success"];
        assert trace.data["result"]["error_code"] == "OUTPUT_NOT_FOUND";

        invalid = client.post(
            "/function/verify_fact",
            json={"decision": "accept", "clinician_id": "server-clinician"}
        );
        assert invalid.status_code == 200;
        assert invalid.ok;
        error_text: str = invalid.data["error"];
        assert "missing 1 required positional argument" in error_text;

        accepted = client.post(
            "/function/verify_fact",
            json={
                "fact_id": "candidate-lab",
                "decision": "accept",
                "clinician_id": "server-clinician",
                "session_id": "server-contract"
            }
        );
        assert accepted.ok;
        client.reload();
        graph = client.post(
            "/function/get_care_graph", json={"session_id": "server-contract"}
        );
        assert graph.ok;
        reloaded = graph.data["result"];
        assert len(reloaded["care_graph"]["verified_facts"]) == 1;
        assert reloaded["care_graph"]["verified_facts"][0]["id"] == (
            "verified-candidate-lab"
        );
    } finally {
        close_client(client, base_path);
    }
}

def verify_private_walker_and_authenticated_root_isolation {
    base_path: str = tempfile.mkdtemp(prefix="pa-co-auth-roots-");
    client: JacTestClient = JacTestClient.from_file(
        "tests/fixtures/auth_isolation.jac", base_path=base_path
    );
    try {
        anonymous = client.post("/walker/AddMarker", json={"value": "anonymous"});
        assert anonymous.status_code == 401;

        alice = client.register_user("alice-caregraph", "password123");
        assert alice.ok , alice.text;
        assert client.login("alice-caregraph", "password123").ok;
        alice_add = client.post("/walker/AddMarker", json={"value": "alice-only"});
        assert alice_add.ok , alice_add.text;
        alice_values = client.post("/function/marker_values", json={});
        assert alice_values.data["result"] == ["alice-only"] , alice_values.text;

        client.clear_auth();
        bob = client.register_user("bob-caregraph", "password123");
        assert bob.ok , bob.text;
        assert client.login("bob-caregraph", "password123").ok;
        bob_values = client.post("/function/marker_values", json={});
        assert bob_values.data["result"] == [] , bob_values.text;
        assert client.post("/walker/AddMarker", json={"value": "bob-only"}).ok;
        assert client.post("/function/marker_values", json={}).data["result"] == [
            "bob-only"
        ];

        client.clear_auth();
        assert client.login("alice-caregraph", "password123").ok;
        assert client.post("/function/marker_values", json={}).data["result"] == [
            "alice-only"
        ];
    } finally {
        close_client(client, base_path);
    }
}

with entry {
    verify_generated_function_contract_and_reload_persistence();
    print("JacTestClient generated function contract and reload persistence passed.");
    verify_private_walker_and_authenticated_root_isolation();
    print("JacTestClient private-walker and authenticated-root isolation passed.");
}
