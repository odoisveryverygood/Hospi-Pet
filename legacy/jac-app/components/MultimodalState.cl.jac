"""Pure frontend helpers for multimodal controls and visit-note projection."""

def:pub formatRecordingTime(seconds: int) -> str {
    minutes: int = seconds // 60;
    remaining: int = seconds % 60;
    minute_text: str = str(minutes);
    second_text: str = str(remaining);
    if minutes < 10 {
        minute_text = "0" + minute_text;
    }
    if remaining < 10 {
        second_text = "0" + second_text;
    }
    return minute_text + ":" + second_text;
}


def:pub imageTypeSupported(file_type: str) -> bool {
    return (
        file_type == "image/jpeg"
        or file_type == "image/png"
        or file_type == "image/webp"
    );
}


def:pub imageSizeAllowed(file_size: int) -> bool {
    return file_size > 0 and file_size <= 1048576;
}


def:pub decisionFor(decisions: dict[str, str], candidate_id: str) -> str {
    if candidate_id in decisions {
        return decisions[candidate_id];
    }
    return "neutral";
}


def:pub candidateSourceId(candidate: dict[str, any]) -> str {
    if ("source_chunk_id" in candidate and len(candidate["source_chunk_id"]) > 0) {
        return candidate["source_chunk_id"];
    } elif (
        "source_text_block_id" in candidate
        and len(candidate["source_text_block_id"]) > 0
    ) {
        return candidate["source_text_block_id"];
    }
    return "";
}


def:pub acceptedCandidates(
    candidates: list[dict[str, any]], decisions: dict[str, str]
) -> list[dict[str, any]] {
    accepted: list[dict[str, any]] = [];
    for candidate in candidates {
        if decisionFor(decisions, candidate["id"]) == "accepted" {
            accepted.append(candidate);
        }
    }
    return accepted;
}


def:pub candidatesForGroup(
    candidates: list[dict[str, any]], decisions: dict[str, str], group_name: str
) -> list[dict[str, any]] {
    grouped: list[dict[str, any]] = [];
    for candidate in acceptedCandidates(candidates, decisions) {
        category: str = candidate["category"];
        if (
            group_name == "concerns"
            and category in [
                "symptom",
                "duration",
                "pain_level",
                "allergy",
                "medical_history",
                "language_preference"
            ]
        ) {
            grouped.append(candidate);
        } elif (
            group_name == "instructions"
            and category in [
                "medication",
                "medication_instruction",
                "clinician_instruction"
            ]
        ) {
            grouped.append(candidate);
        } elif group_name == "labs" and category == "lab_order" {
            grouped.append(candidate);
        } elif group_name == "referrals" and category == "referral" {
            grouped.append(candidate);
        } elif group_name == "follow_up" and category == "follow_up" {
            grouped.append(candidate);
        }
    }
    return grouped;
}


def:pub uniqueAcceptedSourceCount(
    candidates: list[dict[str, any]], decisions: dict[str, str]
) -> int {
    source_ids: list[str] = [];
    for candidate in acceptedCandidates(candidates, decisions) {
        source_id: str = candidateSourceId(candidate);
        if source_id not in source_ids {
            source_ids.append(source_id);
        }
    }
    return len(source_ids);
}


def:pub hasAcceptedConflict(
    candidates: list[dict[str, any]], decisions: dict[str, str]
) -> bool {
    follow_up_values: list[str] = [];
    for candidate in acceptedCandidates(candidates, decisions) {
        if candidate["category"] == "follow_up" {
            if candidate["value"] not in follow_up_values {
                follow_up_values.append(candidate["value"]);
            }
        }
    }
    return len(follow_up_values) > 1;
}


def:pub unresolvedCandidateCount(
    candidates: list[dict[str, any]], decisions: dict[str, str]
) -> int {
    count: int = 0;
    for candidate in candidates {
        if decisionFor(decisions, candidate["id"]) == "neutral" {
            count += 1;
        }
    }
    return count;
}


def:pub sourceTargetId(source_id: str) -> str {
    return "source-" + source_id;
}


def:pub voiceCanStart(permission_requesting: bool, recording_active: bool) -> bool {
    return not permission_requesting and not recording_active;
}


def:pub documentCanAnalyze(has_preview: bool, is_processing: bool) -> bool {
    return has_preview and not is_processing;
}
