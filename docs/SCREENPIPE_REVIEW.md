# Hospi-Pet engineering review

## Project context

Hospi-Pet began as a Jac hackathon prototype for organizing a synthetic
consultation: voice text and document capture fed proposed facts, clinician review,
and a care graph with source links. That implementation remains intact in `legacy/jac-app/`.

The subsequent audit found coupled browser/backend capture state, several unsafe
async paths, and broken typecheck/reload checks. Historical commits change capture
IDs and recovery, but no incident trace proves the exact reported stale-session
root cause. The original used browser speech recognition, **not MediaRecorder**.

## What was improved

The maintained product now has an end-to-end encounter notebook: create → record
voice → attach optional document photos → review → finalize → local history.
The first review introduced the
recorder controller; the subsequent product pass integrated it into encounters without duplicating it.

## Engineering problem

Capture outlives the action that requested it. Permission can resolve after
cancel, recorder data arrives after stop, and image encoding can finish after
switching encounters. Storage also completes asynchronously. A UI boolean cannot
express who owns these results.

Each media controller owns its resources and checks concrete owner identity.
Workspace binds capture generation/UUID to encounter UUID. Navigation invalidates
bindings before cleanup. Microphone stop releases tracks immediately, then accepts
bounded final encoder data. Camera capture releases tracks after copying the frame.
Unresolved permissions stay serialized.

IndexedDB commits sources and metadata together. Save sequencing preserves edits
made during a write; atomic revision checks reject stale tabs. Failed saves retain
visible unsaved input. Finalization only becomes successful after storage commits.


## Evidence and limits

The original 24 microphone tests remain unchanged. Added camera, encounter and
storage tests exercise leaks, stale callbacks, retries, concurrent writes and
corruption recovery. Chromium tests record/decode native audio, capture real canvas
frames from its fake camera, finalize two isolated encounters, reload sources and
delete them. [Exact results](VERIFICATION.md).

No speech service, OCR, restored care-graph backend or hardware/cross-browser
validation is claimed. The original Jac failures remain disclosed.

## Run and inspect

Use Node 22.23.2: `npm ci && npm run dev`; open <http://127.0.0.1:5173>.
In **30–60 seconds**: New encounter → record 3 seconds → stop/play → optional
photo → written note → review/finalize → history → new encounter → record again.
Refresh to reopen the first record. `npm run check` and
`npx playwright install --with-deps chromium && npm run test:browser` reproduce the checks.

Best files:

1. `src/workspace.ts` — encounter binding, save ordering and finalization.
2. `src/microphone-session.ts` — owned recording lifecycle and stale callbacks.
3. `src/camera-session.ts` — acquisition, preview, encoding and teardown.
4. `src/storage/encounter-store.ts` — transactions, revisions and validation boundary.
5. `tests/workspace.test.ts` — stale encounter work and save races.
6. `tests/browser/product.spec.ts` — complete product flow with native media.
7. `docs/PRODUCT_ARCHITECTURE.md` — original product versus maintained scope.
