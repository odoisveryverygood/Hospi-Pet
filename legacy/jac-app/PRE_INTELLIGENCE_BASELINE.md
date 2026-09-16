# Pre-intelligence baseline

Recorded on 2026-07-26 before adding live translation or encounter
intelligence.

## Repository state

- Repository: `/Users/aradhyamishra/pa-co-caregraph`
- Branch: `backend-jac`
- Upstream: `origin/backend-jac`
- Rollback commit: `655ee7f`
- Remote: `https://github.com/odoisveryverygood/pa-co-caregraph.git`
- Worktree before the gate: clean
- Untracked non-ignored files before the gate: none
- Jac: `0.34.7 (Darwin arm64)`
- Frontend-owned files changed: none

The ignored synthetic Jac data store was copied to
`/tmp/pa-co-pre-intelligence-data.v5V3pe/data` before the required cleanup.
`jac clean --data --force` then reported no remaining build artifact
directories. The backup contains only resettable synthetic demonstration
state and is not tracked.

## Verification results

| Check | Result |
|---|---|
| `jac fmt . --check` | PASS — 23/23 Jac files |
| `jac check .` | PASS — 23/23 Jac files; existing non-fatal warnings only |
| `jac test -d tests/ -v` | PASS — 73/73 tests in 274.82 seconds |
| `jac run tests/p0_demo.jac` | PASS — deterministic P0 flow |
| `jac run tests/ai_modes_demo.jac` | PASS — existing optional-AI modes |
| `jac run tests/multimodal_demo.jac` | PASS — 9/9 multimodal cycles |

The existing capture, document extraction, verification, clinician-note,
patient-plan, timeline, patient-audio-script, and provenance paths remain
operational. The reliable path requires no cloud key. All demonstration data
is fictional and synthetic.

## Baseline safety assertions

- Candidate proposals remain unverified until `VerificationWalker` records a
  clinician decision.
- Rejected proposals do not create `VerifiedFact` nodes.
- Patient output is derived from approved, visible, non-conflicted evidence.
- Raw audio and raw uploaded image bytes are not persisted.
- Existing provider failures fall back to deterministic behavior.
- The anonymous demo uses logical synthetic session isolation and does not
  claim production authorization, HIPAA compliance, diagnosis, treatment, or
  emergency triage.
