# Pre-multimodal baseline

Verified before the multimodal feature-completion phase.

## Repository state

- Repository: `/Users/aradhyamishra/pa-co-caregraph`
- Branch: `backend-jac`
- Commit: `568c8bbc7e3c9d6475423c6837bae9b5c9a0b780`
- Remote: `https://github.com/odoisveryverygood/pa-co-caregraph.git`
- Jac: `0.34.7 (Darwin arm64)`
- Tracked changes before work: none
- Untracked source before work: none
- Remote branch matched the local commit
- Non-destructive backup: `/tmp/pa-co-pre-275-backup/`

## Baseline gates

| Gate | Result |
|---|---|
| `jac fmt . --check` | PASS — 16/16 files formatted |
| `jac check .` | PASS — 16/16 files |
| `jac test -d tests/ -v` | PASS — 58/58 tests |
| `jac run tests/p0_demo.jac` | PASS — three complete deterministic cycles |
| `jac run tests/ai_modes_demo.jac` | PASS — disabled, missing-key fallback, MockLLM, and mock-output modes |

The baseline used only the fictional Maya Rivera demonstration. No provider
credential was printed, created, or required.

## Preserved behavior

- Persistent typed care graph and deterministic reset
- Candidate verification boundary
- Care-gap detection and audited resolution
- Approved-only patient plans and graph-grounded answers
- Contradiction preservation
- Provenance and traversal traces
- Session isolation
- Optional typed AI with deterministic fallback
- Generated Jac endpoints and authenticated-root fixture

This baseline is the rollback and regression reference for the multimodal
phase. Existing public action names and response fields remain compatibility
requirements.
