# Technical judge guide

## What is Jac-native here

The care record is a persistent node/edge topology, and operations are walkers
that explicitly visit domain nodes. This follows Jac's object-spatial model:
data is located in nodes, relationships are typed edges, and behavior moves to
the data.

Inspect:

- schema and endpoint constraints: `models.sv.jac`
- visit-driven behavior and traces: `walkers.sv.jac`
- question walker: `patient_agent.sv.jac`
- thin generated actions: `endpoints.sv.jac`
- typed optional `by llm()` boundary: `ai.sv.jac`

`SessionOwns` is not used as a shortcut for clinical navigation. It exists
only so one synthetic demo session can be reset safely.

## Fast verification

```bash
/Users/aradhyamishra/.local/bin/jac fmt . --check
/Users/aradhyamishra/.local/bin/jac check .
/Users/aradhyamishra/.local/bin/jac test -d tests/ -v
/Users/aradhyamishra/.local/bin/jac run tests/server_integration.jac
/Users/aradhyamishra/.local/bin/jac run tests/production_demo.jac
```

The suite covers baseline behavior, graph topology, endpoint-constrained
relationships, immutable evidence, decision/resolution events, provenance,
traces, idempotence, cross-session rejection, reset shape, AI abuse cases,
generated endpoints, persistence reload, a private walker, and authenticated
root isolation.

## Graph evidence to inspect

After accepting a fact, `get_care_graph.relationships` includes candidate
promotion, verified provenance, clinician verification, the appropriate
`Represents*` edge, and its task/dependency paths. A generated brief contains
separate checklist-item IDs connected by `SupportedBy`. A patient answer has
its own ID and `AnsweredFrom` support.

`trace_provenance(output_id)` returns:

```text
output → verified fact → candidate → transcript chunk → encounter → patient
```

The original evidence and a `complete` flag are included for every supporting
fact.

With `DEMO_TRACE_ENABLED=true`, `traversal_trace` lists actual walker entry and
edge-following events with node IDs/types, action, outcome, and a human
explanation.

## AI boundary

AI is optional, returns enum-typed plain objects, and has no graph mutation
tool. Extraction creates only validated pending candidates. Translation and
simplification operate only on an approved English projection. Question AI
selects from an allow-list; deterministic code retrieves facts and writes the
answer.

MockLLM and malformed MockLLM exercise success and recovery without a key. No
cloud key was created and no large local model was downloaded.

## Server and security evidence

The real 0.34.7 server generates `/function/*`, `/docs`, `/openapi.json`, and
health routes. Its `/graph` viewer returns HTTP 200. Stop/restart persistence
is tested in a temporary copied workspace so repository runtime state is
untouched. `jac dot` emits valid DOT but, in the tested 0.34.7 generated-server
store, renders only the root; use `/graph` and
`get_care_graph.relationships` for topology inspection.

The public demo's session IDs provide only logical isolation. A separate
fixture proves anonymous denial for `walker:priv` and separate authenticated
roots for two users, but the demo is intentionally not presented as production
authorization or HIPAA compliance. Default admin/JWT development warnings are
documented deployment blockers.

## Honest limitations

- One synthetic patient and encounter.
- Manual contradiction resolution only.
- String demo dates, not production scheduling.
- No real-provider acceptance cycle without an already-authorized key.
- Jac 0.34.7 `--faux` cleanup defect and generated invalid-argument envelope
  behavior are documented in `JAC_CAPABILITY_MATRIX.md`.

Official references:

- <https://docs.jaseci.org/reference/language/osp/>
- <https://docs.jaseci.org/tutorials/ai/structured-outputs/>
- <https://docs.jaseci.org/tutorials/fullstack/auth/>
