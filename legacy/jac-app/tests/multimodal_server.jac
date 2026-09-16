"""Generated-route and persistence smoke test for multimodal actions."""

import shutil;
import tempfile;
import from jaclang.runtimelib.testing { JacTestClient, }

with entry {
    base_path: str = tempfile.mkdtemp(prefix="pa-co-multimodal-server-");
    client: JacTestClient = JacTestClient.from_file("main.jac", base_path=base_path);
    try {
        reset = client.post(
            "/function/reset_demo", json={"session_id": "multimodal-server"}
        );
        assert reset.ok;
        assert reset.data["result"]["success"];

        prepared = client.post(
            "/function/load_prepared_voice_demo",
            json={
                "encounter_id": "encounter-maya-001",
                "session_id": "multimodal-server"
            }
        );
        assert prepared.ok , prepared.text;
        prepared_result = prepared.data["result"];
        assert prepared_result["success"];
        assert prepared_result["capture_session"]["status"] == "recording";
        assert len(prepared_result["transcript_chunks"]) == 5;
        capture_id: str = prepared_result["capture_session"]["id"];

        completed = client.post(
            "/function/finalize_capture_session",
            json={"capture_session_id": capture_id, "session_id": "multimodal-server"}
        );
        assert completed.ok;
        assert completed.data["result"]["success"];
        assert completed.data["result"]["capture_session"]["status"] == "completed";

        client.reload();
        persisted = client.post(
            "/function/get_capture_session",
            json={"capture_session_id": capture_id, "session_id": "multimodal-server"}
        );
        assert persisted.ok;
        assert persisted.data["result"]["capture_session"]["chunk_count"] == 5;

        denied = client.post(
            "/function/get_capture_session",
            json={"capture_session_id": capture_id, "session_id": "other-session"}
        );
        assert denied.ok;
        assert not denied.data["result"]["success"];
        assert denied.data["result"]["error_code"] == "CAPTURE_NOT_FOUND";
    } finally {
        client.close();
        shutil.rmtree(base_path, ignore_errors=True);
    }
    print("multimodal generated routes and reload persistence passed");
}
