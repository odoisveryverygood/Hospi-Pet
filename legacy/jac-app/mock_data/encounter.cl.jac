"""Synthetic Screen 1 encounter data.

All names and clinical details in this module are fictional and intended only
for the Hospi-Pet hackathon demonstration.
"""

glob:pub MOCK_PATIENT: dict[str, str] = {
         "name": "Elena Marquez",
         "encounter_type": "Primary care follow-up",
         "consultation_status": "Consultation complete",
         "encounter_date": "July 26, 2026",
         "visit_id": "VIS-2026-0427",
         "review_status": "Ready for review"
     };

glob:pub MOCK_TRANSCRIPT: list[dict[str, str]] = [
         {
             "id": "message-01",
             "speaker": "Healthcare Provider",
             "speaker_kind": "provider",
             "timestamp": "08:42",
             "sentence": "Good morning, Elena. What brought you in today?"
         },
         {
             "id": "message-02",
             "speaker": "Patient",
             "speaker_kind": "patient",
             "timestamp": "08:43",
             "sentence": "I have had a dull ache in my lower back for about ten days. It is worse after I sit at my desk for a long time."
         },
         {
             "id": "message-03",
             "speaker": "Healthcare Provider",
             "speaker_kind": "provider",
             "timestamp": "08:44",
             "sentence": "On a scale from zero to ten, how strong is the pain?"
         },
         {
             "id": "message-04",
             "speaker": "Patient",
             "speaker_kind": "patient",
             "timestamp": "08:44",
             "sentence": "It is usually a four, but it reached six out of ten yesterday evening."
         },
         {
             "id": "message-05",
             "speaker": "Healthcare Provider",
             "speaker_kind": "provider",
             "timestamp": "08:45",
             "sentence": "What medications do you take, and do you have any medication allergies?"
         },
         {
             "id": "message-06",
             "speaker": "Patient",
             "speaker_kind": "patient",
             "timestamp": "08:46",
             "sentence": "I take lisinopril, ten milligrams each morning. I am allergic to penicillin; it caused a rash when I was a child."
         },
         {
             "id": "message-07",
             "speaker": "Healthcare Provider",
             "speaker_kind": "provider",
             "timestamp": "08:47",
             "sentence": "Is there any relevant medical history, such as a chronic condition or previous back treatment?"
         },
         {
             "id": "message-08",
             "speaker": "Patient",
             "speaker_kind": "patient",
             "timestamp": "08:47",
             "sentence": "I was diagnosed with hypertension about five years ago. I have not had back surgery or kidney problems."
         }
     ];

glob:pub MOCK_FACTS: list[dict[str, any]] = [
         {
             "id": "fact-symptom",
             "category": "symptom",
             "value": "Dull ache in the lower back",
             "source_chunk_id": "message-02",
             "source_text": "I have had a dull ache in my lower back for about ten days. It is worse after I sit at my desk for a long time.",
             "confidence": 0.96,
             "status": "pending",
             "created_at": "2026-07-26T08:48:01Z"
         },
         {
             "id": "fact-duration",
             "category": "duration",
             "value": "About ten days",
             "source_chunk_id": "message-02",
             "source_text": "I have had a dull ache in my lower back for about ten days. It is worse after I sit at my desk for a long time.",
             "confidence": 0.94,
             "status": "pending",
             "created_at": "2026-07-26T08:48:02Z"
         },
         {
             "id": "fact-pain",
             "category": "pain_level",
             "value": "Usually 4/10; peaked at 6/10",
             "source_chunk_id": "message-04",
             "source_text": "It is usually a four, but it reached six out of ten yesterday evening.",
             "confidence": 0.91,
             "status": "pending",
             "created_at": "2026-07-26T08:48:03Z"
         },
         {
             "id": "fact-medication",
             "category": "medication",
             "value": "Lisinopril, 10 mg each morning",
             "source_chunk_id": "message-06",
             "source_text": "I take lisinopril, ten milligrams each morning. I am allergic to penicillin; it caused a rash when I was a child.",
             "confidence": 0.93,
             "status": "pending",
             "created_at": "2026-07-26T08:48:04Z"
         },
         {
             "id": "fact-allergy",
             "category": "allergy",
             "value": "Penicillin — childhood rash",
             "source_chunk_id": "message-06",
             "source_text": "I take lisinopril, ten milligrams each morning. I am allergic to penicillin; it caused a rash when I was a child.",
             "confidence": 0.89,
             "status": "pending",
             "created_at": "2026-07-26T08:48:05Z"
         },
         {
             "id": "fact-history",
             "category": "medical_history",
             "value": "Hypertension, diagnosed about five years ago",
             "source_chunk_id": "message-08",
             "source_text": "I was diagnosed with hypertension about five years ago. I have not had back surgery or kidney problems.",
             "confidence": 0.92,
             "status": "pending",
             "created_at": "2026-07-26T08:48:06Z"
         }
     ];
