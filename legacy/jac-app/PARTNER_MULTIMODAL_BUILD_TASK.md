# Frontend partner task: multimodal encounter

Work only on your `frontend-ui` branch and frontend-owned files. Do not alter
`CONTRACT.md`, backend Jac modules, graph rules, or fixtures. Merge the latest
`origin/integration` before a major task and request contract changes from the
backend owner.

Use [MULTIMODAL_FRONTEND_HANDOFF.md](MULTIMODAL_FRONTEND_HANDOFF.md),
[CONTRACT.md](CONTRACT.md), and `handoff/fixtures/` as the only response-shape
authority.

## Voice

- Build Start Recording, Stop Recording, Cancel, Retry, timer, live transcript,
  Doctor/Patient badges, permission state, processing state, and fallback-demo
  mode.
- Browser recognition sends only final chunks in contiguous order.
- Permission/provider failure offers prepared fallback; no raw audio is stored.

## Camera

- Build Open Camera, Upload Image, Take Photo, preview, retake, document type,
  Analyze, ordered extracted text, confidence/mode, unverified candidate cards,
  and validation errors.
- Treat the camera as a synthetic administrative-document scanner only.
- Send the selected image as the `image_input` multipart file documented in
  the handoff; discard the `File` reference and revoke preview URLs after the
  action returns.

## Notes

- Build Generate Note, nine-section editor, source counts, Trace Source,
  clinician approval, approved/superseded state, and contradictions requiring
  review.
- Always display `Clinician-review draft — synthetic demonstration.`
- Replace local note ID with the returned ID after any edit.

## Timeline

- Build ordered encounter events with event type, title, graph version, related
  node/source links, and the walker/action label from trace/provenance where
  present.

## Patient accessibility

- Build English/Spanish plan selection and Play/Pause/Resume/Stop, speech rate,
  matching browser voice, visible script, unsupported-browser state, and
  source tracing.
- Speak only `PatientAudioScriptDTO.text`.

## Done when

- Every control is tested against the 17 fixtures and the generated Jac
  endpoints.
- Recoverable failure preserves usable state and presents retry/fallback.
- Reset cancels media/speech, clears IDs, and reloads deterministic state.
- No frontend-owned mock invents a backend field.
- No pending/rejected/conflicted content reaches the patient view.
