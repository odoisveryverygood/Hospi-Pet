# Intelligence frontend handoff

This is the implementation-ready frontend mapping for Pa-Co CareGraph /
Hospi-Pet. Do not invent response fields. Use the nested `BackendResponse`
shapes in `CONTRACT.md` and the fixtures in
`handoff/intelligence-fixtures/`.

The Jac server returns a generated outer HTTP envelope. Read the function
result from the envelope, then render the nested `BackendResponse`. Preserve
`success`, `error_code`, `message`, `recoverable`, and
`current_graph_version` on all paths.

## Live consultation panel

Render two synchronized columns.

Left: Original transcript

Right: Live translation

Each row must show:

- speaker;
- source/original language;
- original text;
- translated text;
- translation status;
- fallback indicator;
- transcript timestamp/sequence.

Call `translate_transcript_chunk` only after a chunk is finalized. Keep
`original_text` visible even if translation fails. Load the ordered rows with
`get_translated_transcript`. A `fallback` row is usable but must show a visible
fallback badge. Do not treat translation as a fact or clinician decision.

## Quick note panel

Call `generate_live_quick_summary(encounter_id, session_id)` after finalized
chunks arrive and render:

- `summary`;
- `key_points`;
- source count from `source_chunk_ids`;
- `model_mode`;
- `fallback_used`;
- this exact badge: **AI conversation draft — not yet clinician verified.**

Never place quick-summary text in the verification, clinician-note, or
patient-plan state automatically.

## Verification panel

Continue using the existing candidate contract. For each candidate show:

- candidate category/value;
- exact source sentence;
- translated source row when one exists;
- Accept;
- Reject;
- current status.

Only `verify_fact` changes verification state.

## Verified analysis panel

Tabs:

1. Verified Summary
2. Care Gaps
3. Clarifying Questions
4. Conflicts
5. Clinician Note
6. Patient Plan
7. Source Trace

The button label is **Analyze accepted information**. It calls
`run_verified_encounter_analysis`. Do not synthesize results in client code.

Render `analysis_run.accepted_fact_ids` and
`rejected_fact_ids_excluded` as an evidence-boundary explanation. Show the
model/fallback indicator without implying that a model verified anything.
When `analysis_run.stale` is true, disable final-review generation and show:

> New verified information is available. Re-run analysis.

## Suggested questions

Each `SuggestedQuestionDTO` row shows:

- `question`;
- `explanation`;
- source fact links;
- related gap or conflict;
- clinician-only badge;
- Dismiss;
- Mark answered.

Dismiss calls `dismiss_suggested_question`. Mark answered requires an existing
accepted fact ID and calls `mark_question_answered`; it never creates a fact.
Questions with `status=dismissed` or `status=answered` remain visible in audit
history.

## Final review

Call `generate_final_review_packet` only with a current analysis and current
English/Spanish approved plans. Render three separate sections:

- Verified — `verified_items` and verified summary/plans;
- Needs Review — `requires_review_items`, active gaps, conflicts, open
  questions, and draft note sections;
- Unverified Drafts — `unverified_items`, including the live quick summary
  label.

Never collapse or visually merge these sections.

## Source trace

Call `trace_analysis_item(analysis_run_id, item_id, session_id)`. Render each
`AnalysisProvenanceDTO.ordered_steps` in order and show:

- source type;
- exact excerpt;
- source fact ID;
- completeness.

An incomplete chain is a blocking error for the traced item, not an invitation
to fill it from client state.

## Loading and errors

- Translation: show row-local `pending`/`translating` state.
- Analysis and final packet: show encounter-level loading state.
- Recoverable failure: retain prior current data and offer the documented
  retry.
- Non-recoverable failure: block the affected action and show `message`.
- Provider failure: display deterministic fallback output plus fallback badge.
- Cross-session/not-found: clear the referenced ID and reload the selected
  session; never search another session.

## Endpoints

```text
POST /function/translate_transcript_chunk
POST /function/get_translated_transcript
POST /function/retry_translation
POST /function/generate_live_quick_summary
POST /function/get_live_quick_summary
POST /function/run_verified_encounter_analysis
POST /function/get_verified_encounter_analysis
POST /function/generate_clarifying_questions
POST /function/dismiss_suggested_question
POST /function/mark_question_answered
POST /function/generate_final_review_packet
POST /function/trace_analysis_item
```

## Demo ordering

1. Reset/load synthetic encounter.
2. Start capture.
3. Append finalized chunk.
4. Translate that chunk.
5. Refresh quick summary.
6. Extract and verify candidates with existing actions.
7. Run care-gap check.
8. Analyze accepted information.
9. Generate clarification questions.
10. After any graph-changing clinician action, reload analysis and re-run when
    stale.
11. Generate note and bilingual plans.
12. Re-run analysis.
13. Generate final review packet.

All included data is synthetic. This anonymous demo is not production
authorization or a medical decision system.
