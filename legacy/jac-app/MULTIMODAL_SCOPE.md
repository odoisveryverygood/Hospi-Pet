# Multimodal scope freeze

## P0 required before Prompt 3

- Progressive, speaker-labeled transcript ingestion with a capture state
  machine and prepared fallback.
- Validated synthetic document-image intake, deterministic extraction, an
  optional typed-image seam, and document-grounded pending candidates.
- Transcript/document provenance, clinician note draft/edit/approval/source
  tracing, encounter timeline, and approved-plan audio scripts.
- Exact public contracts, fixtures, frontend instructions, isolation/security
  tests, real-server smoke tests, a deterministic multimodal demo, and a cold
  start check.

## P1 adapters delivered as safe seams or handoff

- Browser `SpeechRecognition` can append chunks through the same P0 action.
- Browser camera/upload can supply the validated image data URL.
- Browser `speechSynthesis` can speak the returned approved script.
- Real vision uses the typed seam only when an existing authorized provider is
  available. The demo never depends on it.

Uploaded-audio transcription, a local Whisper install, server TTS, required
cloud AI, and video are intentionally omitted. They do not improve the
reliable offline judging path enough to justify their storage, credential, and
latency risks.

## Explicitly outside this phase

No face/body/emotion/identity analysis, wound or symptom diagnosis, clinical
image interpretation, EHR/FHIR/insurance/billing/scheduling integration,
production authentication, real PHI, or autonomous clinical recommendation is
implemented. The camera is a synthetic document scanner only.
