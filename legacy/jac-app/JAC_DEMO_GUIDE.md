# Pa-Co CareGraph demo guide

## Start

From `/Users/aradhyamishra/pa-co-caregraph`:

```bash
/Users/aradhyamishra/.local/bin/jac start main.jac --no-client
```

Open <http://localhost:8000/docs> to call generated functions. The nested
application response is at `data.result`.

## Reliable demo sequence

Use `session_id: "demo-default"` throughout:

1. `reset_demo`
2. `load_demo_encounter` with `ai_mode: "disabled"`
3. `get_candidate_facts` and show five pending facts with exact sources
4. `verify_fact` to accept lab, follow-up, medication, and referral
5. `verify_fact` to reject language preference
6. `get_care_graph` and show `PromotedTo`, `VerifiedFrom`, and specialized
   relationships
7. `run_care_gap_check` and show exactly lab owner and follow-up date gaps
8. `resolve_gap` for the lab owner with owner `clinic-lab-team`, due date
   `this week`, and a non-empty resolution
9. `resolve_gap` for follow-up with owner `clinic-scheduling`, due date
   `2026-08-09`, and a non-empty resolution
10. `generate_patient_plan` in English
11. `ask_patient_question` with `When is my blood test?`
12. `trace_provenance` using a returned checklist-item or answer ID
13. `add_demo_contradiction`
14. `run_evidence_audit` and show both two-week and four-week sources
15. `get_care_graph` and show that the affected previous brief is no longer
    current
16. `reset_demo` and confirm the exact five-candidate initial state

No step calls a model, diagnoses, prescribes, or selects a medically correct
conflict side.

## Trace mode

To expose actual walker entry and edge-following steps:

```bash
DEMO_TRACE_ENABLED=true \
  /Users/aradhyamishra/.local/bin/jac start main.jac --no-client
```

Read `traversal_trace` in the nested `BackendResponse`. Trace mode is off by
default and never records model prompts, hidden reasoning, credentials, or
private data.

## Acceptance automation

```bash
/Users/aradhyamishra/.local/bin/jac run tests/production_demo.jac
```

Expected final line:

```text
Pa-Co production acceptance passed 20 full cycles (720 checked steps).
```

The modes are disabled, missing-key fallback, valid MockLLM, and malformed
MockLLM. Each mode runs five complete cycles.

## Reset guarantee

`reset_demo` verifies that the selected session is synthetic, removes only
nodes on its `SessionOwns` boundary, and recreates one initial topology.
Another session remains unchanged. Do not point this demo at real patient
data.
