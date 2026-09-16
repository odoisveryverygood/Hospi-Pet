# Frontend handoff

## Ownership

The frontend owner retains `frontend.cl.jac`, `frontend.impl.jac`,
`components/`, `styles/`, frontend mock data, and frontend tests. None of
those paths are changed by this backend upgrade. Contract changes must be
requested from the backend owner rather than silently duplicated in the UI.

## Import and call

Import public functions from `endpoints` and DTOs from `models` using
client-side `sv import`. Await each server call. All functions return
`BackendResponse`; branch on `success`, then use the action-specific field.

Raw HTTP consumers call `POST /function/<action>` and read the nested
application response at `data.result`. The outer Jac envelope has `ok`,
`type`, `data`, `error`, and `meta`.

## Stable action mapping

| UI operation | Backend action | Result field |
|---|---|---|
| Load consultation | `load_demo_encounter` | `demo_state` |
| Candidate review list | `get_candidate_facts` | `candidate_facts` |
| Accept/reject | `verify_fact` | `verified_fact` |
| Graph screen | `get_care_graph` | `care_graph` |
| Detect gaps | `run_care_gap_check` | `care_gaps` |
| Resolve gap | `resolve_gap` | `demo_state` |
| Generate plan | `generate_patient_plan` | `patient_plan` |
| Simplify plan | `simplify_patient_plan` | `patient_plan` |
| Ask patient question | `ask_patient_question` | `patient_answer` |
| Audit evidence | `run_evidence_audit` | `conflicts` |
| Trace an item/answer | `trace_provenance` | `provenance_chains` |
| Reset | `reset_demo` | `demo_state` |
| Demo contradiction | `add_demo_contradiction` | `verified_fact` |

Use `current_graph_version` to refresh after mutations. Read
`created_graph_ids` if the UI wants to highlight newly created objects.
`CareGraphDTO.relationships` is the supported graph visualization projection;
do not infer relationships from string IDs.

## Additive fields

- `PlanItemDTO.id` is the persistent checklist-item ID accepted by
  `trace_provenance`.
- `PatientAnswerDTO.id` is the persistent answer ID accepted by
  `trace_provenance`.
- `BackendResponse.traversal_trace` is empty unless the server starts with
  `DEMO_TRACE_ENABLED=true`.
- `BackendResponse.provenance_chains` is populated by `trace_provenance`.
- `BackendResponse.created_graph_ids` lists objects created by that mutation.
- `CareGraphDTO.relationships` contains `from_id`, `edge_type`, `to_id`, and
  optional role.

## Integration rules

- Use one stable synthetic `session_id` per browser/demo.
- Never expose pending, rejected, or conflicted candidates as patient facts.
- Render patient content only from `patient_plan` and `patient_answer`.
- Preserve returned source IDs and checklist item IDs.
- Do not construct a verified fact, resolve a conflict, or answer from frontend
  medical knowledge.
- Display `message` and `error_code` for failures. A recovered AI failure may
  have `success: true`, `recoverable: true`, and
  `ai_status.fallback_used: true`; the deterministic result remains usable.
- For raw HTTP, inspect both the outer Jac envelope and nested response. In
  0.34.7, a missing required generated-function argument may arrive as HTTP
  200 with `data.error`.

## Recommended initial sequence

Call `reset_demo`, then `load_demo_encounter`, and render
`demo_state.candidate_facts`. Use `ai_mode: "disabled"` for the reliable demo.
After clinician decisions, fetch `get_care_graph`; after resolving the two
gaps, generate a plan. Use a returned plan-item or answer ID for provenance.

The complete request/response examples and error lists are in `CONTRACT.md`.
