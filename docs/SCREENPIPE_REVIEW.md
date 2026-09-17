# Hospi-Pet engineering review

Hospi-Pet began as a Jac hackathon prototype organizing synthetic consultations:
voice text and document capture fed proposed facts, clinician review and a care
graph. All 146 original files remain in `legacy/jac-app/`.

The audit found coupled browser/backend state and failing typecheck/reload checks.
History includes capture/recovery changes, but does not prove the exact reported
stale-session incident. The original used browser speech recognition, **not
MediaRecorder**. The recorder controller, maintained encounter UI and inspection
system are subsequent improvements.

## The problem worth reviewing

Capture outlives its initiating action. Permission may resolve after navigation,
encoder events follow Stop, hashing and storage finish asynchronously, and two
tabs can edit the same saved record. UI booleans do not establish result ownership.

Controllers own hardware and guard concrete generations. Workspace binds each
attempt to encounter/session UUIDs. A content-free event journal exposes release,
completion and ignored callbacks. It feeds actual source provenance and a pure
lifecycle replay, never replayed hardware commands. Atomic IDB revisions reject
silent overwrites. SHA-256 fingerprints are computed outside transactions and
verified on reopen; mismatches are visible in the normal workflow.

## Reproduce the difficult part

Use Node 22.23.2: `npm ci && npm run dev`; open <http://127.0.0.1:5173>.
Create an encounter, record/stop/play, attach a practice photo and finalize.
Open **Capture timeline & provenance**, inspect the source's session and creation
event, then step through Replay. Refresh and reopen to verify its fingerprints.

For a controlled race, open <http://127.0.0.1:5173/?lab=1>. In **Capture Lab**, arm
microphone-delay, start capture, navigate to a second encounter, then release the
pending callback. The late stream is stopped; the second record stays unchanged.
Diagnostics show the rejected generation and actual resource counts. The lab
wraps real ports; it does not manufacture error messages in the view.

## Evidence and boundaries

All original tests are preserved. Added tests verify event order, schema rejection,
provenance, replay prefixes, digest changes, delayed callbacks/writes and injected
invariant failures. Chromium encodes/decodes native audio, captures fake-camera
frames, verifies persisted hashes, exports manifests and probes resource cleanup.
[Exact results and measurements](ADVANCED_VERIFICATION.md).

The journal is bounded and replay is a lifecycle projection. No transcript
provider, medical inference, restored Jac backend, media backup, cryptographic
authentication, hardware/OS-permission validation or cross-browser coverage is
claimed. This is an inspectable local prototype, not a continuous capture service.

## Best files

- `src/workspace.ts` — encounter ownership and save races.
- `src/microphone-session.ts` — guarded capture and cleanup.
- `src/capture/events.ts` — allowlisted facts and pure replay.
- `src/capture/integrity.ts` — hash boundaries and verification.
- `src/capture/lab.ts` — deterministic faults at real ports.
- `tests/capture-chaos.test.ts` — recovery and stale-result assertions.
- `tests/browser/engineering.spec.ts` — complete browser evidence.
- `docs/CAPTURE_ARCHITECTURE.md` — design decisions and limits.
