# Advanced capture verification

2026-09-16 (America/Los_Angeles). Starting commit:
`aafca7a7ae642698212c9153f6fd00e7c8680db9` on clean local `main`.
Application and test snapshot:
`28015e02804e312a483ff19537debf32c2d3fbd1`.
Documentation and the standalone production smoke helper are committed afterward;
they do not change the application or dependency graph.

## Reproduction

Use Node **22.23.2** and npm **11.7.0**. The normal demo remains
`npm ci && npm run dev`, with no credentials or application environment variables.

```bash
npm ci
npm run typecheck
npm run lint
npm test
npm run build
npm audit
npx playwright install --with-deps chromium
npm run test:browser
```

`npm run check` still combines typecheck, lint, unit/integration tests and build.
For an additional production smoke, serve the build in one terminal:

```bash
npm run build
npm run preview -- --port 4173
```

In another terminal run:

```bash
node --experimental-strip-types tests/production-smoke.ts
```

This launches Chromium with synthetic media devices, records, fingerprints and
finalizes a source, checks for page errors and verifies that `?lab=1` does not
expose Capture Lab in the production app. It uses an isolated browser context.

## Results

A fresh `git clone --no-local --branch main` of the local repository was verified,
then fast-forwarded to the final application/test snapshot above. Dependencies
were reinstalled with `npm ci`. This is fresh source and dependencies on macOS
arm64, reusing installed runtime/browser/download caches; it is not a fresh OS or
Linux/hosted GitHub Actions result.

| Command | Actual result |
| --- | --- |
| `npm ci` | PASS, exit 0; 136 packages installed, 137 audited |
| `npm run typecheck` | PASS, exit 0 |
| `npm run lint` | PASS, exit 0; zero warnings allowed |
| `npm test` | PASS, exit 0; 91 tests across six files |
| `npm run build` | PASS, exit 0; 19 modules |
| `npm audit` | PASS, exit 0; zero vulnerabilities |
| `npx playwright install --with-deps chromium` | PASS, exit 0 on macOS |
| `npm run test:browser` | PASS, exit 0; all 24 Chromium tests, 1.7 minutes |
| `node --experimental-strip-types tests/production-smoke.ts` | PASS, exit 0 against the production preview |
| `actionlint .github/workflows/ci.yml` | PASS with actionlint 1.7.12 |
| `git diff --check` | PASS |

Warnings/informational output: npm reports 40 packages seeking funding; Vitest
suggests transform caching; Playwright reports that `NO_COLOR` is ignored when
`FORCE_COLOR` is set. None was suppressed. An initial browser run had one navigation
test fail while application source was being edited; subsequent frozen-source
runs passed without weakening that test. A TypeScript error in the new browser
timer probe was corrected before the final checks.

Hosted CI is **not verified**. These commits have not been pushed. The earlier CI
workflow remains configured for checks and Chromium as separate jobs; its Linux
system dependency installation must still run on GitHub after an authorized push.

## Test coverage and actual browser evidence

The original **60 unit/integration tests and 16 browser tests are unchanged**.
The current suites contain **91 unit/integration tests and 24 browser tests**,
plus the standalone production smoke helper.

New coverage includes event ordering and clock reversal, strict payload/schema
rejection, bounded journals, note-checkpoint coalescing, actual source/review
relationships, deterministic replay prefixes, a known SHA-256 vector, same-size
Blob mutation, hash failure before IDB writes, legacy data, and SVG rejection.
The fault tests drive the real controllers/workspace through delayed media,
encoder and storage ports. They assert cleanup, unchanged successor encounters,
visible save failure, pending-write counts and runtime invariant failures. Lab
queue limits and reset/disposal epochs have their own regression tests.

The browser scenario records and decodes native Chromium audio, captures a native
fake-camera frame, inspects provenance, finalizes, replays without opening devices,
redelivers retired recorder callbacks after switching encounters, reloads and
verifies hashes, exports the same validated manifest twice, and deletes local
data. Other tests detect corrupted media and recover by replacing it, exercise the
network observer with real fetch/XHR calls, and inspect replay timer cleanup.

All five engineering panes were exercised at **1280, 820 and 390 px**. Screenshots
were visually inspected; a selected-tab hover contrast defect was fixed and
rechecked. No horizontal page overflow was observed in the tested screens. The
normal capture/review/history screens remain covered by the original visual suite.
This is not a comprehensive accessibility audit or physical-device certification.

## Measured costs and limits

The earlier production bundle contained 46.48 kB JavaScript (13.40 kB gzip) and
10.80 kB CSS (3.13 kB gzip). The current build contains **72.44 kB JavaScript
(20.84 kB gzip)** and **12.53 kB CSS (3.54 kB gzip)**. These are Vite's reported
sizes, not a claim of improved performance. No runtime npm dependency was added.
The production asset contains neither the fault adapter nor network observer
implementation; its UI also rejects lab activation in the smoke check.

One fresh-checkout development-browser run measured **421 ms** from navigation
to the visible empty history. After five native microphone sessions in one
encounter: **50 events**, **15,974 journal bytes** and
**2,889 bytes** in the retained final audio clip. Every sample had
**zero live tracks** and **one playback object URL**. Earlier recorders and media
listeners were also released at each step, as asserted by the browser probe.

The five-capture measurement probes native tracks, recorders, media listeners and
object URLs. The test's own probe intentionally retains references to old native
objects, so this is **not a heap/GC leak benchmark**. Journal/media sizes are logical
payload sizes, not IndexedDB's physical disk footprint. Startup includes automation
latency on one local development-server run, not a cross-machine benchmark.

The journal retains 512 events plus an omitted counter; notes coalesce at write
boundaries. Runtime diagnostics retain 64 session bindings/signals, the lab holds
at most eight callbacks and retains at most two recorder callbacks for redelivery.
The existing 20-encounter/12-MiB-media-per-encounter ceilings bound logical storage;
browser quota can be lower and a failed save stays explicit.

`npm test` generates `test-results/chaos-matrix.json`; browser tests generate
`test-results/capture-measurements.json`, `test-results/visual/` screenshots and
failure traces under `test-results/browser/`. These artifacts are ignored by Git.

## Security, privacy and evidence boundaries

- Dynamic event text uses DOM text nodes; dynamic provenance strings are escaped.
  IndexedDB journals and fingerprints have strict validators; manifests have an
  exact allowlisted schema and checked relationships. There is no import path.
- Playback/image URLs are revoked on replacement/unmount. Export URLs are revoked
  on replacement/view disposal. Raster photo types are allowed; SVG is rejected.
- Hash mismatches surface outside developer mode and block finalization. A digest
  is not authentication: changing both bytes and digest defeats this check.
- Diagnostic events, runtime fault observations and network counters contain no
  audio/image bytes or note text. Manifest exports omit title and note content.
  IDs, timestamps and size/length metadata still deserve care.
- Default capture has no backend, analytics or transcription provider. The optional
  observer covers page fetch/XHR during capture, not assets, WebSockets, extensions
  or OS requests. Loaded offline capture remains tested; cold offline startup is not.
- A tracked-file scan found no matches for the checked private-key, GitHub-token,
  AWS-key or OpenAI-key patterns. This is a scoped pattern scan, not a universal
  guarantee. Maintained Markdown has no personal absolute paths.
- All 146 archived Jac files and every original test remain unchanged. The new
  event/provenance/integrity system is an improvement from this pass, not historical
  Jac functionality or proof of the exact original stale-session incident.

Remaining limitations: Chromium automation only, synthetic browser devices,
unverified physical/OS permission behavior, no continuous/background capture,
partial replay after journal limits or abrupt exits, no encryption/media backup,
no configured transcript provider, no restored care-graph backend, and no hosted
CI result for these unpublished commits.
