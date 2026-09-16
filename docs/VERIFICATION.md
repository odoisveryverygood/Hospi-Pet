# Verification record

Product pass: 2026-09-15 (America/Los_Angeles), macOS arm64, Node **22.23.2**,
npm **11.7.0**, TypeScript **5.9.3**, Vite **8.3.0**, Vitest **5.0.1**,
Playwright **1.63.0** and its bundled Chromium.

Starting point: clean `review/microphone-lifecycle` at
`15b03bc5e4b05c8996e65ba5d03fbb938c1d45c9`. The original maintained baseline was
rerun before editing: 24 controller tests, 6 Chromium acceptance tests, typecheck,
lint and build passed. This pass adds a maintained encounter product around it.

## Current maintained product

The following ran successfully in a new checkout of the complete source/test
commit `9c65efefe3ece8f91954cd31a38f5430198abdd2`. Later documentation is separate
from this implementation. Final-handoff logs also record verification of the
subsequent documentation commit.

| Command | Actual result |
| --- | --- |
| `npm ci` | PASS, exit 0; added 136 packages, audited 137; 0 vulnerabilities |
| `npm run typecheck` | PASS, exit 0; no diagnostics |
| `npm run lint` | PASS, exit 0; no warnings (`--max-warnings 0`) |
| `npm test` | PASS, exit 0; 60 tests in 4 files |
| `npm run build` | PASS, exit 0; TypeScript gate and Vite production bundle, 13 transformed modules |
| `npx playwright install chromium` | PASS, exit 0; browser available |
| `npm run test:browser` | PASS, exit 0; 16 Chromium tests |
| `npm audit` | PASS, exit 0; 0 vulnerabilities reported for the maintained lockfile |
| `git status --porcelain` in fresh checkout | Empty after verification |
| `git diff --check` in working checkout | PASS, exit 0 |

`npm run check` also passed in the working checkout. npm reports **40 packages
looking for funding**. Playwright's processes warn: **“The 'NO_COLOR' env is ignored
due to the 'FORCE_COLOR' env being set.”** This inherited environment warning is
not hidden or counted as a lint warning. No application page exception occurred
in the complete encounter or responsive workflow tests.

## Test scope

| Suite | Count | Meaningful assertions |
| --- | ---: | --- |
| Existing microphone controller | 24 | Unchanged tests: grant/deny/retry, 25 repeated sessions, recorder failures, late callbacks, limits, timers/listeners/tracks and disposal |
| Camera controller | 15 | Native-boundary doubles: grant/capture/cleanup, 20 repeats, deny/retry, cancel/late stream, stale encoding, teardown, timeouts, disconnect, invalid output and reentrant cancellation |
| Encounter workspace | 12 | Both real controllers: source binding, finalize/new encounter, stale media, failed writes/finalization, edits during saves, deletion ordering, timer cleanup and photo limit |
| IndexedDB/domain | 9 | fake-indexeddb transaction semantics: Blob roundtrip, delete/clear, conflicting revisions, simultaneous writes, corrupt rows, capacity, validation and source manifest |
| Original browser regressions | 6 | Native recording/decoding repeated 3 times, rapid actions, injected denial, late native stream, real navigation and synthetic page-cache restoration |
| Product browser acceptance | 6 | Two encounters with native audio/photo encoding, decoding after reload, isolation/deletion, camera retries/teardown, quota recovery, competing tabs, corrupt data and offline operation |
| Responsive browser flows | 4 | Desktop/tablet/mobile full workflows plus mobile permission errors, overflow assertions and focus checks |

The root app has no backend API. Workspace/storage tests and the browser suite
are its integration coverage; there is no hidden unrun server test gate.
Media permissions/errors are injected where required for deterministic failures.
Happy paths use Chromium's actual MediaRecorder and canvas with fake devices,
not a mock recorder or prepared audio file. Decoding is required before and after
persistence. An offline test observes zero HTTP requests after initial loading
while capturing, finalizing, reopening, playing and clearing an encounter.
This does not prove anything about external browser extensions or OS services.

## Visual and interaction review

Opened the production build in an actual in-app browser and exercised creation,
written notes, review, finalization, reload, reopen and deletion of synthetic test
data. Media functionality was exercised by the native Chromium test suite.
Inspected generated browser screenshots at **1280×900**, **820×1100**, and
**390×844** viewport sizes for empty history, create form, idle/recording capture,
camera preview, attached sources, review, expanded record/diagnostics/privacy,
finalization and populated history. Mobile permission-error state was also
inspected. Screenshots are reproducible via `tests/browser/visual.spec.ts`.

No horizontal clipping/overflow was observed in those states. Controls wrap at
mobile width; review becomes a single column. Fixes made during review: do not
allow Take photo before a frame loads, place focus on the new review/finalized
heading, retain visible focus on controls, and make an empty review explain its
disabled finalization action. Native audio controls remain browser supplied.
This is not a screen-reader certification or a physical mobile-device run.

## Fresh checkout method

**PASS for the maintained product.** Used:

```bash
git clone --no-local --branch review/microphone-lifecycle <local-repository> <empty-directory>
cd <empty-directory>
npm ci
npm run typecheck
npm run lint
npm test
npm run build
npx playwright install chromium
npm run test:browser
npm audit
```

The checkout started without node_modules, generated output, `.env`, or Jac state.
Provider/key/token environment variables were removed. Existing local Node,
registry and Chromium caches were reused. This verifies fresh source/dependency
installation on macOS, not a newly provisioned operating system or Linux host.
Playwright started/stopped its own application server. No hosted CI run is claimed.
The Git bundle includes branch history, not vendored dependencies or a browser.
The remote default branch was not changed or published by this pass.

## Final engineering review

- Product coherence: history → capture → source review → finalization → reopened
  local record is a working flow; original care-graph ideas are mapped explicitly.
- Capture depth: owner/generation guards exist below UI state. Both controllers
  release tracks and owned timers/listeners on completion, failure and disposal.
- Data reliability: atomic source writes, revision conflicts, unsaved-state/error
  recovery and delete/save ordering are tested; storage is not called a backup.
- Privacy: no maintained upload/transcription/analytics path; real Blobs stay in
  IndexedDB until deletion. Captured content is absent from developer diagnostics.
- Evidence integrity: 146 legacy files compared byte-for-byte with `82b9211`,
  **zero differences**. Original microphone test file unchanged from `15b03bc`.
- A bounded credential-pattern scan of maintained source, tests and manifests
  found no private-key/GitHub/OpenAI/AWS-shaped tokens. It is not a comprehensive
  security audit. npm audit covers the maintained dependency graph, not Jac's.
- No P0/P1 blocker found for this bounded local prototype. Remaining limitations:
  hardware/OS permissions and other browsers unverified; no transcription/OCR,
  graph backend, encryption, export/backup, or continuous/background capture.
  Pending browser permission prompts can require dismissal/reload. Historical
  incident causality and the original Jac failures remain unresolved.

## Original Jac application — failures are preserved and disclosed

These checks ran before modifying tracked source, at original `82b9211`.
The full app was isolated rather than declared repaired. Commands now belong
in `legacy/jac-app/` if investigating the original behavior.

| Command | Actual baseline result |
| --- | --- |
| `jac install` | PASS, exit 0 |
| `jac fmt . --check` | PASS, exit 0, 69 files |
| `jac check .` | FAIL, exit 1; 1 error, 680 warnings; E1053 at api/backend.cl.jac:196 |
| `jac check . --lint` | Exit 0 with 13 warnings |
| `jac test -d tests/ -v` | BLOCKED: exceeded 180-second timeout with no output; terminated |
| `jac build --client static main.jac` | PASS, exit 0; this did not establish whole-project type safety |
| `jac run tests/server_integration.jac` | FAIL, exit 1; NoneType after reload at line 68 |
| `jac run tests/multimodal_server.jac` | FAIL, exit 1; NoneType capture after reload at line 45 |
| `jac run tests/intelligence_server.jac` | FAIL, exit 1; empty translated transcript after reload at line 77 |

No historical README benchmark/test count is adopted as a current result.
All **146 original tracked files** were compared byte-for-byte with `82b9211`
after relocation: **zero content differences**. See [REPO_AUDIT.md](REPO_AUDIT.md)
for exact history, credential-scan scope, dependencies, and privacy findings.
