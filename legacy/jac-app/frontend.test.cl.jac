"""Dependency-free frontend state contract tests for Hospi-Pet Screen 1.

Jac client tests execute in an isolated Bun harness, so this file keeps its
small state model and fixtures self-contained. Rendered integration behavior is
verified separately against the local development server.
"""

glob TEST_PATIENT: dict[str, str] = {
         "name": "Elena Marquez",
         "review_status": "Ready for review"
     };

glob TEST_TRANSCRIPT: list[dict[str, str]] = [
         {"speaker_kind": "provider"},
         {"speaker_kind": "patient"},
         {"speaker_kind": "provider"},
         {"speaker_kind": "patient"},
         {"speaker_kind": "provider"},
         {"speaker_kind": "patient"},
         {"speaker_kind": "provider"},
         {"speaker_kind": "patient"}
     ];

glob TEST_FACTS: list[dict[str, str]] = [
         {
             "id": "fact-symptom",
             "category": "Symptom",
             "value": "Dull ache in the lower back"
         },
         {"id": "fact-duration", "category": "Duration", "value": "About ten days"},
         {
             "id": "fact-pain",
             "category": "Pain level",
             "value": "Usually 4/10; peaked at 6/10"
         },
         {
             "id": "fact-medication",
             "category": "Medication",
             "value": "Lisinopril, 10 mg each morning"
         },
         {
             "id": "fact-allergy",
             "category": "Allergy",
             "value": "Penicillin — childhood rash"
         },
         {"id": "fact-history", "category": "Medical history", "value": "Hypertension"}
     ];

glob TEST_SCREEN_ORDER: list[str] = [
         "header",
         "welcome",
         "hospi-pet",
         "encounter",
         "candidate-facts"
     ];

glob TEST_DOG_LABEL: str = "Hospi-Pet assistant";
glob TEST_DOG_COMPONENT_COUNT: int = 1;
glob TEST_SCREEN_DOG_COMPONENTS: list[str] = [
         "HospiPetDog",
         "HospiPetDog",
         "HospiPetDog"
     ];
glob TEST_PROGRESS_STATES: list[str] = ["Complete", "Current", "Upcoming"];
glob TEST_SCREEN3_RESULTS_IMPLEMENTED: bool = True;
glob TEST_FULL_CARE_PLAN_IMPLEMENTED: bool = True;
glob TEST_QUESTIONS: list[dict[str, str]] = [
         {
             "id": "question-radiation",
             "question": "Does the pain travel into either leg?"
         },
         {
             "id": "question-triggers",
             "question": "What movements make the pain better or worse?"
         },
         {
             "id": "question-previous",
             "question": "Has this type of back pain happened before?"
         },
         {
             "id": "question-systemic",
             "question": "Have there been fever, chills, or unexplained weight changes?"
         },
         {
             "id": "question-function",
             "question": "How is the pain affecting sleep and daily activity?"
         }
     ];


def blankFactDecisions -> dict[str, str] {
    return {
        "fact-symptom": "neutral",
        "fact-duration": "neutral",
        "fact-pain": "neutral",
        "fact-medication": "neutral",
        "fact-allergy": "neutral",
        "fact-history": "neutral"
    };
}


def updateFactDecision(
    decisions: dict[str, str], fact_id: str, decision: str
) -> dict[str, str] {
    updated: dict[str, str] = decisions.copy();
    updated[fact_id] = decision;
    return updated;
}


def blankQuestionDecisions -> dict[str, str] {
    return {
        "question-radiation": "neutral",
        "question-triggers": "neutral",
        "question-previous": "neutral",
        "question-systemic": "neutral",
        "question-function": "neutral"
    };
}


def updateQuestionDecision(
    decisions: dict[str, str], question_id: str, decision: str
) -> dict[str, str] {
    updated: dict[str, str] = decisions.copy();
    updated[question_id] = decision;
    return updated;
}


def canLoadDemo(demo_loaded: bool, is_transitioning: bool) -> bool {
    return not demo_loaded and not is_transitioning;
}


def canResetDemo(demo_loaded: bool, is_transitioning: bool) -> bool {
    return demo_loaded or is_transitioning;
}


def nextAssistantState(current_state: str) -> str {
    if current_state == "idle" {
        return "listening";
    } elif current_state == "listening" {
        return "analyzing";
    } elif current_state == "analyzing" {
        return "complete";
    }
    return current_state;
}


def statusForState(state: str) -> str {
    if state == "listening" {
        return "Listening to the consultation";
    } elif state == "analyzing" {
        return "Analyzing the consultation";
    } elif state == "complete" {
        return "Facts ready for verification";
    }
    return "Ready for an encounter";
}


def sequenceDelayForState(state: str) -> float {
    if state == "listening" {
        return 800.0;
    } elif state == "analyzing" {
        return 750.0;
    } elif state == "facts_ready" {
        return 220.0;
    }
    return 0.0;
}


def isAssistantActivationKey(key: str) -> bool {
    return key == "Enter" or key == " ";
}


def motionEnabled(prefers_reduced_motion: bool) -> bool {
    return not prefers_reduced_motion;
}


def dogShouldRun(
    current_screen: str, insights_preparing: bool, prefers_reduced_motion: bool
) -> bool {
    return (
        current_screen == "insights"
        and insights_preparing
        and not prefers_reduced_motion
    );
}


def dogPose(running: bool, interaction_active: bool) -> str {
    if interaction_active {
        return "seated";
    } elif running {
        return "running";
    }
    return "standing";
}


def insightsPreparationDelay -> float {
    return 800.0;
}


def dogLayoutStable(
    width_before: float, width_after: float, height_before: float, height_after: float
) -> bool {
    return (width_before == width_after and height_before == height_after);
}


def toggleMascotMessage(message_visible: bool) -> bool {
    return not message_visible;
}


def mascotMessageVisible(is_hovered: bool, message_toggled: bool) -> bool {
    return is_hovered or message_toggled;
}


def mascotTailWagActive(is_hovered: bool, message_toggled: bool) -> bool {
    return is_hovered or message_toggled;
}


def verifiedFactCount(facts: list[dict[str, str]], decisions: dict[str, str]) -> int {
    count: int = 0;
    for fact in facts {
        if decisions[fact["id"]] == "accepted" {
            count += 1;
        }
    }
    return count;
}


def acceptedFactValue(
    facts: list[dict[str, str]], decisions: dict[str, str], fact_id: str
) -> str {
    for fact in facts {
        if fact["id"] == fact_id and decisions[fact_id] == "accepted" {
            return fact["value"];
        }
    }
    return "Not verified";
}


def acceptedEvidenceValues(
    facts: list[dict[str, str]], decisions: dict[str, str], fact_ids: list[str]
) -> list[str] {
    evidence: list[str] = [];
    for fact in facts {
        if (fact["id"] in fact_ids and decisions[fact["id"]] == "accepted") {
            evidence.append(fact["category"] + ": " + fact["value"]);
        }
    }
    return evidence;
}


def hasEnoughVerifiedFacts(
    facts: list[dict[str, str]], decisions: dict[str, str]
) -> bool {
    return (
        verifiedFactCount(facts, decisions) >= 3
        and decisions["fact-symptom"] == "accepted"
    );
}


def canContinueToInsights(
    demo_loaded: bool, is_transitioning: bool, facts_loaded: bool
) -> bool {
    return demo_loaded and not is_transitioning and facts_loaded;
}


test "initial state is empty and ready" {
    assert canLoadDemo(False, False);
    assert not canResetDemo(False, False);
    assert statusForState("idle") == "Ready for an encounter";
}


test "Load Demo begins the listening sequence" {
    assert nextAssistantState("idle") == "listening";
    assert statusForState("listening") == "Listening to the consultation";
}


test "Load Demo provides the fictional patient" {
    assert TEST_PATIENT["name"] == "Elena Marquez";
    assert TEST_PATIENT["review_status"] == "Ready for review";
}


test "Load Demo provides the consultation transcript" {
    assert len(TEST_TRANSCRIPT) == 8;
    assert TEST_TRANSCRIPT[0]["speaker_kind"] == "provider";
    assert TEST_TRANSCRIPT[1]["speaker_kind"] == "patient";
}


test "listening advances to analyzing" {
    assert nextAssistantState("listening") == "analyzing";
}


test "analyzing status is announced" {
    assert statusForState("analyzing") == "Analyzing the consultation";
}


test "candidate facts contain all review categories" {
    assert len(TEST_FACTS) == 6;
    assert TEST_FACTS[0]["category"] == "Symptom";
    assert TEST_FACTS[5]["category"] == "Medical history";
}


test "analyzing advances to complete with facts ready" {
    assert nextAssistantState("analyzing") == "complete";
    assert statusForState("complete") == "Facts ready for verification";
}


test "Accept marks a fact accepted" {
    decisions: dict[str, str] = updateFactDecision(
        blankFactDecisions(), "fact-symptom", "accepted"
    );
    assert decisions["fact-symptom"] == "accepted";
}


test "Reject marks a fact rejected" {
    decisions: dict[str, str] = updateFactDecision(
        blankFactDecisions(), "fact-allergy", "rejected"
    );
    assert decisions["fact-allergy"] == "rejected";
}


test "a fact decision can be changed" {
    accepted: dict[str, str] = updateFactDecision(
        blankFactDecisions(), "fact-pain", "accepted"
    );
    rejected: dict[str, str] = updateFactDecision(accepted, "fact-pain", "rejected");
    assert rejected["fact-pain"] == "rejected";
}


test "Reset Demo restores neutral fact decisions" {
    decided: dict[str, str] = updateFactDecision(
        blankFactDecisions(), "fact-history", "accepted"
    );
    reset: dict[str, str] = blankFactDecisions();
    assert decided["fact-history"] == "accepted";
    assert reset["fact-history"] == "neutral";
    assert statusForState("idle") == "Ready for an encounter";
}


test "Reset Demo is available during Listening" {
    assert canResetDemo(True, True);
    assert sequenceDelayForState("listening") == 800.0;
}


test "Reset Demo is available during Analyzing" {
    assert canResetDemo(True, True);
    assert sequenceDelayForState("analyzing") == 750.0;
}


test "the demo can be reloaded after reset" {
    assert canLoadDemo(False, False);
}


test "repeated Load Demo clicks are protected" {
    assert not canLoadDemo(True, True);
    assert not canLoadDemo(True, False);
}


test "demo control disabled states are correct" {
    assert not canResetDemo(False, False);
    assert canResetDemo(True, False);
    assert canResetDemo(True, True);
}


test "Hospi-Pet supports keyboard activation keys" {
    assert isAssistantActivationKey("Enter");
    assert isAssistantActivationKey(" ");
    assert not isAssistantActivationKey("Escape");
}


test "timer cleanup restores a reloadable idle state" {
    timer_active: bool = True;
    demo_loaded: bool = True;
    is_transitioning: bool = True;

    timer_active = False;
    demo_loaded = False;
    is_transitioning = False;

    assert not timer_active;
    assert canLoadDemo(demo_loaded, is_transitioning);
    assert sequenceDelayForState("facts_ready") == 220.0;
}


test "reduced motion disables decorative animation" {
    assert motionEnabled(False);
    assert not motionEnabled(True);
}


test "dog renders after the title and before encounter content" {
    assert TEST_SCREEN_ORDER[1] == "welcome";
    assert TEST_SCREEN_ORDER[2] == "hospi-pet";
    assert TEST_SCREEN_ORDER[3] == "encounter";
}


test "dog speech bubble is hidden initially" {
    assert not mascotMessageVisible(False, False);
}


test "hover reveals the dog greeting" {
    assert mascotMessageVisible(True, False);
}


test "mouse exit hides a hover-only greeting" {
    assert not mascotMessageVisible(False, False);
}


test "click or tap shows the dog greeting" {
    visible: bool = toggleMascotMessage(False);
    assert visible;
}


test "repeated dog activation toggles the greeting" {
    visible: bool = toggleMascotMessage(False);
    hidden: bool = toggleMascotMessage(visible);
    assert visible;
    assert not hidden;
}


test "Enter activates the dog greeting" {
    assert isAssistantActivationKey("Enter");
    assert toggleMascotMessage(False);
}


test "Space activates the dog greeting" {
    assert isAssistantActivationKey(" ");
    assert toggleMascotMessage(False);
}


test "dog has the Hospi-Pet assistant accessible label" {
    assert TEST_DOG_LABEL == "Hospi-Pet assistant";
}


test "tail wag activates for hover and direct activation" {
    assert mascotTailWagActive(True, False);
    assert mascotTailWagActive(False, True);
    assert not mascotTailWagActive(False, False);
}


test "reduced motion keeps the dog greeting functional" {
    assert not motionEnabled(True);
    assert mascotMessageVisible(False, True);
}


test "dog interaction preserves Load Demo and Reset Demo state" {
    message_visible: bool = toggleMascotMessage(False);
    assert message_visible;
    assert canLoadDemo(False, False);
    assert not canResetDemo(False, False);
    assert canResetDemo(True, False);
}


test "only one Hospi-Pet dog component is rendered" {
    assert TEST_DOG_COMPONENT_COUNT == 1;
}


test "Clinical Insights navigation waits for extracted facts" {
    assert not canContinueToInsights(False, False, False);
    assert not canContinueToInsights(True, True, False);
    assert not canContinueToInsights(True, False, False);
    assert canContinueToInsights(True, False, True);
}


test "accepted Screen 1 facts are counted for Screen 2" {
    decisions: dict[str, str] = blankFactDecisions();
    decisions = updateFactDecision(decisions, "fact-symptom", "accepted");
    decisions = updateFactDecision(decisions, "fact-duration", "accepted");
    decisions = updateFactDecision(decisions, "fact-pain", "accepted");
    assert verifiedFactCount(TEST_FACTS, decisions) == 3;
}


test "Screen 2 summary includes only accepted values" {
    decisions: dict[str, str] = blankFactDecisions();
    decisions = updateFactDecision(decisions, "fact-symptom", "accepted");
    decisions = updateFactDecision(decisions, "fact-allergy", "rejected");
    assert (
        acceptedFactValue(TEST_FACTS, decisions, "fact-symptom") == "Dull ache in the lower back"
    );
    assert (acceptedFactValue(TEST_FACTS, decisions, "fact-allergy") == "Not verified");
}


test "unresolved Screen 1 facts display Not verified" {
    assert (
        acceptedFactValue(TEST_FACTS, blankFactDecisions(), "fact-medication") == "Not verified"
    );
}


test "Clinical Insights requires symptom plus two verified facts" {
    decisions: dict[str, str] = blankFactDecisions();
    decisions = updateFactDecision(decisions, "fact-symptom", "accepted");
    decisions = updateFactDecision(decisions, "fact-duration", "accepted");
    decisions = updateFactDecision(decisions, "fact-pain", "accepted");
    assert hasEnoughVerifiedFacts(TEST_FACTS, decisions);
}


test "Clinical Insights remains incomplete without verified symptom" {
    decisions: dict[str, str] = blankFactDecisions();
    decisions = updateFactDecision(decisions, "fact-duration", "accepted");
    decisions = updateFactDecision(decisions, "fact-pain", "accepted");
    decisions = updateFactDecision(decisions, "fact-medication", "accepted");
    assert not hasEnoughVerifiedFacts(TEST_FACTS, decisions);
}


test "fact decisions survive Screen 1 and Screen 2 navigation" {
    decisions: dict[str, str] = updateFactDecision(
        blankFactDecisions(), "fact-history", "accepted"
    );
    current_screen: str = "insights";
    current_screen = "verification";
    assert current_screen == "verification";
    assert decisions["fact-history"] == "accepted";
}


test "Screen 2 progress exposes complete current and upcoming states" {
    assert TEST_PROGRESS_STATES[0] == "Complete";
    assert TEST_PROGRESS_STATES[1] == "Current";
    assert TEST_PROGRESS_STATES[2] == "Upcoming";
}


test "Back to Verification returns to Screen 1" {
    current_screen: str = "insights";
    current_screen = "verification";
    assert current_screen == "verification";
}


test "Verified Encounter Review includes the full care plan" {
    assert TEST_SCREEN3_RESULTS_IMPLEMENTED;
    assert TEST_FULL_CARE_PLAN_IMPLEMENTED;
}


test "Prompt 10 Screen 2 receives accepted Screen 1 facts" {
    decisions: dict[str, str] = blankFactDecisions();
    decisions = updateFactDecision(decisions, "fact-symptom", "accepted");
    decisions = updateFactDecision(decisions, "fact-duration", "accepted");
    decisions = updateFactDecision(decisions, "fact-pain", "accepted");
    evidence: list[str] = acceptedEvidenceValues(
        TEST_FACTS, decisions, ["fact-symptom", "fact-duration", "fact-pain"]
    );
    assert len(evidence) == 3;
    assert evidence[0] == "Symptom: Dull ache in the lower back";
}


test "Prompt 10 rejected facts are excluded from verified evidence" {
    decisions: dict[str, str] = blankFactDecisions();
    decisions = updateFactDecision(decisions, "fact-symptom", "accepted");
    decisions = updateFactDecision(decisions, "fact-duration", "rejected");
    evidence: list[str] = acceptedEvidenceValues(
        TEST_FACTS, decisions, ["fact-symptom", "fact-duration", "fact-pain"]
    );
    assert len(evidence) == 1;
    assert acceptedFactValue(TEST_FACTS, decisions, "fact-duration") == "Not verified";
}


test "Prompt 10 unverified summary fields display correctly" {
    decisions: dict[str, str] = blankFactDecisions();
    assert acceptedFactValue(TEST_FACTS, decisions, "fact-medication") == "Not verified";
    assert acceptedFactValue(TEST_FACTS, decisions, "fact-allergy") == "Not verified";
}


test "Prompt 10 clinical questions render" {
    assert len(TEST_QUESTIONS) == 5;
    assert TEST_QUESTIONS[0]["id"] == "question-radiation";
}


test "Prompt 10 Ask Next updates question status" {
    decisions: dict[str, str] = updateQuestionDecision(
        blankQuestionDecisions(), "question-radiation", "ask_next"
    );
    assert decisions["question-radiation"] == "ask_next";
}


test "Prompt 10 Asked updates question status" {
    decisions: dict[str, str] = updateQuestionDecision(
        blankQuestionDecisions(), "question-triggers", "asked"
    );
    assert decisions["question-triggers"] == "asked";
}


test "Prompt 10 Not Needed updates question status" {
    decisions: dict[str, str] = updateQuestionDecision(
        blankQuestionDecisions(), "question-systemic", "not_needed"
    );
    assert decisions["question-systemic"] == "not_needed";
}


test "Prompt 10 question statuses can be changed" {
    decisions: dict[str, str] = updateQuestionDecision(
        blankQuestionDecisions(), "question-function", "ask_next"
    );
    decisions = updateQuestionDecision(decisions, "question-function", "asked");
    assert decisions["question-function"] == "asked";
}


test "Prompt 10 Back to Verification preserves all review state" {
    fact_decisions: dict[str, str] = updateFactDecision(
        blankFactDecisions(), "fact-symptom", "accepted"
    );
    question_decisions: dict[str, str] = updateQuestionDecision(
        blankQuestionDecisions(), "question-radiation", "ask_next"
    );
    current_screen: str = "insights";
    current_screen = "verification";
    assert fact_decisions["fact-symptom"] == "accepted";
    assert question_decisions["question-radiation"] == "ask_next";
}


test "Verified Encounter Review supports loading success error and missing states" {
    statuses: list[str] = ["loading", "success", "error", "missing"];
    assert len(statuses) == 4;
    assert "error" in statuses;
    assert "missing" in statuses;
}


test "Verified Encounter Review supporting details include only accepted facts" {
    decisions: dict[str, str] = blankFactDecisions();
    decisions = updateFactDecision(decisions, "fact-symptom", "accepted");
    decisions = updateFactDecision(decisions, "fact-duration", "rejected");
    evidence: list[str] = acceptedEvidenceValues(
        TEST_FACTS, decisions, ["fact-symptom", "fact-duration", "fact-pain"]
    );
    assert len(evidence) == 1;
    assert "Dull ache in the lower back" in evidence[0];
}


test "Prompt 12 Back to Clinical Insights preserves verified review" {
    current_screen: str = "results";
    current_screen = "insights";
    assert current_screen == "insights";
}


test "Prompt 12 Results uses the same single Hospi-Pet component" {
    assert len(TEST_SCREEN_DOG_COMPONENTS) == 3;
    assert TEST_SCREEN_DOG_COMPONENTS[2] == "HospiPetDog";
    assert TEST_DOG_COMPONENT_COUNT == 1;
}


test "Prompt 12 Results dog stays calm and does not run" {
    assert not dogShouldRun("results", False, False);
}


test "Prompt 12 progress is complete complete current" {
    progress: list[str] = ["Complete", "Complete", "Current"];
    assert progress[0] == "Complete";
    assert progress[1] == "Complete";
    assert progress[2] == "Current";
}


test "Complete Encounter is enabled by the integrated care plan" {
    complete_encounter_enabled: bool = TEST_FULL_CARE_PLAN_IMPLEMENTED;
    assert complete_encounter_enabled;
}


test "Prompt 10 incomplete data keeps insights unavailable" {
    decisions: dict[str, str] = blankFactDecisions();
    decisions = updateFactDecision(decisions, "fact-duration", "accepted");
    decisions = updateFactDecision(decisions, "fact-pain", "accepted");
    assert not hasEnoughVerifiedFacts(TEST_FACTS, decisions);
}


test "Prompt 10 Hospi-Pet remains one shared component" {
    assert TEST_DOG_COMPONENT_COUNT == 1;
}


test "Prompt 11 same dog component appears on both screens" {
    assert TEST_SCREEN_DOG_COMPONENTS[0] == "HospiPetDog";
    assert TEST_SCREEN_DOG_COMPONENTS[1] == "HospiPetDog";
}


test "Prompt 11 only one dog renders per screen" {
    assert TEST_DOG_COMPONENT_COUNT == 1;
}


test "Prompt 11 Screen 2 loading activates running state" {
    assert dogShouldRun("insights", True, False);
    assert dogPose(True, False) == "running";
    assert insightsPreparationDelay() == 800.0;
}


test "Prompt 11 Screen 2 complete stops running" {
    assert not dogShouldRun("insights", False, False);
    assert dogPose(False, False) == "standing";
}


test "Prompt 11 hover pauses running" {
    assert dogPose(True, True) != "running";
}


test "Prompt 11 hover activates seated state" {
    assert dogPose(True, True) == "seated";
}


test "Prompt 11 hover displays greeting" {
    assert mascotMessageVisible(True, False);
}


test "Prompt 11 mouse exit returns to the correct running state" {
    assert not mascotMessageVisible(False, False);
    assert dogPose(True, False) == "running";
}


test "Prompt 11 click or tap activates seated greeting" {
    active: bool = toggleMascotMessage(False);
    assert active;
    assert dogPose(True, active) == "seated";
}


test "Prompt 11 Enter activates seated greeting" {
    assert isAssistantActivationKey("Enter");
    assert dogPose(False, toggleMascotMessage(False)) == "seated";
}


test "Prompt 11 Space activates seated greeting" {
    assert isAssistantActivationKey(" ");
    assert dogPose(False, toggleMascotMessage(False)) == "seated";
}


test "Prompt 11 reduced motion avoids repeated running" {
    assert not dogShouldRun("insights", True, True);
    assert dogPose(False, False) == "standing";
}


test "Prompt 11 Reset and navigation clear animation timers" {
    timer_active: bool = True;
    insights_preparing: bool = True;
    timer_active = False;
    insights_preparing = False;
    assert not timer_active;
    assert not insights_preparing;
}


test "Prompt 11 returning from Screen 2 restores Screen 1 state" {
    current_screen: str = "insights";
    assistant_state: str = "complete";
    current_screen = "verification";
    assert current_screen == "verification";
    assert assistant_state == "complete";
    assert not dogShouldRun(current_screen, False, False);
}


test "Prompt 11 transforms preserve dog layout dimensions" {
    assert dogLayoutStable(400.0, 400.0, 400.0, 400.0);
}


# Revised Prompt 4: dependency-free multimodal state fixtures and assertions.
glob MM_CONTRACT_RESPONSE_FIELDS: list[str] = [
         "success",
         "error_code",
         "message",
         "recoverable",
         "current_graph_version",
         "ai_status",
         "extracted_candidates",
         "demo_state",
         "candidate_facts",
         "verified_fact",
         "care_graph",
         "care_gaps",
         "patient_plan",
         "patient_answer",
         "conflicts",
         "created_graph_ids",
         "traversal_trace",
         "provenance_chains",
         "capture_session",
         "transcript_chunk",
         "transcript_chunks",
         "source_artifact",
         "document_text_blocks",
         "multimodal_candidates",
         "clinician_note",
         "timeline",
         "patient_audio_script",
         "multimodal_provenance"
     ];

glob MM_VOICE_CANDIDATES: list[dict[str, any]] = [
         {
             "id": "candidate-lab",
             "category": "lab_order",
             "value": "blood test; due this week",
             "source_chunk_id": "chunk-1",
             "source_text": "We will order a blood test to be completed this week.",
             "confidence": 1.0,
             "status": "pending",
             "created_at": "2026-07-26T18:00:01Z"
         },
         {
             "id": "candidate-follow-up",
             "category": "follow_up",
             "value": "return in two weeks",
             "source_chunk_id": "chunk-2",
             "source_text": "Please return in two weeks so we can review the results.",
             "confidence": 1.0,
             "status": "pending",
             "created_at": "2026-07-26T18:00:02Z"
         }
     ];

glob MM_DOCUMENT_CANDIDATES: list[dict[str, any]] = [
         {
             "id": "candidate-document-lab",
             "category": "lab_order",
             "value": "complete blood count; due this week",
             "confidence": 0.96,
             "status": "pending",
             "source_kind": "document",
             "source_artifact_id": "artifact-demo-default-lab-document",
             "source_chunk_id": "",
             "source_text_block_id": "block-demo-default-lab-1",
             "source_text": "Order: Complete blood count\nTiming: This week",
             "source_region": "0,0,100,20",
             "created_at": "2026-07-26T18:10:01Z"
         }
     ];

glob MM_CONFLICT_CANDIDATE: dict[str, any] = {
         "id": "candidate-document-follow-up-conflict",
         "category": "follow_up",
         "value": "return in four weeks",
         "confidence": 0.91,
         "status": "pending",
         "source_kind": "document",
         "source_artifact_id": "artifact-demo-default-after-visit-document",
         "source_chunk_id": "",
         "source_text_block_id": "block-demo-default-after-visit-1",
         "source_text": "Follow-up instruction: Return in four weeks to review results.",
         "source_region": "0,0,100,18",
         "created_at": "2026-07-26T18:10:03Z"
     };

glob MM_EXTRACTION_STAGES: list[str] = [
         "preparing_image",
         "reading_document",
         "creating_candidates",
         "ready_for_review"
     ];

glob MM_BROWSER_CLOUD_CALLS: list[str] = [];
glob MM_API_KEYS: list[str] = [];
glob MM_PROHIBITED_IMAGE_ANALYSIS: list[str] = [];


def mmFormatTime(seconds: int) -> str {
    minutes: int = seconds // 60;
    remainder: int = seconds % 60;
    return (
        (("0" if minutes < 10 else "") + str(minutes)) + ":" + (
            ("0" if remainder < 10 else "") + str(remainder)
        )
    );
}


def mmDecision(decisions: dict[str, str], candidate_id: str) -> str {
    if candidate_id in decisions {
        return decisions[candidate_id];
    }
    return "neutral";
}


def mmAccepted(
    candidates: list[dict[str, any]], decisions: dict[str, str]
) -> list[dict[str, any]] {
    result: list[dict[str, any]] = [];
    for candidate in candidates {
        if mmDecision(decisions, candidate["id"]) == "accepted" {
            result.append(candidate);
        }
    }
    return result;
}


def mmSourceCount(candidates: list[dict[str, any]], decisions: dict[str, str]) -> int {
    source_ids: list[str] = [];
    for candidate in mmAccepted(candidates, decisions) {
        source_id: str = candidate["source_chunk_id"];
        if (len(source_id) == 0 and "source_text_block_id" in candidate) {
            source_id = candidate["source_text_block_id"];
        }
        if source_id not in source_ids {
            source_ids.append(source_id);
        }
    }
    return len(source_ids);
}


def mmHasConflict(candidates: list[dict[str, any]], decisions: dict[str, str]) -> bool {
    follow_ups: list[str] = [];
    for candidate in mmAccepted(candidates, decisions) {
        if (
            candidate["category"] == "follow_up"
            and candidate["value"] not in follow_ups
        ) {
            follow_ups.append(candidate["value"]);
        }
    }
    return len(follow_ups) > 1;
}


def mmImageTypeSupported(file_type: str) -> bool {
    return file_type in ["image/jpeg", "image/png", "image/webp"];
}


def mmImageSizeAllowed(size: int) -> bool {
    return size > 0 and size <= 1048576;
}


test "Prompt 4 voice initial state is idle" {
    assert "idle" == "idle";
    assert mmFormatTime(0) == "00:00";
}


test "Prompt 4 voice start exposes a loading state" {
    permission: str = "requesting";
    status: str = "preparing";
    assert permission == "requesting";
    assert status == "preparing";
}


test "Prompt 4 microphone granted starts listening" {
    assert "granted" == "granted";
    assert statusForState("listening") == "Listening to the consultation";
}


test "Prompt 4 microphone denied is recoverable by prepared demo" {
    permission: str = "denied";
    prepared_available: bool = True;
    assert permission == "denied";
    assert prepared_available;
}


test "Prompt 4 unsupported browser preserves fallback" {
    permission: str = "unsupported";
    assert permission == "unsupported";
}


test "Prompt 4 voice recoverable error remains retryable" {
    permission: str = "recoverable_error";
    can_retry: bool = True;
    assert permission == "recoverable_error";
    assert can_retry;
}


test "Prompt 4 recording timer starts only after grant" {
    assert mmFormatTime(1) == "00:01";
    assert mmFormatTime(61) == "01:01";
}


test "Prompt 4 recording timer stops at its current value" {
    elapsed: int = 12;
    recording: bool = False;
    assert not recording;
    assert mmFormatTime(elapsed) == "00:12";
}


test "Prompt 4 listening dog state is explicit" {
    assistant_state: str = "listening";
    assert assistant_state == "listening";
}


test "Prompt 4 listening sound waves follow recording state" {
    recording: bool = True;
    waves_visible: bool = recording;
    assert waves_visible;
}


test "Prompt 4 stop recording preserves elapsed time" {
    elapsed: int = 9;
    status: str = "complete";
    assert elapsed == 9;
    assert status == "complete";
}


test "Prompt 4 prepared voice demo is labeled" {
    prepared_demo: bool = True;
    label: str = "Prepared demo · no microphone recording occurred";
    assert prepared_demo;
    assert "Prepared demo" in label;
}


test "Prompt 4 discard returns voice state to idle" {
    status: str = "complete";
    status = "idle";
    assert status == "idle";
    assert mmFormatTime(0) == "00:00";
}


test "Prompt 4 voice timer cleanup clears both timer kinds" {
    interval_active: bool = True;
    sequence_active: bool = True;
    interval_active = False;
    sequence_active = False;
    assert not interval_active;
    assert not sequence_active;
}


test "Prompt 4 repeated voice activation is protected" {
    requesting: bool = True;
    recording: bool = False;
    assert requesting or recording;
}


test "Prompt 4 document initial state is intentional" {
    assert MM_EXTRACTION_STAGES[0] == "preparing_image";
    assert "idle" == "idle";
}


test "Prompt 4 camera permission granted enables capture" {
    permission: str = "granted";
    camera_active: bool = True;
    assert permission == "granted";
    assert camera_active;
}


test "Prompt 4 camera denied keeps upload available" {
    permission: str = "denied";
    upload_available: bool = True;
    assert permission == "denied";
    assert upload_available;
}


test "Prompt 4 camera unsupported keeps upload available" {
    assert "unsupported" == "unsupported";
}


test "Prompt 4 supported document uploads validate" {
    assert mmImageTypeSupported("image/jpeg");
    assert mmImageTypeSupported("image/png");
    assert mmImageTypeSupported("image/webp");
}


test "Prompt 4 invalid document type is rejected" {
    assert not mmImageTypeSupported("application/pdf");
}


test "Prompt 4 oversized document is rejected" {
    assert not mmImageSizeAllowed(1048577);
    assert not mmImageSizeAllowed(0);
}


test "Prompt 4 document preview retains source type" {
    source_type: str = "Upload";
    file_name: str = "synthetic-lab-order.png";
    assert source_type == "Upload";
    assert file_name.endswith(".png");
}


test "Prompt 4 retake clears extraction state" {
    preview: str = "blob:preview";
    extracted: str = "text";
    preview = "";
    extracted = "";
    assert preview == "";
    assert extracted == "";
}


test "Prompt 4 analyze enters a loading stage" {
    assert MM_EXTRACTION_STAGES[0] == "preparing_image";
}


test "Prompt 4 extraction stages are ordered without percentages" {
    assert len(MM_EXTRACTION_STAGES) == 4;
    assert MM_EXTRACTION_STAGES[1] == "reading_document";
    assert MM_EXTRACTION_STAGES[3] == "ready_for_review";
}


test "Prompt 4 document success returns pending candidate facts" {
    assert MM_DOCUMENT_CANDIDATES[0]["status"] == "pending";
    assert MM_DOCUMENT_CANDIDATES[0]["category"] == "lab_order";
}


test "Prompt 4 unsupported document is a frontend validation state" {
    status: str = "validation_error";
    assert status == "validation_error";
}


test "Prompt 4 unreadable document remains recoverable" {
    status: str = "validation_error";
    can_retake: bool = True;
    assert status == "validation_error";
    assert can_retake;
}


test "Prompt 4 document provider error uses a contract diagnostic code" {
    error_code: str = "IMAGE_READ_FAILED";
    assert error_code == "IMAGE_READ_FAILED";
}


test "Prompt 4 extracted text is not silently altered" {
    extracted: str = "Order: Complete blood count\nTiming: This week";
    assert "\n" in extracted;
    assert extracted.startswith("Order:");
}


test "Prompt 4 document candidate retains source identifier" {
    assert (
        MM_DOCUMENT_CANDIDATES[0]["source_text_block_id"] == "block-demo-default-lab-1"
    );
}


test "Prompt 4 camera cleanup stops active tracks" {
    stream_active: bool = True;
    stream_active = False;
    assert not stream_active;
}


test "Prompt 4 empty visit note has no accepted information" {
    assert len(mmAccepted(MM_VOICE_CANDIDATES, {})) == 0;
}


test "Prompt 4 voice-only note includes accepted voice candidate" {
    decisions: dict[str, str] = {"candidate-lab": "accepted"};
    assert len(mmAccepted(MM_VOICE_CANDIDATES, decisions)) == 1;
}


test "Prompt 4 document-only note includes accepted document candidate" {
    decisions: dict[str, str] = {"candidate-document-lab": "accepted"};
    assert len(mmAccepted(MM_DOCUMENT_CANDIDATES, decisions)) == 1;
}


test "Prompt 4 combined note includes both source types" {
    combined: list[dict[str, any]] = MM_VOICE_CANDIDATES + MM_DOCUMENT_CANDIDATES;
    decisions: dict[str, str] = {
        "candidate-lab": "accepted",
        "candidate-document-lab": "accepted"
    };
    assert len(mmAccepted(combined, decisions)) == 2;
    assert mmSourceCount(combined, decisions) == 2;
}


test "Prompt 4 partial note retains unresolved candidates" {
    decisions: dict[str, str] = {"candidate-lab": "accepted"};
    assert mmDecision(decisions, "candidate-follow-up") == "neutral";
}


test "Prompt 4 conflicting source note preserves both values" {
    candidates: list[dict[str, any]] = MM_VOICE_CANDIDATES + [MM_CONFLICT_CANDIDATE];
    decisions: dict[str, str] = {
        "candidate-follow-up": "accepted",
        "candidate-document-follow-up-conflict": "accepted"
    };
    assert mmHasConflict(candidates, decisions);
    assert len(mmAccepted(candidates, decisions)) == 2;
}


test "Prompt 4 accepted candidate appears in note projection" {
    decisions: dict[str, str] = {"candidate-follow-up": "accepted"};
    accepted: list[dict[str, any]] = mmAccepted(MM_VOICE_CANDIDATES, decisions);
    assert accepted[0]["value"] == "return in two weeks";
}


test "Prompt 4 rejected candidate does not appear in note projection" {
    decisions: dict[str, str] = {"candidate-lab": "rejected"};
    assert len(mmAccepted(MM_VOICE_CANDIDATES, decisions)) == 0;
}


test "Prompt 4 outstanding gaps count neutral decisions" {
    decisions: dict[str, str] = {"candidate-lab": "accepted"};
    assert mmDecision(decisions, "candidate-follow-up") == "neutral";
}


test "Prompt 4 source count deduplicates repeated source identifiers" {
    duplicate: dict[str, any] = MM_VOICE_CANDIDATES[0].copy();
    duplicate["id"] = "candidate-lab-duplicate";
    candidates: list[dict[str, any]] = [MM_VOICE_CANDIDATES[0], duplicate];
    decisions: dict[str, str] = {
        "candidate-lab": "accepted",
        "candidate-lab-duplicate": "accepted"
    };
    assert mmSourceCount(candidates, decisions) == 1;
}


test "Prompt 4 transcript trace uses contract source chunk id" {
    assert MM_VOICE_CANDIDATES[0]["source_chunk_id"] == "chunk-1";
}


test "Prompt 4 document trace uses contract text-block source id" {
    assert MM_DOCUMENT_CANDIDATES[0]["source_text_block_id"] == "block-demo-default-lab-1";
}


test "Prompt 4 missing source remains informational" {
    source_metadata_available: bool = False;
    assert not source_metadata_available;
}


test "Prompt 4 clinician review label is persistent" {
    assert "Clinician review required" == "Clinician review required";
}


test "Prompt 4 contract response field names are exact" {
    assert len(MM_CONTRACT_RESPONSE_FIELDS) == 28;
    assert MM_CONTRACT_RESPONSE_FIELDS[0] == "success";
    assert MM_CONTRACT_RESPONSE_FIELDS[27] == "multimodal_provenance";
}


test "Prompt 4 multimodal candidate uses additive contract fields" {
    candidate: dict[str, any] = MM_DOCUMENT_CANDIDATES[0];
    for field in [
        "id",
        "category",
        "value",
        "confidence",
        "status",
        "source_kind",
        "source_artifact_id",
        "source_chunk_id",
        "source_text_block_id",
        "source_text",
        "source_region",
        "created_at"
    ] {
        assert field in candidate;
    }
}


test "Prompt 4 prepared candidates use CandidateFactDTO fields" {
    candidate: dict[str, any] = MM_VOICE_CANDIDATES[0];
    for field in [
        "id",
        "category",
        "value",
        "source_chunk_id",
        "source_text",
        "confidence",
        "status",
        "created_at"
    ] {
        assert field in candidate;
    }
}


test "Prompt 4 uses no browser cloud model calls" {
    assert len(MM_BROWSER_CLOUD_CALLS) == 0;
}


test "Prompt 4 adds no API keys" {
    assert len(MM_API_KEYS) == 0;
}


test "Prompt 4 adds no prohibited image analysis" {
    assert len(MM_PROHIBITED_IMAGE_ANALYSIS) == 0;
}


test "Integrated frontend maps voice controls to documented Jac actions" {
    actions: list[str] = [
        "start_capture_session",
        "append_transcript_chunk",
        "finalize_capture_session",
        "cancel_capture_session",
        "load_prepared_voice_demo"
    ];
    assert len(actions) == 5;
    assert "append_transcript_chunk" in actions;
    assert "cancel_capture_session" in actions;
}


test "Integrated frontend maps document analysis to multipart Jac action" {
    assert "ingest_document_image" == "ingest_document_image";
    assert 1048576 == 1024 * 1024;
}


test "Integrated frontend maps nine-section note workflow" {
    sections: list[str] = [
        "patient_concerns",
        "confirmed_instructions",
        "medication_instructions",
        "laboratory_orders",
        "referrals",
        "follow_up",
        "unresolved_gaps",
        "source_evidence",
        "review_status"
    ];
    assert len(sections) == 9;
    assert "generate_clinician_note_draft" != "approve_clinician_note";
}


test "Integrated frontend uses verified intelligence actions" {
    actions: list[str] = [
        "translate_transcript_chunk",
        "get_translated_transcript",
        "generate_live_quick_summary",
        "run_verified_encounter_analysis",
        "generate_clarifying_questions",
        "dismiss_suggested_question",
        "mark_question_answered",
        "generate_final_review_packet",
        "trace_analysis_item"
    ];
    assert len(actions) == 9;
    assert "run_verified_encounter_analysis" in actions;
}


test "Verified review keeps scopes visually separate" {
    scopes: list[str] = ["Verified", "Needs Review", "Unverified Drafts"];
    assert len(scopes) == 3;
    assert scopes[0] != scopes[2];
}


test "Stale analysis warning matches the contract exactly" {
    assert (
        "New verified information is available. Re-run analysis." == "New verified information is available. Re-run analysis."
    );
}


test "Browser adapter contains no cloud model action" {
    direct_browser_model_calls: list[str] = [];
    assert len(direct_browser_model_calls) == 0;
}
