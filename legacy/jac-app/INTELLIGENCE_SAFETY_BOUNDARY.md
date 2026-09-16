# Intelligence safety boundary

Pa-Co CareGraph (also presented as Hospi-Pet) is a synthetic
continuity-of-care documentation demonstration. Its intelligence layer may
organize evidence; it does not practice medicine.

## Allowed intelligence

The optional model adapter may perform only these constrained operations:

- literal English/Spanish translation of a finalized transcript chunk;
- an explicitly unverified, speaker-aware conversation summary;
- organization and rewriting of clinician-accepted graph facts;
- documentation-completeness checks over accepted facts and care tasks;
- grouping accepted facts by their stored category;
- identification of missing administrative ownership, dates, or follow-up
  fields already represented by the graph;
- source-grounded clarification and care-coordination questions tied to a
  current `CareGap` or `Conflict`;
- contradiction and provenance presentation without selecting a winner;
- a clinician-review note draft derived from accepted evidence;
- translation or simplification of an already approved patient plan.

All model output is advisory, validated, session-scoped, and replaceable by a
deterministic fallback.

## Prohibited intelligence

No deterministic or model-backed path may:

- diagnose, suggest a diagnosis, rank diseases, predict disease, or attach a
  clinical probability;
- prescribe, recommend a medication, change a medication, or select/change a
  dose;
- determine that a treatment, medication, or discharge is safe;
- perform emergency triage or generate emergency advice;
- invent a symptom, concern, instruction, date, owner, allergy, medication,
  laboratory order, referral, follow-up, or source quotation;
- interpret an unstated clinical implication or fill a gap using external
  medical knowledge;
- use a pending or rejected candidate as verified analysis evidence;
- expose a quick-summary claim as verified or patient-facing information;
- create, accept, reject, edit, or delete a `VerifiedFact`;
- resolve a care gap or conflict;
- select the medically correct side of contradictory evidence;
- follow instructions embedded in transcript, translation, document text, or
  model output;
- return a node from another synthetic session.

## Enforcement boundary

Jac code, not the model:

1. selects current-session graph nodes;
2. restricts analysis to accepted `VerifiedFact` paths;
3. excludes rejected, pending, conflicting, stale, and foreign-session data;
4. validates every returned identifier and every source relationship;
5. assembles structured public responses;
6. changes graph state only through the existing clinician-controlled walkers;
7. marks quick summaries and draft material as unverified;
8. detects stale analysis using graph versions.

The model receives the minimum synthetic text needed for its one allowed task.
Prompts, credentials, hidden reasoning, raw media, and private runtime data are
never included in traversal traces or public diagnostics.

## Product labels

The live summary must display:

> AI conversation draft — not yet clinician verified.

Verified outputs must be separated from `REQUIRES REVIEW` and `UNVERIFIED`
outputs. Stale analysis must display:

> New verified information is available. Re-run analysis.

These labels are safety controls, not optional presentation copy.
