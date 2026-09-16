# Hospi-Pet

A local microphone session demo, distilled from a Jac voice/camera encounter prototype, with explicit resource ownership and repeatable cleanup.

## Why this repository is useful

The original project combined microphone input, browser speech recognition,
camera/document capture, and a synthetic care graph. This review surface
isolates one engineering problem: safely ending a microphone session so the
next one can start. Original research remains in [legacy/](legacy/README.md).
The maintained demo uses real browser recording, not prepared transcripts.

## Demo

Use Node **22.23.2** (see `.nvmrc`) and npm. No `.env`, API key, backend, or paid service is required.

```bash
# Run from the directory containing the supplied Git bundle:
git clone --branch review/microphone-lifecycle ./Hospi-Pet-review.bundle Hospi-Pet
cd Hospi-Pet
nvm install
nvm use
npm ci
npm run dev
```

Open <http://127.0.0.1:5173>. Grant microphone permission. If you do not use
nvm, install Node 22.23.2 with your usual version manager first.
The remote default `main` branch is only the old project scaffold; this review
branch must be published/shared explicitly. A local commit is not a deployment.

## What to try

1. Start microphone and allow access.
2. Speak for 3–5 seconds, then stop. The state becomes `completed`.
3. Play the clip. Immediately start a second session.
4. Repeat once more. Each start resets elapsed time and replaces the old clip.
5. Discard to return to `idle`. Optionally block microphone permission in site
   settings, try again, then restore permission and retry.

Use non-sensitive test speech. Audio stays in page memory; discard, a new
session, or leaving the page releases it. The demo caps a session at 60 seconds
and 8 MiB. Microphone use requires localhost or HTTPS.

## Technical focus

- One controller owns the stream, recorder, timers, listeners, and chunks.
- Explicit states: idle → requesting_permission → recording → stopping → completed;
  errors and cancellation release owned resources before retry.
- Each callback captures its session owner. A retired owner cannot change the next session.
- Stop releases tracks immediately and waits for final recorder data, with a bounded watchdog.
- Permission requests cannot be aborted by this API. Canceled/expired requests
  are serialized until they settle, and late streams are stopped immediately.
- Unit tests drive timing/failure races; browser tests use native Chromium media APIs.

## Architecture

`src/microphone-session.ts` is the lifecycle controller and browser adapter.
`src/main.ts` renders the view, manages local playback URLs, and handles page exit
and page-cache restoration. Vite serves/builds this small TypeScript application.
There are no runtime npm dependencies. `legacy/jac-app/` is preserved, unmaintained
research; it does not run inside the demo and is not covered by the new gates.

## Testing

```bash
npm run typecheck
npm run lint
npm test
npm run build
npx playwright install chromium
npm run test:browser
```

`npm run check` combines typecheck, lint, unit tests, and build. Unit tests cover
cleanup, repeated sessions, late callbacks, failures, and teardown. Browser
acceptance tests record three clips using Chromium's fake microphone, decode
the resulting audio, and check real track/recorder/listener cleanup. Hardware
and cross-browser manual steps are in [the lifecycle guide](docs/MICROPHONE_SESSION_LIFECYCLE.md).
Exact observed results, including original failures: [VERIFICATION.md](docs/VERIFICATION.md).

## Limitations

- This is a newly hardened recording surface, not a reproduction of the original
  historical fix. The original used SpeechRecognition, not MediaRecorder.
- No transcription, camera UI, document analysis, clinical decisions, backend
  synchronization, or persistent media in the maintained demo.
- Automated microphone evidence uses a synthetic browser device. Physical
  hardware, OS permission dialogs, Safari/Firefox, and multi-hour use are unverified.
- A browser permission prompt can remain unresolved forever. Cancel invalidates
  its result; dismiss it or reload if the browser never settles it.
- Legacy typechecking and reload/persistence tests fail; see the audit. Its
  “production-shaped” and other older readiness claims are not current guarantees.

## Related technical documentation

- [Microphone session lifecycle](docs/MICROPHONE_SESSION_LIFECYCLE.md)
- [Repository audit](docs/REPO_AUDIT.md)
- [Two-minute Screenpipe review](docs/SCREENPIPE_REVIEW.md)
