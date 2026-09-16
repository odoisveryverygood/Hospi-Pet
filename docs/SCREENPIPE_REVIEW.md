# Screenpipe review — Hospi-Pet

## What I worked on

This repository preserves a Jac hackathon prototype for synthetic voice/camera
encounters and adds a focused local microphone lifecycle demo. The current
recording controller and regression suite were added during this engineering
cleanup; they were not part of the original incident.

## Technical problem

A canceled or completed session can still receive permission results, recorder
events, or timers. Shared mutable state lets those callbacks corrupt the next
session or leak capture resources. The original backend also blocked a new
capture while an earlier capture remained active.

## Implementation

One TypeScript controller owns each stream, recorder, listener, timer, and chunk
buffer. Identity checks reject retired callbacks. Cleanup invalidates ownership
before stopping resources. Stop releases tracks immediately and waits briefly
for encoded data. Clips stay in memory and are limited to 60 seconds / 8 MiB.

## Why session lifecycle was difficult

Browser permission cannot be canceled by the media API, and recorder stop is
asynchronous. The design serializes unresolved acquisitions, stops late streams,
and uses a watchdog for missing stop events. Render updates never own resources.
Historical commits show capture-ID fixes; no historical failing test proves the
precise original root cause. This demo does not claim to reproduce that incident.

## How it is tested

Controller tests cover grant/deny/retry, 25 repeated sessions, rapid actions,
old callbacks, initialization/runtime/stop failures, timeouts, and disposal.
Chromium acceptance uses a fake microphone but native recording and decoding;
three clips must play and all retired capture resources must be released.
See [exact results](VERIFICATION.md), including failures in the preserved app.

## How to reproduce it

Clone the supplied bundle with
`git clone --branch review/microphone-lifecycle ./Hospi-Pet-review.bundle Hospi-Pet`.
In that checkout, use Node 22.23.2, then `npm ci && npm run dev`.
Open <http://127.0.0.1:5173>.
For a **30–60 second demo**: start → allow → speak 3–5 seconds → stop → play;
repeat twice immediately, then discard. Observe increasing generation IDs,
fresh clips, and inactive capture after each stop. `npm run check` runs the
local gates; `npx playwright install chromium && npm run test:browser` runs
browser acceptance.

## Known limitations

No transcription, camera UI, medical inference, or backend in this review
surface. Original camera/graph research is preserved separately and has known
verification failures. Hardware/OS prompts, Safari/Firefox, and multi-hour use
are unverified. The default remote main is a scaffold; this local review branch
must be shared explicitly.

## Best files to review

1. `src/microphone-session.ts` — state, ownership, cleanup, race guards.
2. `tests/microphone-session.test.ts` — failure and resource assertions.
3. `tests/browser/capture.spec.ts` — native browser acceptance.
4. `src/main.ts` — UI lifetime and playback URL cleanup.
5. `docs/MICROPHONE_SESSION_LIFECYCLE.md` — invariants and evidence boundaries.
6. `docs/REPO_AUDIT.md` — actual original code/history and baseline failures.
