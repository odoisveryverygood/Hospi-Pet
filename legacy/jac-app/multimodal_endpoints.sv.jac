"""Stable public adapters for the multimodal encounter workflow."""

import base64;
import from fastapi { UploadFile }
import from typing { BinaryIO, cast }
import from models {
    AIStatusDTO,
    BackendResponse,
    CaptureSession,
    CaptureSessionStatus,
    ClinicianNoteDraft,
    DemoSession,
    DocumentImage,
    DocumentTextBlock,
    Encounter,
    ExtractionMode,
    InputSourceType,
    MultimodalCandidateDTO,
    Patient,
    SourceArtifact,
    TranscriptChunkDTO,
    CaptureSessionDTO,
    ProducedChunk,
    RepresentsDocument,
    ContainsTextBlock,
    HasCandidate,
    candidate_to_dto,
    transcript_to_dto,
}
import from extraction { prepared_transcript, }
import from walkers {
    build_demo_state,
    failure_response,
    find_session,
    session_encounter,
    success_response,
}
import from multimodal_walkers {
    AppendTranscriptChunkWalker,
    ApproveClinicianNoteWalker,
    CancelCaptureSessionWalker,
    DocumentIngestWalker,
    EncounterTimelineWalker,
    FinalizeCaptureSessionWalker,
    GenerateClinicianNoteDraftWalker,
    LoadPreparedVoiceDemoWalker,
    MultimodalTraceProvenanceWalker,
    PatientAudioScriptWalker,
    StartCaptureSessionWalker,
    UpdateNoteSectionWalker,
    artifact_to_dto,
    block_to_dto,
    capture_to_dto,
    extraction_mode_type,
    find_artifact,
    find_capture,
    find_note,
    multimodal_candidate_to_dto,
    note_to_dto,
}

def multimodal_first_response(
    reports: list[BackendResponse], operation: str
) -> BackendResponse {
    if reports {
        return reports[0];
    }
    return failure_response(
        "WALKER_NO_RESPONSE",
        f"{operation} completed without a structured response.",
        True,
        0
    );
}

def:pub start_capture_session(
    encounter_id: str, input_source: str, session_id: str = "demo-default"
) -> BackendResponse {
    result = root spawn StartCaptureSessionWalker(
        encounter_id=encounter_id, input_source=input_source, session_id=session_id
    );
    return multimodal_first_response(result.reports, "start_capture_session");
}

def:pub append_transcript_chunk(
    capture_session_id: str,
    sequence: int,
    speaker: str,
    text: str,
    started_at: str = "",
    ended_at: str = "",
    confidence: float = 1.0,
    session_id: str = "demo-default"
) -> BackendResponse {
    result = root spawn AppendTranscriptChunkWalker(
        capture_session_id=capture_session_id,
        sequence=sequence,
        speaker=speaker,
        text=text,
        started_at=started_at,
        ended_at=ended_at,
        confidence=confidence,
        session_id=session_id
    );
    return multimodal_first_response(result.reports, "append_transcript_chunk");
}

def:pub finalize_capture_session(
    capture_session_id: str, session_id: str = "demo-default"
) -> BackendResponse {
    result = root spawn FinalizeCaptureSessionWalker(
        capture_session_id=capture_session_id, session_id=session_id
    );
    return multimodal_first_response(result.reports, "finalize_capture_session");
}

def:pub cancel_capture_session(
    capture_session_id: str, session_id: str = "demo-default"
) -> BackendResponse {
    result = root spawn CancelCaptureSessionWalker(
        capture_session_id=capture_session_id, session_id=session_id
    );
    return multimodal_first_response(result.reports, "cancel_capture_session");
}

def:pub get_capture_session(
    capture_session_id: str, session_id: str = "demo-default"
) -> BackendResponse {
    session: DemoSession | None = find_session(session_id);
    capture: CaptureSession | None = (
        find_capture(session as DemoSession, capture_session_id)
            if session is not None
            else None
    );
    if session is None or capture is None {
        return failure_response(
            "CAPTURE_NOT_FOUND",
            "The capture was not found in this session.",
            True,
            session.graph_version if session is not None else 0
        );
    }
    response = success_response(session.graph_version, "Capture session loaded.");
    response.capture_session = capture_to_dto(capture as CaptureSession);
    response.transcript_chunks = [
        transcript_to_dto(chunk)
        for chunk in [(capture as CaptureSession)->:ProducedChunk:->]
    ];
    response.transcript_chunks.sort(
        key=lambda (chunk: TranscriptChunkDTO) { chunk.sequence; }
    );
    return response;
}

def:pub load_prepared_voice_demo(
    encounter_id: str, session_id: str = "demo-default"
) -> BackendResponse {
    started: BackendResponse = start_capture_session(
        encounter_id, "prepared_transcript", session_id
    );
    if not started.success or started.capture_session is None {
        return started;
    }
    capture: CaptureSessionDTO = started.capture_session as CaptureSessionDTO;
    for seed in prepared_transcript() {
        appended: BackendResponse = append_transcript_chunk(
            capture.id,
            seed.sequence,
            seed.speaker,
            seed.text,
            f"2026-07-26T18:00:0{seed.sequence}Z",
            f"2026-07-26T18:00:0{seed.sequence}Z",
            1.0,
            session_id
        );
        if not appended.success {
            return appended;
        }
    }
    return get_capture_session(capture.id, session_id);
}

def _ingest_document_image_data_url(
    encounter_id: str,
    document_type: str,
    filename: str,
    mime_type: str,
    image_input: str,
    synthetic: bool,
    session_id: str = "demo-default",
    extraction_mode: str = "deterministic"
) -> BackendResponse {
    result = root spawn DocumentIngestWalker(
        encounter_id=encounter_id,
        document_type=document_type,
        filename=filename,
        mime_type=mime_type,
        image_input=image_input,
        synthetic=synthetic,
        session_id=session_id,
        extraction_mode=extraction_mode
    );
    return multimodal_first_response(result.reports, "ingest_document_image");
}

def:pub ingest_document_image(
    encounter_id: str,
    document_type: str,
    filename: str,
    mime_type: str,
    image_input: UploadFile,
    synthetic: bool,
    session_id: str = "demo-default",
    extraction_mode: str = "deterministic"
) -> BackendResponse {
    try {
        file_object: BinaryIO = cast(BinaryIO, image_input.file);
        raw: bytes = file_object.read();
        file_object.seek(0);
        data_url: str = f"data:{mime_type};base64," + base64.b64encode(raw).decode();
    } except Exception {
        session: DemoSession | None = find_session(session_id);
        return failure_response(
            "IMAGE_READ_FAILED",
            "The uploaded synthetic image could not be read.",
            True,
            session.graph_version if session is not None else 0
        );
    }
    return _ingest_document_image_data_url(
        encounter_id,
        document_type,
        filename,
        mime_type,
        data_url,
        synthetic,
        session_id,
        extraction_mode
    );
}

def document_extraction_response(
    artifact: SourceArtifact, session: DemoSession
) -> BackendResponse {
    response = success_response(session.graph_version, "Document extraction loaded.");
    response.source_artifact = artifact_to_dto(artifact);
    documents: list[DocumentImage] = [artifact->:RepresentsDocument:->];
    blocks: list[DocumentTextBlock] = (
        [documents[0]->:ContainsTextBlock:->] if documents else []
    );
    blocks.sort(key=lambda (block: DocumentTextBlock) { block.sequence; });
    response.document_text_blocks = [block_to_dto(block) for block in blocks];
    encounter: Encounter = session_encounter(session) as Encounter;
    response.multimodal_candidates = [
        multimodal_candidate_to_dto(candidate)
        for candidate in [encounter->:HasCandidate:->]
        if candidate.source_artifact_id == artifact.id
    ];
    response.candidate_facts = [
        candidate_to_dto(candidate)
        for candidate in [encounter->:HasCandidate:->]
        if candidate.source_artifact_id == artifact.id
    ];
    return response;
}

def:pub get_document_extraction(
    source_artifact_id: str, session_id: str = "demo-default"
) -> BackendResponse {
    session: DemoSession | None = find_session(session_id);
    artifact: SourceArtifact | None = (
        find_artifact(session as DemoSession, source_artifact_id)
            if session is not None
            else None
    );
    if session is None or artifact is None {
        return failure_response(
            "SOURCE_ARTIFACT_NOT_FOUND",
            "The synthetic source artifact was not found in this session.",
            True,
            session.graph_version if session is not None else 0
        );
    }
    return document_extraction_response(
        artifact as SourceArtifact, session as DemoSession
    );
}

def:pub retry_document_extraction(
    source_artifact_id: str, extraction_mode: str, session_id: str = "demo-default"
) -> BackendResponse {
    session: DemoSession | None = find_session(session_id);
    artifact: SourceArtifact | None = (
        find_artifact(session as DemoSession, source_artifact_id)
            if session is not None
            else None
    );
    if session is None or artifact is None {
        return failure_response(
            "SOURCE_ARTIFACT_NOT_FOUND",
            "The synthetic source artifact was not found in this session.",
            True,
            session.graph_version if session is not None else 0
        );
    }
    mode: ExtractionMode | None = extraction_mode_type(extraction_mode);
    if mode is None {
        return failure_response(
            "EXTRACTION_MODE_INVALID",
            "extraction_mode is unsupported.",
            True,
            session.graph_version
        );
    }
    active_session: DemoSession = session as DemoSession;
    active_artifact: SourceArtifact = artifact as SourceArtifact;
    if extraction_mode.lower().strip() in ["cloud_model", "mock_malformed"] {
        active_artifact.extraction_mode = ExtractionMode.FALLBACK;
        active_artifact.extraction_status = "completed_with_fallback";
        active_session.graph_version += 1;
        response = document_extraction_response(active_artifact, active_session);
        response.message = (
            "Raw content was already deleted; existing deterministic extraction "
            "was retained."
        );
        response.recoverable = True;
        response.error_code = "VISION_FALLBACK_USED";
        response.ai_status = AIStatusDTO(
            requested=True,
            used=False,
            fallback_used=True,
            mode="fallback",
            diagnostic_code="RAW_CONTENT_UNAVAILABLE",
            diagnostic_message="Raw image content is intentionally not persisted."
        );
        return response;
    }
    if active_artifact.extraction_mode != mode {
        active_artifact.extraction_mode = mode as ExtractionMode;
        active_session.graph_version += 1;
    }
    return document_extraction_response(active_artifact, active_session);
}

def:pub generate_clinician_note_draft(
    encounter_id: str, clinician_hints: str = "", session_id: str = "demo-default"
) -> BackendResponse {
    result = root spawn GenerateClinicianNoteDraftWalker(
        encounter_id=encounter_id,
        clinician_hints=clinician_hints,
        session_id=session_id
    );
    return multimodal_first_response(result.reports, "generate_clinician_note_draft");
}

def:pub update_note_section(
    note_id: str,
    section_id: str,
    content: str,
    clinician_id: str,
    session_id: str = "demo-default"
) -> BackendResponse {
    result = root spawn UpdateNoteSectionWalker(
        note_id=note_id,
        section_id=section_id,
        content=content,
        clinician_id=clinician_id,
        session_id=session_id
    );
    return multimodal_first_response(result.reports, "update_note_section");
}

def:pub approve_clinician_note(
    note_id: str, clinician_id: str, session_id: str = "demo-default"
) -> BackendResponse {
    result = root spawn ApproveClinicianNoteWalker(
        note_id=note_id, clinician_id=clinician_id, session_id=session_id
    );
    return multimodal_first_response(result.reports, "approve_clinician_note");
}

def:pub get_clinician_note(
    note_id: str, session_id: str = "demo-default"
) -> BackendResponse {
    session: DemoSession | None = find_session(session_id);
    note: ClinicianNoteDraft | None = (
        find_note(session as DemoSession, note_id) if session is not None else None
    );
    if session is None or note is None {
        return failure_response(
            "NOTE_NOT_FOUND",
            "The note was not found in this session.",
            True,
            session.graph_version if session is not None else 0
        );
    }
    response = success_response(session.graph_version, "Clinician note loaded.");
    response.clinician_note = note_to_dto(note as ClinicianNoteDraft);
    return response;
}

def:pub get_encounter_timeline(
    encounter_id: str, session_id: str = "demo-default"
) -> BackendResponse {
    result = root spawn EncounterTimelineWalker(
        encounter_id=encounter_id, session_id=session_id
    );
    return multimodal_first_response(result.reports, "get_encounter_timeline");
}

def:pub trace_output_to_source(
    output_type: str,
    output_id: str,
    section_id: str = "",
    session_id: str = "demo-default"
) -> BackendResponse {
    result = root spawn MultimodalTraceProvenanceWalker(
        output_type=output_type,
        output_id=output_id,
        section_id=section_id,
        session_id=session_id
    );
    return multimodal_first_response(result.reports, "trace_output_to_source");
}

def:pub generate_patient_audio_script(
    language: str, session_id: str = "demo-default"
) -> BackendResponse {
    result = root spawn PatientAudioScriptWalker(
        language=language, session_id=session_id
    );
    return multimodal_first_response(result.reports, "generate_patient_audio_script");
}
