# Verification record

Executed locally on 2026-09-15, macOS arm64. Maintained demo runtime:
Node **22.23.2**, npm **11.7.0**, TypeScript **5.9.3**, Vite **8.3.0**,
Vitest **5.0.1**, Playwright **1.63.0**, bundled Chromium.

## Maintained microphone demo

| Command | Actual result |
| --- | --- |
| `npm install --no-fund` | PASS, exit 0; lockfile created; npm audit reported 0 vulnerabilities |
| `npm run typecheck` | PASS, exit 0, no diagnostics |
| `npm run lint` | PASS, exit 0, no warnings (`--max-warnings 0`) |
| `npm test` | PASS, exit 0, 24 tests in 1 file |
| `npm run build` | PASS, exit 0, TypeScript gate and Vite production bundle |
| `npx playwright install chromium` | PASS, exit 0; browser available |
| `npm run test:browser` | PASS, exit 0, 6 browser integration/acceptance tests |
| `npm run check` | PASS, exit 0; typecheck + lint + unit tests + build |
| `npm audit --json` | PASS, exit 0, 0 reported vulnerabilities at this run |
| `git diff --check` | PASS, exit 0 |

Browser warning observed: **“The 'NO_COLOR' env is ignored due to the
'FORCE_COLOR' env being set.”** This comes from inherited runner environment
settings. No application page exception or external HTTP request was observed
in the three-session acceptance test. This is a bounded observation, not a
security certification. Screenshot of the completed three-session flow was
visually inspected; the UI displayed idle, generation 3, and inactive capture.

The six browser tests cover native repeated recording/decoding, duplicate UI
actions, injected denial then native retry, cancel followed by a late native
stream, real navigation cleanup, and synthetic page-cache restoration.
There is no separate server integration suite for the new app: it has no server
API. The browser suite is its integration test. Automated media is synthetic;
no physical microphone or OS permission dialog was tested.

## Fresh clone

**PASS for the maintained demo.** Source/test baseline:
`35c109265003f7f89521c3a38d71bda6618ff217`. Subsequent review documentation does
not change that tested implementation.

A new checkout was made with:

```bash
git clone --no-local --branch review/microphone-lifecycle <local-repository> <empty-directory>
```

It started without node_modules, build outputs, `.env`, or Jac state. Provider
key/mode environment variables were removed for verification. From that checkout,
each of these commands completed with exit 0:

```bash
npm ci --no-fund
npm run typecheck
npm run lint
npm test
npm run build
npx playwright install chromium
npm run test:browser
```

The clone ran all 24 unit tests and all 6 browser tests successfully. Its
Playwright webServer started the application on localhost automatically and
stopped it after testing. npm reported 0 vulnerabilities; the same color-env
warning appeared. This used an existing local Node installation and shared npm
and Chromium download caches. It was a fresh checkout/dependency installation,
not a newly provisioned operating system, Linux run, or air-gapped install.

The deliverable Git bundle is self-contained Git history; it does not vendor npm
packages or browsers. Installation requires registry/download access. The GitHub
remote default branch remains unchanged and does **not** contain this demo.

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

## Final engineering review

- Capture resources have a single owner; retired callbacks cannot act on a new owner.
- State and ownership tests cover start/stop races, timeouts, failures, and teardown.
- Real Chromium encoding/decoding complements boundary doubles in unit tests.
- The review flow is deliberately bounded to short sessions, not continuous capture.
- Logs/UI contain metadata and error messages, not transcript or audio contents.
- No paid provider, deployment, public upload, or clinical success is claimed.
- P0: none found in the maintained demo during this review.
- P1 outside this surface: legacy typecheck and persistence/reload failures;
  the original full-stack microphone path is not rehabilitated or browser-verified.
- P2: physical hardware/OS permission and other-browser validation; unresolved
  permission prompts require browser interaction/reload; historical causality
  remains unproven. The current remote main is not the distributable review branch.
