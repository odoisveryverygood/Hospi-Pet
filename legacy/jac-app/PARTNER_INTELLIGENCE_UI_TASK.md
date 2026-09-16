# Partner task: intelligence UI

Build only the frontend presentation for the already implemented backend
contract. Do not edit backend-owned Jac files or invent response shapes.

## Branch and preparation

Work on `frontend-ui`, created from the newest `integration`. Before starting,
merge the backend handoff only after the backend pull request is available.
Read:

- `CONTRACT.md`
- `INTELLIGENCE_FRONTEND_HANDOFF.md`
- `handoff/intelligence-fixtures/`

## Build

1. Add the two-column original/translation consultation panel.
2. Add the unverified quick-note panel and exact safety badge.
3. Extend candidate verification rows with translated evidence where present.
4. Add the seven verified-analysis tabs.
5. Wire **Analyze accepted information** to the real public action.
6. Add question dismiss/mark-answered controls.
7. Add the stale-analysis banner and disable final review while stale.
8. Add the three-section final review display.
9. Add an ordered source-trace view.
10. Add loading, fallback, recoverable-error, and cross-session-not-found
    states from the supplied fixtures.

## Constraints

- Never promote, reject, resolve, or fabricate data in client state.
- Never show a quick summary as verified.
- Never merge Verified, Needs Review, and Unverified Drafts.
- Never use pending/rejected candidates in a plan or analysis.
- Preserve original transcript text beside every translation.
- Do not present the product as diagnostic, prescriptive, emergency-triage, or
  production-HIPAA software.

## Pull request

- Base branch: `integration`
- Compare branch: `frontend-ui`
- Include screenshots for translation, stale analysis, and final review.
- Confirm the fixture names and endpoint names match the handoff exactly.
