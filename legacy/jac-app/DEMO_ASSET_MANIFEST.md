# Synthetic multimodal demo assets

Every asset is fictional, visibly labeled, small, and contains no real
provider, organization, address, telephone number, credential, or patient
data. SVG source is retained for transparent review; PNG derivatives exercise
the actual image contract.

| Asset | Purpose | Expected extraction | Candidate | Trace / fallback |
|---|---|---|---|---|
| `consultation_transcript.json` | Prepared voice fallback | Five ordered Doctor/Patient chunks | Existing five pending facts | Candidate → chunk → capture → encounter |
| `synthetic_lab_order.png` | Required document demo | Order and this-week instruction, fictional patient, responsible team | `lab_order: blood test; due this week` | Candidate → block 3/region → image metadata → artifact |
| `synthetic_referral.png` | Referral adapter fixture | Community nutrition counselor | `referral` pending | Same document chain |
| `synthetic_appointment_card.png` | Appointment adapter fixture | Follow-up date `2026-08-09` | `follow_up` pending | Same document chain |
| `expected_document_extraction.json` | Frontend/test oracle | Exact blocks, regions, candidates | Never verified automatically | Deterministic fallback oracle |

Deterministic extraction is the judging path. MockLLM validates the typed
vision seam. Missing key, provider error, timeout, empty/malformed output, or
unsafe proposal retains the deterministic result and a recoverable diagnostic.
