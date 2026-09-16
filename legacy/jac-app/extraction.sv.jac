"""Deterministic P0 consultation data with no model-provider dependency."""

import from models { CandidateCategory }

obj SeedTranscriptChunk {
    has id: str = "",
        sequence: int = 0,
        speaker: str = "",
        text: str = "";
}

obj SeedCandidateFact {
    has id: str = "",
        category: CandidateCategory = CandidateCategory.LAB_ORDER,
        value: str = "",
        confidence: float = 1.0,
        source_chunk_id: str = "",
        created_at: str = "";
}

def deterministic_timestamp(version: int) -> str {
    if version < 10 {
        return f"2026-07-26T18:00:0{version}Z";
    }
    return f"2026-07-26T18:00:{version}Z";
}

def prepared_transcript -> list[SeedTranscriptChunk] {
    return [
        SeedTranscriptChunk(
            id="chunk-1",
            sequence=1,
            speaker="Doctor",
            text="We will order a blood test to be completed this week."
        ),
        SeedTranscriptChunk(
            id="chunk-2",
            sequence=2,
            speaker="Doctor",
            text="Please return in two weeks so we can review the results."
        ),
        SeedTranscriptChunk(
            id="chunk-3",
            sequence=3,
            speaker="Doctor",
            text="Continue your current medication exactly as it appears on your existing prescription."
        ),
        SeedTranscriptChunk(
            id="chunk-4",
            sequence=4,
            speaker="Doctor",
            text="I am referring you to a community nutrition counselor."
        ),
        SeedTranscriptChunk(
            id="chunk-5",
            sequence=5,
            speaker="Patient",
            text="Can someone explain the instructions to me in Spanish?"
        )
    ];
}

def prepared_candidates -> list[SeedCandidateFact] {
    return [
        SeedCandidateFact(
            id="candidate-lab",
            category=CandidateCategory.LAB_ORDER,
            value="blood test; due this week",
            confidence=1.0,
            source_chunk_id="chunk-1",
            created_at="2026-07-26T18:00:01Z"
        ),
        SeedCandidateFact(
            id="candidate-follow-up",
            category=CandidateCategory.FOLLOW_UP,
            value="return in two weeks",
            confidence=1.0,
            source_chunk_id="chunk-2",
            created_at="2026-07-26T18:00:02Z"
        ),
        SeedCandidateFact(
            id="candidate-medication",
            category=CandidateCategory.MEDICATION_INSTRUCTION,
            value="continue existing prescription unchanged",
            confidence=1.0,
            source_chunk_id="chunk-3",
            created_at="2026-07-26T18:00:03Z"
        ),
        SeedCandidateFact(
            id="candidate-referral",
            category=CandidateCategory.REFERRAL,
            value="community nutrition counselor",
            confidence=1.0,
            source_chunk_id="chunk-4",
            created_at="2026-07-26T18:00:04Z"
        ),
        SeedCandidateFact(
            id="candidate-language",
            category=CandidateCategory.LANGUAGE_PREFERENCE,
            value="Spanish",
            confidence=1.0,
            source_chunk_id="chunk-5",
            created_at="2026-07-26T18:00:05Z"
        )
    ];
}

def prepared_contradiction_chunk -> SeedTranscriptChunk {
    return SeedTranscriptChunk(
        id="chunk-6",
        sequence=6,
        speaker="Doctor",
        text="Please return in four weeks so we can review the results."
    );
}

def prepared_contradiction_candidate -> SeedCandidateFact {
    return SeedCandidateFact(
        id="candidate-follow-up-4-weeks",
        category=CandidateCategory.FOLLOW_UP,
        value="return in four weeks",
        confidence=1.0,
        source_chunk_id="chunk-6",
        created_at="2026-07-26T18:00:06Z"
    );
}
