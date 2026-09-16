# Jac architecture upgrade plan

Status: implemented and release-verified.

## Rollback and checkpoints

- Baseline rollback point: `865677e`.
- Audit/characterization checkpoint: `1d2909e`.
- Canonical traversal/provenance checkpoint: `566a319`.
- Pre-schema ignored runtime backup:
  `/tmp/pa-co-jac-data-pre-upgrade.y9VDXs/data`.
- Final release commit is repository `HEAD`; a commit cannot contain its own
  hash.

No tracked file, frontend file, unrelated session, secret, or real patient
record was deleted. Jac's supported clean command was used only after the
ignored `.jac/data` backup; that state contained resettable synthetic demo
data.

## Target topology

```text
Root -HasSession→ DemoSession -HasPatient→ Patient -HasEncounter→ Encounter
Encounter -ContainsChunk→ TranscriptChunk
Encounter -HasCandidate→ CandidateFact -ExtractedFrom→ TranscriptChunk
CandidateFact -PromotedTo→ VerifiedFact -Represents*→ obligation
Encounter -HasTask/HasGap→ CareTask/CareGap
Patient -HasBrief→ PatientBrief -HasChecklistItem→ ChecklistItem
Patient -HasQuestion→ PatientQuestion -HasAnswer→ PatientAnswer
ChecklistItem/PatientAnswer -SupportedBy/AnsweredFrom→ VerifiedFact
VerifiedFact -VerifiedFrom→ CandidateFact
```

This topology is implemented with endpoint-constrained clinical edges.
`SessionOwns` remains only the reset/ownership boundary.

## Completed migration

1. Audited the baseline contract, persistence, graph queries, AI, server, and
   security capabilities; added characterization tests.
2. Backed up ignored synthetic runtime data and cleaned it with Jac.
3. Added string-backed safety enums, precise semantics, event/output nodes,
   relationship DTOs, traces, and provenance DTOs.
4. Reworked core behavior into explicit visit-driven domain traversal.
5. Preserved all 12 existing function names/signatures and added only
   `trace_provenance`.
6. Hardened optional AI and added valid/malformed MockLLM acceptance modes.
7. Added topology, provenance, trace, cross-session, endpoint, persistence,
   auth-root, injection, and 20-cycle acceptance verification.
8. Updated contract, demo, judge, frontend, model, audit, and capability
   documentation.

## Compatibility

- Existing DTO fields and public function signatures remain.
- Additive fields have safe empty defaults.
- Existing string values remain the API representation of internal enums.
- Generated `/function/*` routes remain the only production-shaped public
  route layer; no second framework was added.
- Old briefs and answers remain persisted for audit but become non-current
  after supporting graph changes or conflicts.

## Intentionally omitted

- ModelPool, tool calling, AI graph mutation, and AI-guided traversal.
- A multi-gigabyte local model download or creation of a paid cloud key.
- Login changes to the shared synthetic hackathon demo.
- Deployment, production JWT/admin configuration, HIPAA claims, and PHI.
- Automated conflict winner selection or medical decision support.
- Frontend-owned code or styling changes.
