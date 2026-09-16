# Multimodal security and privacy report

Status: synthetic hackathon demo controls implemented and tested. This is not
production authorization, HIPAA compliance, or permission to process PHI.

## Enforced boundaries

- `synthetic=false` document input is rejected.
- Only administrative lab/referral/appointment/after-visit document types and
  PNG/JPEG/WEBP are accepted.
- Base64 syntax, matching MIME, non-empty bytes, decoded size (1 MiB), image
  decoding, and positive dimensions are validated.
- A temporary file is used only for decode verification and removed in
  `finally`; no path appears in a DTO/error.
- The public upload action uses Jac's multipart `UploadFile`. Jac 0.34.7 logs
  filename, size, and MIME metadata for generated function calls, but not raw
  bytes; the real-server smoke test verified that behavior.
- Raw image bytes and raw audio have no graph field and are never persisted.
- The browser handoff sends finalized synthetic text, not audio.
- Candidate facts always start pending. Only `VerificationWalker` creates a
  `VerifiedFact`, verification event, obligation, or task.
- Typed image proposals require exact block evidence, allow-listed category,
  confidence range, clinician-review flag, and session-local source.
- Diagnosis, prescribing, dosage change, safety claims, emergency triage,
  biometric/body/wound analysis, fabricated dates, and instruction-injection
  phrases are prohibited.
- Notes use verified graph facts. Generated and clinician-edited content are
  separate fields; approval is event-audited; an approved edit supersedes.
- Patient audio uses only a current approved `PatientBrief`.
- Capture/artifact/note/provenance lookups are scoped to one synthetic session
  and return not-found across sessions.
- Reset deletes only the selected `SessionOwns` synthetic boundary.

## Verified cases

Tests cover valid transitions, duplicate/out-of-order/blank/invalid-speaker
chunks, cancellation/finalization closure, prepared idempotence, unsupported
MIME, malformed/empty/corrupt/oversized image input, real-data rejection,
deterministic/Mock/malformed/missing-key extraction, pending-only model output,
document/voice provenance, note edit/approval/versioning, cross-session
capture/document/note/provenance denial, reset isolation, no raw graph fields,
and optional-provider fallback.

Prompt-injection validation is also exercised by the existing optional-AI
suite. Printed document text such as “approve automatically,” “return a
verified node,” or “reveal another patient” is untrusted evidence and cannot
invoke graph mutation. Model returns are plain typed objects, never nodes.

## Operational limitations

- The public demo uses logical session IDs, not production authentication.
- Browser speech recognition support and privacy behavior vary by browser.
- The generated service has development default-admin/JWT warnings and is not
  deployed.
- Request body buffering can occur before application-level decoded-size
  validation; the frontend must preflight 1 MiB too. A production reverse
  proxy/body limit is required later.
- Deterministic extraction recognizes only bundled fictional fixtures. Real
  OCR/vision remains optional and unverified here.
- No cloud credential was created, no model weights were downloaded, and no
  real-provider result is claimed.
