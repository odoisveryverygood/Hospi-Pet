"""Scrollable consultation transcript for Screen 1."""

import from .TranscriptMessage { TranscriptMessage }


def:pub TranscriptPanel(
    messages: list[dict[str, any]],
    highlighted_source_id: str,
    transcription_status: str,
    is_prepared_demo: bool,
    interim_text: str,
    interim_speaker: str
) -> JsxElement {
    has_messages: bool = len(messages) > 0;

    return
        <section
            className="panel transcript-panel"
            aria-labelledby="transcript-heading"
        >
            <div className="section-heading">
                <div>
                    <p className="eyebrow">Consultation record</p>
                    <h2 id="transcript-heading">Transcript</h2>
                </div>
                <p className="section-heading__meta" role="status">
                    {(
                        str(len(messages)) + " entries · " + (
                            "Prepared demo · Final" if is_prepared_demo else "Final"
                        )
                            if has_messages
                            else (
                                "Microphone active · browser transcription listening"
                                    if transcription_status == "recording"
                                    else "Waiting for encounter input"
                            )
                    )}
                </p>
            </div>
            <div className="transcript-scroll" aria-label="Consultation transcript">
                {(
                    <div className="transcript-list">
                        {[
                            <TranscriptMessage
                                key={message["id"]}
                                source_id={message["id"]}
                                speaker={(
                                    "Clinician"
                                        if message["speaker"] == "Doctor"
                                        else (
                                            message["speaker"]
                                                if message["speaker"] in [
                                                    "Patient",
                                                    "Healthcare Provider"
                                                ]
                                                else "Unknown Speaker"
                                        )
                                )}
                                speaker_kind={(
                                    message["speaker_kind"]
                                        if "speaker_kind" in message
                                        else (
                                            "patient"
                                                if message["speaker"] == "Patient"
                                                else (
                                                    "provider"
                                                        if message["speaker"] == "Doctor"
                                                        else "unknown"
                                                )
                                        )
                                )}
                                timestamp={(
                                    message["timestamp"]
                                        if "timestamp" in message
                                        else "Line " + str(message["sequence"])
                                )}
                                sentence={(
                                    message["sentence"]
                                        if "sentence" in message
                                        else message["text"]
                                )}
                                message_status={"Final"}
                                highlighted={highlighted_source_id == message["id"]}
                            /> for message in messages
                        ]}{(
                            <TranscriptMessage
                                source_id="interim"
                                speaker={(
                                    "Clinician"
                                        if interim_speaker == "Doctor"
                                        else "Patient"
                                )}
                                speaker_kind={(
                                    "provider"
                                        if interim_speaker == "Doctor"
                                        else "patient"
                                )}
                                timestamp="Live"
                                sentence={interim_text}
                                message_status="Interim"
                                highlighted={False}
                            />
                                if len(interim_text) > 0
                                else None
                        )}
                    </div>
                        if has_messages or len(interim_text) > 0
                        else <div className="transcript-empty">
                            <h3>No consultation loaded</h3>
                            <p>
                                Start a voice encounter or load the prepared demo to review speaker-labeled transcript content.
                            </p>
                        </div>
                )}
            </div>
            {(
                <p className="transcript-panel__footer">
                    Scroll within the record to review the complete consultation.
                </p>
                    if has_messages
                    else None
            )}
        </section>;
}
