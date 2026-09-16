# Transcription decision

The live method is browser-native `SpeechRecognition` where supported. It
emits final speaker-labeled text chunks to `append_transcript_chunk`; the
backend does not pretend to transcribe audio. Browser support is incomplete
and some implementations use a network service, so the UI must surface
permission, availability, and failure states.

The mandatory path is the prepared five-chunk transcript. It is loaded through
the same start/append/finalize walkers as live text, so fallback does not
bypass graph provenance or clinician verification.

| Property | Decision |
|---|---|
| Model | None required |
| Provider credential | None configured or required |
| Expected latency | Progressive browser events; deterministic fallback is immediate |
| Raw audio persistence | Prohibited; graph stores no audio bytes |
| Privacy | Browser permission is explicit; only synthetic finalized text is sent |
| Failure | Report recoverable state, then use prepared transcript |
| Uploaded audio | Not implemented in P0 |
| Local model | Not installed; no cached small model and disk is constrained |

This is appropriate for a hackathon because the complete flow works offline
and keylessly while preserving one integration seam for improved live capture.
