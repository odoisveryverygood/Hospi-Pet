"""Hospi-Pet Screen 1 — client-side visual foundation."""

import "./styles/theme.css";
import "./styles/encounter.css";
import "./styles/assistant.css";
import "./styles/facts.css";
import "./styles/clinical-insights.css";
import "./styles/multimodal.css";
import "./styles/results.css";
import "./styles/intelligence.css";

import from .api.backend { callBackendAction, callDocumentIngest }
import from .components.Header { Header }
import from .components.EncounterWelcome { EncounterWelcome }
import from .components.PatientHeader { PatientHeader }
import from .components.TranscriptPanel { TranscriptPanel }
import from .components.LiveConsultation { LiveConsultation }
import from .components.AIQuickNote { AIQuickNote }
import from .components.ClinicianVerification { ClinicianVerification }
import from .components.ClinicianNoteEditor { ClinicianNoteEditor }
import from .components.VerifiedIntelligence { VerifiedIntelligence }
import from .components.FinalReview { FinalReview }
import from .components.AssistantSection { AssistantSection }
import from .components.VoiceEncounterSection { VoiceEncounterSection }
import from .components.DocumentCaptureSection { DocumentCaptureSection }
import from .components.ClinicalInsightsScreen { ClinicalInsightsScreen }
import from .components.ResultsScreen { ResultsScreen }
import from .components.WorkflowNavigation { VerificationNavigation }
import from .components.IntelligenceState {
    acceptedCandidateCount,
    analysisBecomesStale,
    responseUiStatus
}
import from .components.ProjectFooter { ProjectFooter }
import from .components.Screen1State {
    blankFactDecisions,
    canContinueToInsights,
    canLoadDemo,
    sequenceDelayForState,
    statusForState,
    updateFactDecision
}


def noteSectionId(note: dict[str, any], section_type: str) -> str {
    matches: list[str] = [
        section["id"]
        for section in note.get("note_sections", [])
        if section["section_type"] == section_type
    ];
    return matches[0] if len(matches) > 0 else "";
}


def:pub app -> JsxElement {
    has current_screen: str = "verification",
        assistant_state: str = "idle",
        assistant_status: str = "Ready for an encounter",
        assistant_message: str = "Load the synthetic demo when you're ready.",
        demo_loaded: bool = False,
        is_transitioning: bool = False,
        patient_data: dict[str, str] = {},
        transcript_data: list[dict[str, any]] = [],
        candidate_facts: list[dict[str, any]] = [],
        document_candidates: list[dict[str, any]] = [],
        fact_decisions: dict[str, str] = blankFactDecisions(),
        pending_fact_id: str = "",
        pending_fact_decision: str = "",
        insights_preparing: bool = False,
        mascot_message_visible: bool = False,
        sequence_timer: float | None = None,
        highlighted_source_id: str = "",
        trace_message: str = "",
        trace_timer: float | None = None,
        voice_permission: str = "not_requested",
        voice_status: str = "idle",
        voice_scenario: str = "browser",
        voice_requesting: bool = False,
        voice_recording: bool = False,
        voice_stopping: bool = False,
        voice_prepared_demo: bool = False,
        voice_speaker: str = "Doctor",
        voice_recognition: any = None,
        voice_interim_text: str = "",
        voice_chunk_queue: list[dict[str, str]] = [],
        voice_chunk_pending: bool = False,
        voice_next_sequence: int = 1,
        voice_finalize_requested: bool = False,
        recording_seconds: int = 0,
        voice_timer: float | None = None,
        voice_sequence_timer: float | None = None,
        voice_stream: any = None,
        voice_runtime: any = {
            "capture_id": "",
            "recognition": None,
            "stream": None,
            "queue": [],
            "pending": False,
            "sequence": 1,
            "finalize": False,
            "rows": [],
            "seconds": 0
        },
        capture_session_id: str = "",
        document_permission: str = "not_requested",
        document_scenario: str = "lab_success",
        document_requesting: bool = False,
        document_processing: bool = False,
        document_stage: str = "idle",
        document_message: str = "",
        document_source_type: str = "",
        document_file_name: str = "",
        document_preview_url: str = "",
        document_label: str = "",
        document_source_id: str = "",
        document_artifact_id: str = "",
        document_text: str = "",
        camera_active: bool = False,
        camera_stream: any = None,
        document_file: any = None,
        document_timer: float | None = None,
        document_stage_index: int = 0,
        note_status: str = "empty",
        note_error: str = "",
        note_timer: float | None = None,
        note_edits: dict[str, str] = {},
        note_pending_action: str = "",
        note_pending_section: str = "",
        result_status: str = "missing",
        result_data: dict[str, any] = {},
        result_timer: float | None = None,
        translation_status: str = "empty",
        translation_chunk_index: int = 0,
        translated_rows: list[dict[str, any]] = [],
        quick_note_status: str = "empty",
        quick_note_data: dict[str, any] = {},
        analysis_status: str = "empty",
        analysis_data: dict[str, any] = {},
        analysis_stale: bool = False,
        clinician_note_data: dict[str, any] = {},
        intelligence_questions: list[dict[str, any]] = [],
        intelligence_question_states: dict[str, str] = {},
        pending_question_id: str = "",
        pending_question_decision: str = "",
        detail_question_id: str = "",
        detail_mode: str = "",
        active_intelligence_tab: str = "summary",
        source_trace_status: str = "empty",
        source_trace_data: list[dict[str, any]] = [],
        care_gap_status: str = "empty",
        care_gaps: list[dict[str, any]] = [],
        patient_plan_status: str = "empty",
        english_patient_plan: dict[str, any] = {},
        spanish_patient_plan: dict[str, any] = {},
        patient_audio_status: str = "empty",
        patient_audio_script: dict[str, any] = {},
        audit_status: str = "empty",
        audit_conflicts: list[dict[str, any]] = [],
        final_review_status: str = "empty",
        final_review_data: dict[str, any] = {},
        intelligence_error_message: str = "",
        intelligence_pending_action: str = "",
        intelligence_timer: float | None = None,
        backend_connected: bool = False;

    def loadDemo -> None;
    def receiveDemoReset(response: any) -> None;
    def receiveDemoEncounter(response: any) -> None;
    def failDemoLoad(error: any) -> None;
    def resetDemo -> None;
    def activateAssistant -> None;
    def beginAnalyzing -> None;
    def revealFacts -> None;
    def finishDemo -> None;
    def finishInsightsPreparation -> None;
    def cancelSequence -> None;
    def acceptFact(fact_id: str) -> None;
    def rejectFact(fact_id: str) -> None;
    def verifyFact(fact_id: str, decision: str) -> None;
    def receiveFactDecision(response: any, fact_id: str, decision: str) -> None;
    def failFactDecision(error: any) -> None;
    def continueToInsights -> None;
    def backToVerification -> None;
    def continueToResults -> None;
    def finishResult -> None;
    def retryResult -> None;
    def backToInsights -> None;
    def cancelResultTimer -> None;
    def loadTranslations -> None;
    def translateChunkAt(index: int, rows: list[dict[str, any]]) -> None;
    def receiveTranslationChunk(
        response: any, index: int, rows: list[dict[str, any]]
    ) -> None;
    def generateQuickNote -> None;
    def analyzeAcceptedInformation -> None;
    def loadAnalysisTrace -> None;
    def prepareFinalReview -> None;
    def finishIntelligenceAction -> None;
    def receiveIntelligenceResponse(response: any, action: str) -> None;
    def failIntelligenceAction(error: any) -> None;
    def cancelIntelligenceTimer -> None;
    def resetIntelligence -> None;
    def setIntelligenceTab(tab_id: str) -> None;
    def dismissIntelligenceQuestion(question_id: str) -> None;
    def answerIntelligenceQuestion(question_id: str) -> None;
    def finishIntelligenceQuestionAction -> None;
    def receiveQuestionResponse(response: any, question_id: str) -> None;
    def receiveGeneratedQuestions(response: any) -> None;
    def checkCareGaps -> None;
    def receiveCareGaps(response: any) -> None;
    def resolveFirstGap -> None;
    def receiveGapResolution(response: any) -> None;
    def generatePatientPlans -> None;
    def receiveEnglishPatientPlan(response: any) -> None;
    def receiveSpanishPatientPlan(response: any) -> None;
    def generatePatientAudio -> None;
    def receivePatientAudio(response: any) -> None;
    def playPatientAudio -> None;
    def runEvidenceAudit -> None;
    def receiveEvidenceAudit(response: any) -> None;
    def addDemoContradiction -> None;
    def receiveDemoContradiction(response: any) -> None;
    def toggleIntelligenceQuestionDetail(question_id: str, mode: str) -> None;
    def changeVoiceScenario(e: any) -> None;
    def changeVoiceSpeaker(e: any) -> None;
    def startRecording -> None;
    def receiveVoiceBootstrap(response: any) -> None;
    def startLiveCapture -> None;
    def receiveCaptureStart(response: any) -> None;
    def failCaptureStart(error: any) -> None;
    def requestBrowserMicrophone(capture_id: str) -> None;
    def voicePermissionGranted(stream: any, capture_id: str) -> None;
    def voicePermissionFailed(error: any, capture_id: str) -> None;
    def voicePermissionTimedOut(capture_id: str) -> None;
    def startBrowserTranscription -> None;
    def handleSpeechResult(event: any) -> None;
    def handleSpeechError(event: any) -> None;
    def queueFinalTranscript(text: str) -> None;
    def flushVoiceRuntimeQueue -> None;
    def receiveRuntimeTranscriptChunk(response: any) -> None;
    def failRuntimeTranscriptChunk(error: any) -> None;
    def sendNextTranscriptChunk -> None;
    def receiveTranscriptChunk(response: any) -> None;
    def failTranscriptChunk(error: any) -> None;
    def beginFinalizeCapture -> None;
    def simulateVoiceDenied -> None;
    def simulateVoiceUnsupported -> None;
    def simulateVoiceError -> None;
    def incrementRecordingTimer -> None;
    def stopRecording -> None;
    def finishVoiceRecognition -> None;
    def forceFinishVoiceRecognition(capture_id: str) -> None;
    def beginFinalizeCaptureById(capture_id: str) -> None;
    def finishStopRecording -> None;
    def receiveCaptureFinalized(response: any) -> None;
    def loadPreparedVoiceDemo -> None;
    def receivePreparedDemoReset(response: any) -> None;
    def receivePreparedEncounter(response: any) -> None;
    def finishPreparedVoiceDemo -> None;
    def receivePreparedVoiceDemo(response: any) -> None;
    def failPreparedVoiceDemo(error: any) -> None;
    def cancelAndRetryVoice -> None;
    def discardRecording -> None;
    def stopVoiceCapture -> None;
    def cancelVoiceTimers -> None;
    def changeDocumentScenario(e: any) -> None;
    def openCamera -> None;
    def cameraPermissionGranted(stream: any, request_token: str) -> None;
    def cameraPermissionFailed(error: any, request_token: str) -> None;
    def cameraPermissionTimedOut(request_token: str) -> None;
    def attachCameraStream(stream: any) -> None;
    def handleDocumentUpload(e: any) -> None;
    def takePhoto -> None;
    def retakeDocument -> None;
    def analyzeDocument -> None;
    def sendDocumentForm(image_input: any) -> None;
    def receiveCapturedDocumentBlob(blob: any) -> None;
    def advanceDocumentStage -> None;
    def finishDocumentAnalysis -> None;
    def receiveDocumentAnalysis(response: any) -> None;
    def refreshDocumentExtraction -> None;
    def receiveDocumentExtraction(response: any) -> None;
    def failDocumentAnalysis(error: any) -> None;
    def cancelDocumentTimer -> None;
    def stopCameraCapture -> None;
    def clearDocumentResults -> None;
    def traceSource(source_id: str) -> None;
    def receiveNoteTrace(response: any) -> None;
    def failNoteTrace(error: any) -> None;
    def clearTrace -> None;
    def changeClinicianNoteSection(section_key: str, value: str) -> None;
    def generateClinicianNote -> None;
    def saveClinicianNoteSection(section_key: str) -> None;
    def approveClinicianNote -> None;
    def finishClinicianNoteAction -> None;
    def receiveClinicianNoteResponse(response: any, action: str) -> None;
    def failClinicianNoteAction(error: any) -> None;
    def cancelClinicianNoteTimer -> None;

    can with exit {
        cancelSequence();
        cancelVoiceTimers();
        cancelDocumentTimer();
        stopVoiceCapture();
        stopCameraCapture();
        if trace_timer is not None {
            clearTimeout(trace_timer);
        }
        cancelClinicianNoteTimer();
        cancelResultTimer();
        cancelIntelligenceTimer();
    }

    all_candidates: list[dict[str, any]] = candidate_facts + document_candidates;
    multimodal_busy: bool = (
        is_transitioning
        or voice_requesting
        or voice_recording
        or voice_stopping
        or document_requesting
        or document_processing
        or note_status == "loading"
        or len(note_pending_action) > 0
        or result_status == "loading"
        or len(intelligence_pending_action) > 0
    );

    return
        <div className="app-shell">
            <Header
                screen_label={(
                    "Live Encounter"
                        if current_screen == "verification"
                        else (
                            "Clinical Insights"
                                if current_screen == "insights"
                                else "Verified Encounter Review"
                        )
                )}
                load_demo={loadDemo}
                reset_demo={resetDemo}
                demo_loaded={demo_loaded}
                is_transitioning={multimodal_busy}
            />
            <main className="main-content">
                {(
                    <div className="screen-one">
                        <EncounterWelcome/>
                        <AssistantSection
                            assistant_state={assistant_state}
                            status_text={assistant_status}
                            friendly_message={assistant_message}
                            message_visible={mascot_message_visible}
                            on_activate={activateAssistant}
                            is_transitioning={multimodal_busy}
                            is_running={False}
                        />
                        <VoiceEncounterSection
                            permission_state={voice_permission}
                            transcription_status={voice_status}
                            recording_seconds={recording_seconds}
                            is_requesting={voice_requesting}
                            is_recording={voice_recording}
                            is_stopping={voice_stopping}
                            is_prepared_demo={voice_prepared_demo}
                            speaker={voice_speaker}
                            interim_text={voice_interim_text}
                            scenario={voice_scenario}
                            on_scenario_change={changeVoiceScenario}
                            on_speaker_change={changeVoiceSpeaker}
                            on_start={startRecording}
                            on_stop={stopRecording}
                            on_cancel_retry={cancelAndRetryVoice}
                            on_prepared_demo={loadPreparedVoiceDemo}
                            on_discard={discardRecording}
                        />
                        {(
                            <div className="encounter-loaded">
                                <PatientHeader patient={patient_data}/>
                                <TranscriptPanel
                                    messages={transcript_data}
                                    highlighted_source_id={highlighted_source_id}
                                    transcription_status={voice_status}
                                    is_prepared_demo={voice_prepared_demo}
                                    interim_text={voice_interim_text}
                                    interim_speaker={voice_speaker}
                                />
                            </div>
                                if demo_loaded
                                else <div className="encounter-empty">
                                    <TranscriptPanel
                                        messages={transcript_data}
                                        highlighted_source_id={highlighted_source_id}
                                        transcription_status={voice_status}
                                        is_prepared_demo={voice_prepared_demo}
                                        interim_text={voice_interim_text}
                                        interim_speaker={voice_speaker}
                                    />
                                </div>
                        )}
                        <LiveConsultation
                            rows={translated_rows}
                            status={translation_status}
                            recording_state={voice_status}
                            pending_action={intelligence_pending_action}
                            on_load={loadTranslations}
                        />
                        <AIQuickNote
                            note={quick_note_data}
                            status={quick_note_status}
                            pending_action={intelligence_pending_action}
                            on_generate={generateQuickNote}
                        />
                        <DocumentCaptureSection
                            permission_state={document_permission}
                            source_type={document_source_type}
                            file_name={document_file_name}
                            preview_url={document_preview_url}
                            camera_active={camera_active}
                            is_requesting={document_requesting}
                            is_processing={document_processing}
                            extraction_stage={document_stage}
                            extraction_message={document_message}
                            extracted_text={document_text}
                            document_label={document_label}
                            document_source_id={document_source_id}
                            highlighted_source_id={highlighted_source_id}
                            scenario={document_scenario}
                            on_scenario_change={changeDocumentScenario}
                            on_open_camera={openCamera}
                            on_file_change={handleDocumentUpload}
                            on_take_photo={takePhoto}
                            on_retake={retakeDocument}
                            on_analyze={analyzeDocument}
                        />
                        <ClinicianVerification
                            candidates={all_candidates}
                            decisions={fact_decisions}
                            translated_rows={translated_rows}
                            pending_action={intelligence_pending_action}
                            on_accept={acceptFact}
                            on_reject={rejectFact}
                        />
                        <ClinicianNoteEditor
                            note={clinician_note_data}
                            status={note_status}
                            edits={note_edits}
                            pending_action={note_pending_action}
                            pending_section={note_pending_section}
                            trace_message={trace_message}
                            can_generate={acceptedCandidateCount(fact_decisions) > 0}
                            error_message={note_error}
                            on_generate={generateClinicianNote}
                            on_change={changeClinicianNoteSection}
                            on_save={saveClinicianNoteSection}
                            on_approve={approveClinicianNote}
                            on_trace={traceSource}
                        />
                        <VerifiedIntelligence
                            status={analysis_status}
                            analysis={analysis_data}
                            clinician_note={clinician_note_data}
                            final_review={final_review_data}
                            source_trace={source_trace_data}
                            trace_status={source_trace_status}
                            questions={intelligence_questions}
                            question_states={intelligence_question_states}
                            pending_question_id={pending_question_id}
                            detail_question_id={detail_question_id}
                            detail_mode={detail_mode}
                            active_tab={active_intelligence_tab}
                            stale={analysis_stale}
                            can_analyze={acceptedCandidateCount(fact_decisions) > 0}
                            pending_action={intelligence_pending_action}
                            error_message={intelligence_error_message}
                            on_analyze={analyzeAcceptedInformation}
                            on_tab={setIntelligenceTab}
                            on_trace={loadAnalysisTrace}
                            on_dismiss_question={dismissIntelligenceQuestion}
                            on_answer_question={answerIntelligenceQuestion}
                            on_question_detail={toggleIntelligenceQuestionDetail}
                            care_gap_status={care_gap_status}
                            care_gaps={care_gaps}
                            patient_plan_status={patient_plan_status}
                            english_patient_plan={english_patient_plan}
                            spanish_patient_plan={spanish_patient_plan}
                            patient_audio_status={patient_audio_status}
                            patient_audio_script={patient_audio_script}
                            audit_status={audit_status}
                            audit_conflicts={audit_conflicts}
                            on_check_gaps={checkCareGaps}
                            on_resolve_gap={resolveFirstGap}
                            on_generate_plans={generatePatientPlans}
                            on_generate_audio={generatePatientAudio}
                            on_play_audio={playPatientAudio}
                            on_run_audit={runEvidenceAudit}
                            on_add_contradiction={addDemoContradiction}
                        />
                        <FinalReview
                            packet={final_review_data}
                            status={final_review_status}
                            stale={analysis_stale}
                            pending_action={intelligence_pending_action}
                            error_message={intelligence_error_message}
                            on_generate={prepareFinalReview}
                        />
                        <VerificationNavigation
                            can_continue={canContinueToInsights(
                                demo_loaded, multimodal_busy, len(all_candidates) > 0
                            )}
                            on_continue={continueToInsights}
                        />
                    </div>
                        if current_screen == "verification"
                        else <ClinicalInsightsScreen
                            patient={patient_data}
                            facts={all_candidates}
                            decisions={fact_decisions}
                            insights_preparing={insights_preparing}
                            message_visible={mascot_message_visible}
                            on_mascot_activate={activateAssistant}
                            on_back={backToVerification}
                            on_continue={continueToResults}
                        />
                            if current_screen == "insights"
                            else <ResultsScreen
                                patient={patient_data}
                                packet_status={final_review_status}
                                packet={final_review_data}
                                analysis={analysis_data}
                                clinician_note={clinician_note_data}
                                english_plan={english_patient_plan}
                                spanish_plan={spanish_patient_plan}
                                source_trace={source_trace_data}
                                questions={intelligence_questions}
                                care_gaps={care_gaps}
                                conflicts={audit_conflicts}
                                stale={analysis_stale}
                                message_visible={mascot_message_visible}
                                on_mascot_activate={activateAssistant}
                                on_back={backToInsights}
                                on_generate={prepareFinalReview}
                            />
                )}
            </main>
            <ProjectFooter/>
        </div>;
}
