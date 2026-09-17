# Hospi-Pet

A local-first encounter notebook that keeps a visit's voice recording, document photos and written notes together for review.

Record real audio, attach document photos and your own notes, review the sources,
then finalize and reopen an encounter from local history. Drafts and captured media
survive refresh. Use synthetic information; this is not a clinical record system.

The engineering focus is reliable capture across repeated encounters: explicit
media ownership, stale-callback protection, atomic local saves and deterministic
browser tests that encode and decode real media using synthetic devices. Captured
sources have a lifecycle journal, provenance links and SHA-256 integrity fingerprints.

## Run locally

Use Node **22.23.2** (pinned in `.nvmrc`) and npm. **`main` is canonical.**

```bash
git clone https://github.com/odoisveryverygood/Hospi-Pet.git
cd Hospi-Pet
npm ci
npm run dev
```

Open <http://127.0.0.1:5173>. No environment variables, backend, account or API key
are required. If you use nvm, run `nvm install && nvm use` inside the checkout
before `npm ci`.

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

**Capture → events → sources → provenance → review → replay.**

- Existing microphone/camera controllers own tracks, listeners, recorder and timers.
- Encounter/session identity prevents retired callbacks attaching to a newer encounter.
- A typed, content-free journal makes asynchronous ordering inspectable.
- SHA-256 fingerprints are stored with sources and checked on reopen; failures are visible.
- Atomic IndexedDB revisions reject silent competing-tab overwrites.
- A pure replay projection never reacquires hardware or reconstructs private content.
- Deterministic unit and Chromium tests exercise real controller/storage boundaries.

Normal capture stays simple. Open **Capture timeline & provenance** below an
encounter for Timeline, Provenance, Replay and Privacy; **Developer diagnostics**
shows owned resources, pending writes, ignored callbacks and invariant failures.
Provenance can export a validated metadata-only JSON manifest.

To explore failures, run the same development server and open
<http://127.0.0.1:5173/?lab=1>. **Capture Lab** arms one fault at an actual media or
storage boundary. Try microphone-delay → Start → All encounters → create another
encounter → Release pending callbacks. No source should cross that boundary.
Lab adapters and network instrumentation are excluded from production builds.

[Capture architecture](docs/CAPTURE_ARCHITECTURE.md) explains the event vocabulary,
provenance, bounded history and replay. [Fault matrix](docs/CHAOS_MATRIX.md) maps
reproducible failures to their assertions.

## Architecture

```text
History / Capture / Review views
             ↓
    Encounter workspace
       ↙           ↘
Media controllers → session events → sources + fingerprints
(mic + camera)          ↓
                Encounter → atomic IndexedDB row
                       ↓
                Provenance / lifecycle replay / metadata export
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
npx playwright install --with-deps chromium
npm run test:browser
npm audit
```

`npm run check` combines typecheck, lint, unit/integration tests and build.
[CI](.github/workflows/ci.yml) runs separate check and Chromium jobs on pushes to
`main` and pull requests targeting `main`. Hosted results appear in the
[Actions tab](https://github.com/odoisveryverygood/Hospi-Pet/actions/workflows/ci.yml);
local verification does not establish a hosted CI result.
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
  media backup/import, sync or storage durability guarantee. Keep the same site address/port.
- One clip per encounter; 60 seconds / 8 MiB, four photos ≤1 MiB each, 20 encounters.
- Events are bounded to 512 per encounter; omitted history is explicit. Replay is a
  lifecycle projection, not full event-sourced content reconstruction.
- Hashes are integrity fingerprints, not signatures or authentication. Metadata export
  excludes media and note text; there is no import or media archive.
- No transcription, OCR, medical inference or care-graph backend in the maintained app.
- Chromium is automated. Physical devices, OS prompts, Safari/Firefox and long-running
  capture have not been validated. Pending permission prompts need browser interaction.
- Loaded capture works offline; opening the app from a cold offline browser is unsupported.

## Further technical context

[Current verification and measurements](docs/ADVANCED_VERIFICATION.md).
[Optional Screenpipe engineering review](docs/SCREENPIPE_REVIEW.md).
[Microphone lifecycle details](docs/MICROPHONE_SESSION_LIFECYCLE.md).
