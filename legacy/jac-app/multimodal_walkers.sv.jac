"""Visit-driven capture, document, note, timeline, audio, and provenance walkers."""

import os;
import base64;
import hashlib;
import tempfile;
import from io { BytesIO, }
import from PIL { Image as PILImage, }
import from jaclang.byllm.lib { Image, }
import from models {
    AIStatusDTO,
    BackendResponse,
    CandidateCategory,
    CandidateFact,
    CandidateStatus,
    CaptureSession,
    CaptureSessionDTO,
    CaptureSessionStatus,
    CareGap,
    CareNode,
    ChecklistItem,
    ClinicianNoteDraft,
    ClinicianNoteDraftDTO,
    DemoSession,
    DocumentImage,
    DocumentTextBlock,
    DocumentTextBlockDTO,
    Encounter,
    EncounterTimelineEventDTO,
    ExtractionMode,
    GapResolutionEvent,
    HasAnswer,
    HasAudioScript,
    HasBrief,
    HasCandidate,
    HasCaptureSession,
    HasClinicianNote,
    HasConflict,
    HasEncounter,
    HasGap,
    HasPatient,
    HasQuestion,
    HasSourceArtifact,
    HasTimelineEvent,
    HasVerifiedFact,
    HasVerificationEvent,
    InputSourceType,
    MultimodalCandidateDTO,
    MultimodalProvenanceDTO,
    NoteApprovalEvent,
    NoteEditEvent,
    NoteSection,
    NoteSectionDTO,
    NoteStatus,
    Patient,
    PatientAnswer,
    PatientAudioScript,
    PatientAudioScriptDTO,
    PatientBrief,
    PatientQuestion,
    ProducedChunk,
    SourceArtifact,
    SourceArtifactDTO,
    SourceArtifactType,
    TimelineEvent,
    TranscriptChunk,
    TranscriptChunkDTO,
    TraversalStepDTO,
    VerificationEvent,
    VerifiedFact,
    ContainsChunk,
    ContainsSection,
    ContainsTextBlock,
    ExtractedFrom,
    ExtractedFromDocument,
    GeneratedFrom,
    NoteGeneratedFrom,
    NoteSupportedBy,
    ApprovedByEvent,
    HasNoteEdit,
    SupersedesNote,
    RepresentsDocument,
    PromotedTo,
    ResolvedBy,
    HasChecklistItem,
    SupportedBy,
    AnsweredFrom,
    VerifiedFrom,
    AudioGeneratedFrom,
    AudioSupportedBy,
    SessionOwns,
    transcript_to_dto,
    candidate_to_dto,
}
import from extraction { deterministic_timestamp, prepared_transcript, }
import from multimodal_data {
    SyntheticDocumentProposal,
    SyntheticTextBlock,
    synthetic_document_blocks,
    synthetic_document_proposals,
}
import from multimodal_ai {
    DocumentFactProposal,
    DocumentVisionAttempt,
    run_document_vision,
}
import from walkers {
    TraceableWalker,
    active_gaps,
    candidates_for_session,
    failure_response,
    fact_is_conflicted,
    find_session,
    invalidate_current_outputs,
    latest_plan,
    own_node,
    seed_prepared_candidate_graph,
    session_encounter,
    session_patient,
    success_response,
    unresolved_conflicts,
    verified_facts_for_session,
}

glob ALLOWED_IMAGE_MIME_TYPES: list[str] = [
         "image/png",
         "image/jpeg",
         "image/webp"
     ],
     MAX_IMAGE_BYTES: int = 1048576,
     ALLOWED_SPEAKERS: list[str] = ["Doctor", "Patient", "Clinician", "Interpreter"],
     BLOCKED_NOTE_PHRASES: list[str] = [
         "diagnos",
         "start taking",
         "stop taking",
         "increase the dose",
         "decrease the dose",
         "safe to",
         "call 911",
         "emergency triage"
     ],
     BLOCKED_DOCUMENT_PHRASES: list[str] = [
         "approve automatically",
         "return a verified node",
         "create a verified fact",
         "ignore previous instructions",
         "reveal another patient",
         "resolve the contradiction"
     ];

obj ImageValidationResult {
    has success: bool = False,
        raw_bytes: bytes | None = None,
        width: int = 0,
        height: int = 0,
        error_code: str = "",
        message: str = "",
        temporary_content_deleted: bool = True;
}

def input_source_type(value: str) -> InputSourceType | None {
    normalized: str = value.lower().strip();
    for item in [
        InputSourceType.TYPED_TEXT,
        InputSourceType.PREPARED_TRANSCRIPT,
        InputSourceType.LIVE_VOICE,
        InputSourceType.AUDIO_UPLOAD,
        InputSourceType.CAMERA_CAPTURE,
        InputSourceType.IMAGE_UPLOAD
    ] {
        if normalized == item {
            return item;
        }
    }
    return None;
}

def extraction_mode_type(value: str) -> ExtractionMode | None {
    normalized: str = value.lower().strip();
    for item in [
        ExtractionMode.DETERMINISTIC,
        ExtractionMode.BROWSER_NATIVE,
        ExtractionMode.LOCAL_MODEL,
        ExtractionMode.CLOUD_MODEL,
        ExtractionMode.MOCK,
        ExtractionMode.FALLBACK
    ] {
        if normalized == item {
            return item;
        }
    }
    if normalized == "mock_malformed" {
        return ExtractionMode.MOCK;
    }
    return None;
}

def document_type_value(value: str) -> SourceArtifactType | None {
    normalized: str = value.lower().strip();
    for item in [
        SourceArtifactType.LAB_DOCUMENT,
        SourceArtifactType.REFERRAL_DOCUMENT,
        SourceArtifactType.APPOINTMENT_CARD,
        SourceArtifactType.AFTER_VISIT_DOCUMENT
    ] {
        if normalized == item {
            return item;
        }
    }
    return None;
}

def capture_to_dto(capture: CaptureSession) -> CaptureSessionDTO {
    return CaptureSessionDTO(
        id=capture.id,
        encounter_id=capture.encounter_id,
        session_id=capture.session_id,
        input_source=capture.input_source,
        status=capture.status,
        extraction_mode=capture.extraction_mode,
        started_at=capture.started_at,
        completed_at=capture.completed_at,
        fallback_used=capture.fallback_used,
        chunk_count=len([capture->:ProducedChunk:->]),
        error_code=capture.error_code,
        recoverable=capture.recoverable
    );
}

def artifact_to_dto(artifact: SourceArtifact) -> SourceArtifactDTO {
    return SourceArtifactDTO(
        id=artifact.id,
        encounter_id=artifact.encounter_id,
        artifact_type=artifact.artifact_type,
        display_name=artifact.display_name,
        mime_type=artifact.mime_type,
        synthetic=artifact.synthetic,
        extraction_mode=artifact.extraction_mode,
        extraction_status=artifact.extraction_status,
        created_at=artifact.created_at,
        temporary_content_deleted=artifact.temporary_content_deleted
    );
}

def block_to_dto(block: DocumentTextBlock) -> DocumentTextBlockDTO {
    return DocumentTextBlockDTO(
        id=block.id,
        source_artifact_id=block.source_artifact_id,
        sequence=block.sequence,
        text=block.text,
        confidence=block.confidence,
        page_number=block.page_number,
        bounding_region=block.bounding_region,
        source_hash=block.source_hash
    );
}

def multimodal_candidate_to_dto(candidate: CandidateFact) -> MultimodalCandidateDTO {
    return MultimodalCandidateDTO(
        id=candidate.id,
        category=candidate.category,
        value=candidate.value,
        confidence=candidate.confidence,
        status=candidate.status,
        source_kind=candidate.source_kind,
        source_artifact_id=candidate.source_artifact_id,
        source_chunk_id=candidate.source_chunk_id,
        source_text_block_id=candidate.source_text_block_id,
        source_text=candidate.source_text,
        source_region=candidate.source_region,
        created_at=candidate.created_at
    );
}

def note_section_to_dto(section: NoteSection) -> NoteSectionDTO {
    facts: list[VerifiedFact] = [section->:NoteSupportedBy:->];
    artifact_ids: list[str] = [];
    for fact in facts {
        if fact.source_artifact_id and fact.source_artifact_id not in artifact_ids {
            artifact_ids.append(fact.source_artifact_id);
        }
    }
    return NoteSectionDTO(
        id=section.id,
        section_type=section.section_type,
        heading=section.heading,
        content=(
            section.edited_content
                if section.manually_edited
                else section.generated_content
        ),
        source_fact_ids=[fact.id for fact in facts],
        source_artifact_ids=artifact_ids,
        manually_edited=section.manually_edited,
        approved=section.approved
    );
}

def note_to_dto(note: ClinicianNoteDraft) -> ClinicianNoteDraftDTO {
    sections: list[NoteSection] = [note->:ContainsSection:->];
    sections.sort(key=lambda (section: NoteSection) { section.id; });
    section_dtos: list[NoteSectionDTO] = [
        note_section_to_dto(section) for section in sections
    ];
    source_ids: list[str] = [];
    for section in section_dtos {
        for fact_id in section.source_fact_ids {
            if fact_id not in source_ids {
                source_ids.append(fact_id);
            }
        }
    }
    patient_concerns: str = "";
    confirmed_instructions: str = "";
    medication_instructions: str = "";
    laboratory_orders: str = "";
    referrals: str = "";
    follow_up: str = "";
    unresolved_gaps: str = "";
    for section in section_dtos {
        if section.section_type == "patient_concerns" {
            patient_concerns = section.content;
        } elif section.section_type == "confirmed_instructions" {
            confirmed_instructions = section.content;
        } elif section.section_type == "medication_instructions" {
            medication_instructions = section.content;
        } elif section.section_type == "laboratory_orders" {
            laboratory_orders = section.content;
        } elif section.section_type == "referrals" {
            referrals = section.content;
        } elif section.section_type == "follow_up" {
            follow_up = section.content;
        } elif section.section_type == "unresolved_gaps" {
            unresolved_gaps = section.content;
        }
    }
    return ClinicianNoteDraftDTO(
        id=note.id,
        encounter_id=note.encounter_id,
        status=note.status,
        patient_concerns=patient_concerns,
        confirmed_instructions=confirmed_instructions,
        medication_instructions=medication_instructions,
        laboratory_orders=laboratory_orders,
        referrals=referrals,
        follow_up=follow_up,
        unresolved_gaps=unresolved_gaps,
        note_sections=section_dtos,
        source_fact_ids=source_ids,
        generated_at=note.generated_at,
        edited_at=note.edited_at,
        approved_at=note.approved_at,
        approved_by=note.approved_by
    );
}

def find_capture(session: DemoSession, capture_id: str) -> CaptureSession | None {
    encounter: Encounter | None = session_encounter(session);
    if encounter is None {
        return None;
    }
    matches: list[CaptureSession] = [(encounter as Encounter)->:HasCaptureSession:->[?:CaptureSession, id==capture_id]];
    return matches[0] if matches else None;
}

def find_artifact(session: DemoSession, artifact_id: str) -> SourceArtifact | None {
    encounter: Encounter | None = session_encounter(session);
    if encounter is None {
        return None;
    }
    matches: list[SourceArtifact] = [(encounter as Encounter)->:HasSourceArtifact:->[?:SourceArtifact, id==artifact_id]];
    return matches[0] if matches else None;
}

def find_note(session: DemoSession, note_id: str) -> ClinicianNoteDraft | None {
    encounter: Encounter | None = session_encounter(session);
    if encounter is None {
        return None;
    }
    matches: list[ClinicianNoteDraft] = [(encounter as Encounter)->:HasClinicianNote:->[?:ClinicianNoteDraft, id==note_id]];
    return matches[0] if matches else None;
}

def add_timeline_event(
    session: DemoSession,
    encounter: Encounter,
    event_type: str,
    title: str,
    description: str,
    related_ids: list[str],
    fact_ids: list[str] = []
) -> TimelineEvent {
    existing: list[TimelineEvent] = [
        event
        for event in [encounter->:HasTimelineEvent:->]
        if (
            event.event_type == event_type
            and event.related_node_ids == related_ids
            and event.description == description
        )
    ];
    if existing {
        return existing[0];
    }
    timeline_count: int = len([encounter->:HasTimelineEvent:->]);
    event = TimelineEvent(
        session_id=session.id,
        id=f"timeline-{session.id}-{session.graph_version}-{timeline_count + 1}",
        event_type=event_type,
        occurred_at=deterministic_timestamp(session.graph_version),
        title=title,
        description=description,
        related_node_ids=related_ids,
        source_fact_ids=fact_ids,
        graph_version=session.graph_version
    );
    own_node(session, event);
    encounter +>:HasTimelineEvent():+> event;
    return event;
}

def validate_image_data_url(image_input: str, mime_type: str) -> ImageValidationResult {
    if mime_type not in ALLOWED_IMAGE_MIME_TYPES {
        return ImageValidationResult(
            success=False,
            error_code="MIME_TYPE_INVALID",
            message="Only PNG, JPEG, and WEBP synthetic documents are accepted."
        );
    }
    expected_prefix: str = f"data:{mime_type};base64,";
    if not image_input.startswith(expected_prefix) {
        return ImageValidationResult(
            success=False,
            error_code="IMAGE_DATA_URL_INVALID",
            message="image_input must be a matching base64 data URL."
        );
    }
    encoded: str = image_input[len(expected_prefix):];
    if not encoded.strip() {
        return ImageValidationResult(
            success=False,
            error_code="IMAGE_EMPTY",
            message="The synthetic image is empty."
        );
    }
    try {
        raw: bytes = base64.b64decode(encoded, validate=True);
    } except Exception as error {
        return ImageValidationResult(
            success=False,
            error_code="IMAGE_DATA_URL_INVALID",
            message="The base64 image payload is malformed."
        );
    }
    if not raw {
        return ImageValidationResult(
            success=False,
            error_code="IMAGE_EMPTY",
            message="The synthetic image is empty."
        );
    }
    if len(raw) > MAX_IMAGE_BYTES {
        return ImageValidationResult(
            success=False,
            error_code="IMAGE_TOO_LARGE",
            message="The decoded synthetic image exceeds the 1 MiB limit."
        );
    }
    temp_path: str = "";
    try {
        suffix: str = (
            ".png"
                if mime_type == "image/png"
                else (".jpg" if mime_type == "image/jpeg" else ".webp")
        );
        temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=suffix);
        temp_path = temp_file.name;
        _ = temp_file.write(raw);
        temp_file.close();
        image = PILImage.open(temp_path);
        width: int = image.width;
        height: int = image.height;
        image.verify();
        if width <= 0 or height <= 0 {
            raise ValueError("invalid dimensions");
        }
        return ImageValidationResult(
            success=True,
            raw_bytes=raw,
            width=width,
            height=height,
            temporary_content_deleted=True
        );
    } except Exception as error {
        return ImageValidationResult(
            success=False,
            error_code="IMAGE_CORRUPT",
            message="The decoded payload is not a valid supported image.",
            temporary_content_deleted=True
        );
    } finally {
        if temp_path and os.path.exists(temp_path) {
            os.unlink(temp_path);
        }
    }
}

def unsafe_text(text: str) -> bool {
    lowered: str = text.lower();
    return any(phrase in lowered for phrase in BLOCKED_NOTE_PHRASES);
}

def unsafe_document_proposal(proposal: DocumentFactProposal) -> bool {
    lowered: str = f"{proposal.value} {proposal.exact_source_text}".lower();
    if any(phrase in lowered for phrase in BLOCKED_NOTE_PHRASES) {
        return True;
    }
    if any(phrase in lowered for phrase in BLOCKED_DOCUMENT_PHRASES) {
        return True;
    }
    return not proposal.requires_clinician_review;
}

def verified_values(facts: list[VerifiedFact], category: CandidateCategory) -> str {
    values: list[str] = [
        fact.value
        for fact in facts
        if fact.category == category
    ];
    return "; ".join(values) if values else "No verified information recorded.";
}

walker StartCaptureSessionWalker(TraceableWalker) {
    has encounter_id: str = "",
        input_source: str = "",
        session_id: str = "demo-default",
        reports: list[BackendResponse] = [];

    can locate with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        source: InputSourceType | None = input_source_type(self.input_source);
        if session is None {
            report failure_response(
                "DEMO_NOT_LOADED",
                "Load the synthetic encounter before capture.",
                True,
                0
            );
            disengage;
        }
        if source is None {
            report failure_response(
                "INVALID_INPUT_SOURCE",
                "input_source is outside the supported capture enum.",
                True,
                session.graph_version
            );
            disengage;
        }
        visit session;
    }

    can enter_session with DemoSession entry {
        visit [here->:HasPatient:->];
    }

    can enter_patient with Patient entry {
        visit [here->:HasEncounter:->[?:Encounter, id==self.encounter_id]] else {
            session = find_session(self.session_id);
            report failure_response(
                "ENCOUNTER_NOT_FOUND",
                "The encounter was not found in this session.",
                True,
                session.graph_version if session is not None else 0
            );
            disengage;
        }
    }

    can start with Encounter entry {
        session: DemoSession = find_session(self.session_id) as DemoSession;
        source: InputSourceType = input_source_type(
            self.input_source
        ) as InputSourceType;
        existing_prepared: list[CaptureSession] = [
            capture
            for capture in [here->:HasCaptureSession:->]
            if (
                capture.input_source == source
                and source == InputSourceType.PREPARED_TRANSCRIPT
            )
        ];
        if existing_prepared {
            response = success_response(
                session.graph_version,
                "The prepared capture already exists; no duplicate was created."
            );
            response.capture_session = capture_to_dto(existing_prepared[0]);
            report response;
            disengage;
        }
        active: list[CaptureSession] = [
            capture
            for capture in [here->:HasCaptureSession:->]
            if capture.status in [
                CaptureSessionStatus.CREATED,
                CaptureSessionStatus.PERMISSION_REQUIRED,
                CaptureSessionStatus.RECORDING,
                CaptureSessionStatus.TRANSCRIBING,
                CaptureSessionStatus.PROCESSING
            ]
        ];
        if active {
            report failure_response(
                "ACTIVE_CAPTURE_EXISTS",
                "Finish or cancel the active capture before starting another.",
                True,
                session.graph_version
            );
            disengage;
        }
        session.graph_version += 1;
        capture = CaptureSession(
            session_id=self.session_id,
            id=f"capture-{self.session_id}-{session.graph_version}",
            encounter_id=here.id,
            input_source=source,
            status=(
                CaptureSessionStatus.PERMISSION_REQUIRED
                    if source == InputSourceType.LIVE_VOICE
                    else CaptureSessionStatus.CREATED
            ),
            extraction_mode=(
                ExtractionMode.BROWSER_NATIVE
                    if source == InputSourceType.LIVE_VOICE
                    else ExtractionMode.DETERMINISTIC
            ),
            started_at=deterministic_timestamp(session.graph_version)
        );
        own_node(session, capture);
        here +>:HasCaptureSession():+> capture;
        _ = add_timeline_event(
            session,
            here,
            "capture_started",
            "Capture session started",
            f"Started {source} capture.",
            [capture.id]
        );
        self.trace(
            "StartCaptureSessionWalker",
            here.id,
            "Encounter",
            "HasCaptureSession",
            "create capture session",
            "complete",
            "Created one session-local capture without raw audio."
        );
        response = success_response(session.graph_version, "Capture session created.");
        response.capture_session = capture_to_dto(capture);
        response.created_graph_ids = [capture.id];
        response.traversal_trace = self.traversal_trace;
        report response;
    }
}

walker AppendTranscriptChunkWalker(TraceableWalker) {
    has capture_session_id: str = "",
        sequence: int = 0,
        speaker: str = "",
        text: str = "",
        started_at: str = "",
        ended_at: str = "",
        confidence: float = 1.0,
        session_id: str = "demo-default",
        reports: list[BackendResponse] = [];

    can locate with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        if session is None {
            report failure_response(
                "DEMO_NOT_LOADED", "Load the synthetic encounter first.", True, 0
            );
            disengage;
        }
        capture: CaptureSession | None = find_capture(
            session as DemoSession, self.capture_session_id
        );
        if capture is None {
            report failure_response(
                "CAPTURE_NOT_FOUND",
                "The capture was not found in this session.",
                True,
                session.graph_version
            );
            disengage;
        }
        visit capture;
    }

    can append with CaptureSession entry {
        session: DemoSession = find_session(self.session_id) as DemoSession;
        if here.status in [
            CaptureSessionStatus.CANCELLED,
            CaptureSessionStatus.COMPLETED,
            CaptureSessionStatus.PROCESSING,
            CaptureSessionStatus.TRANSCRIBING
        ] {
            report failure_response(
                "CAPTURE_CLOSED",
                "Transcript chunks cannot be appended after capture closes.",
                False,
                session.graph_version
            );
            disengage;
        }
        clean_text: str = self.text.strip();
        clean_speaker: str = self.speaker.strip();
        if self.sequence <= 0 {
            report failure_response(
                "INVALID_SEQUENCE",
                "sequence must be positive.",
                True,
                session.graph_version
            );
            disengage;
        }
        if not clean_text {
            report failure_response(
                "BLANK_TRANSCRIPT",
                "Blank transcript text is rejected.",
                True,
                session.graph_version
            );
            disengage;
        }
        if clean_speaker not in ALLOWED_SPEAKERS {
            report failure_response(
                "INVALID_SPEAKER",
                "speaker must be Doctor, Patient, Clinician, or Interpreter.",
                True,
                session.graph_version
            );
            disengage;
        }
        if self.confidence < 0.0 or self.confidence > 1.0 {
            report failure_response(
                "INVALID_CONFIDENCE",
                "confidence must be between 0.0 and 1.0.",
                True,
                session.graph_version
            );
            disengage;
        }
        chunks: list[TranscriptChunk] = [here->:ProducedChunk:->];
        matching: list[TranscriptChunk] = [
            chunk
            for chunk in chunks
            if chunk.sequence == self.sequence
        ];
        if matching {
            if (
                matching[0].speaker == clean_speaker and matching[0].text == clean_text
            ) {
                response = success_response(
                    session.graph_version,
                    "Identical transcript chunk replayed; no duplicate was created."
                );
                response.transcript_chunk = transcript_to_dto(matching[0]);
                response.capture_session = capture_to_dto(here);
                report response;
            } else {
                report failure_response(
                    "DUPLICATE_SEQUENCE",
                    "A different chunk already uses this sequence.",
                    True,
                    session.graph_version
                );
            }
            disengage;
        }
        if self.sequence != len(chunks) + 1 {
            report failure_response(
                "OUT_OF_ORDER_CHUNK",
                "Chunks must be appended in contiguous sequence order.",
                True,
                session.graph_version
            );
            disengage;
        }
        encounter: Encounter = session_encounter(session) as Encounter;
        reusable: list[TranscriptChunk] = [
            chunk
            for chunk in [encounter->:ContainsChunk:->]
            if (
                chunk.sequence == self.sequence
                and chunk.speaker == clean_speaker
                and chunk.text == clean_text
                and (
                    not chunk.capture_session_id or chunk.capture_session_id == here.id
                )
            )
        ];
        chunk: TranscriptChunk;
        created_ids: list[str] = [];
        if reusable {
            chunk = reusable[0];
            chunk.capture_session_id = here.id;
            chunk.started_at = self.started_at;
            chunk.ended_at = self.ended_at;
            chunk.confidence = self.confidence;
            chunk.source_type = here.input_source;
            chunk.finalized = True;
        } else {
            chunk = TranscriptChunk(
                session_id=self.session_id,
                id=f"{here.id}-chunk-{self.sequence}",
                encounter_id=encounter.id,
                capture_session_id=here.id,
                sequence=self.sequence,
                speaker=clean_speaker,
                text=clean_text,
                started_at=self.started_at,
                ended_at=self.ended_at,
                confidence=self.confidence,
                source_type=here.input_source,
                finalized=True
            );
            own_node(session, chunk);
            encounter +>:ContainsChunk():+> chunk;
            created_ids.append(chunk.id);
        }
        here +>:ProducedChunk():+> chunk;
        here.status = CaptureSessionStatus.RECORDING;
        session.graph_version += 1;
        _ = add_timeline_event(
            session,
            encounter,
            "transcript_chunk_captured",
            f"Transcript chunk {self.sequence} captured",
            f"Captured finalized {clean_speaker} text.",
            [here.id, chunk.id]
        );
        self.trace(
            "AppendTranscriptChunkWalker",
            here.id,
            "CaptureSession",
            "ProducedChunk",
            "append ordered evidence",
            "complete",
            "Connected one immutable speaker-labeled chunk to the capture."
        );
        response = success_response(
            session.graph_version, "Transcript chunk appended."
        );
        response.transcript_chunk = transcript_to_dto(chunk);
        response.capture_session = capture_to_dto(here);
        response.created_graph_ids = created_ids;
        response.traversal_trace = self.traversal_trace;
        report response;
    }
}

walker FinalizeCaptureSessionWalker(TraceableWalker) {
    has capture_session_id: str = "",
        session_id: str = "demo-default",
        reports: list[BackendResponse] = [];

    can locate with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        capture: CaptureSession | None = (
            find_capture(session as DemoSession, self.capture_session_id)
                if session is not None
                else None
        );
        if session is None or capture is None {
            report failure_response(
                "CAPTURE_NOT_FOUND",
                "The capture was not found in this session.",
                True,
                session.graph_version if session is not None else 0
            );
            disengage;
        }
        visit capture;
    }

    can finalize with CaptureSession entry {
        session: DemoSession = find_session(self.session_id) as DemoSession;
        if here.status == CaptureSessionStatus.COMPLETED {
            response = success_response(
                session.graph_version,
                "Capture was already completed; no duplicate extraction occurred."
            );
            response.capture_session = capture_to_dto(here);
            response.candidate_facts = [
                candidate_to_dto(candidate)
                for candidate in candidates_for_session(session)
            ];
            report response;
            disengage;
        }
        if here.status == CaptureSessionStatus.CANCELLED {
            report failure_response(
                "CAPTURE_CANCELLED",
                "A cancelled capture cannot be finalized.",
                False,
                session.graph_version
            );
            disengage;
        }
        chunks: list[TranscriptChunk] = [here->:ProducedChunk:->];
        chunks.sort(key=lambda (chunk: TranscriptChunk) { chunk.sequence; });
        if not chunks {
            report failure_response(
                "EMPTY_CAPTURE",
                "At least one transcript chunk is required.",
                True,
                session.graph_version
            );
            disengage;
        }
        if [chunk.sequence for chunk in chunks] != list(range(1, len(chunks) + 1)) {
            report failure_response(
                "TRANSCRIPT_SEQUENCE_GAP",
                "Transcript sequence contains a gap.",
                True,
                session.graph_version
            );
            disengage;
        }
        here.status = CaptureSessionStatus.TRANSCRIBING;
        here.status = CaptureSessionStatus.PROCESSING;
        _ = seed_prepared_candidate_graph(session);
        here.status = CaptureSessionStatus.COMPLETED;
        session.graph_version += 1;
        here.completed_at = deterministic_timestamp(session.graph_version);
        encounter: Encounter = session_encounter(session) as Encounter;
        _ = add_timeline_event(
            session,
            encounter,
            "capture_completed",
            "Capture completed",
            "Ordered transcript evidence was processed into pending proposals.",
            [here.id]
        );
        response = success_response(
            session.graph_version,
            "Capture completed; candidates remain pending clinician review."
        );
        response.capture_session = capture_to_dto(here);
        response.transcript_chunks = [transcript_to_dto(chunk) for chunk in chunks];
        response.candidate_facts = [
            candidate_to_dto(candidate) for candidate in candidates_for_session(session)
        ];
        report response;
    }
}

walker CancelCaptureSessionWalker(TraceableWalker) {
    has capture_session_id: str = "",
        session_id: str = "demo-default",
        reports: list[BackendResponse] = [];

    can cancel with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        capture: CaptureSession | None = (
            find_capture(session as DemoSession, self.capture_session_id)
                if session is not None
                else None
        );
        if session is None or capture is None {
            report failure_response(
                "CAPTURE_NOT_FOUND",
                "The capture was not found in this session.",
                True,
                session.graph_version if session is not None else 0
            );
            disengage;
        }
        active: CaptureSession = capture as CaptureSession;
        if active.status == CaptureSessionStatus.COMPLETED {
            report failure_response(
                "CAPTURE_ALREADY_COMPLETED",
                "A completed capture cannot be cancelled.",
                False,
                session.graph_version
            );
            disengage;
        }
        if active.status != CaptureSessionStatus.CANCELLED {
            active.status = CaptureSessionStatus.CANCELLED;
            session.graph_version += 1;
            active.completed_at = deterministic_timestamp(session.graph_version);
            encounter: Encounter = session_encounter(session) as Encounter;
            _ = add_timeline_event(
                session,
                encounter,
                "capture_cancelled",
                "Capture cancelled",
                "The unfinished capture was cancelled without deleting its audit metadata.",
                [active.id]
            );
        }
        response = success_response(session.graph_version, "Capture cancelled.");
        response.capture_session = capture_to_dto(active);
        report response;
    }
}

walker LoadPreparedVoiceDemoWalker(TraceableWalker) {
    has encounter_id: str = "",
        session_id: str = "demo-default",
        reports: list[BackendResponse] = [];

    can stream with Root entry {
        start_result = root spawn StartCaptureSessionWalker(
            encounter_id=self.encounter_id,
            input_source=InputSourceType.PREPARED_TRANSCRIPT,
            session_id=self.session_id
        );
        if not start_result.reports or not start_result.reports[0].success {
            report (
                start_result.reports[0]
                    if start_result.reports
                    else failure_response(
                        "PREPARED_STREAM_FAILED",
                        "Prepared capture could not start.",
                        True,
                        0
                    )
            );
            disengage;
        }
        capture_dto: CaptureSessionDTO = start_result.reports[
            0
        ].capture_session as CaptureSessionDTO;
        for seed in prepared_transcript() {
            append_result = root spawn AppendTranscriptChunkWalker(
                capture_session_id=capture_dto.id,
                sequence=seed.sequence,
                speaker=seed.speaker,
                text=seed.text,
                started_at=f"2026-07-26T18:00:0{seed.sequence}Z",
                ended_at=f"2026-07-26T18:00:0{seed.sequence}Z",
                confidence=1.0,
                session_id=self.session_id
            );
            if not append_result.reports or not append_result.reports[0].success {
                report (
                    append_result.reports[0]
                        if append_result.reports
                        else failure_response(
                            "PREPARED_STREAM_FAILED",
                            "A prepared chunk could not be appended.",
                            True,
                            0
                        )
                );
                disengage;
            }
        }
        session: DemoSession = find_session(self.session_id) as DemoSession;
        capture: CaptureSession = find_capture(
            session, capture_dto.id
        ) as CaptureSession;
        chunks: list[TranscriptChunk] = [capture->:ProducedChunk:->];
        chunks.sort(key=lambda (chunk: TranscriptChunk) { chunk.sequence; });
        response = success_response(
            session.graph_version,
            "Prepared transcript streamed through normal capture ingestion."
        );
        response.capture_session = capture_to_dto(capture);
        response.transcript_chunks = [transcript_to_dto(chunk) for chunk in chunks];
        report response;
    }
}

walker DocumentIngestWalker(TraceableWalker) {
    has encounter_id: str = "",
        document_type: str = "",
        filename: str = "",
        mime_type: str = "",
        image_input: str = "",
        synthetic: bool = True,
        session_id: str = "demo-default",
        extraction_mode: str = "deterministic",
        reports: list[BackendResponse] = [];

    can locate with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        doc_type: SourceArtifactType | None = document_type_value(self.document_type);
        mode: ExtractionMode | None = extraction_mode_type(self.extraction_mode);
        if session is None {
            report failure_response(
                "DEMO_NOT_LOADED", "Load the synthetic encounter first.", True, 0
            );
            disengage;
        }
        if not self.synthetic {
            report failure_response(
                "REAL_DATA_PROHIBITED",
                "Hackathon document intake accepts synthetic material only.",
                False,
                session.graph_version
            );
            disengage;
        }
        if doc_type is None {
            report failure_response(
                "DOCUMENT_TYPE_INVALID",
                "document_type is outside the administrative-document allow-list.",
                True,
                session.graph_version
            );
            disengage;
        }
        if mode is None {
            report failure_response(
                "EXTRACTION_MODE_INVALID",
                "extraction_mode is unsupported.",
                True,
                session.graph_version
            );
            disengage;
        }
        visit session;
    }

    can enter_session with DemoSession entry {
        visit [here->:HasPatient:->];
    }

    can enter_patient with Patient entry {
        visit [here->:HasEncounter:->[?:Encounter, id==self.encounter_id]] else {
            session = find_session(self.session_id);
            report failure_response(
                "ENCOUNTER_NOT_FOUND",
                "The encounter was not found in this session.",
                True,
                session.graph_version if session is not None else 0
            );
            disengage;
        }
    }

    can ingest with Encounter entry {
        session: DemoSession = find_session(self.session_id) as DemoSession;
        doc_type: SourceArtifactType = document_type_value(
            self.document_type
        ) as SourceArtifactType;
        existing: list[SourceArtifact] = [
            artifact
            for artifact in [here->:HasSourceArtifact:->]
            if (
                artifact.artifact_type == doc_type
                and artifact.display_name == self.filename
            )
        ];
        if existing {
            response = success_response(
                session.graph_version,
                "Synthetic document was already ingested; no duplicate was created."
            );
            response.source_artifact = artifact_to_dto(existing[0]);
            document_images: list[DocumentImage] = [existing[0]->:RepresentsDocument:->];
            blocks: list[DocumentTextBlock] = (
                [document_images[0]->:ContainsTextBlock:->] if document_images else []
            );
            blocks.sort(key=lambda (block: DocumentTextBlock) { block.sequence; });
            response.document_text_blocks = [block_to_dto(block) for block in blocks];
            response.multimodal_candidates = [
                multimodal_candidate_to_dto(candidate)
                for candidate in [here->:HasCandidate:->]
                if candidate.source_artifact_id == existing[0].id
            ];
            report response;
            disengage;
        }
        validation: ImageValidationResult = validate_image_data_url(
            self.image_input, self.mime_type
        );
        if not validation.success {
            report failure_response(
                validation.error_code, validation.message, True, session.graph_version
            );
            disengage;
        }
        session.graph_version += 1;
        artifact_id: str = (
            f"artifact-{self.session_id}-{doc_type}-{session.graph_version}"
        );
        requested_mode: ExtractionMode = extraction_mode_type(
            self.extraction_mode
        ) as ExtractionMode;
        artifact = SourceArtifact(
            session_id=self.session_id,
            id=artifact_id,
            encounter_id=here.id,
            artifact_type=doc_type,
            display_name=self.filename,
            mime_type=self.mime_type,
            synthetic=True,
            extraction_mode=requested_mode,
            extraction_status="processing",
            temporary_content_deleted=True,
            created_at=deterministic_timestamp(session.graph_version)
        );
        document = DocumentImage(
            session_id=self.session_id,
            id=f"document-{artifact_id}",
            document_type=doc_type,
            filename=self.filename,
            mime_type=self.mime_type,
            width=validation.width,
            height=validation.height,
            extraction_mode=requested_mode,
            synthetic=True
        );
        own_node(session, artifact);
        own_node(session, document);
        here +>:HasSourceArtifact():+> artifact;
        artifact +>:RepresentsDocument():+> document;
        block_nodes: list[DocumentTextBlock] = [];
        for seed in synthetic_document_blocks(doc_type) {
            block = DocumentTextBlock(
                session_id=self.session_id,
                id=f"{artifact_id}-block-{seed.sequence}",
                source_artifact_id=artifact_id,
                sequence=seed.sequence,
                text=seed.text,
                confidence=seed.confidence,
                page_number=seed.page_number,
                bounding_region=seed.bounding_region,
                source_hash=hashlib.sha256(seed.text.encode()).hexdigest()
            );
            own_node(session, block);
            document +>:ContainsTextBlock():+> block;
            block_nodes.append(block);
        }
        proposals: list[SyntheticDocumentProposal] = synthetic_document_proposals(
            doc_type
        );
        ai_status: AIStatusDTO | None = None;
        mode_text: str = self.extraction_mode.lower().strip();
        if mode_text in ["mock", "mock_malformed", "cloud_model"] {
            image: Image = Image(self.image_input);
            attempt: DocumentVisionAttempt = run_document_vision(
                image, str(doc_type), mode_text
            );
            ai_status = attempt.ai_status;
            valid_ai: list[SyntheticDocumentProposal] = [];
            for proposal in attempt.proposals {
                block_matches: list[DocumentTextBlock] = [
                    block
                    for block in block_nodes
                    if (
                        block.sequence == proposal.source_block_sequence
                        and proposal.exact_source_text == block.text
                    )
                ];
                if (
                    block_matches
                    and 0.0 <= proposal.confidence <= 1.0
                    and not unsafe_document_proposal(proposal)
                ) {
                    valid_ai.append(
                        SyntheticDocumentProposal(
                            category=proposal.category,
                            value=proposal.value,
                            exact_source_text=proposal.exact_source_text,
                            source_block_sequence=proposal.source_block_sequence,
                            confidence=proposal.confidence,
                            patient_visible_candidate=proposal.patient_visible_candidate,
                            requires_clinician_review=True
                        )
                    );
                }
            }
            if valid_ai {
                proposals = valid_ai;
            } else {
                artifact.extraction_mode = ExtractionMode.FALLBACK;
                artifact.extraction_status = "completed_with_fallback";
            }
        }
        candidate_nodes: list[CandidateFact] = [];
        for proposal in proposals {
            source_blocks: list[DocumentTextBlock] = [
                block
                for block in block_nodes
                if (
                    block.sequence == proposal.source_block_sequence
                    and block.text == proposal.exact_source_text
                )
            ];
            if not source_blocks {
                continue;
            }
            duplicate: list[CandidateFact] = [
                candidate
                for candidate in [here->:HasCandidate:->]
                if (
                    candidate.category == proposal.category
                    and candidate.value == proposal.value
                    and candidate.source_artifact_id == artifact.id
                )
            ];
            if duplicate {
                candidate_nodes.extend(duplicate);
                continue;
            }
            candidate = CandidateFact(
                session_id=self.session_id,
                id=f"candidate-document-{artifact.id}-{proposal.source_block_sequence}",
                category=proposal.category,
                value=proposal.value,
                confidence=proposal.confidence,
                status=CandidateStatus.PENDING,
                source_kind="document",
                source_artifact_id=artifact.id,
                source_text_block_id=source_blocks[0].id,
                source_text=source_blocks[0].text,
                source_region=source_blocks[0].bounding_region,
                created_at=deterministic_timestamp(session.graph_version)
            );
            own_node(session, candidate);
            here +>:HasCandidate():+> candidate;
            candidate +>:ExtractedFromDocument():+> source_blocks[0];
            candidate_nodes.append(candidate);
        }
        artifact.extraction_status = (
            artifact.extraction_status
                if artifact.extraction_status == "completed_with_fallback"
                else "completed"
        );
        _ = add_timeline_event(
            session,
            here,
            "document_scanned",
            "Synthetic document scanned",
            f"Extracted {len(block_nodes)} text blocks and {len(
                candidate_nodes
            )} pending proposals.",
            [artifact.id, document.id],
            [candidate.id for candidate in candidate_nodes]
        );
        response = success_response(
            session.graph_version,
            "Synthetic document metadata and pending proposals were stored; raw image content was deleted."
        );
        response.source_artifact = artifact_to_dto(artifact);
        response.document_text_blocks = [block_to_dto(block) for block in block_nodes];
        response.multimodal_candidates = [
            multimodal_candidate_to_dto(candidate) for candidate in candidate_nodes
        ];
        response.candidate_facts = [
            candidate_to_dto(candidate) for candidate in candidate_nodes
        ];
        response.ai_status = ai_status;
        if ai_status is not None and ai_status.fallback_used {
            response.recoverable = True;
            response.error_code = ai_status.diagnostic_code;
        }
        response.created_graph_ids = (
            [artifact.id, document.id] + [block.id for block in block_nodes] + [
                candidate.id for candidate in candidate_nodes
            ]
        );
        report response;
    }
}

walker GenerateClinicianNoteDraftWalker(TraceableWalker) {
    has encounter_id: str = "",
        clinician_hints: str = "",
        session_id: str = "demo-default",
        reports: list[BackendResponse] = [];

    can locate with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        if session is None {
            report failure_response(
                "DEMO_NOT_LOADED", "Load the synthetic encounter first.", True, 0
            );
            disengage;
        }
        if unsafe_text(self.clinician_hints) {
            report failure_response(
                "UNSAFE_CLINICIAN_HINT",
                "The hint contains prohibited autonomous clinical content.",
                True,
                session.graph_version
            );
            disengage;
        }
        visit session;
    }

    can enter_session with DemoSession entry {
        visit [here->:HasPatient:->];
    }

    can enter_patient with Patient entry {
        visit [here->:HasEncounter:->[?:Encounter, id==self.encounter_id]] else {
            session = find_session(self.session_id);
            report failure_response(
                "ENCOUNTER_NOT_FOUND",
                "The encounter was not found in this session.",
                True,
                session.graph_version if session is not None else 0
            );
            disengage;
        }
    }

    can generate with Encounter entry {
        session: DemoSession = find_session(self.session_id) as DemoSession;
        facts: list[VerifiedFact] = [
            fact
            for fact in [here->:HasVerifiedFact:->]
            if not fact_is_conflicted(session, fact.id)
        ];
        if not facts {
            report failure_response(
                "NO_VERIFIED_FACTS",
                "A note draft requires clinician-verified facts.",
                True,
                session.graph_version
            );
            disengage;
        }
        session.graph_version += 1;
        note = ClinicianNoteDraft(
            session_id=self.session_id,
            id=f"note-{self.session_id}-{session.graph_version}",
            encounter_id=here.id,
            status=NoteStatus.DRAFT,
            generated_at=deterministic_timestamp(session.graph_version)
        );
        own_node(session, note);
        here +>:HasClinicianNote():+> note;
        note +>:NoteGeneratedFrom():+> here;
        gaps: list[CareGap] = [here->:HasGap:->];
        open_gap_text: str = (
            "; ".join(
                [
                    gap.message
                    for gap in gaps
                    if not gap.resolved
                ]
            )
                if any(not gap.resolved for gap in gaps)
                else "No unresolved administrative care gaps."
        );
        conflict_text: str = (
            "; ".join(
                [conflict.explanation for conflict in unresolved_conflicts(session)]
            )
                if unresolved_conflicts(session)
                else "No unresolved contradictions in the current verified graph."
        );
        hint_text: str = (
            f" Clinician hint — unverified administrative context: {self.clinician_hints.strip()}"
                if self.clinician_hints.strip()
                else ""
        );
        section_specs: list[tuple[str, str, str]] = [
            (
                "patient_concerns",
                "Patient-stated concerns",
                f"{verified_values(facts, CandidateCategory.LANGUAGE_PREFERENCE)}{hint_text}"
            ),
            (
                "confirmed_instructions",
                "Confirmed instructions",
                "; ".join([fact.value for fact in facts])
            ),
            (
                "medication_instructions",
                "Confirmed medication instructions",
                verified_values(facts, CandidateCategory.MEDICATION_INSTRUCTION)
            ),
            (
                "laboratory_orders",
                "Laboratory orders",
                verified_values(facts, CandidateCategory.LAB_ORDER)
            ),
            (
                "referrals",
                "Referrals",
                verified_values(facts, CandidateCategory.REFERRAL)
            ),
            (
                "follow_up",
                "Follow-up plan",
                verified_values(facts, CandidateCategory.FOLLOW_UP)
            ),
            ("unresolved_gaps", "Outstanding administrative tasks", open_gap_text),
            ("contradictions", "Contradictions requiring review", conflict_text),
            (
                "source_evidence",
                "Source evidence summary",
                "; ".join([f"{fact.id}: {fact.source_text}" for fact in facts])
            )
        ];
        created_ids: list[str] = [note.id];
        for index in range(len(section_specs)) {
            spec = section_specs[index];
            section = NoteSection(
                session_id=self.session_id,
                id=f"{note.id}-{index + 1:02d}-{spec[0]}",
                section_type=spec[0],
                heading=spec[1],
                generated_content=spec[2],
                edited_content="",
                manually_edited=False,
                approved=False
            );
            own_node(session, section);
            note +>:ContainsSection():+> section;
            for fact in facts {
                section +>:NoteSupportedBy():+> fact;
            }
            created_ids.append(section.id);
        }
        _ = add_timeline_event(
            session,
            here,
            "note_generated",
            "Clinician-review note draft generated",
            "Generated a synthetic draft from verified graph facts.",
            [note.id],
            [fact.id for fact in facts]
        );
        response = success_response(
            session.graph_version,
            "Clinician-review draft generated from verified facts only."
        );
        response.clinician_note = note_to_dto(note);
        response.created_graph_ids = created_ids;
        report response;
    }
}

walker UpdateNoteSectionWalker(TraceableWalker) {
    has note_id: str = "",
        section_id: str = "",
        content: str = "",
        clinician_id: str = "",
        session_id: str = "demo-default",
        reports: list[BackendResponse] = [];

    can update with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        note: ClinicianNoteDraft | None = (
            find_note(session as DemoSession, self.note_id)
                if session is not None
                else None
        );
        if session is None or note is None {
            report failure_response(
                "NOTE_NOT_FOUND",
                "The note was not found in this session.",
                True,
                session.graph_version if session is not None else 0
            );
            disengage;
        }
        if not self.clinician_id.strip() {
            report failure_response(
                "INVALID_CLINICIAN_ID",
                "clinician_id is required.",
                True,
                session.graph_version
            );
            disengage;
        }
        if not self.content.strip() {
            report failure_response(
                "BLANK_NOTE_CONTENT",
                "Edited note content cannot be blank.",
                True,
                session.graph_version
            );
            disengage;
        }
        if unsafe_text(self.content) {
            report failure_response(
                "UNSAFE_NOTE_CONTENT",
                "The edit contains prohibited autonomous clinical content.",
                True,
                session.graph_version
            );
            disengage;
        }
        active_note: ClinicianNoteDraft = note as ClinicianNoteDraft;
        if active_note.status == NoteStatus.APPROVED {
            session.graph_version += 1;
            replacement = ClinicianNoteDraft(
                session_id=self.session_id,
                id=f"note-{self.session_id}-{session.graph_version}",
                encounter_id=active_note.encounter_id,
                status=NoteStatus.DRAFT,
                generated_at=deterministic_timestamp(session.graph_version),
                supersedes_note_id=active_note.id
            );
            own_node(session, replacement);
            encounter: Encounter = session_encounter(session) as Encounter;
            encounter +>:HasClinicianNote():+> replacement;
            replacement +>:NoteGeneratedFrom():+> encounter;
            replacement +>:SupersedesNote():+> active_note;
            old_sections: list[NoteSection] = [active_note->:ContainsSection:->];
            for old_section in old_sections {
                copied = NoteSection(
                    session_id=self.session_id,
                    id=old_section.id.replace(active_note.id, replacement.id),
                    section_type=old_section.section_type,
                    heading=old_section.heading,
                    generated_content=(
                        old_section.edited_content
                            if old_section.manually_edited
                            else old_section.generated_content
                    ),
                    edited_content="",
                    manually_edited=False,
                    approved=False
                );
                own_node(session, copied);
                replacement +>:ContainsSection():+> copied;
                for fact in [old_section->:NoteSupportedBy:->] {
                    copied +>:NoteSupportedBy():+> fact;
                }
            }
            active_note.status = NoteStatus.SUPERSEDED;
            active_note = replacement;
            self.note_id = replacement.id;
            self.section_id = self.section_id.replace(
                (note as ClinicianNoteDraft).id, replacement.id
            );
        }
        sections: list[NoteSection] = [active_note->:ContainsSection:->[?:NoteSection, id==self.section_id]];
        if not sections {
            report failure_response(
                "SECTION_NOT_FOUND",
                "The section was not found in this note.",
                True,
                session.graph_version
            );
            disengage;
        }
        session.graph_version += 1;
        section: NoteSection = sections[0];
        section.edited_content = self.content.strip();
        section.manually_edited = True;
        section.approved = False;
        active_note.status = NoteStatus.EDITED;
        active_note.edited_at = deterministic_timestamp(session.graph_version);
        event = NoteEditEvent(
            session_id=self.session_id,
            id=f"note-edit-{active_note.id}-{session.graph_version}",
            clinician_id=self.clinician_id,
            edited_at=active_note.edited_at,
            section_id=section.id
        );
        own_node(session, event);
        active_note +>:HasNoteEdit():+> event;
        encounter = session_encounter(session) as Encounter;
        _ = add_timeline_event(
            session,
            encounter,
            "note_edited",
            "Clinician-review note edited",
            "A clinician edit was stored separately from generated text.",
            [active_note.id, section.id, event.id],
            [fact.id for fact in [section->:NoteSupportedBy:->]]
        );
        response = success_response(session.graph_version, "Note section updated.");
        response.clinician_note = note_to_dto(active_note);
        response.created_graph_ids = [event.id];
        report response;
    }
}

walker ApproveClinicianNoteWalker(TraceableWalker) {
    has note_id: str = "",
        clinician_id: str = "",
        session_id: str = "demo-default",
        reports: list[BackendResponse] = [];

    can approve with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        note: ClinicianNoteDraft | None = (
            find_note(session as DemoSession, self.note_id)
                if session is not None
                else None
        );
        if session is None or note is None {
            report failure_response(
                "NOTE_NOT_FOUND",
                "The note was not found in this session.",
                True,
                session.graph_version if session is not None else 0
            );
            disengage;
        }
        if not self.clinician_id.strip() {
            report failure_response(
                "INVALID_CLINICIAN_ID",
                "clinician_id is required.",
                True,
                session.graph_version
            );
            disengage;
        }
        active_note: ClinicianNoteDraft = note as ClinicianNoteDraft;
        if active_note.status == NoteStatus.APPROVED {
            response = success_response(
                session.graph_version,
                "Note was already approved; no duplicate approval was created."
            );
            response.clinician_note = note_to_dto(active_note);
            report response;
            disengage;
        }
        if unresolved_conflicts(session as DemoSession) {
            report failure_response(
                "UNRESOLVED_NOTE_CONFLICT",
                "Resolve or supersede contradictions before approving a new note.",
                True,
                session.graph_version
            );
            disengage;
        }
        sections: list[NoteSection] = [active_note->:ContainsSection:->];
        if len(sections) < 9
        or any(not [section->:NoteSupportedBy:->] for section in sections) {
            report failure_response(
                "NOTE_SECTION_MISSING",
                "Every required note section needs verified source support.",
                False,
                session.graph_version
            );
            disengage;
        }
        session.graph_version += 1;
        active_note.status = NoteStatus.APPROVED;
        active_note.approved_at = deterministic_timestamp(session.graph_version);
        active_note.approved_by = self.clinician_id;
        for section in sections {
            section.approved = True;
        }
        event = NoteApprovalEvent(
            session_id=self.session_id,
            id=f"note-approval-{active_note.id}",
            clinician_id=self.clinician_id,
            approved_at=active_note.approved_at
        );
        own_node(session, event);
        active_note +>:ApprovedByEvent():+> event;
        encounter: Encounter = session_encounter(session) as Encounter;
        _ = add_timeline_event(
            session,
            encounter,
            "note_approved",
            "Clinician-review note approved",
            "A clinician approved the synthetic draft.",
            [active_note.id, event.id],
            note_to_dto(active_note).source_fact_ids
        );
        response = success_response(session.graph_version, "Clinician note approved.");
        response.clinician_note = note_to_dto(active_note);
        response.created_graph_ids = [event.id];
        report response;
    }
}

walker EncounterTimelineWalker(TraceableWalker) {
    has encounter_id: str = "",
        session_id: str = "demo-default",
        reports: list[BackendResponse] = [];

    can timeline with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        encounter: Encounter | None = (
            session_encounter(session as DemoSession) if session is not None else None
        );
        if (
            session is None
            or encounter is None
            or (encounter as Encounter).id != self.encounter_id
        ) {
            report failure_response(
                "ENCOUNTER_NOT_FOUND",
                "The encounter was not found in this session.",
                True,
                session.graph_version if session is not None else 0
            );
            disengage;
        }
        active: Encounter = encounter as Encounter;
        events: list[EncounterTimelineEventDTO] = [
            EncounterTimelineEventDTO(
                id=event.id,
                event_type=event.event_type,
                occurred_at=event.occurred_at,
                title=event.title,
                description=event.description,
                related_node_ids=event.related_node_ids,
                source_fact_ids=event.source_fact_ids,
                graph_version=event.graph_version
            ) for event in [active->:HasTimelineEvent:->]
        ];
        for candidate in [active->:HasCandidate:->] {
            events.append(
                EncounterTimelineEventDTO(
                    id=f"timeline-derived-{candidate.id}",
                    event_type="candidate_proposed",
                    occurred_at=candidate.created_at,
                    title="Candidate fact proposed",
                    description=f"{candidate.category} remains {candidate.status}.",
                    related_node_ids=[candidate.id],
                    source_fact_ids=[],
                    graph_version=session.graph_version
                )
            );
            for decision in [candidate->:HasVerificationEvent:->] {
                events.append(
                    EncounterTimelineEventDTO(
                        id=f"timeline-derived-{decision.id}",
                        event_type=(
                            "fact_accepted"
                                if decision.decision == "accept"
                                else "fact_rejected"
                        ),
                        occurred_at=decision.decided_at,
                        title="Clinician verification decision",
                        description=f"Clinician {decision.clinician_id} recorded {decision.decision}.",
                        related_node_ids=[candidate.id, decision.id],
                        source_fact_ids=[
                            fact.id for fact in [candidate->:PromotedTo:->]
                        ],
                        graph_version=session.graph_version
                    )
                );
            }
        }
        for gap in [active->:HasGap:->] {
            events.append(
                EncounterTimelineEventDTO(
                    id=f"timeline-derived-{gap.id}",
                    event_type=(
                        "care_gap_resolved" if gap.resolved else "care_gap_detected"
                    ),
                    occurred_at=(
                        (
                            [gap->:ResolvedBy:->][0].recorded_at
                                if [gap->:ResolvedBy:->]
                                else deterministic_timestamp(session.graph_version)
                        )
                    ),
                    title=(
                        "Care gap resolved" if gap.resolved else "Care gap detected"
                    ),
                    description=gap.message,
                    related_node_ids=[gap.id],
                    source_fact_ids=gap.related_fact_ids,
                    graph_version=session.graph_version
                )
            );
        }
        events.sort(
            key=lambda (event: EncounterTimelineEventDTO) { event.occurred_at; }
        );
        response = success_response(
            session.graph_version, "Encounter timeline loaded."
        );
        response.timeline = events;
        report response;
    }
}

walker PatientAudioScriptWalker(TraceableWalker) {
    has language: str = "English",
        session_id: str = "demo-default",
        reports: list[BackendResponse] = [];

    can generate with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        if session is None {
            report failure_response(
                "DEMO_NOT_LOADED", "Load the synthetic encounter first.", True, 0
            );
            disengage;
        }
        normalized: str = self.language.lower().strip();
        if normalized not in ["english", "spanish"] {
            report failure_response(
                "UNSUPPORTED_LANGUAGE",
                "Patient audio supports English and Spanish only.",
                True,
                session.graph_version
            );
            disengage;
        }
        patient: Patient | None = session_patient(session as DemoSession);
        if patient is None {
            report failure_response(
                "PATIENT_PLAN_NOT_FOUND",
                "Generate an approved patient plan first.",
                True,
                session.graph_version
            );
            disengage;
        }
        briefs: list[PatientBrief] = [
            brief
            for brief in [(patient as Patient)->:HasBrief:->]
            if brief.current and brief.language.lower() == normalized
        ];
        if not briefs {
            report failure_response(
                "PATIENT_PLAN_NOT_FOUND",
                "Generate the requested approved patient plan first.",
                True,
                session.graph_version
            );
            disengage;
        }
        brief: PatientBrief = briefs[-1];
        if any(
            fact_is_conflicted(session as DemoSession, fact_id)
            for fact_id in brief.source_fact_ids
        ) {
            report failure_response(
                "CONFLICTED_PLAN",
                "A conflicted plan cannot be converted to patient audio.",
                True,
                session.graph_version
            );
            disengage;
        }
        existing: list[PatientAudioScript] = [
            script
            for script in [(patient as Patient)->:HasAudioScript:->]
            if (
                script.language.lower() == normalized
                and script.source_fact_ids == brief.source_fact_ids
            )
        ];
        script: PatientAudioScript;
        if existing {
            script = existing[-1];
        } else {
            session.graph_version += 1;
            prefix: str = (
                "Su plan de atención aprobado. "
                    if normalized == "spanish"
                    else "Your approved care plan. "
            );
            script = PatientAudioScript(
                session_id=self.session_id,
                id=f"audio-script-{self.session_id}-{normalized}-{session.graph_version}",
                language=("Spanish" if normalized == "spanish" else "English"),
                text=prefix + " ".join(brief.checklist),
                source_fact_ids=brief.source_fact_ids,
                generated_at=deterministic_timestamp(session.graph_version),
                voice_name="browser-default",
                fallback_used=False
            );
            own_node(session, script);
            (patient as Patient) +>:HasAudioScript():+> script;
            script +>:AudioGeneratedFrom():+> brief;
            for fact in verified_facts_for_session(session) {
                if fact.id in brief.source_fact_ids {
                    script +>:AudioSupportedBy():+> fact;
                }
            }
        }
        response = success_response(
            session.graph_version,
            "Approved patient audio script generated for browser speech synthesis."
        );
        response.patient_audio_script = PatientAudioScriptDTO(
            patient_id=(patient as Patient).id,
            language=script.language,
            text=script.text,
            source_fact_ids=script.source_fact_ids,
            generated_from_approved_plan=True,
            voice_name=script.voice_name,
            fallback_used=script.fallback_used
        );
        report response;
    }
}

def provenance_steps_for_fact(
    fact: VerifiedFact, output_id: str
) -> MultimodalProvenanceDTO {
    candidates: list[CandidateFact] = [fact->:VerifiedFrom:->];
    if len(candidates) != 1 {
        return MultimodalProvenanceDTO(output_id=output_id, complete=False);
    }
    candidate: CandidateFact = candidates[0];
    encounter_nodes: list[Encounter] = [candidate<-:HasCandidate:<-];
    patient_nodes: list[Patient] = (
        [encounter_nodes[0]<-:HasEncounter:<-] if encounter_nodes else []
    );
    steps: list[TraversalStepDTO] = [
        TraversalStepDTO(
            order=1,
            walker_name="MultimodalTraceProvenanceWalker",
            current_node_id=fact.id,
            current_node_type="VerifiedFact",
            edge_type="VerifiedFrom",
            action="follow verification source",
            outcome=candidate.id,
            human_explanation="Reached the clinician-approved fact's pending proposal."
        )
    ];
    source_type: str = candidate.source_kind;
    complete: bool = False;
    if source_type == "document" {
        blocks: list[DocumentTextBlock] = [candidate->:ExtractedFromDocument:->];
        if blocks {
            documents: list[DocumentImage] = [blocks[0]<-:ContainsTextBlock:<-];
            artifacts: list[SourceArtifact] = (
                [documents[0]<-:RepresentsDocument:<-] if documents else []
            );
            steps.append(
                TraversalStepDTO(
                    order=2,
                    walker_name="MultimodalTraceProvenanceWalker",
                    current_node_id=candidate.id,
                    current_node_type="CandidateFact",
                    edge_type="ExtractedFromDocument",
                    action="follow document evidence",
                    outcome=blocks[0].id,
                    human_explanation="Reached the exact synthetic document text block and region."
                )
            );
            if artifacts {
                steps.append(
                    TraversalStepDTO(
                        order=3,
                        walker_name="MultimodalTraceProvenanceWalker",
                        current_node_id=blocks[0].id,
                        current_node_type="DocumentTextBlock",
                        edge_type="ContainsTextBlock/RepresentsDocument",
                        action="follow source artifact",
                        outcome=artifacts[0].id,
                        human_explanation="Reached non-raw synthetic source metadata."
                    )
                );
            }
            complete = bool(
                artifacts
                and encounter_nodes
                and patient_nodes
                and artifacts[0].encounter_id == encounter_nodes[0].id
            );
        }
    } else {
        chunks: list[TranscriptChunk] = [candidate->:ExtractedFrom:->];
        if chunks {
            captures: list[CaptureSession] = [chunks[0]<-:ProducedChunk:<-];
            steps.append(
                TraversalStepDTO(
                    order=2,
                    walker_name="MultimodalTraceProvenanceWalker",
                    current_node_id=candidate.id,
                    current_node_type="CandidateFact",
                    edge_type="ExtractedFrom",
                    action="follow transcript evidence",
                    outcome=chunks[0].id,
                    human_explanation="Reached the exact speaker-labeled transcript chunk."
                )
            );
            if captures {
                steps.append(
                    TraversalStepDTO(
                        order=3,
                        walker_name="MultimodalTraceProvenanceWalker",
                        current_node_id=chunks[0].id,
                        current_node_type="TranscriptChunk",
                        edge_type="ProducedChunk",
                        action="follow capture session",
                        outcome=captures[0].id,
                        human_explanation="Reached the capture session without raw audio."
                    )
                );
            }
            complete = bool(encounter_nodes and patient_nodes);
        }
    }
    return MultimodalProvenanceDTO(
        output_id=output_id,
        ordered_steps=steps,
        source_excerpt=candidate.source_text,
        source_type=source_type,
        verification_status=candidate.status,
        clinician_id=fact.verified_by,
        complete=complete
    );
}

walker MultimodalTraceProvenanceWalker(TraceableWalker) {
    has output_type: str = "",
        output_id: str = "",
        section_id: str = "",
        session_id: str = "demo-default",
        reports: list[BackendResponse] = [];

    can trace with Root entry {
        session: DemoSession | None = find_session(self.session_id);
        if session is None {
            report failure_response(
                "DEMO_NOT_LOADED", "Load the synthetic encounter first.", True, 0
            );
            disengage;
        }
        normalized: str = self.output_type.lower().strip();
        if normalized not in [
            "candidate",
            "note_section",
            "checklist_item",
            "patient_answer"
        ] {
            report failure_response(
                "OUTPUT_TYPE_INVALID",
                "output_type is unsupported.",
                True,
                session.graph_version
            );
            disengage;
        }
        facts: list[VerifiedFact] = [];
        target_id: str = self.output_id;
        if normalized == "candidate" {
            candidates: list[CandidateFact] = [
                candidate
                for candidate in candidates_for_session(session as DemoSession)
                if candidate.id == self.output_id
            ];
            if candidates {
                facts = [candidates[0]->:PromotedTo:->];
            }
        } elif normalized == "note_section" {
            note: ClinicianNoteDraft | None = find_note(
                session as DemoSession, self.output_id
            );
            if note is not None {
                sections: list[NoteSection] = [(note as ClinicianNoteDraft)->:ContainsSection:->[?:NoteSection, id==self.section_id]];
                if sections {
                    target_id = sections[0].id;
                    facts = [sections[0]->:NoteSupportedBy:->];
                }
            }
        } elif normalized == "checklist_item" {
            patient: Patient | None = session_patient(session as DemoSession);
            if patient is not None {
                for brief in [(patient as Patient)->:HasBrief:->] {
                    for item in [brief->:HasChecklistItem:->[?:ChecklistItem, id==self.output_id]] {
                        facts.extend([item->:SupportedBy:->]);
                    }
                }
            }
        } else {
            patient = session_patient(session as DemoSession);
            if patient is not None {
                for question in [(patient as Patient)->:HasQuestion:->] {
                    for answer in [question->:HasAnswer:->[?:PatientAnswer, id==self.output_id]] {
                        facts.extend([answer->:AnsweredFrom:->]);
                    }
                }
            }
        }
        if not facts {
            report failure_response(
                "OUTPUT_NOT_FOUND",
                "The output was not found in this session or has no verified support.",
                True,
                session.graph_version
            );
            disengage;
        }
        chains: list[MultimodalProvenanceDTO] = [];
        for fact in facts {
            chain: MultimodalProvenanceDTO = provenance_steps_for_fact(fact, target_id);
            chain.output_type = normalized;
            chain.section_id = self.section_id;
            chains.append(chain);
        }
        if any(not chain.complete for chain in chains) {
            response = failure_response(
                "PROVENANCE_INCOMPLETE",
                "At least one output path is incomplete.",
                False,
                session.graph_version
            );
            response.multimodal_provenance = chains;
            report response;
            disengage;
        }
        response = success_response(session.graph_version, "Source provenance traced.");
        response.multimodal_provenance = chains;
        report response;
    }
}
