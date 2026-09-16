"""Generated-route, raw-envelope, and reload persistence smoke test."""

import shutil;
import tempfile;
import from jaclang.runtimelib.testing { JacTestClient, }

with entry {
    base_path: str = tempfile.mkdtemp(prefix="pa-co-intelligence-server-");
    client: JacTestClient = JacTestClient.from_file("main.jac", base_path=base_path);
    try {
        reset = client.post(
            "/function/reset_demo", json={"session_id": "intelligence-server"}
        );
        assert reset.ok;
        assert reset.json()["ok"];
        assert reset.data["result"]["success"];

        capture_response = client.post(
            "/function/start_capture_session",
            json={
                "encounter_id": "encounter-maya-001",
                "input_source": "typed_text",
                "session_id": "intelligence-server"
            }
        );
        assert capture_response.ok;
        capture_id: str = capture_response.data["result"]["capture_session"]["id"];
        chunk_response = client.post(
            "/function/append_transcript_chunk",
            json={
                "capture_session_id": capture_id,
                "sequence": 1,
                "speaker": "Patient",
                "text": "Me he sentido mareada durante tres días.",
                "session_id": "intelligence-server"
            }
        );
        assert chunk_response.ok;
        chunk_id: str = chunk_response.data["result"]["transcript_chunk"]["id"];

        translated = client.post(
            "/function/translate_transcript_chunk",
            json={
                "transcript_chunk_id": chunk_id,
                "target_language": "English",
                "session_id": "intelligence-server"
            }
        );
        assert translated.ok , translated.text;
        translated_result = translated.data["result"];
        assert translated_result["success"];
        assert translated_result["translated_chunk"]["translated_text"] == (
            "I have felt dizzy for three days."
        );
        translated_id: str = translated_result["translated_chunk"]["id"];

        quick = client.post(
            "/function/generate_live_quick_summary",
            json={
                "encounter_id": "encounter-maya-001",
                "session_id": "intelligence-server"
            }
        );
        assert quick.ok;
        assert quick.data["result"]["live_quick_summary"]["unverified"];

        client.reload();
        persisted = client.post(
            "/function/get_translated_transcript",
            json={
                "capture_session_id": capture_id,
                "target_language": "English",
                "session_id": "intelligence-server"
            }
        );
        assert persisted.ok;
        assert persisted.data["result"]["translated_transcript"][0]["id"] == (
            translated_id
        );
        quick_persisted = client.post(
            "/function/get_live_quick_summary",
            json={
                "encounter_id": "encounter-maya-001",
                "session_id": "intelligence-server"
            }
        );
        assert quick_persisted.ok;
        assert quick_persisted.data["result"]["live_quick_summary"]["unverified"];

        foreign = client.post(
            "/function/get_translated_transcript",
            json={
                "capture_session_id": capture_id,
                "target_language": "English",
                "session_id": "intelligence-server-foreign"
            }
        );
        assert foreign.ok;
        assert not foreign.data["result"]["success"];
        assert foreign.data["result"]["error_code"] == "CAPTURE_NOT_FOUND";

        invalid = client.post(
            "/function/translate_transcript_chunk", json={"target_language": "English"}
        );
        assert invalid.ok;
        assert "missing 1 required positional argument" in str(invalid.data["error"]);

        # JacTestClient exercises generated function routes but does not mount
        # the real server's /docs and /openapi.json routes. Those are verified
        # by the real `jac start main.jac --no-client` acceptance smoke test.
    } finally {
        client.close();
        shutil.rmtree(base_path, ignore_errors=True);
    }
    print("intelligence generated routes and reload persistence passed");
}
