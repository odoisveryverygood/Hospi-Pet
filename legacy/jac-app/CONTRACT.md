# Pa-Co CareGraph backend contract

Status: production-shaped compatibility contract for Jac 0.34.7. The frontend
may depend on every type and action documented here. All original public
function names and request signatures are preserved. New fields and
`trace_provenance` are additive. Contract changes after frontend integration
require a documented migration note and coordination with the frontend owner.

## Ownership boundary

The backend owner controls:

- `main.jac`
- `jac.toml`
- `models.sv.jac`
- `extraction.sv.jac`
- `ai.sv.jac`
- `walkers.sv.jac`
- `patient_agent.sv.jac`
- `endpoints.sv.jac`
- `tests/`
- `CONTRACT.md`
- backend sections of `README.md`

The frontend owner controls `frontend.cl.jac`, `frontend.impl.jac`,
`components/`, `styles/`, frontend mock data, and frontend tests. Backend work
must not edit those paths.

## Implementation checklist

- [x] Define typed DTOs, graph nodes, and typed relationships.
- [x] Seed the deterministic Maya Rivera encounter without an AI dependency.
- [x] Implement ingest, verification, gap, resolution, plan, question, audit,
      and reset walkers.
- [x] Preserve the twelve existing public action signatures and add
      `trace_provenance`.
- [x] Enforce patient-visibility, provenance, contradiction, and reset
      invariants.
- [x] Add at least twenty backend tests.
- [x] Run static checks, the complete test suite, and the P0 flow three times.
- [x] Add optional typed extraction, Spanish translation, simplification, and
      verified-fact question matching with deterministic fallbacks.
- [x] Validate AI modes with `MockLLM`, no credentials, simulated provider
      errors, simulated timeout, malformed output, and disabled AI.
- [x] Add canonical visit-driven topology, decision/resolution events,
      independent checklist/answer nodes, traces, and backward provenance.
- [x] Prove generated endpoint behavior, reload persistence, cross-session
      rejection, private-walker enforcement, and authenticated-root isolation.

## Common response envelope

Every frontend-callable action returns `BackendResponse`.

```text
BackendResponse
- success: bool
- error_code: str
- message: str
- recoverable: bool
- current_graph_version: int
- ai_status: AIStatusDTO | None
- extracted_candidates: list[ExtractedCandidate]
- demo_state: DemoStateDTO | None
- candidate_facts: list[CandidateFactDTO]
- verified_fact: VerifiedFactDTO | None
- care_graph: CareGraphDTO | None
- care_gaps: list[CareGapDTO]
- patient_plan: PatientPlanDTO | None
- patient_answer: PatientAnswerDTO | None
- conflicts: list[ConflictDTO]
- created_graph_ids: list[str]
- traversal_trace: list[TraversalStepDTO]
- provenance_chains: list[ProvenanceChainDTO]
```

On full success, `success` is `true`, `error_code` is empty, and the
action-specific field contains the result. A recovered optional-AI failure also
returns `success: true` because the deterministic result is usable, while
`recoverable: true`, `error_code`, and `ai_status.fallback_used` describe the
degraded AI attempt. On unrecovered failure, `success` is `false`. Unused
result fields are empty or `None`.

Jac clients receive the typed `BackendResponse` directly. Raw REST consumers
receive Jac's standard transport envelope and read the object at
`data.result`:

```json
{
  "ok": true,
  "type": "response",
  "data": {"result": {"success": true}, "reports": []},
  "error": null,
  "meta": {}
}
```

The outer `ok` reports transport/runtime handling; the nested
`BackendResponse.success` reports domain success. Jac 0.34.7 may return HTTP
200 with `data.error` for a missing required generated-function argument, so
raw clients must inspect the envelope as well as `data.result`.

## Required DTOs

```text
ExtractedCandidate
- category: str
- value: str
- source_text: str
- source_chunk_id: str
- confidence: float
- patient_visible_candidate: bool

AIStatusDTO
- requested: bool
- used: bool
- fallback_used: bool
- mode: str
- diagnostic_code: str
- diagnostic_message: str

CandidateFactDTO
- id: str
- category: str
- value: str
- source_chunk_id: str
- source_text: str
- confidence: float
- status: str
- created_at: str

VerifiedFactDTO
- id: str
- category: str
- value: str
- source_chunk_id: str
- source_text: str
- verified_by: str
- verified_at: str
- visible_to_patient: bool

CareGapDTO
- id: str
- gap_type: str
- message: str
- related_fact_ids: list[str]
- resolved: bool
- resolution: str
- owner: str
- due_date: str

PlanItemDTO
- id: str
- kind: str
- text: str
- owner: str
- due_date: str
- status: str
- source_fact_id: str

PatientPlanDTO
- patient_id: str
- language: str
- medications: list[PlanItemDTO]
- labs: list[PlanItemDTO]
- referrals: list[PlanItemDTO]
- follow_ups: list[PlanItemDTO]
- checklist: list[str]
- source_fact_ids: list[str]
- generated_at: str
- ai_enhanced: bool
- translation_fallback_used: bool
- simplification_fallback_used: bool

PatientAnswerDTO
- id: str
- answer: str
- grounded: bool
- source_fact_ids: list[str]
- fallback_used: bool
- ai_matching_used: bool

PatientDTO
- id: str
- display_name: str
- preferred_language: str
- synthetic: bool

EncounterDTO
- id: str
- occurred_at: str
- status: str

TranscriptChunkDTO
- id: str
- sequence: int
- speaker: str
- text: str

ConflictDTO
- id: str
- left_fact_id: str
- right_fact_id: str
- conflict_type: str
- explanation: str
- resolved: bool
- left_source_text: str
- right_source_text: str

TraversalStepDTO
- order: int
- walker_name: str
- current_node_id: str
- current_node_type: str
- edge_type: str
- action: str
- outcome: str
- human_explanation: str

ProvenanceChainDTO
- output_id: str
- output_type: str
- source_fact_id: str
- candidate_fact_id: str
- transcript_chunk_id: str
- encounter_id: str
- patient_id: str
- source_text: str
- complete: bool

GraphRelationshipDTO
- from_id: str
- edge_type: str
- to_id: str
- role: str

CareGraphDTO
- patient: PatientDTO | None
- encounter: EncounterDTO | None
- transcript: list[TranscriptChunkDTO]
- candidate_facts: list[CandidateFactDTO]
- verified_facts: list[VerifiedFactDTO]
- care_gaps: list[CareGapDTO]
- patient_plan: PatientPlanDTO | None
- conflicts: list[ConflictDTO]
- relationships: list[GraphRelationshipDTO]
- graph_version: int

DemoStateDTO
- patient: PatientDTO | None
- encounter: EncounterDTO | None
- transcript: list[TranscriptChunkDTO]
- candidate_facts: list[CandidateFactDTO]
- verified_facts: list[VerifiedFactDTO]
- care_gaps: list[CareGapDTO]
- patient_plan: PatientPlanDTO | None
- conflicts: list[ConflictDTO]
- graph_version: int
```

Internal candidate category/status, gap type/status, conflict type, language,
and verification-decision enums serialize to the existing strings shown in
this contract.

`CareGraphDTO.relationships` is a read projection of persisted typed edges.
Each relationship contains `from_id`, `edge_type`, `to_id`, and an optional
role such as `left` or `right` for conflict evidence. It is the supported
frontend graph-visualization input.

Mutations populate `created_graph_ids` when new persistent records are
created. With `DEMO_TRACE_ENABLED=true`, internal walkers append
`traversal_trace` during actual node entry and edge-following events. The field
is empty by default and never includes prompts, hidden reasoning, credentials,
or private patient data.

When supporting graph state changes or becomes conflicted, previously
generated briefs, checklist items, questions, and answers are marked
non-current. They remain audit history but cannot be returned as current
patient-facing output or traced through the public current-output action.

## Callable actions

All actions accept an optional `session_id: str = "demo-default"`. This keeps
two synthetic browser/test sessions isolated while preserving a zero-config
default for the demo UI.

### `load_demo_encounter`

Inputs:

```text
session_id: str = "demo-default"
ai_mode: str = "disabled"
```

Output: `BackendResponse.demo_state`. It contains Maya Rivera, five ordered
transcript chunks, five pending candidate facts, and no verified facts.

`ai_mode` is `disabled`, `live`, `mock`, or `mock_malformed`. `disabled`
preserves deterministic ingest. `live` invokes typed `by llm()` extraction
only for a fresh synthetic session. `mock` is the valid keyless `MockLLM`
path. `mock_malformed` deliberately exercises recoverable malformed output and
is not for production. AI proposals are schema- and provenance-validated and
persisted only as pending candidates. Any AI failure loads the five prepared
candidates.

Possible errors: `INVALID_SESSION_ID`, `AI_MODE_INVALID`,
`AI_SESSION_ALREADY_INITIALIZED`. Recovered AI diagnostic codes include
`AI_CREDENTIALS_MISSING`, `AI_TIMEOUT`, `AI_PROVIDER_ERROR`,
`AI_MALFORMED_OUTPUT`, `AI_EMPTY_OUTPUT`, `AI_UNSUPPORTED_CATEGORY`,
`AI_SOURCE_CHUNK_NOT_FOUND`, `AI_SOURCE_EVIDENCE_MISSING`,
`AI_INVALID_CONFIDENCE`, `AI_PROHIBITED_MEDICAL_CONTENT`, and
`AI_DUPLICATE_CANDIDATE`. Instruction-injection and fabricated-detail
rejections are also recoverable validation failures.

Example request:

```json
{"session_id": "demo-default", "ai_mode": "disabled"}
```

Example response:

```json
{
  "success": true,
  "current_graph_version": 1,
  "demo_state": {
    "patient": {
      "id": "patient-maya",
      "display_name": "Maya Rivera",
      "preferred_language": "Spanish",
      "synthetic": true
    },
    "candidate_facts": [
      {
        "id": "candidate-lab",
        "category": "lab_order",
        "value": "blood test; due this week",
        "source_chunk_id": "chunk-1",
        "source_text": "We will order a blood test to be completed this week.",
        "confidence": 1.0,
        "status": "pending",
        "created_at": "2026-07-26T18:00:01Z"
      }
    ],
    "graph_version": 1
  }
}
```

Changes graph state: yes, only when the named synthetic session does not yet
exist.

### `get_candidate_facts`

Inputs:

```text
session_id: str = "demo-default"
```

Output: `BackendResponse.candidate_facts`, ordered by source transcript
sequence.

Possible errors: `DEMO_NOT_LOADED`.

Example request:

```json
{"session_id": "demo-default"}
```

Example response:

```json
{
  "success": true,
  "current_graph_version": 1,
  "candidate_facts": [
    {
      "id": "candidate-lab",
      "category": "lab_order",
      "value": "blood test; due this week",
      "source_chunk_id": "chunk-1",
      "source_text": "We will order a blood test to be completed this week.",
      "confidence": 1.0,
      "status": "pending",
      "created_at": "2026-07-26T18:00:01Z"
    }
  ]
}
```

Changes graph state: no.

### `verify_fact`

Inputs:

```text
fact_id: str
decision: str  # "accept" or "reject"
clinician_id: str
session_id: str = "demo-default"
```

Output: `BackendResponse.verified_fact` for an accepted fact. For a rejection,
the field is `None` and the candidate status is returned through a subsequent
state read.

Possible errors: `DEMO_NOT_LOADED`, `FACT_NOT_FOUND`, `INVALID_DECISION`,
`INVALID_CLINICIAN_ID`, `FACT_ALREADY_DECIDED`.

Example request:

```json
{
  "fact_id": "candidate-lab",
  "decision": "accept",
  "clinician_id": "clinician-1",
  "session_id": "demo-default"
}
```

Example response:

```json
{
  "success": true,
  "current_graph_version": 2,
  "verified_fact": {
    "id": "verified-candidate-lab",
    "category": "lab_order",
    "value": "blood test; due this week",
    "source_chunk_id": "chunk-1",
    "source_text": "We will order a blood test to be completed this week.",
    "verified_by": "clinician-1",
    "verified_at": "2026-07-26T18:00:02Z",
    "visible_to_patient": true
  }
}
```

Changes graph state: yes. Only `VerificationWalker` can create the verified
record and specialized care node.

### `get_care_graph`

Inputs:

```text
session_id: str = "demo-default"
```

Output: `BackendResponse.care_graph`.

Possible errors: `DEMO_NOT_LOADED`.

Example request:

```json
{"session_id": "demo-default"}
```

Example response:

```json
{
  "success": true,
  "current_graph_version": 4,
  "care_graph": {
    "patient": {"id": "patient-maya", "display_name": "Maya Rivera"},
    "candidate_facts": [],
    "verified_facts": [],
    "care_gaps": [],
    "conflicts": [],
    "graph_version": 4
  }
}
```

Changes graph state: no.

### `run_care_gap_check`

Inputs:

```text
session_id: str = "demo-default"
```

Output: `BackendResponse.care_gaps`, containing unresolved documentation gaps
only.

Possible errors: `DEMO_NOT_LOADED`, `NO_VERIFIED_FACTS`.

Example request:

```json
{"session_id": "demo-default"}
```

Example response:

```json
{
  "success": true,
  "current_graph_version": 6,
  "care_gaps": [
    {
      "id": "gap-lab-owner-verified-candidate-lab",
      "gap_type": "lab_owner_missing",
      "message": "The blood test does not have a responsible owner.",
      "related_fact_ids": ["verified-candidate-lab"],
      "resolved": false,
      "resolution": "",
      "owner": "",
      "due_date": ""
    },
    {
      "id": "gap-follow-up-date-verified-candidate-follow-up",
      "gap_type": "follow_up_date_missing",
      "message": "The follow-up period is recorded but no appointment date is scheduled.",
      "related_fact_ids": ["verified-candidate-follow-up"],
      "resolved": false,
      "resolution": "",
      "owner": "",
      "due_date": ""
    }
  ]
}
```

Changes graph state: yes only when a newly detected gap is persisted. Repeated
checks are idempotent.

### `resolve_gap`

Inputs:

```text
gap_id: str
resolution: str
owner: str
due_date: str
session_id: str = "demo-default"
```

Output: `BackendResponse.demo_state` with the updated specialized node, task,
gap, and audit history reflected.

Possible errors: `DEMO_NOT_LOADED`, `GAP_NOT_FOUND`, `GAP_ALREADY_RESOLVED`,
`INVALID_RESOLUTION`, `INVALID_OWNER`, `INVALID_DUE_DATE`.

Example request:

```json
{
  "gap_id": "gap-lab-owner-verified-candidate-lab",
  "resolution": "Assigned blood-test coordination",
  "owner": "clinic-lab-team",
  "due_date": "this week",
  "session_id": "demo-default"
}
```

Example response:

```json
{
  "success": true,
  "current_graph_version": 7,
  "demo_state": {
    "care_gaps": [],
    "graph_version": 7
  }
}
```

Changes graph state: yes. Resolution is append-audited; provenance is never
replaced.

### `generate_patient_plan`

Inputs:

```text
language: str
session_id: str = "demo-default"
ai_mode: str = "disabled"
```

Output: `BackendResponse.patient_plan`.

When `ai_mode` is `live` or `mock` and `language` is Spanish, deterministic
code first persists an approved English `PatientBrief`; AI translates only its
text projection. Dates, numbers, checklist count, and source IDs are validated.
Translation failure returns that approved English plan with
`translation_fallback_used: true`.

Possible errors: `DEMO_NOT_LOADED`, `INVALID_LANGUAGE`, `UNSUPPORTED_LANGUAGE`,
`NO_VISIBLE_FACTS`, `ACTIVE_CARE_GAPS`, `AI_MODE_INVALID`. Recovered AI
failures are reported through `ai_status`.

Example request:

```json
{"language": "Spanish", "session_id": "demo-default", "ai_mode": "mock"}
```

Example response:

```json
{
  "success": true,
  "patient_plan": {
    "patient_id": "patient-maya",
    "language": "English",
    "medications": [],
    "labs": [
      {
        "id": "checklist-demo-default-9-1",
        "kind": "lab",
        "text": "Complete the blood test this week.",
        "owner": "clinic-lab-team",
        "due_date": "this week",
        "status": "ordered",
        "source_fact_id": "verified-candidate-lab"
      }
    ],
    "referrals": [],
    "follow_ups": [],
    "checklist": [
      "Complete the blood test this week. [source: verified-candidate-lab]"
    ],
    "source_fact_ids": ["verified-candidate-lab"],
    "generated_at": "2026-07-26T18:00:08Z"
  }
}
```

Changes graph state: yes. A `PatientBrief` is persisted using approved,
patient-visible, non-conflicting facts only. An optional translation is a
validated response projection and cannot alter verified graph nodes or source
IDs.

### `simplify_patient_plan`

Inputs:

```text
session_id: str = "demo-default"
ai_mode: str = "live"
```

Output: `BackendResponse.patient_plan`.

This action generates an approved English brief, then optionally simplifies
only its text. It preserves structure, dates, numbers, obligations, and source
IDs. On failure it returns approved English unchanged with
`simplification_fallback_used: true`.

Possible errors: `AI_MODE_INVALID`, `DEMO_NOT_LOADED`, `NO_VISIBLE_FACTS`,
`ACTIVE_CARE_GAPS`. Recovered provider, timeout, credential, or validation
failures appear in `ai_status`.

Example request:

```json
{"session_id": "demo-default", "ai_mode": "mock"}
```

Example response:

```json
{
  "success": true,
  "ai_status": {
    "requested": true,
    "used": true,
    "fallback_used": false,
    "mode": "mock"
  },
  "patient_plan": {
    "language": "English",
    "ai_enhanced": true,
    "source_fact_ids": ["verified-candidate-lab"],
    "checklist": [
      "Get the blood test this week. [source: verified-candidate-lab]"
    ]
  }
}
```

Changes graph state: yes only because the approved English `PatientBrief` is
created first. AI cannot mutate that brief or any verified graph record.

### `ask_patient_question`

Inputs:

```text
question: str
session_id: str = "demo-default"
ai_mode: str = "disabled"
```

Output: `BackendResponse.patient_answer`.

With AI enabled, the model receives only approved, patient-visible,
non-conflicting fact references and may return IDs only. Deterministic code
validates those IDs, retrieves the graph nodes, and constructs the factual
answer. Provider failure falls back to deterministic matching. An
unverified/unknown returned ID is rejected and produces the exact safe
fallback.

Possible errors: `DEMO_NOT_LOADED`, `INVALID_QUESTION`, `AI_MODE_INVALID`.
Recovered matching failures appear in `ai_status`.

Example request:

```json
{
  "question": "When is my blood test?",
  "session_id": "demo-default",
  "ai_mode": "mock"
}
```

Example response:

```json
{
  "success": true,
  "patient_answer": {
    "id": "answer-demo-default-10",
    "answer": "Your blood test is due this week and is assigned to clinic-lab-team.",
    "grounded": true,
    "source_fact_ids": ["verified-candidate-lab"],
    "fallback_used": false,
    "ai_matching_used": true
  }
}
```

Unknown-answer example:

```json
{
  "success": true,
  "patient_answer": {
    "id": "answer-demo-default-11",
    "answer": "This is not recorded in your approved care plan. Please contact your clinic.",
    "grounded": false,
    "source_fact_ids": [],
    "fallback_used": true
  }
}
```

Changes graph state: yes. The question and its verified evidence links are
stored for auditability; no medical knowledge is consulted.

### `run_evidence_audit`

Inputs:

```text
session_id: str = "demo-default"
```

Output: `BackendResponse.conflicts`.

Possible errors: `DEMO_NOT_LOADED`, `NO_VERIFIED_FACTS`.

Example request:

```json
{"session_id": "demo-default"}
```

Example response:

```json
{
  "success": true,
  "conflicts": [
    {
      "id": "conflict-verified-candidate-follow-up-verified-candidate-follow-up-4-weeks",
      "left_fact_id": "verified-candidate-follow-up",
      "right_fact_id": "verified-candidate-follow-up-4-weeks",
      "conflict_type": "contradictory_follow_up_period",
      "explanation": "Two approved follow-up periods differ; neither was overwritten.",
      "resolved": false,
      "left_source_text": "Please return in two weeks so we can review the results.",
      "right_source_text": "Please return in four weeks so we can review the results."
    }
  ]
}
```

Changes graph state: yes only when a new `Conflict` is persisted. Repeated
audits are idempotent and never pick a clinically correct side.

### `trace_provenance`

Inputs:

```text
output_id: str
session_id: str = "demo-default"
```

`output_id` must be the stable `PlanItemDTO.id` for a current checklist item or
the stable `PatientAnswerDTO.id` for a current patient answer.

Output: `BackendResponse.provenance_chains`. One chain is returned for each
supporting fact. Every complete chain identifies the output, verified fact,
candidate, transcript chunk, encounter, patient, and original source text.

Possible errors: `INVALID_OUTPUT_ID`, `DEMO_NOT_LOADED`, `OUTPUT_NOT_FOUND`,
`PROVENANCE_INCOMPLETE`. An output from another session is deliberately
reported as `OUTPUT_NOT_FOUND`.

Example request:

```json
{
  "output_id": "checklist-demo-default-9-1",
  "session_id": "demo-default"
}
```

Example response:

```json
{
  "success": true,
  "provenance_chains": [
    {
      "output_id": "checklist-demo-default-9-1",
      "output_type": "ChecklistItem",
      "source_fact_id": "verified-candidate-lab",
      "candidate_fact_id": "candidate-lab",
      "transcript_chunk_id": "chunk-1",
      "encounter_id": "encounter-maya-001",
      "patient_id": "patient-maya",
      "source_text": "We will order a blood test to be completed this week.",
      "complete": true
    }
  ]
}
```

Changes graph state: no.

### `reset_demo`

Inputs:

```text
session_id: str = "demo-default"
```

Output: `BackendResponse.demo_state` containing the exact prepared initial
state.

Possible errors: `INVALID_SESSION_ID`, `NON_SYNTHETIC_SESSION`.

Example request:

```json
{"session_id": "demo-default"}
```

Example response:

```json
{
  "success": true,
  "current_graph_version": 1,
  "demo_state": {
    "patient": {"id": "patient-maya", "display_name": "Maya Rivera"},
    "candidate_facts": [
      {"id": "candidate-lab", "status": "pending"},
      {"id": "candidate-follow-up", "status": "pending"},
      {"id": "candidate-medication", "status": "pending"},
      {"id": "candidate-referral", "status": "pending"},
      {"id": "candidate-language", "status": "pending"}
    ],
    "verified_facts": [],
    "care_gaps": [],
    "conflicts": [],
    "graph_version": 1
  }
}
```

Changes graph state: yes. Only nodes owned by the named synthetic demo session
are removed and recreated.

## Demo-only backend action

### `add_demo_contradiction`

This action exists for the deterministic acceptance demo. It adds the prepared
four-week doctor statement and candidate, then invokes `VerificationWalker`
with a synthetic demo clinician. It never edits the existing two-week fact.

Inputs:

```text
session_id: str = "demo-default"
```

Output: `BackendResponse.verified_fact` for
`verified-candidate-follow-up-4-weeks`.

Possible errors: `DEMO_NOT_LOADED`, `BASE_FOLLOW_UP_NOT_VERIFIED`,
`CONTRADICTION_ALREADY_ADDED`.

Example request:

```json
{"session_id": "demo-default"}
```

Example response:

```json
{
  "success": true,
  "current_graph_version": 10,
  "verified_fact": {
    "id": "verified-candidate-follow-up-4-weeks",
    "category": "follow_up",
    "value": "return in four weeks",
    "source_chunk_id": "chunk-6",
    "source_text": "Please return in four weeks so we can review the results.",
    "verified_by": "demo-clinician",
    "verified_at": "2026-07-26T18:00:10Z",
    "visible_to_patient": true
  }
}
```

Changes graph state: yes, through deterministic ingest and
`VerificationWalker` only.

## Optional AI configuration and fallback contract

AI is off by default. No key is required for the reliable demo.

```bash
export PA_CO_AI_MODEL="gpt-4o-mini"
export OPENAI_API_KEY="<provider key>"
```

`PA_CO_AI_API_KEY` may be used instead of the provider-specific variable
because `jac.toml` maps it to `[byllm.model].api_key`. For Anthropic or Google,
set `PA_CO_AI_MODEL` plus `ANTHROPIC_API_KEY` or `GOOGLE_API_KEY`.
`BYLLM_DEFAULT_MODEL` overrides the configured model. Ollama (`ollama/...`) and
installed Jac local models (`local:...`) require no API key.

The checked-in `jac.toml` sets temperature `0.0`, output limit `1200`, and a
request timeout of eight seconds. Typed calls use one corrective output retry.
Keys remain environment-only and must never be placed in Git.

For a frontend-callable action, use:

```text
ai_mode="disabled"  deterministic path, no model call
ai_mode="live"      configured provider, validated fallback on every failure
ai_mode="mock"      deterministic Jac MockLLM, tests/demo only
ai_mode="mock_malformed" deliberately invalid MockLLM, recovery tests only
```

AI extraction failure still returns five pending prepared candidates. AI
translation/simplification failure returns the approved English plan. AI
question-matching failure uses deterministic matching; an invalid returned ID
is denied and yields the exact safe fallback. In every recovered case the
top-level result remains usable and `ai_status` records a non-sensitive
diagnostic code.

## Safety invariants

- Candidate facts are never patient-visible.
- Rejected and pending candidates never enter patient plans or answers.
- Only `VerificationWalker` promotes candidates.
- Transcript source text and source-chunk links are immutable.
- Patient-facing output traverses approved, visible graph nodes only.
- Every patient-facing checklist entry and grounded answer carries source fact
  IDs.
- Unknown answers use exactly: “This is not recorded in your approved care
  plan. Please contact your clinic.”
- Contradictions preserve both statements and create a `Conflict`.
- No deterministic or optional AI pathway diagnoses, recommends medication,
  changes dosage, declares treatment safe, performs emergency triage, or fills
  missing medical facts.
- LLM functions return plain typed objects, never graph nodes.
- Only deterministic code can persist validated AI output, and it can persist
  extraction output only as `CandidateFact(status="pending")`.
- Question matching sends only verified allow-list references and never lets a
  model write the answer.
- Translation and simplification preserve source IDs outside the model.
- The deterministic P0 flow uses no model provider and requires no API key.

## Multimodal additive contract

Status: frozen before multimodal implementation. Every earlier action and
field remains compatible. New actions use Jac's existing transport envelope
and the nested `BackendResponse`.

### Enums and DTOs

```text
InputSourceType = typed_text | prepared_transcript | live_voice |
                  audio_upload | camera_capture | image_upload
CaptureSessionStatus = created | permission_required | recording |
                       transcribing | processing | completed | cancelled |
                       failed | fallback
SourceArtifactType = transcript_chunk | audio_metadata | lab_document |
                     referral_document | appointment_card |
                     after_visit_document | clinician_hint
NoteStatus = draft | edited | approved | superseded
ExtractionMode = deterministic | browser_native | local_model | cloud_model |
                 mock | fallback

CaptureSessionDTO
- id, encounter_id, session_id, input_source, status, extraction_mode
- started_at, completed_at, fallback_used, chunk_count, error_code, recoverable

TranscriptChunkDTO (additive)
- id, encounter_id, capture_session_id, sequence, speaker, text
- started_at, ended_at, confidence, source_type, finalized

SourceArtifactDTO
- id, encounter_id, artifact_type, display_name, mime_type, synthetic
- extraction_mode, extraction_status, created_at, temporary_content_deleted

DocumentTextBlockDTO
- id, source_artifact_id, sequence, text, confidence, page_number
- bounding_region, source_hash

MultimodalCandidateDTO
- id, category, value, confidence, status, source_kind
- source_artifact_id, source_chunk_id, source_text_block_id
- source_text, source_region, created_at

NoteSectionDTO
- id, section_type, heading, content, source_fact_ids, source_artifact_ids
- manually_edited, approved

ClinicianNoteDraftDTO
- id, encounter_id, status, patient_concerns, confirmed_instructions
- medication_instructions, laboratory_orders, referrals, follow_up
- unresolved_gaps, note_sections, source_fact_ids
- generated_at, edited_at, approved_at, approved_by

EncounterTimelineEventDTO
- id, event_type, occurred_at, title, description
- related_node_ids, source_fact_ids, graph_version

PatientAudioScriptDTO
- patient_id, language, text, source_fact_ids
- generated_from_approved_plan, voice_name, fallback_used

MultimodalProvenanceDTO
- output_type, output_id, section_id, ordered_steps, source_excerpt
- source_type, verification_status, clinician_id, complete
```

`BackendResponse` adds `capture_session`, `transcript_chunk`,
`transcript_chunks`, `source_artifact`, `document_text_blocks`,
`multimodal_candidates`, `clinician_note`, `timeline`,
`patient_audio_script`, and `multimodal_provenance`.

Every action can return this cross-session-safe failure:

```json
{"success":false,"error_code":"RESOURCE_NOT_FOUND","message":"The synthetic resource was not found in this session.","recoverable":true,"current_graph_version":4}
```

### Voice and transcript actions

#### `start_capture_session(encounter_id, input_source, session_id="demo-default")`

Public function spawning `StartCaptureSessionWalker`. `encounter_id` and
`input_source` are required. It returns `capture_session`, creates one graph
node, and increments the graph version. `live_voice` begins in
`permission_required`; prepared/typed input begins in `created`. Errors:
`DEMO_NOT_LOADED`, `ENCOUNTER_NOT_FOUND`, `INVALID_INPUT_SOURCE`,
`ACTIVE_CAPTURE_EXISTS`. No provider fallback is needed.

```json
{"encounter_id":"encounter-maya-001","input_source":"prepared_transcript","session_id":"demo-default"}
```
```json
{"success":true,"current_graph_version":2,"capture_session":{"id":"capture-demo-default-2","status":"created","chunk_count":0}}
```
```json
{"success":false,"error_code":"ACTIVE_CAPTURE_EXISTS","recoverable":true}
```

#### `append_transcript_chunk(capture_session_id, sequence, speaker, text, started_at="", ended_at="", confidence=1.0, session_id="demo-default")`

Public function spawning `AppendTranscriptChunkWalker`. The first four fields
are required. It returns `transcript_chunk` and `capture_session`; a new chunk
increments the version and identical replay is idempotent. Errors:
`CAPTURE_NOT_FOUND`, `CAPTURE_CLOSED`, `INVALID_SEQUENCE`,
`OUT_OF_ORDER_CHUNK`, `DUPLICATE_SEQUENCE`, `INVALID_SPEAKER`,
`BLANK_TRANSCRIPT`, `INVALID_CONFIDENCE`. It never invokes a model.

```json
{"capture_session_id":"capture-demo-default-2","sequence":1,"speaker":"Doctor","text":"We will order a blood test to be completed this week.","confidence":1.0,"session_id":"demo-default"}
```
```json
{"success":true,"transcript_chunk":{"id":"chunk-1","sequence":1,"speaker":"Doctor","finalized":true},"capture_session":{"status":"recording","chunk_count":1}}
```
```json
{"success":false,"error_code":"OUT_OF_ORDER_CHUNK","recoverable":true}
```

#### `finalize_capture_session(capture_session_id, session_id="demo-default")`

Public function spawning `FinalizeCaptureSessionWalker`. It returns a
completed `capture_session` and pending `candidate_facts`, mutates once, and
is idempotent. Internal state passes through `transcribing` and `processing`.
Errors: `CAPTURE_NOT_FOUND`, `EMPTY_CAPTURE`, `CAPTURE_CANCELLED`,
`TRANSCRIPT_SEQUENCE_GAP`. Optional extraction failure uses prepared
candidates and reports `TRANSCRIPTION_FALLBACK_USED`.

```json
{"capture_session_id":"capture-demo-default-2","session_id":"demo-default"}
```
```json
{"success":true,"capture_session":{"status":"completed","chunk_count":5},"candidate_facts":[{"id":"candidate-lab","status":"pending"}]}
```
```json
{"success":true,"recoverable":true,"error_code":"TRANSCRIPTION_FALLBACK_USED","capture_session":{"status":"completed","fallback_used":true}}
```

#### `cancel_capture_session(capture_session_id, session_id="demo-default")`

Public function spawning `CancelCaptureSessionWalker`. It returns
`capture_session`, mutates an unfinished capture, increments once, and is
idempotent. Errors: `CAPTURE_NOT_FOUND`, `CAPTURE_ALREADY_COMPLETED`.

```json
{"capture_session_id":"capture-demo-default-2","session_id":"demo-default"}
```
```json
{"success":true,"capture_session":{"status":"cancelled"}}
```
```json
{"success":false,"error_code":"CAPTURE_ALREADY_COMPLETED","recoverable":false}
```

#### `get_capture_session(capture_session_id, session_id="demo-default")`

Read-only public function. It returns `capture_session`; error:
`CAPTURE_NOT_FOUND`.

```json
{"capture_session_id":"capture-demo-default-2","session_id":"demo-default"}
```
```json
{"success":true,"capture_session":{"id":"capture-demo-default-2","chunk_count":3}}
```
```json
{"success":false,"error_code":"CAPTURE_NOT_FOUND","recoverable":true}
```

#### `load_prepared_voice_demo(encounter_id, session_id="demo-default")`

Public function spawning `LoadPreparedVoiceDemoWalker`. It starts a prepared
capture then uses the same append walker for all five chunks; it never creates
a parallel source graph. It returns the recording `capture_session` and
ordered `transcript_chunks`. Repeated calls return the same prepared capture.
Errors mirror start/append and `PREPARED_STREAM_FAILED`.

```json
{"encounter_id":"encounter-maya-001","session_id":"demo-default"}
```
```json
{"success":true,"capture_session":{"status":"recording","chunk_count":5},"transcript_chunks":[{"sequence":1},{"sequence":2},{"sequence":3},{"sequence":4},{"sequence":5}]}
```
```json
{"success":false,"error_code":"PREPARED_STREAM_FAILED","recoverable":true}
```

### Document actions

#### `ingest_document_image(encounter_id, document_type, filename, mime_type, image_input, synthetic, session_id="demo-default", extraction_mode="deterministic")`

Public function spawning `DocumentIngestWalker`; the first six fields are
required. Over HTTP this action consumes `multipart/form-data`;
`image_input` is an `UploadFile` and the other fields are form fields.
PNG/JPEG/WEBP content is limited to 1 MiB decoded. This representation keeps
raw image bytes out of Jac's generated function-parameter console line (the
runtime prints only upload filename, size, and headers). Direct backend tests
use a non-public data-URL adapter that reaches the same validation walker.
The action returns `source_artifact`, `document_text_blocks`, and pending
`multimodal_candidates`; persists metadata/text only; deletes temporary
content; and increments the version. Errors: `ENCOUNTER_NOT_FOUND`,
`REAL_DATA_PROHIBITED`, `DOCUMENT_TYPE_INVALID`, `MIME_TYPE_INVALID`,
`IMAGE_TOO_LARGE`, `IMAGE_DATA_URL_INVALID`, `IMAGE_EMPTY`, `IMAGE_CORRUPT`,
`IMAGE_READ_FAILED`, `EXTRACTION_MODE_INVALID`, `DOCUMENT_ALREADY_INGESTED`.
A model/key failure uses deterministic extraction with
`VISION_FALLBACK_USED`.

```bash
curl -F encounter_id=encounter-maya-001 \
  -F document_type=lab_document \
  -F filename=synthetic_lab_order.png \
  -F mime_type=image/png \
  -F 'image_input=@synthetic_lab_order.png;type=image/png' \
  -F synthetic=true \
  -F session_id=demo-default \
  -F extraction_mode=deterministic \
  http://localhost:8000/function/ingest_document_image
```
```json
{"success":true,"source_artifact":{"id":"artifact-demo-default-lab-document","temporary_content_deleted":true,"extraction_status":"completed"},"document_text_blocks":[{"sequence":1,"bounding_region":"0,0,100,20"}],"multimodal_candidates":[{"category":"lab_order","status":"pending","source_kind":"document"}]}
```
```json
{"success":false,"error_code":"IMAGE_CORRUPT","recoverable":true}
```

#### `get_document_extraction(source_artifact_id, session_id="demo-default")`

Read-only public function returning artifact, blocks, and candidates. Error:
`SOURCE_ARTIFACT_NOT_FOUND`.

```json
{"source_artifact_id":"artifact-demo-default-lab-document","session_id":"demo-default"}
```
```json
{"success":true,"source_artifact":{"extraction_status":"completed"},"document_text_blocks":[{"sequence":1}]}
```
```json
{"success":false,"error_code":"SOURCE_ARTIFACT_NOT_FOUND","recoverable":true}
```

#### `retry_document_extraction(source_artifact_id, extraction_mode, session_id="demo-default")`

Public function spawning the extraction walker. Completed deterministic
extraction is idempotent. Raw bytes are never retained, so retry validates
stored synthetic blocks and returns the existing candidate; unavailable
model input reports `RAW_CONTENT_UNAVAILABLE` or safely falls back. Errors:
`SOURCE_ARTIFACT_NOT_FOUND`, `EXTRACTION_MODE_INVALID`.

```json
{"source_artifact_id":"artifact-demo-default-lab-document","extraction_mode":"mock","session_id":"demo-default"}
```
```json
{"success":true,"source_artifact":{"extraction_mode":"mock"},"multimodal_candidates":[{"status":"pending"}]}
```
```json
{"success":true,"recoverable":true,"error_code":"VISION_FALLBACK_USED","source_artifact":{"extraction_mode":"fallback"}}
```

### Clinician note actions

#### `generate_clinician_note_draft(encounter_id, clinician_hints="", session_id="demo-default")`

Public function spawning `GenerateClinicianNoteDraftWalker`. It returns
`clinician_note`, mutates, and increments the version. Only current verified
facts, gaps/conflicts, and clearly labeled hints are used. Errors:
`ENCOUNTER_NOT_FOUND`, `NO_VERIFIED_FACTS`, `UNSAFE_CLINICIAN_HINT`.
Deterministic generation is always available.

```json
{"encounter_id":"encounter-maya-001","clinician_hints":"Confirm interpreter follow-up.","session_id":"demo-default"}
```
```json
{"success":true,"clinician_note":{"status":"draft","note_sections":[{"section_type":"laboratory_orders","source_fact_ids":["verified-candidate-lab"]}]}}
```
```json
{"success":false,"error_code":"NO_VERIFIED_FACTS","recoverable":true}
```

#### `update_note_section(note_id, section_id, content, clinician_id, session_id="demo-default")`

Public function spawning `UpdateNoteSectionWalker`. It preserves generated
text, stores edited text separately, returns `clinician_note`, and increments
the version. Editing an approved note creates a superseding draft. Errors:
`NOTE_NOT_FOUND`, `SECTION_NOT_FOUND`, `INVALID_CLINICIAN_ID`,
`BLANK_NOTE_CONTENT`, `UNSAFE_NOTE_CONTENT`.

```json
{"note_id":"note-demo-default-8","section_id":"note-demo-default-8-labs","content":"Blood test remains due this week.","clinician_id":"clinician-1","session_id":"demo-default"}
```
```json
{"success":true,"clinician_note":{"status":"edited","note_sections":[{"manually_edited":true}]}}
```
```json
{"success":false,"error_code":"UNSAFE_NOTE_CONTENT","recoverable":true}
```

#### `approve_clinician_note(note_id, clinician_id, session_id="demo-default")`

Public function spawning `ApproveClinicianNoteWalker`. It validates sections
and unresolved unsafe content, persists `NoteApprovalEvent`, returns approved
`clinician_note`, and increments once. Repeated approval is idempotent. Errors:
`NOTE_NOT_FOUND`, `INVALID_CLINICIAN_ID`, `NOTE_SECTION_MISSING`,
`UNRESOLVED_NOTE_CONFLICT`.

```json
{"note_id":"note-demo-default-8","clinician_id":"clinician-1","session_id":"demo-default"}
```
```json
{"success":true,"clinician_note":{"status":"approved","approved_by":"clinician-1"}}
```
```json
{"success":false,"error_code":"UNRESOLVED_NOTE_CONFLICT","recoverable":true}
```

#### `get_clinician_note(note_id, session_id="demo-default")`

Read-only public function returning `clinician_note`. Error: `NOTE_NOT_FOUND`.

```json
{"note_id":"note-demo-default-8","session_id":"demo-default"}
```
```json
{"success":true,"clinician_note":{"id":"note-demo-default-8","status":"approved"}}
```
```json
{"success":false,"error_code":"NOTE_NOT_FOUND","recoverable":true}
```

### Timeline, provenance, and accessibility

#### `get_encounter_timeline(encounter_id, session_id="demo-default")`

Public function spawning `EncounterTimelineWalker`; read-only; returns ordered
`timeline` events derived from graph/audit state. Error:
`ENCOUNTER_NOT_FOUND`. No hardcoded event list is returned.

```json
{"encounter_id":"encounter-maya-001","session_id":"demo-default"}
```
```json
{"success":true,"timeline":[{"event_type":"capture_started","graph_version":2}]}
```
```json
{"success":false,"error_code":"ENCOUNTER_NOT_FOUND","recoverable":true}
```

#### `trace_output_to_source(output_type, output_id, section_id="", session_id="demo-default")`

Public function spawning `MultimodalTraceProvenanceWalker`; read-only; supports
candidate, note section, checklist item, and patient answer. It returns one
`multimodal_provenance` chain per support fact. Errors:
`OUTPUT_TYPE_INVALID`, `OUTPUT_NOT_FOUND`, `PROVENANCE_INCOMPLETE`.

```json
{"output_type":"note_section","output_id":"note-demo-default-8","section_id":"note-demo-default-8-labs","session_id":"demo-default"}
```
```json
{"success":true,"multimodal_provenance":[{"source_type":"transcript_chunk","verification_status":"accepted","complete":true}]}
```
```json
{"success":false,"error_code":"PROVENANCE_INCOMPLETE","recoverable":false}
```

#### `generate_patient_audio_script(language, session_id="demo-default")`

Public function spawning `PatientAudioScriptWalker`. It uses only a current
approved `PatientBrief`, returns `patient_audio_script`, and increments the
version only on first creation. Text is still usable if browser speech
synthesis is unavailable. Errors: `PATIENT_PLAN_NOT_FOUND`,
`UNSUPPORTED_LANGUAGE`, `CONFLICTED_PLAN`.

```json
{"language":"Spanish","session_id":"demo-default"}
```
```json
{"success":true,"patient_audio_script":{"language":"Spanish","generated_from_approved_plan":true,"source_fact_ids":["verified-candidate-lab"],"fallback_used":false}}
```
```json
{"success":false,"error_code":"PATIENT_PLAN_NOT_FOUND","recoverable":true}
```

## Live translation and verified encounter intelligence

This section is additive. Every action and field above remains supported.
Intelligence actions use the same nested `BackendResponse` and generated Jac
HTTP envelope documented earlier. A generated `/function/*` response is an
outer JSON array containing the nested response object; direct Jac calls
return the nested `BackendResponse`.

The reliable default is deterministic and keyless. Optional modes are selected
by the server's configured intelligence adapter, never by transcript content.
`model_mode` reports the adapter that actually produced an output.
`fallback_used=true` means the requested adapter failed validation or was
unavailable and deterministic Jac behavior produced the response.

### Enums

```text
TranslationStatus = pending | translating | translated | fallback | failed
AnalysisStatus = created | running | completed | partial | failed | superseded
AnalysisSourceScope =
  unverified_transcript | verified_graph | approved_patient_plan
QuestionPurpose =
  clarify_missing_information | resolve_documentation_gap |
  confirm_follow_up | confirm_responsibility | resolve_contradiction
```

These are internal string-backed enums and serialize exactly as the lowercase
values above.

### Additive response fields

`BackendResponse` adds:

```text
translated_chunk: TranslatedTranscriptChunkDTO | None
translated_transcript: list[TranslatedTranscriptChunkDTO]
live_quick_summary: LiveQuickSummaryDTO | None
verified_encounter_summary: VerifiedEncounterSummaryDTO | None
analysis_run: AnalysisRunDTO | None
suggested_questions: list[SuggestedQuestionDTO]
final_review_packet: FinalReviewPacketDTO | None
analysis_provenance: list[AnalysisProvenanceDTO]
```

All existing fields remain unchanged. A failure continues to include
`success=false`, `error_code`, `message`, `recoverable`, and
`current_graph_version`. Model-backed failures also return a non-sensitive
`ai_status`; they never expose a key, prompt, raw media, or hidden reasoning.

### Intelligence DTOs

`TranslatedTranscriptChunkDTO`

```text
id: str
original_chunk_id: str
capture_session_id: str
source_language: str
target_language: str
original_text: str
translated_text: str
speaker: str
sequence: int
status: str
translation_mode: str
fallback_used: bool
created_at: str
```

`LiveQuickSummaryDTO`

```text
id: str
encounter_id: str
status: str
summary: str
key_points: list[str]
source_chunk_ids: list[str]
unverified: bool
model_mode: str
fallback_used: bool
generated_at: str
```

The required UI label is `AI conversation draft — not yet clinician
verified.`

`VerifiedEncounterSummaryDTO`

```text
id: str
encounter_id: str
summary: str
patient_concerns: list[str]
medications: list[str]
allergies: list[str]
laboratory_orders: list[str]
referrals: list[str]
follow_ups: list[str]
outstanding_tasks: list[str]
contradictions: list[str]
source_fact_ids: list[str]
verified_only: bool
generated_at: str
```

`InsightItemDTO`

```text
id: str
insight_type: str
title: str
description: str
severity: str
source_fact_ids: list[str]
related_gap_ids: list[str]
requires_clinician_review: bool
```

`SuggestedQuestionDTO`

```text
id: str
question: str
purpose: str
explanation: str
source_fact_ids: list[str]
related_gap_ids: list[str]
clinician_only: bool
status: str
```

`AnalysisRunDTO`

```text
id: str
encounter_id: str
status: str
graph_version: int
accepted_fact_ids: list[str]
rejected_fact_ids_excluded: list[str]
summary: VerifiedEncounterSummaryDTO | None
insights: list[InsightItemDTO]
questions: list[SuggestedQuestionDTO]
care_gaps: list[CareGapDTO]
conflicts: list[ConflictDTO]
source_fact_ids: list[str]
model_mode: str
fallback_used: bool
created_at: str
completed_at: str
stale: bool
superseding_run_id: str
```

`FinalReviewPacketDTO`

```text
id: str
encounter_id: str
verified_summary: VerifiedEncounterSummaryDTO | None
clinician_note_id: str
suggested_questions: list[SuggestedQuestionDTO]
active_care_gaps: list[CareGapDTO]
conflicts: list[ConflictDTO]
patient_plan_id: str
english_patient_plan: PatientPlanDTO | None
spanish_patient_plan: PatientPlanDTO | None
encounter_timeline: list[EncounterTimelineEventDTO]
source_fact_ids: list[str]
graph_version: int
generated_at: str
verified_items: list[str]
requires_review_items: list[str]
unverified_items: list[str]
```

`AnalysisProvenanceDTO`

```text
analysis_run_id: str
item_id: str
item_type: str
source_fact_ids: list[str]
ordered_steps: list[TraversalStepDTO]
source_excerpt: str
source_type: str
complete: bool
```

### `translate_transcript_chunk`

```text
translate_transcript_chunk(
  transcript_chunk_id: str,
  target_language: str,
  session_id: str = "demo-default"
) -> BackendResponse
```

Spawns `TranslateTranscriptChunkWalker` from the selected synthetic session.
The source chunk must be finalized and belong to that session. The walker
preserves the original text, speaker, sequence, dates, numbers, names,
negation, and uncertainty. It creates at most one current translation per
source/target pair. Translation cannot create a candidate or verified fact.

- Success: `translated_chunk`
- Loading status: a persisted translation may move from `pending` to
  `translating` to `translated`; the synchronous public response is terminal
- Model mode: configured adapter, deterministic prepared map, pass-through, or
  fallback
- Graph mutation: yes on first creation or status transition
- Graph version: increments only when translation state changes
- Errors: `SESSION_NOT_FOUND`, `TRANSCRIPT_CHUNK_NOT_FOUND`,
  `TRANSCRIPT_CHUNK_NOT_FINALIZED`, `UNSUPPORTED_LANGUAGE`,
  `TRANSLATION_VALIDATION_FAILED`

Request:

```json
{"transcript_chunk_id":"chunk-live-es-1","target_language":"English","session_id":"demo-default"}
```

Success:

```json
{"success":true,"current_graph_version":4,"translated_chunk":{"id":"translation-demo-default-chunk-live-es-1-English","original_chunk_id":"chunk-live-es-1","source_language":"Spanish","target_language":"English","original_text":"Me he sentido mareada durante tres días.","translated_text":"I have felt dizzy for three days.","speaker":"Patient","sequence":1,"status":"translated","translation_mode":"deterministic","fallback_used":false}}
```

Failure:

```json
{"success":false,"error_code":"TRANSCRIPT_CHUNK_NOT_FOUND","message":"The finalized transcript chunk was not found in this session.","recoverable":true,"current_graph_version":3}
```

### `get_translated_transcript`

```text
get_translated_transcript(
  capture_session_id: str,
  target_language: str,
  session_id: str = "demo-default"
) -> BackendResponse
```

Spawns `GetTranslatedTranscriptWalker`, traverses only the named capture, and
returns `translated_transcript` in source sequence order. It never
auto-translates missing rows.

- Graph mutation/version: none
- Model/fallback: reports persisted row values only
- Errors: `CAPTURE_NOT_FOUND`, `UNSUPPORTED_LANGUAGE`

Request:

```json
{"capture_session_id":"capture-demo-default-2","target_language":"English","session_id":"demo-default"}
```

Success:

```json
{"success":true,"translated_transcript":[{"original_chunk_id":"chunk-live-es-1","sequence":1,"status":"translated"}]}
```

Failure:

```json
{"success":false,"error_code":"CAPTURE_NOT_FOUND","message":"The capture was not found in this session.","recoverable":true}
```

### `retry_translation`

```text
retry_translation(
  translated_chunk_id: str,
  session_id: str = "demo-default"
) -> BackendResponse
```

Spawns `RetryTranslationWalker`. Only a current `fallback` or `failed`
translation in the selected session is eligible. The original transcript is
immutable.

- Graph mutation: yes when a retry status/result changes
- Graph version: increments on change; successful idempotent replay does not
- Model/fallback: configured adapter with deterministic fallback
- Errors: `TRANSLATION_NOT_FOUND`, `TRANSLATION_NOT_RETRYABLE`

Request:

```json
{"translated_chunk_id":"translation-demo-default-chunk-live-es-1-English","session_id":"demo-default"}
```

Success:

```json
{"success":true,"translated_chunk":{"status":"translated","fallback_used":false}}
```

Failure:

```json
{"success":false,"error_code":"TRANSLATION_NOT_RETRYABLE","message":"Only failed or fallback translations can be retried.","recoverable":false}
```

### `generate_live_quick_summary`

```text
generate_live_quick_summary(
  encounter_id: str,
  session_id: str = "demo-default"
) -> BackendResponse
```

Spawns `LiveQuickSummaryWalker`, reads finalized encounter transcript chunks,
and stores a superseding unverified draft. It can summarize only speaker-aware
source text and must retain all supporting chunk IDs. It cannot create a
candidate, verification, note approval, or patient brief.

- Success: `live_quick_summary` with `unverified=true`
- Graph mutation/version: yes for a new or changed draft
- Model/fallback: optional validated model; deterministic extractive fallback
- Errors: `ENCOUNTER_NOT_FOUND`, `NO_FINALIZED_TRANSCRIPT`,
  `QUICK_SUMMARY_UNSUPPORTED_CLAIM`

Request:

```json
{"encounter_id":"encounter-maya-001","session_id":"demo-default"}
```

Success:

```json
{"success":true,"live_quick_summary":{"id":"quick-summary-demo-default-5","status":"completed","summary":"Patient: I have felt dizzy for three days. Doctor: A blood test will be ordered this week.","key_points":["I have felt dizzy for three days.","A blood test will be ordered this week."],"source_chunk_ids":["chunk-live-es-1","chunk-live-en-2"],"unverified":true,"model_mode":"deterministic","fallback_used":false}}
```

Failure:

```json
{"success":false,"error_code":"NO_FINALIZED_TRANSCRIPT","message":"No finalized transcript is available for an unverified quick summary.","recoverable":true}
```

### `get_live_quick_summary`

```text
get_live_quick_summary(
  encounter_id: str,
  session_id: str = "demo-default"
) -> BackendResponse
```

Spawns `GetLiveQuickSummaryWalker` and returns the current unverified draft.

- Graph mutation/version: none
- Model/fallback: persisted values only
- Errors: `ENCOUNTER_NOT_FOUND`, `QUICK_SUMMARY_NOT_FOUND`

Request:

```json
{"encounter_id":"encounter-maya-001","session_id":"demo-default"}
```

Success:

```json
{"success":true,"live_quick_summary":{"unverified":true,"source_chunk_ids":["chunk-live-es-1","chunk-live-en-2"]}}
```

Failure:

```json
{"success":false,"error_code":"QUICK_SUMMARY_NOT_FOUND","message":"No live quick summary exists for this encounter.","recoverable":true}
```

### `run_verified_encounter_analysis`

```text
run_verified_encounter_analysis(
  encounter_id: str,
  session_id: str = "demo-default"
) -> BackendResponse
```

Spawns `VerifiedEncounterAnalysisWalker`. Deterministic Jac selects accepted
`VerifiedFact` paths, specialized obligations, tasks, active gaps, conflicts,
and supporting evidence. Pending and rejected candidates, other sessions,
quick-summary claims, and unresolved conflicting patient-facing conclusions
are excluded before optional model organization.

- Success: `analysis_run`, `verified_encounter_summary`, `care_gaps`,
  `conflicts`
- Graph mutation/version: analysis nodes are persisted; domain graph version
  remains the evidence version used by the run
- Model/fallback: optional organization of the allowed facts; deterministic
  structured fallback
- Errors: `ENCOUNTER_NOT_FOUND`, `NO_VERIFIED_FACTS`,
  `ANALYSIS_VALIDATION_FAILED`

Request:

```json
{"encounter_id":"encounter-maya-001","session_id":"demo-default"}
```

Success:

```json
{"success":true,"current_graph_version":9,"analysis_run":{"id":"analysis-demo-default-9-1","status":"completed","graph_version":9,"accepted_fact_ids":["verified-candidate-lab"],"rejected_fact_ids_excluded":["candidate-language"],"source_fact_ids":["verified-candidate-lab"],"model_mode":"deterministic","fallback_used":false,"stale":false},"verified_encounter_summary":{"verified_only":true,"laboratory_orders":["blood test; due this week"],"source_fact_ids":["verified-candidate-lab"]}}
```

Failure:

```json
{"success":false,"error_code":"NO_VERIFIED_FACTS","message":"No accepted facts are available for verified analysis.","recoverable":true,"current_graph_version":2}
```

### `get_verified_encounter_analysis`

```text
get_verified_encounter_analysis(
  analysis_run_id: str,
  session_id: str = "demo-default"
) -> BackendResponse
```

Spawns `GetVerifiedEncounterAnalysisWalker`. It returns the scoped run and
computes `stale=true` when its evidence version differs from the session graph
version or it has a superseding run. A stale response must display `New
verified information is available. Re-run analysis.`

- Graph mutation/version: none
- Model/fallback: persisted values only
- Errors: `ANALYSIS_NOT_FOUND`

Request:

```json
{"analysis_run_id":"analysis-demo-default-9-1","session_id":"demo-default"}
```

Success:

```json
{"success":true,"analysis_run":{"id":"analysis-demo-default-9-1","status":"superseded","stale":true,"superseding_run_id":"analysis-demo-default-10-2"}}
```

Failure:

```json
{"success":false,"error_code":"ANALYSIS_NOT_FOUND","message":"The analysis run was not found in this session.","recoverable":true}
```

### `generate_clarifying_questions`

```text
generate_clarifying_questions(
  encounter_id: str,
  analysis_run_id: str,
  session_id: str = "demo-default"
) -> BackendResponse
```

Spawns `ClarifyingQuestionWalker`. Each generated question must connect to a
current accepted fact and a current `CareGap` or `Conflict`. Questions are
administrative/documentation prompts only and are always clinician-only.

- Success: `suggested_questions` and updated `analysis_run.questions`
- Graph mutation/version: persists idempotent question nodes; does not change
  the evidence graph version
- Model/fallback: optional wording from allowed graph material; deterministic
  templates otherwise
- Errors: `ENCOUNTER_NOT_FOUND`, `ANALYSIS_NOT_FOUND`,
  `ANALYSIS_STALE`, `QUESTION_VALIDATION_FAILED`

Request:

```json
{"encounter_id":"encounter-maya-001","analysis_run_id":"analysis-demo-default-9-1","session_id":"demo-default"}
```

Success:

```json
{"success":true,"suggested_questions":[{"id":"question-gap-lab-owner-verified-candidate-lab","question":"Who is responsible for coordinating the blood test?","purpose":"confirm_responsibility","source_fact_ids":["verified-candidate-lab"],"related_gap_ids":["gap-lab-owner-verified-candidate-lab"],"clinician_only":true,"status":"open"}]}
```

Failure:

```json
{"success":false,"error_code":"ANALYSIS_STALE","message":"New verified information is available. Re-run analysis.","recoverable":true}
```

### `dismiss_suggested_question`

```text
dismiss_suggested_question(
  question_id: str,
  clinician_id: str,
  session_id: str = "demo-default"
) -> BackendResponse
```

Spawns `DismissSuggestedQuestionWalker` and records the clinician-controlled
status transition. It does not alter evidence, gaps, or conflicts.

- Graph mutation: yes; the persisted clinician-review status changes
- Graph version: unchanged because accepted evidence, gaps, conflicts, and
  patient-visible outputs do not change
- Model/fallback: none
- Errors: `QUESTION_NOT_FOUND`, `CLINICIAN_ID_REQUIRED`,
  `QUESTION_ALREADY_ANSWERED`

Request:

```json
{"question_id":"question-gap-lab-owner-verified-candidate-lab","clinician_id":"demo-clinician","session_id":"demo-default"}
```

Success:

```json
{"success":true,"suggested_questions":[{"id":"question-gap-lab-owner-verified-candidate-lab","status":"dismissed"}]}
```

Failure:

```json
{"success":false,"error_code":"QUESTION_NOT_FOUND","message":"The suggested question was not found in this session.","recoverable":true}
```

### `mark_question_answered`

```text
mark_question_answered(
  question_id: str,
  answer_source_fact_id: str,
  clinician_id: str,
  session_id: str = "demo-default"
) -> BackendResponse
```

Spawns `MarkSuggestedQuestionAnsweredWalker`. The answer source must already be
a current-session `VerifiedFact`; this action never creates or promotes one.

- Graph mutation: yes; the question gains clinician-review state and a
  `QuestionAnsweredBy` edge to an already accepted fact
- Graph version: unchanged because no accepted evidence is created or modified
- Model/fallback: none
- Errors: `QUESTION_NOT_FOUND`, `VERIFIED_FACT_NOT_FOUND`,
  `CLINICIAN_ID_REQUIRED`, `QUESTION_SUPPORT_INVALID`

Request:

```json
{"question_id":"question-gap-lab-owner-verified-candidate-lab","answer_source_fact_id":"verified-candidate-lab-owner","clinician_id":"demo-clinician","session_id":"demo-default"}
```

Success:

```json
{"success":true,"suggested_questions":[{"id":"question-gap-lab-owner-verified-candidate-lab","status":"answered","source_fact_ids":["verified-candidate-lab","verified-candidate-lab-owner"]}]}
```

Failure:

```json
{"success":false,"error_code":"VERIFIED_FACT_NOT_FOUND","message":"The answer source is not an accepted fact in this session.","recoverable":true}
```

### `generate_final_review_packet`

```text
generate_final_review_packet(
  encounter_id: str,
  session_id: str = "demo-default"
) -> BackendResponse
```

Spawns `FinalReviewPacketWalker`. It combines the latest current analysis,
review-ready/approved clinician note, active gaps, resolved tasks, suggested
questions, conflicts, current English and Spanish patient plans, timeline,
provenance identifiers, and graph version. It preserves separate
`verified_items`, `requires_review_items`, and `unverified_items`.

- Graph mutation/version: persists a versioned packet; the evidence graph
  version does not change
- Model/fallback: no new clinical generation; uses current validated outputs
- Errors: `ENCOUNTER_NOT_FOUND`, `CURRENT_ANALYSIS_NOT_FOUND`,
  `ANALYSIS_STALE`, `PATIENT_PLAN_NOT_FOUND`

Request:

```json
{"encounter_id":"encounter-maya-001","session_id":"demo-default"}
```

Success:

```json
{"success":true,"final_review_packet":{"id":"final-packet-demo-default-14","graph_version":14,"verified_items":["Verified encounter summary","Approved English patient plan"],"requires_review_items":["2 active care gaps"],"unverified_items":["AI conversation draft — not yet clinician verified."]}}
```

Failure:

```json
{"success":false,"error_code":"ANALYSIS_STALE","message":"New verified information is available. Re-run analysis.","recoverable":true}
```

### `trace_analysis_item`

```text
trace_analysis_item(
  analysis_run_id: str,
  item_id: str,
  session_id: str = "demo-default"
) -> BackendResponse
```

Spawns `TraceAnalysisItemWalker`. It walks from a summary, insight, or
suggested-question item through accepted facts to immutable transcript or
document evidence. It returns one `analysis_provenance` chain per support
fact.

- Graph mutation/version: none
- Model/fallback: none
- Errors: `ANALYSIS_NOT_FOUND`, `ANALYSIS_ITEM_NOT_FOUND`,
  `PROVENANCE_INCOMPLETE`

Request:

```json
{"analysis_run_id":"analysis-demo-default-14-2","item_id":"insight-gap-lab-owner","session_id":"demo-default"}
```

Success:

```json
{"success":true,"analysis_provenance":[{"analysis_run_id":"analysis-demo-default-14-2","item_id":"insight-gap-lab-owner","source_fact_ids":["verified-candidate-lab"],"source_type":"transcript","source_excerpt":"We will order a blood test to be completed this week.","complete":true}]}
```

Failure:

```json
{"success":false,"error_code":"PROVENANCE_INCOMPLETE","message":"The analysis item does not have a complete current-session evidence chain.","recoverable":false}
```

## Intelligence state and invalidation

An analysis becomes stale after a candidate decision, gap resolution,
contradiction insertion, note approval, new transcript chunk, or acceptance of
a document-derived fact. Old analysis, summaries, questions, and final packets
remain as audit history but are not presented as current. A rerun records
`superseding_run_id` on the prior analysis.

Translations and quick summaries belong to the unverified transcript scope.
Verified encounter summaries belong to `verified_graph`. Patient-plan
translation belongs to `approved_patient_plan`. No action may silently move
content between these scopes.
