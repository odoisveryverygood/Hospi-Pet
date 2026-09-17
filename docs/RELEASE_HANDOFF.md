# Release handoff verification

Historical cleanup snapshot. Subsequent capture-system changes and checks are
recorded in [ADVANCED_VERIFICATION.md](ADVANCED_VERIFICATION.md).

Release cleanup, 2026-09-16. This pass changes documentation, ignore rules and CI;
application code, dependencies, tests and the 146-file Jac archive are unchanged.

## Canonical branch

GitHub's default branch is `main`. Before editing, fetched `origin/main` and
`origin/review/microphone-lifecycle` both resolved to
`32e069d74f4ed87d259ffe0aff1866d1d03abbfe`; their trees were identical and included
the complete maintained encounter prototype. The local `main` was fast-forwarded
to that existing commit. No history was rewritten or branch deleted.

The [README](../README.md) now uses a normal GitHub clone. Historical branch names
in the audit and dated [verification record](VERIFICATION.md) identify earlier
work; they are not setup requirements.

## CI configuration

[ci.yml](../.github/workflows/ci.yml) triggers on pushes to `main` and pull requests
targeting `main`. Both jobs use Ubuntu 24.04, the Node version in `.nvmrc`,
lockfile-based npm caching and a clean `npm ci` installation.

- `checks`: typecheck, lint, unit/integration tests, build and dependency audit.
- `browser`: install Chromium with OS dependencies, then run all browser tests.
  Failure artifacts are retained for seven days.

Actions are pinned to verified upstream release commits. Repository permissions
are read-only and checkout credentials are not persisted. Jobs have timeouts;
new commits cancel superseded runs. No required check uses `continue-on-error`.
`npm run check` already combines typecheck, lint, unit/integration tests and build,
so its existing definition was retained.

## Local checks

Run on macOS arm64 with Node **22.23.2** and npm **11.7.0**, using the existing
browser/download caches. This is a local checkout verification, not a new Linux
machine or a hosted GitHub Actions execution.

| Command | Result |
| --- | --- |
| `npm ci` | PASS; 136 packages installed, 137 audited, zero vulnerabilities |
| `npm run typecheck` | PASS; no diagnostics |
| `npm run lint` | PASS; zero warnings permitted |
| `npm test` | PASS; 60 tests in four files |
| `npm run build` | PASS; TypeScript gate and production build, 13 modules |
| `npm audit` | PASS; zero vulnerabilities |
| `npx playwright install --with-deps chromium` | PASS on macOS; Linux system dependency installation remains unverified |
| `npm run test:browser` | PASS; all 16 Chromium tests, 1.4 minutes |
| `actionlint .github/workflows/ci.yml` | PASS with actionlint 1.7.12; no diagnostics |
| `git diff --check` | PASS |

Output includes npm's 40-package funding notice and Vitest's transform-cache
performance suggestion. Playwright emits Node's warning that `NO_COLOR` is ignored
when `FORCE_COLOR` is set. These messages were not suppressed.

Actionlint validates workflow YAML, GitHub Actions fields and expressions. It does
not execute the workflow. GitHub Actions could not be executed locally; Linux
runner behavior and hosted success must be established on GitHub.

## Publication status at this review

The published starting commit had **zero check runs**, and GitHub returned no
workflow runs. This cleanup is committed locally only; it does not claim a hosted
pass or change repository metadata. After a separately authorized push to `main`,
inspect the [CI runs](https://github.com/odoisveryverygood/Hospi-Pet/actions/workflows/ci.yml)
and confirm **both jobs pass for the exact pushed commit**. Local success is not
hosted CI evidence.

## Repository hygiene and landing page

No generated builds, screenshots, test reports, dependency directories or bundles
were tracked. Ignore rules additionally cover handoff bundles, Playwright blob
reports/cache, editor swap files and OS junk. Maintained Markdown has no personal
absolute paths or temporary output-directory dependencies. Historical local paths
remain in the clearly archived Jac documents; the archive was not rewritten.
Tracked files had no matches for the checked private-key, GitHub-token, AWS-key or
OpenAI-key patterns. This pattern scan is not a guarantee that every possible
secret format is absent. The sole tracked environment example contains blank
provider values in the legacy archive; maintained setup needs none.

GitHub's existing description still presents the old Jac care-graph concept.
Recommended replacement (not applied):

> Local encounter notebook for voice recordings, document photos and notes, with tested browser media ownership and session isolation.
