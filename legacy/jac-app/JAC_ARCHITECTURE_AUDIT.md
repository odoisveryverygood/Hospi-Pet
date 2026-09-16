# Jac architecture audit

Baseline audited: `865677e`. Canonical architecture checkpoint: `566a319`.

## Baseline findings and resolution

| Area | Baseline risk | Implemented resolution |
|---|---|---|
| Navigation | Some clinical operations found resources through broad `SessionOwns` scans and string IDs. | Clinical walkers traverse session → patient → encounter → evidence/obligation/task edges. `SessionOwns` remains reset-only ownership. |
| Verification | Accepted state existed but had no append-only decision object or forward promotion path. | `VerificationEvent`, `HasVerificationEvent`, and `PromotedTo` record accepted/rejected decisions idempotently. |
| Obligations | Generic materialization obscured lab, medication, referral, and follow-up semantics. | Four endpoint-constrained `Represents*` edges are authoritative. |
| Gaps | Gaps were derived, but session-wide scans weakened topology evidence. | Gap walker traverses verified obligations and their task/owner/date relationships. |
| Resolution | Resolution used related string IDs and an audit record without complete topology. | `GapResolutionEvent`, `ResolvedBy`, and `ResolutionUpdates` form an append-only path to the task. |
| Plans | Brief checklist strings had no independently traceable node identity. | `ChecklistItem` nodes carry stable IDs and `SupportedBy` verified facts. |
| Answers | Evidence was linked from the question itself and matching was blood-test-specific. | Separate `PatientAnswer` nodes, generalized category/term matching, and `AnsweredFrom` edges. |
| Conflicts | Conflict did not connect both evidence roles and stale patient output remained current. | Role-bearing evidence edges preserve both sides; affected briefs/answers become non-current. |
| Provenance | Source fields were present but no public backward traversal existed. | `TraceProvenanceWalker` and `trace_provenance` return one typed chain per support fact. |
| Traces | No public execution trace. | Actual walker entry and followed-edge events append typed steps when trace mode is enabled. |
| AI | Good fallback existed, but prompt injection, fabricated times, and malformed diagnostic mode needed hardening. | Strict validator, current-session allow-lists, one retry, and `mock_malformed` were added. |
| Isolation | Synthetic session IDs were logically scoped but authorization claims were not proven. | Cross-session denials plus isolated private-walker and authenticated-root tests; demo remains explicitly anonymous. |

## Canonical source-of-truth audit

- Persistent graph nodes and typed relationships are the care-state authority.
- DTO lists are projections, not independent mutable storage.
- Stable string IDs are API compatibility identifiers; topology is the
  authoritative membership and navigation check.
- Transcript source text and `ExtractedFrom` provenance are immutable through
  all public actions.
- Candidate status changes only through `VerificationWalker`.
- Verified facts are never LLM return values and are created only by
  deterministic verification code.
- `VerificationEvent` and `GapResolutionEvent` are append-only audit records.
- Current patient briefs and answers are projections over visible, approved,
  non-conflicted support. Superseded outputs remain historical nodes.
- `SessionOwns` is intentionally duplicated metadata solely for bounded
  synthetic reset; core clinical walkers do not treat it as their primary
  graph path.

## Collection and query classification

| Collection/query | Classification |
|---|---|
| `DemoStateDTO`, `CareGraphDTO`, checklist DTO arrays | Read projection |
| Walker `has` lists and visited-ID sets | Request-local accumulator |
| Prepared transcript/candidate functions | Deterministic immutable seed source |
| Model extraction return list | Untrusted typed proposal pending validation |
| Relationship projection | Judge/frontend read view of actual graph edges |
| `SessionOwns` neighbor set | Reset ownership index only |
| Domain-edge neighbors | Authoritative clinical navigation |
| `.jac/data` | Jac-managed ignored local persistence |

There is no module-global clinical dictionary, second database, frontend mock
source of truth, committed runtime cache, or real-patient collection.

## Hardcoding assessment

Hardcoded material is limited to the stated deterministic hackathon case:
Maya Rivera, five exact transcript chunks, five prepared pending candidates,
two expected documentation gaps derived from missing relationships, safe
patient wording, and the later four-week contradiction. Walkers do not use
fixed responses to pretend traversal occurred: verification, gap detection,
resolutions, plans, questions, provenance, and conflict audit read the graph.

## Security and reliability boundary

The public demo's `session_id` is logical synthetic isolation, not an
authorization credential. Cross-session resource IDs are rejected, and reset
requires a synthetic session. An isolated fixture proves Jac 0.34.7 private
walker enforcement and per-user root isolation, but authentication is not
silently introduced into the frontend contract.

No PHI, credentials, model prompts, hidden reasoning, or provider response
bodies are stored in traces. Default runtime admin/JWT development warnings
remain deployment blockers. This repository is not HIPAA compliant and is not
deployed.

## Residual limitations

- The domain contains one deterministic synthetic encounter.
- Conflict resolution is intentionally manual.
- Demo due dates are strings rather than scheduling objects.
- The generated endpoint runtime may encode a missing required argument inside
  an HTTP 200 envelope; nested error inspection is required.
- `jac start --faux` has a verified 0.34.7 cleanup defect.
- `jac dot` emits DOT but did not discover the tested generated-server graph
  store; `/graph` and typed relationship projections remain available.
- A real cloud provider is optional and was not exercised without an existing
  authorized credential.
