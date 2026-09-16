"""Pure fixture-state helpers for the intelligence frontend."""

def:pub responseUiStatus(response: dict[str, any], payload_field: str) -> str {
    if not response["success"] {
        return "recoverable_error" if response["recoverable"] else "error";
    }
    if (
        "ai_status" in response
        and response["ai_status"] is not None
        and response["ai_status"]["fallback_used"]
    ) {
        return "provider_fallback";
    }
    if payload_field not in response or response[payload_field] is None {
        return "empty";
    }
    if isinstance(response[payload_field], list)
    and len(response[payload_field]) == 0 {
        return "empty";
    }
    if (
        isinstance(response[payload_field], dict)
        and "fallback_used" in response[payload_field]
        and response[payload_field]["fallback_used"]
    ) {
        return "provider_fallback";
    }
    return "success";
}


def:pub translatedSource(rows: list[dict[str, any]], source_text: str) -> str {
    for row in rows {
        if row["original_text"] == source_text {
            return row["translated_text"];
        }
    }
    return "No translated source sentence is available.";
}


def:pub acceptedCandidateCount(decisions: dict[str, str]) -> int {
    count: int = 0;
    for decision in decisions.values() {
        if decision == "accepted" {
            count += 1;
        }
    }
    return count;
}


def:pub analysisBecomesStale(analysis_status: str, decision_changed: bool) -> bool {
    return (decision_changed and analysis_status in ["success", "provider_fallback"]);
}


def:pub actionDisabled(pending_action: str, action: str) -> bool {
    return len(pending_action) > 0 or pending_action == action;
}
