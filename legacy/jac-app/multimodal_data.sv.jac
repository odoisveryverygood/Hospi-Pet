"""Small deterministic, fictional multimodal fixtures used by the keyless demo."""

import from models { CandidateCategory, SourceArtifactType, }

obj SyntheticTextBlock {
    has sequence: int = 0,
        text: str = "",
        confidence: float = 1.0,
        page_number: int = 1,
        bounding_region: str = "";
}

obj SyntheticDocumentProposal {
    has category: CandidateCategory = CandidateCategory.LAB_ORDER,
        value: str = "",
        exact_source_text: str = "",
        source_block_sequence: int = 0,
        confidence: float = 1.0,
        patient_visible_candidate: bool = True,
        requires_clinician_review: bool = True;
}

def synthetic_document_blocks(
    document_type: SourceArtifactType
) -> list[SyntheticTextBlock] {
    if document_type == SourceArtifactType.LAB_DOCUMENT {
        return [
            SyntheticTextBlock(
                sequence=1,
                text="SYNTHETIC DEMO — Harbor Bridge Community Clinic",
                bounding_region="40,30,720,75"
            ),
            SyntheticTextBlock(
                sequence=2,
                text="Patient: Maya Rivera (fictional)",
                bounding_region="40,100,520,135"
            ),
            SyntheticTextBlock(
                sequence=3,
                text="Order: blood test; complete this week.",
                bounding_region="40,160,420,200"
            ),
            SyntheticTextBlock(
                sequence=4, text="Complete this week.", bounding_region="40,220,420,260"
            ),
            SyntheticTextBlock(
                sequence=5,
                text="Responsible team: Clinic Lab Team",
                bounding_region="40,280,600,320"
            )
        ];
    }
    if document_type == SourceArtifactType.REFERRAL_DOCUMENT {
        return [
            SyntheticTextBlock(
                sequence=1,
                text="SYNTHETIC DEMO — Fictional Referral",
                bounding_region="40,30,700,75"
            ),
            SyntheticTextBlock(
                sequence=2,
                text="Refer Maya Rivera to a community nutrition counselor.",
                bounding_region="40,110,740,165"
            )
        ];
    }
    if document_type == SourceArtifactType.APPOINTMENT_CARD {
        return [
            SyntheticTextBlock(
                sequence=1,
                text="SYNTHETIC DEMO — Fictional Appointment Card",
                bounding_region="40,30,720,75"
            ),
            SyntheticTextBlock(
                sequence=2,
                text="Follow-up appointment: 2026-08-09",
                bounding_region="40,120,620,165"
            )
        ];
    }
    return [
        SyntheticTextBlock(
            sequence=1,
            text="SYNTHETIC DEMO — After-visit instruction sheet",
            bounding_region="40,30,720,75"
        ),
        SyntheticTextBlock(
            sequence=2,
            text="Use only the clinician-approved care plan.",
            bounding_region="40,120,700,165"
        )
    ];
}

def synthetic_document_proposals(
    document_type: SourceArtifactType
) -> list[SyntheticDocumentProposal] {
    if document_type == SourceArtifactType.LAB_DOCUMENT {
        return [
            SyntheticDocumentProposal(
                category=CandidateCategory.LAB_ORDER,
                value="blood test; due this week",
                exact_source_text="Order: blood test; complete this week.",
                source_block_sequence=3,
                confidence=1.0,
                patient_visible_candidate=True,
                requires_clinician_review=True
            )
        ];
    }
    if document_type == SourceArtifactType.REFERRAL_DOCUMENT {
        return [
            SyntheticDocumentProposal(
                category=CandidateCategory.REFERRAL,
                value="community nutrition counselor",
                exact_source_text=(
                    "Refer Maya Rivera to a community nutrition counselor."
                ),
                source_block_sequence=2,
                confidence=1.0,
                patient_visible_candidate=True,
                requires_clinician_review=True
            )
        ];
    }
    if document_type == SourceArtifactType.APPOINTMENT_CARD {
        return [
            SyntheticDocumentProposal(
                category=CandidateCategory.FOLLOW_UP,
                value="appointment on 2026-08-09",
                exact_source_text="Follow-up appointment: 2026-08-09",
                source_block_sequence=2,
                confidence=1.0,
                patient_visible_candidate=True,
                requires_clinician_review=True
            )
        ];
    }
    return [];
}
