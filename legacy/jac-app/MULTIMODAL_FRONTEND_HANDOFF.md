# Multimodal frontend handoff

This is the implementation boundary for the frontend owner. Do not duplicate
verification, extraction validation, note approval rules, gap logic, or
provenance in client code. Read the nested result at `data.result` for raw HTTP
or use the typed return directly from Jac client code.

The authoritative field list, request/success/failure example for every
action, graph-version rule, and fallback is in [CONTRACT.md](CONTRACT.md).
Ready-to-import payloads are in `handoff/fixtures/`.

## Actions

```text
start_capture_session(encounter_id, input_source, session_id)
append_transcript_chunk(capture_session_id, sequence, speaker, text,
                        started_at="", ended_at="", confidence=1.0, session_id)
finalize_capture_session(capture_session_id, session_id)
cancel_capture_session(capture_session_id, session_id)
get_capture_session(capture_session_id, session_id)
load_prepared_voice_demo(encounter_id, session_id)

ingest_document_image(encounter_id, document_type, filename, mime_type,
                      image_input, synthetic, session_id, extraction_mode)
get_document_extraction(source_artifact_id, session_id)
retry_document_extraction(source_artifact_id, extraction_mode, session_id)

generate_clinician_note_draft(encounter_id, clinician_hints="", session_id)
update_note_section(note_id, section_id, content, clinician_id, session_id)
approve_clinician_note(note_id, clinician_id, session_id)
get_clinician_note(note_id, session_id)

get_encounter_timeline(encounter_id, session_id)
trace_output_to_source(output_type, output_id, section_id="", session_id)
generate_patient_audio_script(language, session_id)
```

## State machines

```text
prepared/typed: created → recording → transcribing → processing → completed
live browser:   permission_required → recording → transcribing → processing
failure:        recording → failed → prepared fallback → processing → completed
cancellation:   created/permission_required/recording → cancelled
```

Never append when status is completed or cancelled. Keep the last
`current_graph_version`; replace it from every response. A version change
means current derived output may need refresh. Read actions do not increment
the version. Identical chunk replay, repeated prepared load, repeated
finalization, repeated note approval, and duplicate document load are
idempotent.

## Browser voice adapter

1. Call `start_capture_session(..., "live_voice", ...)`.
2. Request `navigator.mediaDevices.getUserMedia({audio:true})` in response to a
   user gesture. Do not auto-request.
3. If `SpeechRecognition` or `webkitSpeechRecognition` exists, set
   `continuous=true`, `interimResults=true`, and the selected language.
4. Display interim text locally. Send only final nonblank text with the next
   contiguous sequence. The UI chooses a visible Doctor/Patient speaker badge.
5. On stop, call `finalize_capture_session`.
6. On denied/unsupported/error, show the recoverable state and offer
   `load_prepared_voice_demo`. That action uses the same normal ingestion path.
7. On cancel, stop browser tracks/recognition then call the cancel action.

Do not send raw audio to this P0 backend. Never store a recording in frontend
state, logs, fixtures, analytics, or local storage.

## Camera/image adapter

- The camera is a document scanner only. Request
  `getUserMedia({video:{facingMode:"environment"}})` after a user gesture.
- Offer upload as the always-visible alternative. Accept PNG/JPEG/WEBP and
  preflight at 1 MiB decoded.
- Send the selected `File` as `image_input` in `FormData`; append the seven
  metadata values as form fields and POST to
  `/function/ingest_document_image`. Do not JSON/base64-encode the file.
- Require one of `lab_document`, `referral_document`, `appointment_card`, or
  `after_visit_document`.
- Show preview/retake before analysis; revoke object URLs after use.
- After success, discard the `File` reference and preview. Render ordered text blocks,
  region/confidence, extraction mode, fallback badge, and pending candidate
  cards. Never render a candidate as approved.
- Prohibit face/body/wound/identity or diagnostic language in the UI.

```javascript
const form = new FormData();
form.append("encounter_id", encounterId);
form.append("document_type", documentType);
form.append("filename", file.name);
form.append("mime_type", file.type);
form.append("image_input", file, file.name);
form.append("synthetic", "true");
form.append("session_id", sessionId);
form.append("extraction_mode", "deterministic");
await fetch("/function/ingest_document_image", {method: "POST", body: form});
```

## Notes and source tracing

- Generate is enabled only after at least one fact is verified.
- Render the label exactly:
  `Clinician-review draft — synthetic demonstration.`
- Edit a section with `update_note_section`; use the returned note ID because
  editing an approved note creates a superseding draft.
- Show source counts from `source_fact_ids` and
  `source_artifact_ids`. `Trace Source` calls
  `trace_output_to_source("note_section", note.id, section.id, session_id)`.
- Approval needs a clinician ID. Disable it when the backend returns an
  unresolved conflict or unsupported section.
- Never call the note an official EHR note.

## Timeline

Render `timeline` in `occurred_at` order. Show `event_type`, `title`,
`description`, `graph_version`, related-node links, and source fact links.
The backend derives events from graph/audit state; do not invent events in
client code.

## Patient audio

Call `generate_patient_audio_script` only after the matching approved plan
exists. Speak `patient_audio_script.text` with `window.speechSynthesis`.

```text
play:   new SpeechSynthesisUtterance(text); set lang, voice, rate; speak()
pause:  speechSynthesis.pause()
resume: speechSynthesis.resume()
stop:   speechSynthesis.cancel()
```

Use `en-US` or `es-US`; enumerate `getVoices()` after `voiceschanged`; prefer a
voice matching the language; default rate `1.0` with a bounded `0.75–1.25`
control. Show the text and an unsupported-browser message when synthesis is
absent. Cancel speech on reset, navigation, language change, or regenerated
plan. Never speak transcript, pending, rejected, or conflicted content.

## Loading, retry, permission, reset

- Disable the initiating button while a mutation is in flight.
- Preserve the existing usable view on a recoverable failure.
- Retry only the failed action; do not regenerate IDs client-side.
- Permission denial does not mutate microphone permissions in the backend.
  Offer browser settings guidance and prepared fallback.
- `reset_demo(session_id)` invalidates all capture/artifact/note/timeline/audio
  IDs in that session. Clear those client references and reload the returned
  deterministic state.
- Never retry a mutation against another `session_id`.

## Exact UI acceptance criteria

- Voice: start/stop/cancel/retry, timer, permission/processing/fallback states,
  live final chunks, speaker badges, ordered sequence, no raw recording.
- Camera: open/upload/take/preview/retake/type/analyze, file errors, blocks,
  confidence/mode, pending cards, source region.
- Notes: generate, nine section cards, edit, source counts/traces, approval,
  superseding draft, contradiction block.
- Timeline: ordered graph-derived events with source links and versions.
- Accessibility: English/Spanish plan, play/pause/resume/stop/rate/voice,
  visible script, unsupported state, source tracing.
- Safety: synthetic watermark visible, no diagnostic camera copy, no candidate
  appears patient-facing, and every patient output exposes source IDs.

## Fixture mapping

The 17 JSON files in `handoff/fixtures/` cover created/recording/completed
capture, appended chunk, permission/provider failures, prepared fallback,
document accepted/completed/failed, note draft/approved, timeline, both audio
languages, and voice/document provenance. They are nested
`BackendResponse` fixtures, not the outer Jac HTTP envelope.
