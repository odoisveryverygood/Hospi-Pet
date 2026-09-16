"""Pure Screen 1 state helpers shared by the UI and frontend tests."""

def:pub blankFactDecisions -> dict[str, str] {
    return {
        "fact-symptom": "neutral",
        "fact-duration": "neutral",
        "fact-pain": "neutral",
        "fact-medication": "neutral",
        "fact-allergy": "neutral",
        "fact-history": "neutral"
    };
}


def:pub blankConditionDecisions -> dict[str, str] {
    return {
        "condition-mechanical-pattern": "neutral",
        "condition-strain-overuse": "neutral"
    };
}


def:pub blankQuestionDecisions -> dict[str, str] {
    return {
        "question-radiation": "neutral",
        "question-triggers": "neutral",
        "question-previous": "neutral",
        "question-systemic": "neutral",
        "question-function": "neutral"
    };
}


def:pub updateFactDecision(
    decisions: dict[str, str], fact_id: str, decision: str
) -> dict[str, str] {
    updated: dict[str, str] = decisions.copy();
    updated[fact_id] = decision;
    return updated;
}


def:pub updateConditionDecision(
    decisions: dict[str, str], condition_id: str, decision: str
) -> dict[str, str] {
    updated: dict[str, str] = decisions.copy();
    updated[condition_id] = decision;
    return updated;
}


def:pub updateQuestionDecision(
    decisions: dict[str, str], question_id: str, decision: str
) -> dict[str, str] {
    updated: dict[str, str] = decisions.copy();
    updated[question_id] = decision;
    return updated;
}


def:pub canLoadDemo(demo_loaded: bool, is_transitioning: bool) -> bool {
    return not demo_loaded and not is_transitioning;
}


def:pub canResetDemo(demo_loaded: bool, is_transitioning: bool) -> bool {
    return demo_loaded or is_transitioning;
}


def:pub nextAssistantState(current_state: str) -> str {
    if current_state == "idle" {
        return "listening";
    } elif current_state == "listening" {
        return "analyzing";
    } elif current_state == "analyzing" {
        return "complete";
    }
    return current_state;
}


def:pub statusForState(state: str) -> str {
    if state == "listening" {
        return "Listening to the consultation";
    } elif state == "analyzing" {
        return "Analyzing the consultation";
    } elif state == "complete" {
        return "Facts ready for verification";
    }
    return "Ready for an encounter";
}


def:pub sequenceDelayForState(state: str) -> float {
    if state == "listening" {
        return 800.0;
    } elif state == "analyzing" {
        return 750.0;
    } elif state == "facts_ready" {
        return 220.0;
    }
    return 0.0;
}


def:pub isAssistantActivationKey(key: str) -> bool {
    return key == "Enter" or key == " ";
}


def:pub motionEnabled(prefers_reduced_motion: bool) -> bool {
    return not prefers_reduced_motion;
}


def:pub toggleMascotMessage(message_visible: bool) -> bool {
    return not message_visible;
}


def:pub mascotMessageVisible(is_hovered: bool, message_toggled: bool) -> bool {
    return is_hovered or message_toggled;
}


def:pub mascotTailWagActive(is_hovered: bool, message_toggled: bool) -> bool {
    return is_hovered or message_toggled;
}


def:pub verifiedFactCount(
    facts: list[dict[str, str]], decisions: dict[str, str]
) -> int {
    count: int = 0;
    for fact in facts {
        if decisions[fact["id"]] == "accepted" {
            count += 1;
        }
    }
    return count;
}


def:pub acceptedFactValue(
    facts: list[dict[str, str]], decisions: dict[str, str], fact_id: str
) -> str {
    for fact in facts {
        if (fact["id"] == fact_id and decisions[fact_id] == "accepted") {
            return fact["value"];
        }
    }
    return "Not verified";
}


def:pub acceptedEvidenceValues(
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


def:pub hasEnoughVerifiedFacts(
    facts: list[dict[str, str]], decisions: dict[str, str]
) -> bool {
    return (
        verifiedFactCount(facts, decisions) >= 3
        and decisions["fact-symptom"] == "accepted"
    );
}


def:pub canContinueToInsights(
    demo_loaded: bool, is_transitioning: bool, facts_loaded: bool
) -> bool {
    return demo_loaded and not is_transitioning and facts_loaded;
}
