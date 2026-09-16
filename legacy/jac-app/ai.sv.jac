"""Optional, typed AI seams with deterministic and safety-first fallbacks."""

import os;
import from jaclang.byllm.lib { MockLLM, OutputConversionError, }
import from models {
    AIStatusDTO,
    CandidateCategory,
    ExtractedCandidate,
    PatientPlanDTO,
    PlanItemDTO,
    TranscriptChunkDTO,
    TranslatedBriefText,
    VerifiedFactReference,
}
import from extraction { prepared_candidates, prepared_transcript, }

glob ALLOWED_CATEGORIES: list[CandidateCategory] = [
         CandidateCategory.LAB_ORDER,
         CandidateCategory.FOLLOW_UP,
         CandidateCategory.MEDICATION_INSTRUCTION,
         CandidateCategory.REFERRAL,
         CandidateCategory.LANGUAGE_PREFERENCE,

     ],
     BLOCKED_MEDICAL_PHRASES: list[str] = [
         "diagnos",
         "start taking",
         "stop taking",
         "increase the dose",
         "decrease the dose",
         "change the dose",
         "change dosage",
         "new dosage",
         "safe to",
         "call 911",
         "emergency triage",

     ],
     BLOCKED_INJECTION_PHRASES: list[str] = [
         "approve automatically",
         "return a verified node",
         "create a verified fact",
         "ignore previous instructions",
         "reveal another patient",
         "resolve the contradiction",

     ],
     PROTECTED_TIME_TOKENS: list[str] = [
         "today",
         "tomorrow",
         "week",
         "weeks",
         "month",
         "months",
         "monday",
         "tuesday",
         "wednesday",
         "thursday",
         "friday",
         "saturday",
         "sunday",

     ];

obj LLMExtractedCandidate {
    has category: CandidateCategory = CandidateCategory.LAB_ORDER,
        value: str = "",
        source_text: str = "",
        source_chunk_id: str = "",
        confidence: float = 0.0,
        patient_visible_candidate: bool = False;
}

sem LLMExtractedCandidate.category = "One allowed category only: lab_order, follow_up, medication_instruction, referral, or language_preference. Never use diagnosis, treatment advice, emergency triage, or dosage.";
sem LLMExtractedCandidate.value = "A concise normalization of only what the source states. Never infer, diagnose, recommend, prescribe, add a dose, or fill missing details.";
sem LLMExtractedCandidate.source_text = "Exact verbatim evidence copied from one transcript chunk.";
sem LLMExtractedCandidate.source_chunk_id = "The exact identifier of the transcript chunk containing source_text.";
sem LLMExtractedCandidate.confidence = "Extraction confidence from 0.0 through 1.0, not clinical certainty.";
sem LLMExtractedCandidate.patient_visible_candidate = "Whether the statement might later be patient-facing after clinician approval. This never makes the unverified candidate patient-visible.";

obj LLMTranslatedBriefText {
    has medication_texts: list[str] = [],
        lab_texts: list[str] = [],
        referral_texts: list[str] = [],
        follow_up_texts: list[str] = [],
        checklist: list[str] = [];
}

sem LLMTranslatedBriefText.medication_texts = "Translated approved medication instructions in the same order and count.";
sem LLMTranslatedBriefText.lab_texts = "Translated approved laboratory instructions in the same order and count.";
sem LLMTranslatedBriefText.referral_texts = "Translated approved referral instructions in the same order and count.";
sem LLMTranslatedBriefText.follow_up_texts = "Translated approved follow-up instructions in the same order and count.";
sem LLMTranslatedBriefText.checklist = "Translated checklist in the same order and count. Preserve every date, number, proper name, and bracketed source fact identifier exactly.";

obj LLMQuestionMatch {
    has verified_fact_ids: list[str] = [];
}

sem LLMQuestionMatch.verified_fact_ids = "Only identifiers copied from the supplied approved fact references that could answer the question. Return an empty list when none is relevant.";

obj CandidateValidationResult {
    has success: bool = False,
        candidates: list[ExtractedCandidate] = [],
        error_code: str = "",
        message: str = "";
}

obj CandidateExtractionAttempt {
    has candidates: list[ExtractedCandidate] = [],
        ai_status: AIStatusDTO | None = None;
}

obj BriefEnhancementAttempt {
    has plan: PatientPlanDTO | None = None,
        ai_status: AIStatusDTO | None = None;
}

obj QuestionMatchAttempt {
    has matched_fact_ids: list[str] = [],
        ai_status: AIStatusDTO | None = None;
}

sem extract_candidate_proposals = "Extract only explicitly stated continuity-of-care candidate facts from the supplied synthetic transcript chunks. Classify each candidate as exactly one of lab_order, follow_up, medication_instruction, referral, or language_preference. Copy source_text verbatim from exactly one chunk and copy that chunk's id. Never diagnose, prescribe, recommend medication, select or change a dosage, decide safety, perform emergency triage, resolve a contradiction, or infer missing information. The result is unverified proposals only and has no authority to approve or modify graph records.";
sem extract_candidate_proposals.transcript_text = "Synthetic transcript chunks serialized as chunk id, speaker, and text only. Do not infer patient identity or information beyond these supplied fields.";
def extract_candidate_proposals(transcript_text: str) -> list[LLMExtractedCandidate] by llm(
    temperature=0.0, max_tokens=1200, max_output_retries=1, timeout=8.0
);

sem translate_approved_brief = "Translate an already clinician-approved English care-plan text bundle to Spanish. Preserve list counts, order, dates, numbers, proper names, and every bracketed source fact identifier exactly. Do not add explanations, medical advice, diagnoses, urgency, medication changes, or unstated information.";
sem translate_approved_brief.approved_english = "Approved English plan text only. Its source identifiers are immutable.";
def translate_approved_brief(approved_english: str) -> LLMTranslatedBriefText by llm(
    temperature=0.0, max_tokens=1200, max_output_retries=1, timeout=8.0
);

sem simplify_approved_brief = "Simplify the wording of an already clinician-approved English care plan without changing meaning. Preserve list counts, order, dates, numbers, names, obligations, and every bracketed source identifier. Do not add medical advice, diagnosis, urgency, or missing information.";
sem simplify_approved_brief.approved_english = "Approved English plan text only. Keep all clinical content and source identifiers unchanged while using shorter plain language.";
def simplify_approved_brief(approved_english: str) -> LLMTranslatedBriefText by llm(
    temperature=0.0, max_tokens=1200, max_output_retries=1, timeout=8.0
);

sem match_question_to_verified_facts = "Select only the ids of supplied clinician-verified graph facts that are directly relevant to the patient question. Never answer the question, use general medical knowledge, invent an id, consider an unverified candidate, or resolve a contradiction. Return an empty list when supplied facts do not answer the question.";
sem match_question_to_verified_facts.question = "A synthetic patient question used only for relevance matching.";
sem match_question_to_verified_facts.verified_facts = "The complete allow-list of approved, patient-visible, non-conflicting fact references. Only ids from this list may be returned.";
def match_question_to_verified_facts(
    question: str, verified_facts: str
) -> LLMQuestionMatch by llm(
    temperature=0.0, max_tokens=300, max_output_retries=1, timeout=8.0
);

glob MOCK_LLM_EXTRACTED_CANDIDATES: list[LLMExtractedCandidate] = [
         LLMExtractedCandidate(
             category=CandidateCategory.LAB_ORDER,
             value="blood test; due this week",
             source_text="We will order a blood test to be completed this week.",
             source_chunk_id="chunk-1",
             confidence=0.99,
             patient_visible_candidate=True
         ),
         LLMExtractedCandidate(
             category=CandidateCategory.FOLLOW_UP,
             value="return in two weeks",
             source_text="Please return in two weeks so we can review the results.",
             source_chunk_id="chunk-2",
             confidence=0.99,
             patient_visible_candidate=True
         ),
         LLMExtractedCandidate(
             category=CandidateCategory.MEDICATION_INSTRUCTION,
             value="continue existing prescription unchanged",
             source_text=(
                 "Continue your current medication exactly as it appears "
                 "on your existing prescription."
             ),
             source_chunk_id="chunk-3",
             confidence=0.99,
             patient_visible_candidate=True
         ),
         LLMExtractedCandidate(
             category=CandidateCategory.REFERRAL,
             value="community nutrition counselor",
             source_text=("I am referring you to a community nutrition counselor."),
             source_chunk_id="chunk-4",
             confidence=0.99,
             patient_visible_candidate=True
         ),
         LLMExtractedCandidate(
             category=CandidateCategory.LANGUAGE_PREFERENCE,
             value="Spanish",
             source_text=("Can someone explain the instructions to me in Spanish?"),
             source_chunk_id="chunk-5",
             confidence=0.99,
             patient_visible_candidate=False
         )
     ],
     MOCK_SPANISH_BRIEF: LLMTranslatedBriefText = LLMTranslatedBriefText(
         medication_texts=[
             (
                 "Continúe su medicamento actual exactamente como aparece "
                 "en su receta existente."
             )
         ],
         lab_texts=["Complete el análisis de sangre esta semana."],
         referral_texts=["Su remisión es a un consejero comunitario de nutrición."],
         follow_up_texts=["Regrese en dos semanas; cita: 2026-08-09."],
         checklist=[
             (
                 "Complete el análisis de sangre esta semana. "
                 "[source: verified-candidate-lab]"
             ),
             (
                 "Regrese en dos semanas; cita: 2026-08-09. "
                 "[source: verified-candidate-follow-up]"
             ),
             (
                 "Continúe su medicamento actual exactamente como aparece "
                 "en su receta existente. "
                 "[source: verified-candidate-medication]"
             ),
             (
                 "Su remisión es a un consejero comunitario de nutrición. "
                 "[source: verified-candidate-referral]"
             )
         ]
     ),
     MOCK_SIMPLIFIED_BRIEF: LLMTranslatedBriefText = LLMTranslatedBriefText(
         medication_texts=[
             "Keep taking your medication exactly as written on your prescription."
         ],
         lab_texts=["Get the blood test this week."],
         referral_texts=["Your referral is to a community nutrition counselor."],
         follow_up_texts=["Return in two weeks; appointment: 2026-08-09."],
         checklist=[
             "Get the blood test this week. [source: verified-candidate-lab]",
             (
                 "Return in two weeks; appointment: 2026-08-09. "
                 "[source: verified-candidate-follow-up]"
             ),
             (
                 "Keep taking your medication exactly as written on your "
                 "prescription. [source: verified-candidate-medication]"
             ),
             (
                 "Your referral is to a community nutrition counselor. "
                 "[source: verified-candidate-referral]"
             )
         ]
     ),
     mock_extraction_model = MockLLM(
         model_name="mockllm",
         config={"outputs": [MOCK_LLM_EXTRACTED_CANDIDATES for unused in range(32)]}
     ),
     mock_translation_model = MockLLM(
         model_name="mockllm",
         config={"outputs": [MOCK_SPANISH_BRIEF for unused in range(32)]}
     ),
     mock_simplification_model = MockLLM(
         model_name="mockllm",
         config={"outputs": [MOCK_SIMPLIFIED_BRIEF for unused in range(32)]}
     ),
     mock_question_model = MockLLM(
         model_name="mockllm",
         config={
             "outputs": [
                 LLMQuestionMatch(verified_fact_ids=["verified-candidate-lab"])
                 for unused in range(32)
             ]
         }
     ),
     malformed_extraction_model = MockLLM(
         model_name="mockllm",
         config={"outputs": ["not a typed candidate list" for unused in range(64)]}
     );

def mock_extract_candidate_proposals(
    transcript_text: str
) -> list[LLMExtractedCandidate] by mock_extraction_model(
    temperature=0.0, max_tokens=1200, max_output_retries=1, timeout=1.0
);

sem mock_extract_candidate_proposals = "Return deterministic typed candidate proposals for tests.";
sem mock_extract_candidate_proposals.transcript_text = "Synthetic transcript text.";

def mock_translate_approved_brief(approved_english: str) -> LLMTranslatedBriefText by mock_translation_model(
    temperature=0.0, max_tokens=1200, max_output_retries=1, timeout=1.0
);

sem mock_translate_approved_brief = "Return a deterministic Spanish translation for tests.";
sem mock_translate_approved_brief.approved_english = "Approved English text.";

def mock_simplify_approved_brief(approved_english: str) -> LLMTranslatedBriefText by mock_simplification_model(
    temperature=0.0, max_tokens=1200, max_output_retries=1, timeout=1.0
);

sem mock_simplify_approved_brief = "Return deterministic plain-language approved text for tests.";
sem mock_simplify_approved_brief.approved_english = "Approved English text.";

def mock_match_question(question: str, verified_facts: str) -> LLMQuestionMatch by mock_question_model(
    temperature=0.0, max_tokens=300, max_output_retries=1, timeout=1.0
);

sem mock_match_question = "Return deterministic verified fact ids for tests.";
sem mock_match_question.question = "Synthetic patient question.";
sem mock_match_question.verified_facts = "Approved fact allow-list.";

def malformed_mock_extraction(transcript_text: str) -> list[LLMExtractedCandidate] by malformed_extraction_model(
    temperature=0.0, max_tokens=1200, max_output_retries=1, timeout=1.0
);

sem malformed_mock_extraction = "Return malformed output for a fallback test.";
sem malformed_mock_extraction.transcript_text = "Synthetic transcript text.";

def ai_status(
    requested: bool,
    used: bool,
    fallback_used: bool,
    mode: str,
    diagnostic_code: str = "",
    diagnostic_message: str = ""
) -> AIStatusDTO {
    return AIStatusDTO(
        requested=requested,
        used=used,
        fallback_used=fallback_used,
        mode=mode,
        diagnostic_code=diagnostic_code,
        diagnostic_message=diagnostic_message
    );
}

def prepared_extracted_candidates -> list[ExtractedCandidate] {
    output: list[ExtractedCandidate] = [];
    chunks = prepared_transcript();
    for seed in prepared_candidates() {
        sources = [
            chunk
            for chunk in chunks
            if chunk.id == seed.source_chunk_id
        ];
        source_text: str = sources[0].text if sources else "";
        output.append(
            ExtractedCandidate(
                category=seed.category,
                value=seed.value,
                source_text=source_text,
                source_chunk_id=seed.source_chunk_id,
                confidence=seed.confidence,
                patient_visible_candidate=seed.category != "language_preference"
            )
        );
    }
    return output;
}

def contains_blocked_medical_behavior(candidate: ExtractedCandidate) -> bool {
    normalized: str = f"{candidate.category} {candidate.value}".lower();
    return any(phrase in normalized for phrase in BLOCKED_MEDICAL_PHRASES);
}

def contains_instruction_injection(candidate: ExtractedCandidate) -> bool {
    normalized: str = candidate.source_text.lower();
    return any(phrase in normalized for phrase in BLOCKED_INJECTION_PHRASES);
}

def contains_fabricated_time(candidate: ExtractedCandidate) -> bool {
    value: str = candidate.value.lower();
    evidence: str = candidate.source_text.lower();
    for token in PROTECTED_TIME_TOKENS {
        if token in value and token not in evidence {
            return True;
        }
    }
    value_digits: list[str] = digit_tokens(value);
    evidence_digits: list[str] = digit_tokens(evidence);
    return any(token not in evidence_digits for token in value_digits);
}

def validate_extracted_candidates(
    candidates: list[ExtractedCandidate], transcript: list[TranscriptChunkDTO]
) -> CandidateValidationResult {
    if not candidates {
        return CandidateValidationResult(
            error_code="AI_EMPTY_OUTPUT",
            message="The model returned no candidate proposals."
        );
    }

    seen: list[str] = [];
    validated: list[ExtractedCandidate] = [];
    for candidate in candidates {
        if not isinstance(candidate, ExtractedCandidate) {
            return CandidateValidationResult(
                error_code="AI_MALFORMED_OUTPUT",
                message="The model returned a value outside the typed candidate schema."
            );
        }
        if (
            not candidate.category.strip()
            or not candidate.value.strip()
            or not candidate.source_text.strip()
            or not candidate.source_chunk_id.strip()
        ) {
            return CandidateValidationResult(
                error_code="AI_MALFORMED_OUTPUT",
                message="A candidate is missing a required field."
            );
        }
        if candidate.category not in ALLOWED_CATEGORIES {
            return CandidateValidationResult(
                error_code="AI_UNSUPPORTED_CATEGORY",
                message="A candidate used a category outside the allow-list."
            );
        }
        if candidate.confidence < 0.0 or candidate.confidence > 1.0 {
            return CandidateValidationResult(
                error_code="AI_INVALID_CONFIDENCE",
                message="A candidate confidence is outside 0.0 through 1.0."
            );
        }

        sources: list[TranscriptChunkDTO] = [
            chunk
            for chunk in transcript
            if chunk.id == candidate.source_chunk_id
        ];
        source: TranscriptChunkDTO | None = sources[0] if sources else None;
        if source is None {
            return CandidateValidationResult(
                error_code="AI_SOURCE_CHUNK_NOT_FOUND",
                message="A candidate referenced a transcript chunk that does not exist."
            );
        }
        if candidate.source_text not in (source as TranscriptChunkDTO).text {
            return CandidateValidationResult(
                error_code="AI_SOURCE_EVIDENCE_MISSING",
                message="A candidate source_text is not present in its source chunk."
            );
        }
        if contains_blocked_medical_behavior(candidate) {
            return CandidateValidationResult(
                error_code="AI_PROHIBITED_MEDICAL_CONTENT",
                message="A candidate attempted prohibited medical behavior."
            );
        }
        if contains_instruction_injection(candidate) {
            return CandidateValidationResult(
                error_code="AI_INSTRUCTION_INJECTION",
                message="Transcript instructions directed at the model were treated as untrusted data."
            );
        }
        if contains_fabricated_time(candidate) {
            return CandidateValidationResult(
                error_code="AI_FABRICATED_DETAIL",
                message="A candidate added a date or time detail absent from its evidence."
            );
        }

        duplicate_key: str = (
            f"{candidate.category}|{candidate.value.lower().strip()}|"
            f"{candidate.source_chunk_id}"
        );
        if duplicate_key in seen {
            return CandidateValidationResult(
                error_code="AI_DUPLICATE_CANDIDATE",
                message="The model returned a duplicate candidate proposal."
            );
        }
        seen.append(duplicate_key);
        validated.append(
            ExtractedCandidate(
                category=candidate.category,
                value=candidate.value.strip(),
                source_text=candidate.source_text,
                source_chunk_id=candidate.source_chunk_id,
                confidence=candidate.confidence,
                patient_visible_candidate=candidate.patient_visible_candidate
            )
        );
    }
    return CandidateValidationResult(success=True, candidates=validated);
}

def configured_model_name -> str {
    model: str | None = os.getenv("BYLLM_DEFAULT_MODEL");
    if model is None or not model.strip() {
        model = os.getenv("PA_CO_AI_MODEL");
    }
    return model.strip() if model is not None and model.strip() else "gpt-4o-mini";
}

def environment_has_value(name: str) -> bool {
    value: str | None = os.getenv(name);
    return value is not None and bool(value.strip());
}

def live_credentials_available -> bool {
    model_name: str = configured_model_name().lower();
    if model_name.startswith("ollama/") or model_name.startswith("local:") {
        return True;
    }
    if "claude" in model_name or "anthropic" in model_name {
        return (
            environment_has_value("ANTHROPIC_API_KEY")
            or environment_has_value("PA_CO_AI_API_KEY")
        );
    }
    if "gemini" in model_name {
        return (
            environment_has_value("GOOGLE_API_KEY")
            or environment_has_value("PA_CO_AI_API_KEY")
        );
    }
    return (
        environment_has_value("OPENAI_API_KEY")
        or environment_has_value("PA_CO_AI_API_KEY")
    );
}

def fallback_extraction(
    mode: str, diagnostic_code: str, diagnostic_message: str
) -> CandidateExtractionAttempt {
    return CandidateExtractionAttempt(
        candidates=prepared_extracted_candidates(),
        ai_status=ai_status(
            requested=True,
            used=False,
            fallback_used=True,
            mode=mode,
            diagnostic_code=diagnostic_code,
            diagnostic_message=diagnostic_message
        )
    );
}

def transcript_prompt(transcript: list[TranscriptChunkDTO]) -> str {
    return "\n".join(
        [f"{chunk.id} | {chunk.speaker} | {chunk.text}" for chunk in transcript]
    );
}

def public_candidates_from_llm(
    raw_output: list[LLMExtractedCandidate]
) -> list[ExtractedCandidate] | None {
    if not isinstance(raw_output, list) {
        return None;
    }
    output: list[ExtractedCandidate] = [];
    for item in raw_output {
        if not isinstance(item, LLMExtractedCandidate) {
            return None;
        }
        output.append(
            ExtractedCandidate(
                category=item.category,
                value=item.value,
                source_text=item.source_text,
                source_chunk_id=item.source_chunk_id,
                confidence=item.confidence,
                patient_visible_candidate=item.patient_visible_candidate
            )
        );
    }
    return output;
}

def run_candidate_extraction(
    transcript: list[TranscriptChunkDTO], mode: str
) -> CandidateExtractionAttempt {
    normalized: str = mode.lower().strip();
    if normalized == "disabled" {
        return CandidateExtractionAttempt(
            candidates=prepared_extracted_candidates(),
            ai_status=ai_status(False, False, False, "disabled")
        );
    }
    if normalized == "live" and not live_credentials_available() {
        return fallback_extraction(
            normalized,
            "AI_CREDENTIALS_MISSING",
            "Live model credentials are unavailable; deterministic candidates were used."
        );
    }
    if normalized == "test-no-key" {
        return fallback_extraction(
            normalized,
            "AI_CREDENTIALS_MISSING",
            "Live model credentials are unavailable; deterministic candidates were used."
        );
    }

    raw_proposals: list[LLMExtractedCandidate] = [];
    prompt_text: str = transcript_prompt(transcript);
    try {
        if normalized == "mock" {
            raw_proposals = mock_extract_candidate_proposals(prompt_text);
        } elif normalized == "live" {
            raw_proposals = extract_candidate_proposals(prompt_text);
        } elif normalized in ["mock_malformed", "test-malformed"] {
            raw_proposals = malformed_mock_extraction(prompt_text);
        } elif normalized == "test-api-error" {
            raise RuntimeError("simulated provider exception");
        } elif normalized == "test-timeout" {
            raise TimeoutError("simulated provider timeout");
        } elif normalized == "test-empty" {
            raw_proposals = [];
        } else {
            return fallback_extraction(
                normalized,
                "AI_MODE_INVALID",
                "The requested AI mode is unsupported; deterministic candidates were used."
            );
        }
    } except OutputConversionError {
        return fallback_extraction(
            normalized,
            "AI_MALFORMED_OUTPUT",
            "The model returned malformed structured output; deterministic candidates were used."
        );
    } except TimeoutError {
        return fallback_extraction(
            normalized,
            "AI_TIMEOUT",
            "The model request timed out; deterministic candidates were used."
        );
    } except Exception {
        return fallback_extraction(
            normalized,
            "AI_PROVIDER_ERROR",
            "The model request failed; deterministic candidates were used."
        );
    }

    converted: list[ExtractedCandidate] | None = public_candidates_from_llm(
        raw_proposals
    );
    if converted is None {
        return fallback_extraction(
            normalized,
            "AI_MALFORMED_OUTPUT",
            "The model returned malformed structured output; deterministic candidates were used."
        );
    }
    proposals: list[ExtractedCandidate] = converted as list[ExtractedCandidate];
    validation: CandidateValidationResult = validate_extracted_candidates(
        proposals, transcript
    );
    if not validation.success {
        return fallback_extraction(
            normalized, validation.error_code, validation.message
        );
    }
    return CandidateExtractionAttempt(
        candidates=validation.candidates,
        ai_status=ai_status(True, True, False, normalized)
    );
}

def brief_text_from_plan(plan: PatientPlanDTO) -> TranslatedBriefText {
    return TranslatedBriefText(
        medication_texts=[item.text for item in plan.medications],
        lab_texts=[item.text for item in plan.labs],
        referral_texts=[item.text for item in plan.referrals],
        follow_up_texts=[item.text for item in plan.follow_ups],
        checklist=plan.checklist
    );
}

def brief_prompt(bundle: TranslatedBriefText) -> str {
    return (
        "MEDICATIONS:\n" + "\n".join(bundle.medication_texts) + "\nLABS:\n" + "\n".join(
            bundle.lab_texts
        ) + "\nREFERRALS:\n" + "\n".join(bundle.referral_texts) + "\nFOLLOW_UPS:\n" + "\n".join(
            bundle.follow_up_texts
        ) + "\nCHECKLIST:\n" + "\n".join(bundle.checklist)
    );
}

def public_brief_text(output: LLMTranslatedBriefText) -> TranslatedBriefText {
    return TranslatedBriefText(
        medication_texts=output.medication_texts,
        lab_texts=output.lab_texts,
        referral_texts=output.referral_texts,
        follow_up_texts=output.follow_up_texts,
        checklist=output.checklist
    );
}

def digit_tokens(text: str) -> list[str] {
    output: list[str] = [];
    token: str = "";
    for character in text {
        if character.isdigit() or (character == "-" and token) {
            token += character;
        } elif token {
            output.append(token.rstrip("-"));
            token = "";
        }
    }
    if token {
        output.append(token.rstrip("-"));
    }
    return [
        item
        for item in output
        if item
    ];
}

def flattened_text(bundle: TranslatedBriefText) -> str {
    return " ".join(
        bundle.medication_texts + bundle.lab_texts + bundle.referral_texts + bundle.follow_up_texts + bundle.checklist
    );
}

def validate_brief_enhancement(
    original: PatientPlanDTO, enhanced: TranslatedBriefText
) -> str {
    if (
        len(enhanced.medication_texts) != len(original.medications)
        or len(enhanced.lab_texts) != len(original.labs)
        or len(enhanced.referral_texts) != len(original.referrals)
        or len(enhanced.follow_up_texts) != len(original.follow_ups)
        or len(enhanced.checklist) != len(original.checklist)
    ) {
        return "AI_PLAN_STRUCTURE_CHANGED";
    }
    if any(not item.strip() for item in enhanced.checklist) {
        return "AI_PLAN_TEXT_MISSING";
    }

    enhanced_flat: str = flattened_text(enhanced);
    for source_id in original.source_fact_ids {
        if source_id not in enhanced_flat {
            return "AI_PLAN_SOURCE_CHANGED";
        }
    }
    original_digits: list[str] = digit_tokens(
        " ".join(
            [item.text for item in original.medications] + [
                item.text for item in original.labs
            ] + [item.text for item in original.referrals] + [
                item.text for item in original.follow_ups
            ] + original.checklist
        )
    );
    enhanced_digits: list[str] = digit_tokens(enhanced_flat);
    if sorted(original_digits) != sorted(enhanced_digits) {
        return "AI_PLAN_NUMBER_CHANGED";
    }
    normalized: str = enhanced_flat.lower();
    if any(phrase in normalized for phrase in BLOCKED_MEDICAL_PHRASES) {
        return "AI_PLAN_PROHIBITED_CONTENT";
    }
    return "";
}

def copy_plan_items(
    originals: list[PlanItemDTO], texts: list[str]
) -> list[PlanItemDTO] {
    output: list[PlanItemDTO] = [];
    for index in range(len(originals)) {
        original: PlanItemDTO = originals[index];
        output.append(
            PlanItemDTO(
                id=original.id,
                kind=original.kind,
                text=texts[index],
                owner=original.owner,
                due_date=original.due_date,
                status=original.status,
                source_fact_id=original.source_fact_id
            )
        );
    }
    return output;
}

def enhanced_plan(
    original: PatientPlanDTO,
    text: TranslatedBriefText,
    language: str,
    translation_fallback_used: bool = False,
    simplification_fallback_used: bool = False
) -> PatientPlanDTO {
    return PatientPlanDTO(
        patient_id=original.patient_id,
        language=language,
        medications=copy_plan_items(original.medications, text.medication_texts),
        labs=copy_plan_items(original.labs, text.lab_texts),
        referrals=copy_plan_items(original.referrals, text.referral_texts),
        follow_ups=copy_plan_items(original.follow_ups, text.follow_up_texts),
        checklist=text.checklist,
        source_fact_ids=original.source_fact_ids,
        generated_at=original.generated_at,
        ai_enhanced=True,
        translation_fallback_used=translation_fallback_used,
        simplification_fallback_used=simplification_fallback_used
    );
}

def english_fallback_plan(
    original: PatientPlanDTO, translation: bool
) -> PatientPlanDTO {
    return PatientPlanDTO(
        patient_id=original.patient_id,
        language="English",
        medications=original.medications,
        labs=original.labs,
        referrals=original.referrals,
        follow_ups=original.follow_ups,
        checklist=original.checklist,
        source_fact_ids=original.source_fact_ids,
        generated_at=original.generated_at,
        ai_enhanced=False,
        translation_fallback_used=translation,
        simplification_fallback_used=not translation
    );
}

def enhancement_fallback(
    original: PatientPlanDTO,
    mode: str,
    diagnostic_code: str,
    diagnostic_message: str,
    translation: bool
) -> BriefEnhancementAttempt {
    return BriefEnhancementAttempt(
        plan=english_fallback_plan(original, translation),
        ai_status=ai_status(
            True, False, True, mode, diagnostic_code, diagnostic_message
        )
    );
}

def run_brief_enhancement(
    original: PatientPlanDTO, mode: str, operation: str
) -> BriefEnhancementAttempt {
    normalized: str = mode.lower().strip();
    is_translation: bool = operation == "translate";
    if normalized == "disabled" {
        return BriefEnhancementAttempt(
            plan=original, ai_status=ai_status(False, False, False, "disabled")
        );
    }
    if normalized == "live" and not live_credentials_available() {
        return enhancement_fallback(
            original,
            normalized,
            "AI_CREDENTIALS_MISSING",
            "Live model credentials are unavailable; approved English was used.",
            is_translation
        );
    }
    if normalized == "test-no-key" {
        return enhancement_fallback(
            original,
            normalized,
            "AI_CREDENTIALS_MISSING",
            "Live model credentials are unavailable; approved English was used.",
            is_translation
        );
    }
    if normalized == "mock_malformed" {
        return enhancement_fallback(
            original,
            normalized,
            "AI_MALFORMED_OUTPUT",
            "The diagnostic mock returned malformed structured output; approved English was used.",
            is_translation
        );
    }

    llm_output: LLMTranslatedBriefText;
    try {
        source: TranslatedBriefText = brief_text_from_plan(original);
        source_text: str = brief_prompt(source);
        if normalized == "test-api-error" {
            raise RuntimeError("simulated provider exception");
        } elif normalized == "test-timeout" {
            raise TimeoutError("simulated provider timeout");
        } elif operation == "translate" {
            llm_output = (
                mock_translate_approved_brief(source_text)
                    if normalized == "mock"
                    else translate_approved_brief(source_text)
            );
        } else {
            llm_output = (
                mock_simplify_approved_brief(source_text)
                    if normalized == "mock"
                    else simplify_approved_brief(source_text)
            );
        }
    } except TimeoutError {
        return enhancement_fallback(
            original,
            normalized,
            "AI_TIMEOUT",
            "The model request timed out; approved English was used.",
            is_translation
        );
    } except Exception {
        return enhancement_fallback(
            original,
            normalized,
            "AI_PROVIDER_ERROR",
            "The model request failed; approved English was used.",
            is_translation
        );
    }

    output: TranslatedBriefText = public_brief_text(llm_output);
    validation_error: str = validate_brief_enhancement(original, output);
    if validation_error {
        return enhancement_fallback(
            original,
            normalized,
            validation_error,
            "The model changed protected plan structure; approved English was used.",
            is_translation
        );
    }
    return BriefEnhancementAttempt(
        plan=enhanced_plan(
            original, output, "Spanish" if is_translation else "English"
        ),
        ai_status=ai_status(True, True, False, normalized)
    );
}

def validate_question_match(
    selection: LLMQuestionMatch, verified_facts: list[VerifiedFactReference]
) -> str {
    allowed_ids: list[str] = [fact.id for fact in verified_facts];
    seen: list[str] = [];
    for fact_id in selection.verified_fact_ids {
        if fact_id not in allowed_ids {
            return "AI_MATCH_UNVERIFIED_ID";
        }
        if fact_id in seen {
            return "AI_MATCH_DUPLICATE_ID";
        }
        seen.append(fact_id);
    }
    return "";
}

def verified_facts_prompt(verified_facts: list[VerifiedFactReference]) -> str {
    return "\n".join(
        [f"{fact.id} | {fact.category} | {fact.value}" for fact in verified_facts]
    );
}

def question_match_fallback(
    mode: str, diagnostic_code: str, diagnostic_message: str
) -> QuestionMatchAttempt {
    return QuestionMatchAttempt(
        matched_fact_ids=[],
        ai_status=ai_status(
            True, False, True, mode, diagnostic_code, diagnostic_message
        )
    );
}

def run_question_match(
    question: str, verified_facts: list[VerifiedFactReference], mode: str
) -> QuestionMatchAttempt {
    normalized: str = mode.lower().strip();
    if normalized == "disabled" {
        return QuestionMatchAttempt(
            ai_status=ai_status(False, False, False, "disabled")
        );
    }
    if normalized == "live" and not live_credentials_available() {
        return question_match_fallback(
            normalized,
            "AI_CREDENTIALS_MISSING",
            "Live model credentials are unavailable; deterministic matching was used."
        );
    }
    if normalized == "test-no-key" {
        return question_match_fallback(
            normalized,
            "AI_CREDENTIALS_MISSING",
            "Live model credentials are unavailable; deterministic matching was used."
        );
    }
    if normalized == "mock_malformed" {
        return question_match_fallback(
            normalized,
            "AI_MALFORMED_OUTPUT",
            "The diagnostic mock returned malformed matching output; deterministic matching was used."
        );
    }
    if normalized == "test-api-error" {
        return question_match_fallback(
            normalized,
            "AI_PROVIDER_ERROR",
            "The model request failed; deterministic matching was used."
        );
    }
    if normalized == "test-timeout" {
        return question_match_fallback(
            normalized,
            "AI_TIMEOUT",
            "The model request timed out; deterministic matching was used."
        );
    }

    selection: LLMQuestionMatch;
    facts_text: str = verified_facts_prompt(verified_facts);
    try {
        selection = (
            mock_match_question(question, facts_text)
                if normalized == "mock"
                else match_question_to_verified_facts(question, facts_text)
        );
    } except TimeoutError {
        return question_match_fallback(
            normalized,
            "AI_TIMEOUT",
            "The model request timed out; deterministic matching was used."
        );
    } except Exception {
        return question_match_fallback(
            normalized,
            "AI_PROVIDER_ERROR",
            "The model request failed; deterministic matching was used."
        );
    }

    validation_error: str = validate_question_match(selection, verified_facts);
    if validation_error {
        return question_match_fallback(
            normalized,
            validation_error,
            "The model returned an id outside the approved fact allow-list."
        );
    }
    return QuestionMatchAttempt(
        matched_fact_ids=selection.verified_fact_ids,
        ai_status=ai_status(True, True, False, normalized)
    );
}
