"""One timestamped message in the consultation transcript."""

def:pub TranscriptMessage(
    source_id: str,
    speaker: str,
    speaker_kind: str,
    timestamp: str,
    sentence: str,
    message_status: str,
    highlighted: bool
) -> JsxElement {
    return
        <article
            id={"source-" + source_id}
            className={"transcript-message transcript-message--" + speaker_kind + (
                " source-highlight" if highlighted else ""
            )}
            tabIndex={-1}
            aria-label={speaker + " transcript message"}
        >
            <time className="transcript-message__time">{timestamp}</time>
            <p className="transcript-message__speaker">{speaker}</p>
            <p className="transcript-message__sentence">{sentence}</p>
            <span className="transcript-message__state">{message_status}</span>
        </article>;
}
