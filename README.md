# Hospi-Pet

An encounter notebook that keeps a visit's voice recording, document photos and written notes together for review.

## Current Prototype

Create an encounter, capture real audio, optionally photograph a practice document,
review the sources and finalize a local record. Reopen drafts or finalized
encounters after refreshing; delete individual encounters or clear local data.
Use synthetic information: this is an organization prototype, not a clinical record system.

## Demo

Use Node **22.23.2** (`.nvmrc`) and npm. From the directory containing the supplied
Git bundle:

```bash
git clone --branch review/microphone-lifecycle ./Hospi-Pet-review.bundle Hospi-Pet
cd Hospi-Pet
nvm install
nvm use
npm ci
npm run dev
```

Open <http://127.0.0.1:5173>. No environment variables, backend, account or API key
are required. Without nvm, use your usual Node version manager. This review branch
has not been pushed; the remote default branch is not this version of the project.

## Core Workflow

**Encounter → voice → optional document photo → review → local history.**

For a 30–60 second walkthrough:

1. Choose **New encounter**, name a practice visit and create it.
2. **Start microphone**, allow access, speak for 3 seconds, then **Stop recording**.
3. Play the clip. Optionally **Open camera → Take photo** using a synthetic document.
4. Add your own note, choose **Review encounter → Finalize encounter**.
5. Return to history, create another encounter and record again. Refresh to reopen
   the first record with its original sources.

Permission errors explain how to retry. Starting another recording replaces the
current clip. Stop completes/saves the clip; navigating away during recording
cancels that unfinished clip. Saved drafts and finalized records survive refresh.

## Engineering Focus

- One owner per media controller: tracks, recorder, listeners and timers have explicit cleanup.
- Retired callbacks cannot attach media to a newer capture or a different encounter.
- Permission requests are serialized; late grants are stopped after cancellation.
- IndexedDB stores metadata and Blobs atomically. Revision checks prevent silent
  competing-tab overwrites; save failures remain visible and retryable.
- Collapsible diagnostics show capture states, IDs, track counts and owned timers.
- Deterministic tests combine timing/failure injection with native Chromium recording,
  audio decoding, camera frames, persistence and complete product flows.

## Architecture

```text
History / Capture / Review views
             ↓
    Encounter workspace
       ↙           ↘
Media controllers   Encounter model → IndexedDB
(mic + camera)      (sources + notes + revisions)
```

`src/` is the maintained TypeScript/Vite prototype. It has no runtime npm
dependencies. [Product architecture](docs/PRODUCT_ARCHITECTURE.md) explains the
original care-graph ideas, retained workflow and current boundaries.

## Testing

```bash
npm run typecheck
npm run lint
npm test
npm run build
npx playwright install chromium
npm run test:browser
npm audit
```

`npm run check` combines typecheck, lint, unit/integration tests and build.
Browser acceptance uses fake microphone/camera devices with real browser media
APIs, encoding and decoding. It also checks save recovery, competing tabs, corrupt
records, offline use after loading and responsive screens. Generated screenshots
are in `test-results/visual/`. See [verification](docs/VERIFICATION.md) for exact
results and [manual hardware steps](docs/MICROPHONE_SESSION_LIFECYCLE.md).

## Historical Prototype

`legacy/jac-app/` preserves all 146 original files from the Jac hackathon prototype:
voice recognition, camera/document ingestion, synthetic care-graph research and
clinician review concepts. Known original typecheck and persistence failures
remain documented in the [audit](docs/REPO_AUDIT.md).

The original acquired microphone audio and used browser speech recognition; it
did **not** contain this MediaRecorder implementation. The recorder was added
during the first engineering review and integrated into this encounter product
during the second. History contains capture/recovery changes but does not prove
the exact reported stale-session incident or its root cause.

## Limitations

- Local browser storage only: no encryption by this app, account, cloud backup,
  export/import, sync or storage durability guarantee. Keep the same site address/port.
- One clip per encounter; 60 seconds / 8 MiB, four photos ≤1 MiB each, 20 encounters.
- No transcription, OCR, medical inference or care-graph backend in the maintained app.
- Chromium is automated. Physical devices, OS prompts, Safari/Firefox and long-running
  capture have not been validated. Pending permission prompts need browser interaction.
- Loaded capture works offline; opening the app from a cold offline browser is unsupported.

## Screenpipe Engineering Review

[Project context, implementation and review path](docs/SCREENPIPE_REVIEW.md).
[Microphone lifecycle details](docs/MICROPHONE_SESSION_LIFECYCLE.md).
