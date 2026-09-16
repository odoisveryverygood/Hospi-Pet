# Historical inspection inventory

All 146 tracked files under `legacy/jac-app/` were inspected during the product pass.
This inventory records scope, not a claim that every feature ran successfully.
See [PRODUCT_ARCHITECTURE.md](PRODUCT_ARCHITECTURE.md) for findings and decisions.

## Root source and configuration (25)

- `.dockerignore`
- `.env.example`
- `.gitignore`
- `Dockerfile`
- `ai.sv.jac`
- `endpoints.sv.jac`
- `extraction.sv.jac`
- `frontend.cl.jac`
- `frontend.impl.jac`
- `frontend.test.cl.jac`
- `intelligence_ai.sv.jac`
- `intelligence_endpoints.sv.jac`
- `intelligence_models.sv.jac`
- `intelligence_walkers.sv.jac`
- `jac.toml`
- `main.jac`
- `models.sv.jac`
- `multimodal_ai.sv.jac`
- `multimodal_data.sv.jac`
- `multimodal_endpoints.sv.jac`
- `multimodal_walkers.sv.jac`
- `patient_agent.sv.jac`
- `railway.toml`
- `vercel.json`
- `walkers.sv.jac`

## Root documentation (25)

- `ARCHITECTURE_UPGRADE_PLAN.md`
- `CONTRACT.md`
- `CONTRIBUTING.md`
- `DEMO_ASSET_MANIFEST.md`
- `FRONTEND_HANDOFF.md`
- `INTELLIGENCE_FRONTEND_HANDOFF.md`
- `INTELLIGENCE_READINESS_REPORT.md`
- `INTELLIGENCE_SAFETY_BOUNDARY.md`
- `JAC_ARCHITECTURE_AUDIT.md`
- `JAC_CAPABILITY_MATRIX.md`
- `JAC_DEMO_GUIDE.md`
- `MODEL_SETUP.md`
- `MULTIMODAL_CAPABILITY_DECISION.md`
- `MULTIMODAL_FRONTEND_HANDOFF.md`
- `MULTIMODAL_SCOPE.md`
- `MULTIMODAL_SECURITY_REPORT.md`
- `PARTNER_INTELLIGENCE_UI_TASK.md`
- `PARTNER_MULTIMODAL_BUILD_TASK.md`
- `PARTNER_SETUP.md`
- `PRE_INTELLIGENCE_BASELINE.md`
- `PRE_MULTIMODAL_BASELINE.md`
- `PROMPT3_READINESS_REPORT.md`
- `README.md`
- `TECHNICAL_JUDGE_GUIDE.md`
- `TRANSCRIPTION_DECISION.md`

## api (1)

- `api/backend.cl.jac`

## components (32)

- `components/AIQuickNote.cl.jac`
- `components/AssistantSection.cl.jac`
- `components/CandidateFactsSection.cl.jac`
- `components/ClinicalInsightsIncomplete.cl.jac`
- `components/ClinicalInsightsIntro.cl.jac`
- `components/ClinicalInsightsScreen.cl.jac`
- `components/ClinicianNoteEditor.cl.jac`
- `components/ClinicianVerification.cl.jac`
- `components/DemoControls.cl.jac`
- `components/DocumentCaptureSection.cl.jac`
- `components/EncounterProgress.cl.jac`
- `components/EncounterWelcome.cl.jac`
- `components/FactCard.cl.jac`
- `components/FinalReview.cl.jac`
- `components/Header.cl.jac`
- `components/HospiPetDog.cl.jac`
- `components/IntelligenceState.cl.jac`
- `components/LiveConsultation.cl.jac`
- `components/MultimodalState.cl.jac`
- `components/PatientHeader.cl.jac`
- `components/ProjectFooter.cl.jac`
- `components/ResultsProgress.cl.jac`
- `components/ResultsScreen.cl.jac`
- `components/Screen1State.cl.jac`
- `components/SuggestedQuestions.cl.jac`
- `components/TranscriptMessage.cl.jac`
- `components/TranscriptPanel.cl.jac`
- `components/VerifiedIntelligence.cl.jac`
- `components/VerifiedPatientSummary.cl.jac`
- `components/VerifiedVisitNote.cl.jac`
- `components/VoiceEncounterSection.cl.jac`
- `components/WorkflowNavigation.cl.jac`

## demo_assets (8)

- `demo_assets/consultation_transcript.json`
- `demo_assets/expected_document_extraction.json`
- `demo_assets/synthetic_appointment_card.png`
- `demo_assets/synthetic_appointment_card.svg`
- `demo_assets/synthetic_lab_order.png`
- `demo_assets/synthetic_lab_order.svg`
- `demo_assets/synthetic_referral.png`
- `demo_assets/synthetic_referral.svg`

## handoff (27)

- `handoff/fixtures/capture_session_completed.json`
- `handoff/fixtures/capture_session_created.json`
- `handoff/fixtures/capture_session_recording.json`
- `handoff/fixtures/clinician_note_approved.json`
- `handoff/fixtures/clinician_note_draft.json`
- `handoff/fixtures/document_extraction_completed.json`
- `handoff/fixtures/document_extraction_failed.json`
- `handoff/fixtures/document_upload_accepted.json`
- `handoff/fixtures/encounter_timeline.json`
- `handoff/fixtures/microphone_permission_denied.json`
- `handoff/fixtures/patient_audio_script_en.json`
- `handoff/fixtures/patient_audio_script_es.json`
- `handoff/fixtures/prepared_transcript_fallback.json`
- `handoff/fixtures/provenance_document.json`
- `handoff/fixtures/provenance_voice.json`
- `handoff/fixtures/transcript_chunk_appended.json`
- `handoff/fixtures/transcription_provider_failed.json`
- `handoff/intelligence-fixtures/analysis_source_trace.json`
- `handoff/intelligence-fixtures/clarifying_questions.json`
- `handoff/intelligence-fixtures/final_review_packet.json`
- `handoff/intelligence-fixtures/live_quick_summary.json`
- `handoff/intelligence-fixtures/provider_failure.json`
- `handoff/intelligence-fixtures/stale_analysis.json`
- `handoff/intelligence-fixtures/translated_chunk_en_to_es.json`
- `handoff/intelligence-fixtures/translated_chunk_es_to_en.json`
- `handoff/intelligence-fixtures/translation_fallback.json`
- `handoff/intelligence-fixtures/verified_analysis.json`

## mock_data (3)

- `mock_data/encounter.cl.jac`
- `mock_data/intelligence.cl.jac`
- `mock_data/multimodal.cl.jac`

## public (1)

- `public/favicon.ico`

## scripts (1)

- `scripts/build-vercel.sh`

## styles (8)

- `styles/assistant.css`
- `styles/clinical-insights.css`
- `styles/encounter.css`
- `styles/facts.css`
- `styles/intelligence.css`
- `styles/multimodal.css`
- `styles/results.css`
- `styles/theme.css`

## tests (15)

- `tests/ai_modes_demo.jac`
- `tests/ai_tests.jac`
- `tests/architecture_characterization.jac`
- `tests/backend_tests.jac`
- `tests/fixtures/auth_isolation.jac`
- `tests/intelligence_demo.jac`
- `tests/intelligence_server.jac`
- `tests/intelligence_tests.jac`
- `tests/multimodal_contract_tests.jac`
- `tests/multimodal_demo.jac`
- `tests/multimodal_server.jac`
- `tests/p0_demo.jac`
- `tests/production_architecture_tests.jac`
- `tests/production_demo.jac`
- `tests/server_integration.jac`

