# Repository audit

> Historical baseline from the first engineering review. The second pass started
> at `15b03bc5e4b05c8996e65ba5d03fbb938c1d45c9` on the same branch and built the
> maintained encounter product around that controller. Current architecture and
> checks are in [PRODUCT_ARCHITECTURE.md](PRODUCT_ARCHITECTURE.md) and
> [VERIFICATION.md](VERIFICATION.md). Original findings below remain evidence,
> not a description of the current root UI.

## Scope and provenance

Inspected on 2026-09-15 (America/Los_Angeles), before changing tracked source.
Remote: `https://github.com/odoisveryverygood/Hospi-Pet.git`.
Fresh clone: branch `main`, HEAD `97b5beb0767fc47f4e62240b00b2d1c48ba00683`, clean.
`main` contains only README, CONTRIBUTING, and PARTNER_SETUP. `integration`
also contains no application. Other fetched branches: `backend-jac`,
`frontend-ui`, `codex/jac-fullstack-release`.

The actual combined application is on `codex/jac-fullstack-release`, HEAD
`82b92118bace890f42ebba09435c8ed92b94ba1a`. Local repair branch:
`review/microphone-lifecycle`, based on that commit, initially clean.
21 commits and 146 tracked files were available. No AGENTS.md was present.
No push, deployment, or history rewrite is part of this work.

## Architecture actually present

Paths below refer to the original application, now preserved at `legacy/jac-app/`.

- Jac 0.34.7 web application: `main.jac`, `jac.toml`; client-owned Jac compiles
  to browser JavaScript/React. `frontend.impl.jac` has 2,638 lines and mixes
  microphone, speech recognition, camera, graph API, mock paths, and UI state.
- Typed graph nodes/edges and walkers implement synthetic encounter ingestion,
  candidate verification, provenance, care-plan projection, capture metadata,
  transcript ingestion, document processing, and intelligence projections.
  Endpoint functions wrap these walkers. This is substantive implementation,
  not merely README text; it is not evidence of clinical correctness.
- Browser adapter uses Jac runtime login/signup and endpoints. It creates
  random synthetic credentials in localStorage. A shared logical encounter
  name is used by the frontend; authorization depends on Jac root context.
- Optional server byLLM seams use model/key environment variables; disabled
  and MockLLM paths exist. Pillow and server runtime modules come from Jac's
  dependency closure. No Python requirements lock or npm lock was committed.
- Camera requests video-only getUserMedia, binds a video element, captures a
  canvas image, validates image uploads (1 MiB cap), then calls Jac processing.
  Synthetic assets and deterministic extraction are included. This is not a
  verified general OCR service. Speech synthesis reads generated script text.
- Vercel rewrites hardcode a Railway backend; install scripts download a
  versioned Jac installer through a mutable main-branch URL. These deployment
  configurations are historical and are no longer at the repository root.

## Microphone and session lifecycle

There was **no MediaRecorder implementation**. The UI's “Start Recording”
acquires an audio stream and starts browser SpeechRecognition when available.
Final text is submitted to the backend. Audio playback was not implemented.

State is spread across reactive booleans/fields, a mutable `voice_runtime`
dictionary, and sessionStorage. Backend capture creation precedes the browser
permission request. Backend `StartCaptureSessionWalker` rejects another active
capture with `ACTIVE_CAPTURE_EXISTS`. Cancellation/finalization are therefore
necessary on both sides; clearing browser UI alone cannot release that gate.

Existing cleanup stops tracks and recognizers and cancels timers on component
exit. Permission callbacks compare stored capture IDs and stop late streams.
These are useful defenses, but do not cover the whole lifecycle:

1. `forceFinishVoiceRecognition` checks only nonempty capture ID. Both `onend`
   and a 1.5-second timeout can call it, and the forced path does not clear the
   timeout. It can issue duplicate finalize calls or touch a newer runtime.
2. `receiveRuntimeTranscriptChunk`, `receiveCaptureFinalized`, and bootstrap
   callbacks have no generation check. Old responses can mutate current data.
3. `stopVoiceCapture` calls recognition.stop without exception protection;
   an exception skips track cleanup. Runtime clearing is inside the stream
   branch, so state can survive when a stream is absent.
4. `voicePermissionGranted` and failure handlers lose the timer handle without
   clearing the permission timeout. The token check limits damage but does
   not remove the timer.
5. Component exit does not cancel the server-side capture. A later same-root
   encounter can encounter the active-capture gate. Backend failures and
   overlapping reset/cancel/start actions are not fully coordinated.
6. The older transcript queue functions remain beside newer runtime queue
   functions; multiple finalization implementations increase ambiguity.
7. Camera attachment uses an unowned delayed callback. Camera request tokens
   help with late grants, but do not establish complete teardown correctness.

These are source-observed risks, not a claim that every race was reproduced
in the legacy browser. The new controller's tests reproduce the relevant
stale-callback and resource-ownership failure classes deterministically.

## Historical claim versus evidence

The user recalls fixing a stale session that blocked microphone access.
History supports capture/session recovery work:

- `0ed7023` adds late-permission handling and backend cancellation on failure.
- `f7d0881` adds runtime resource/queue handling and capture-ID propagation.
- `be40a7b` stores an active capture in sessionStorage, changes stop to retrieve
  it there, and removes the prior identity/finalization guard and queue wait
  from forced finalization.
- `82b9211` captures the backend-returned ID in local `new_capture_id` and uses
  it immediately instead of rereading assigned reactive state.

These diffs are present. There is no historical failing browser test, incident
trace, or controlled before/after run proving the exact original root cause.
Do not call the new MediaRecorder demo a historical implementation or claim
that this work reproduced and fixed the original incident end to end.

## Baseline verification (original application, before edits)

Machine: macOS arm64; Jac 0.34.7 standalone, Node 25.4.0, npm 11.7.0.

| Command | Observed result |
| --- | --- |
| `jac install` | PASS, exit 0; Python closure and 223 npm packages installed; Bun 1.3.11 |
| `jac fmt . --check` | PASS, exit 0, 69 Jac files |
| `jac check .` | FAIL, exit 1; 1 error, 680 warnings; E1053 at api/backend.cl.jac:196, `new(FileReader)` |
| `jac check . --lint` | Exit 0, **13 warnings** (parameter counts and unnecessary None returns) |
| `jac test -d tests/ -v` | BLOCKED: no output/completion within 180 seconds; terminated by timeout |
| `jac build --client static main.jac` | PASS, exit 0; static client bundle emitted despite separate typecheck failure |
| `jac run tests/server_integration.jac` | FAIL, exit 1, NoneType subscript at line 68 after client reload |
| `jac run tests/multimodal_server.jac` | FAIL, exit 1, NoneType capture subscript at line 45 after reload |
| `jac run tests/intelligence_server.jac` | FAIL, exit 1, empty translated transcript at line 77 after reload; CAPTURE_NOT_FOUND observed |

Legacy end-to-end browser behavior, provider calls, and original README's
720-step/nine-cycle claims were not verified. Their presence is not test evidence.

## Coverage, incomplete and unused surfaces

Backend tests include meaningful assertions about graph provenance, validation,
ordered chunks, cancellation, endpoints, and root isolation. Preserve them.
`frontend.test.cl.jac` instead duplicates state helpers and contains assertions
such as `"granted" == "granted"` and locally setting stream_active to False.
Those tests do not exercise microphone devices, listeners, timers, or the UI.
There was no browser acceptance harness or credible microphone regression suite.

`mock_data/` has no imports in application modules (source-search observation).
Older and newer transcript queue/finalization methods coexist. Extensive prior
handoff/readiness documents contain claims that are not current verification.
None of this research was deleted to reduce the file count.

## Fresh-clone blockers and privacy

- Default branch has no application; old README uses an author-specific absolute
  executable path and starts `--no-client`, which gives a reviewer no UI.
- No locked client dependency graph, browser acceptance commands, or single
  tested review workflow. API/login/backend availability gates microphone use.
- Typechecking and persistence/reload integration currently fail as above.
- Browser SpeechRecognition may use a browser/vendor remote service. Old UI
  “local only / raw audio never uploaded” language is too broad. The new demo
  does not instantiate SpeechRecognition and has no upload code.
- Original synthetic auto-login stores credentials locally; transcript text is
  sent to Jac. Real patient data must not be used. The full app has not had a
  security review; session IDs alone are not authorization.
- Pattern scan across 21 reachable commits / 240 distinct blobs found no
  private-key blocks, GitHub/OpenAI-shaped tokens, or AWS access-key patterns.
  Ten assignment matches were environment interpolation/documentation
  placeholders, manually inspected. This bounded scan is not proof that all
  possible secrets are absent. Test passwords are synthetic fixtures.

## Repair priorities and disposition

1. Make an honest runnable entry point with no credentials or backend gate.
2. Give microphone acquisition, recorder, listeners, timers, and bytes one owner.
3. Invalidate retiring owners before cleanup and verify stale-callback rejection.
4. Test native browser recording and repeated sessions, beyond API test doubles.
5. Bound memory/time, release playback URLs, handle page teardown, document limits.
6. Separate historical research from current supported demo and verification.

At the end of the first pass, the maintained review surface was the root TypeScript capture demo. Original
tracked application and documentation are isolated under `legacy/jac-app/`;
their contents and useful tests remain preserved. They are not an alternative
supported implementation. The new demo and all new tests use the single
`src/microphone-session.ts` controller. No second mock demo controller exists.
This is a scoped replacement of the review capture surface, not an integration
of MediaRecorder into the old clinical graph. See VERIFICATION.md for final gates.
