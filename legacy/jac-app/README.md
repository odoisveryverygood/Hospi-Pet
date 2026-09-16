# Pa-Co CareGraph

Pa-Co CareGraph is a Jac-native verified continuity-of-care graph that turns
synthetic consultation information into clinician-approved, traceable patient
follow-up plans.

Development is underway. The production-shaped backend and deterministic
multimodal workflow are implemented on Jac 0.34.7; frontend work remains
separately owned.

## Backend status

The reliable path is deterministic and needs no model or API key. It loads the
synthetic Maya Rivera consultation, proposes five pending facts, records
clinician decisions, creates typed care obligations, detects documentation
gaps, stores append-only resolutions, generates an approved-only checklist,
answers from stored evidence, detects contradictions without overwriting
either statement, and resets one synthetic session.

The additive multimodal path streams prepared or browser-produced
speaker-labeled chunks into the same evidence graph, validates small synthetic
document images, optionally exercises a typed Jac `Image` seam, creates only
pending document proposals, drafts/edits/approves a sourced clinician-review
note, derives an encounter timeline, and returns English/Spanish scripts for
browser speech synthesis. Raw audio and raw image bytes are never persisted.

The additive intelligence path pairs finalized English/Spanish transcript
chunks with literal translations, produces an explicitly unverified live
conversation draft, traverses only clinician-accepted facts for verified
encounter analysis, generates gap/conflict-bound clarification questions,
invalidates stale analysis by graph version, and assembles a final packet with
separate verified, review-required, and unverified sections.

Optional Jac `by llm()` helpers may propose unverified candidates, translate or
simplify an approved brief, and select relevant verified IDs. Deterministic code
validates every result and remains the only code that can mutate the graph.

See [CONTRACT.md](CONTRACT.md) for the stable frontend interface,
[JAC_DEMO_GUIDE.md](JAC_DEMO_GUIDE.md) for the demo, and
[TECHNICAL_JUDGE_GUIDE.md](TECHNICAL_JUDGE_GUIDE.md) for verification evidence.

## Start and verify

Use the pinned compiler:

```bash
/Users/aradhyamishra/.local/bin/jac --version
/Users/aradhyamishra/.local/bin/jac start main.jac --no-client
```

The generated service listens at <http://localhost:8000>. Useful routes are
`/docs`, `/openapi.json`, `/healthz`, and `POST /function/<action>`.

Run the complete gate from the repository root:

```bash
/Users/aradhyamishra/.local/bin/jac clean --all --force
/Users/aradhyamishra/.local/bin/jac fmt . --check
/Users/aradhyamishra/.local/bin/jac check .
/Users/aradhyamishra/.local/bin/jac test -d tests/ -v
/Users/aradhyamishra/.local/bin/jac run tests/server_integration.jac
/Users/aradhyamishra/.local/bin/jac run tests/multimodal_server.jac
/Users/aradhyamishra/.local/bin/jac run tests/production_demo.jac
/Users/aradhyamishra/.local/bin/jac run tests/multimodal_demo.jac
/Users/aradhyamishra/.local/bin/jac run tests/intelligence_demo.jac
```

`production_demo.jac` executes 36 checks in each cycle, five cycles in each of
four mandatory modes: AI disabled, missing-key fallback, valid MockLLM, and
malformed MockLLM. That is 20 full cycles and 720 checked steps.

`multimodal_demo.jac` executes the 36-step encounter, document, note,
timeline, audio, provenance, conflict, and reset flow three times in each of
deterministic, missing-key fallback, and valid MockLLM modes: nine complete
multimodal cycles.

`intelligence_demo.jac` executes the complete 34-step bilingual translation,
unverified-summary, verification, analysis, question, stale-version, final
packet, voice/document trace, contradiction, and reset flow three times in
each mandatory mode: disabled, valid MockLLM, and malformed MockLLM fallback.
That is nine complete intelligence cycles.

## Canonical graph

`SessionOwns` is retained only as the synthetic-session reset boundary.
Clinical behavior navigates domain relationships:

```text
Root -HasSession→ DemoSession -HasPatient→ Patient -HasEncounter→ Encounter
Encounter -ContainsChunk→ TranscriptChunk
Encounter -HasCandidate→ CandidateFact -ExtractedFrom→ TranscriptChunk
CandidateFact -PromotedTo→ VerifiedFact -Represents*→ obligation
Encounter -HasTask/HasGap→ CareTask/CareGap
Patient -HasBrief→ PatientBrief -HasChecklistItem→ ChecklistItem
Patient -HasQuestion→ PatientQuestion -HasAnswer→ PatientAnswer
ChecklistItem -SupportedBy→ VerifiedFact
PatientAnswer -AnsweredFrom→ VerifiedFact
VerifiedFact -VerifiedFrom→ CandidateFact

Encounter -HasCaptureSession→ CaptureSession -ProducedChunk→ TranscriptChunk
Encounter -HasSourceArtifact→ SourceArtifact -RepresentsDocument→ DocumentImage
DocumentImage -ContainsTextBlock→ DocumentTextBlock
CandidateFact -ExtractedFromDocument→ DocumentTextBlock
Encounter -HasClinicianNote→ ClinicianNoteDraft -ContainsSection→ NoteSection
NoteSection -NoteSupportedBy→ VerifiedFact
Patient -HasAudioScript→ PatientAudioScript -AudioGeneratedFrom→ PatientBrief

TranscriptChunk -TranslatedAs→ TranslatedTranscriptChunk
Encounter -HasQuickSummary→ QuickSummaryDraft -SupportedByChunk→ TranscriptChunk
Encounter -HasAnalysisRun→ AnalysisRun -AnalyzedFact→ VerifiedFact
AnalysisRun -ProducedSummary→ VerifiedEncounterSummary
AnalysisRun -ProducedInsight→ InsightItem -InsightSupportedBy→ VerifiedFact
AnalysisRun -ProducedQuestion→ SuggestedQuestion -QuestionBasedOn→ VerifiedFact
Encounter -HasFinalPacket→ FinalReviewPacket -ContainsAnalysis→ AnalysisRun
```

Four endpoint-constrained representation edges distinguish medication, lab,
referral, and follow-up obligations. Typed relationships also represent task
assignment, gap resolution, clinician verification, provenance, patient
visibility, conflict evidence roles, contradiction, and supersession.

Every accepted or rejected decision creates a `VerificationEvent`. Every gap
resolution creates a `GapResolutionEvent`. Brief checklist items and patient
answers are independent persistent nodes so their evidence can be traversed.
When supporting facts change or become conflicted, old outputs remain as audit
history but are marked non-current.

## Walkers

- `ConsultationIngestWalker` creates and validates one deterministic session
  topology without creating verified information.
- `VerificationWalker` is the sole promotion boundary; it is session-scoped,
  event-audited, and idempotent.
- `CareGapWalker` derives documentation gaps from verified obligations,
  tasks, owners, and dates without making medical decisions.
- `GapResolutionWalker` updates the related task topology and appends a
  resolution event.
- `PatientPlanWalker` visits only visible, verified, non-conflicted support and
  persists sourced checklist items.
- `PatientQuestionWalker` matches categories and stored terms, then assembles
  answers from verified graph values and resolved tasks only.
- `EvidenceAuditWalker` creates idempotent role-bearing conflicts and
  invalidates affected current outputs without selecting a winner.
- `TraceProvenanceWalker` walks backward from an item or answer to verified
  fact, candidate, transcript chunk, encounter, and patient.
- `ResetDemoWalker` removes only the selected synthetic session ownership
  boundary and recreates its deterministic topology.
- `TranslateTranscriptChunkWalker` preserves original evidence and connects one
  literal English/Spanish translation.
- `LiveQuickSummaryWalker` creates only an explicitly unverified sourced draft.
- `VerifiedEncounterAnalysisWalker` traverses accepted facts, obligations,
  tasks, gaps, and conflicts and persists a versioned verified-only result.
- `ClarifyingQuestionWalker` creates only gap/conflict-bound clinician
  questions.
- `FinalReviewPacketWalker` preserves separate verified, review-required, and
  unverified sections.
- `TraceAnalysisItemWalker` walks from analysis output to immutable transcript
  or synthetic document evidence.

Traversal traces are recorded at actual walker entry and edge-follow events
only when `DEMO_TRACE_ENABLED=true`. They contain no prompts, hidden reasoning,
credentials, or private patient data.

## Public actions

All existing names and request signatures remain compatible, with one additive
action:

```text
load_demo_encounter(session_id="demo-default", ai_mode="disabled")
get_candidate_facts(session_id="demo-default")
verify_fact(fact_id, decision, clinician_id, session_id="demo-default")
get_care_graph(session_id="demo-default")
run_care_gap_check(session_id="demo-default")
resolve_gap(gap_id, resolution, owner, due_date, session_id="demo-default")
generate_patient_plan(language, session_id="demo-default", ai_mode="disabled")
simplify_patient_plan(session_id="demo-default", ai_mode="live")
ask_patient_question(question, session_id="demo-default", ai_mode="disabled")
run_evidence_audit(session_id="demo-default")
reset_demo(session_id="demo-default")
add_demo_contradiction(session_id="demo-default")
trace_provenance(output_id, session_id="demo-default")
```

The compatibility functions are thin typed entry points that spawn the
internal walkers. Raw HTTP consumers read `BackendResponse` at
`data.result` inside Jac's transport envelope. The additive response fields
are `created_graph_ids`, `traversal_trace`, `provenance_chains`, relationship
projections, and persistent plan-item/answer IDs.

Additive multimodal actions are:

```text
start_capture_session
append_transcript_chunk
finalize_capture_session
cancel_capture_session
get_capture_session
load_prepared_voice_demo
ingest_document_image
get_document_extraction
retry_document_extraction
generate_clinician_note_draft
update_note_section
approve_clinician_note
get_clinician_note
get_encounter_timeline
trace_output_to_source
generate_patient_audio_script
```

Additive live-translation and intelligence actions are:

```text
translate_transcript_chunk
get_translated_transcript
retry_translation
generate_live_quick_summary
get_live_quick_summary
run_verified_encounter_analysis
get_verified_encounter_analysis
generate_clarifying_questions
dismiss_suggested_question
mark_question_answered
generate_final_review_packet
trace_analysis_item
```

All generated function actions use JSON request bodies except
`ingest_document_image`, which uses Jac's native `multipart/form-data`
`UploadFile` boundary. The exact `FormData` mapping is in
[MULTIMODAL_FRONTEND_HANDOFF.md](MULTIMODAL_FRONTEND_HANDOFF.md).

Reset a synthetic demo session while the backend is running:

```bash
curl -H 'Content-Type: application/json' \
  -d '{"session_id":"demo-default"}' \
  http://localhost:8000/function/reset_demo
```

## Optional AI

Copy variable names from `.env.example`; never commit a populated `.env`.
Configuration is documented in [MODEL_SETUP.md](MODEL_SETUP.md). AI is off by
default. Mandatory keyless test modes are:

```text
disabled        deterministic path
mock            valid typed MockLLM
mock_malformed  deliberately malformed MockLLM with deterministic fallback
live            configured provider, always guarded by fallback
```

Set `PA_CO_INTELLIGENCE_MODE` to one of those values for translation and live
summary actions. Its safe default is `disabled`.

Extraction validates schema, allowed enums, session-local chunks, exact
evidence, confidence, duplicates, fabricated details, prohibited medical
behavior, and instruction-injection attempts. Translation preserves dates,
names, numbers, checklist structure, and source IDs. Question AI may return
only IDs from the current verified, visible, non-conflicted allow-list; the
answer is always assembled deterministically.

No cloud key was created and no multi-gigabyte local model was downloaded.
Browser `SpeechRecognition`, `getUserMedia`, and `speechSynthesis` are client
adapters rather than server-native transcription/TTS. The reliable judging
path remains prepared text, deterministic document extraction, and browser
playback of an approved script.

## Frontend integration

Client-owned Jac imports the functions and DTOs from `endpoints` and `models`
using `sv import`, then awaits calls. Treat `BackendResponse.success` as the
branch point, display recoverable messages, use stable DTO IDs, and never
reimplement verification or graph rules in frontend code.

Exact mappings and an integration sequence are in
[FRONTEND_HANDOFF.md](FRONTEND_HANDOFF.md) and
[MULTIMODAL_FRONTEND_HANDOFF.md](MULTIMODAL_FRONTEND_HANDOFF.md), with the
additive intelligence mapping in
[INTELLIGENCE_FRONTEND_HANDOFF.md](INTELLIGENCE_FRONTEND_HANDOFF.md). Backend
work does not edit
`frontend.cl.jac`, `frontend.impl.jac`, `components/`, `styles/`, frontend mock
data, or frontend tests.

## Safety and limitations

- All included clinical-looking content is synthetic demonstration data.
- Candidate, pending, rejected, and conflicted facts are excluded from current
  patient output.
- Unknown questions return exactly: “This is not recorded in your approved
  care plan. Please contact your clinic.”
- The system does not diagnose, prescribe, change dosage, determine treatment
  safety, perform emergency triage, or invent missing information.
- The anonymous public demo uses logical synthetic session IDs, not
  authorization. It is not HIPAA compliant and must not receive PHI.
- Isolated tests prove private walkers and separate authenticated Jac roots,
  but login is intentionally not added to the hackathon demo.
- Jac 0.34.7 returns some generated-endpoint argument errors inside an HTTP 200
  transport response; clients must inspect the outer envelope and nested
  `BackendResponse`.
- On the generated `append_transcript_chunk` HTTP route, Jac 0.34.7 may
  materialize an omitted `confidence` default as a string. HTTP clients should
  send `"confidence": 1.0` explicitly; direct Jac calls and `JacTestClient`
  calls preserve the typed default.
- `jac start --faux` prints its endpoint report but then encounters a 0.34.7
  cleanup defect. It is not used as a release gate.
- Conflict resolution is intentionally manual. Dates remain deterministic demo
  strings rather than production scheduling objects.

## Backend files

Core code is in `main.jac`, `models.sv.jac`, `extraction.sv.jac`,
`ai.sv.jac`, `walkers.sv.jac`, `patient_agent.sv.jac`, `endpoints.sv.jac`,
`multimodal_data.sv.jac`, `multimodal_ai.sv.jac`,
`multimodal_walkers.sv.jac`, `multimodal_endpoints.sv.jac`, and `jac.toml`.
Intelligence code is isolated in `intelligence_models.sv.jac`,
`intelligence_ai.sv.jac`, `intelligence_walkers.sv.jac`, and
`intelligence_endpoints.sv.jac`.
Verification lives in `tests/`; architecture, contract, demo,
model, judge, and frontend handoff documents live at the repository root.

The architecture checkpoint is `566a319`. A commit cannot contain its own
hash, so obtain the final checkout hash with:

```bash
git rev-parse HEAD
```
