"""Browser-local voice controls with a prepared contract-shaped fallback."""

import from .MultimodalState { formatRecordingTime, voiceCanStart }


def:pub VoiceEncounterSection(
    permission_state: str,
    transcription_status: str,
    recording_seconds: int,
    is_requesting: bool,
    is_recording: bool,
    is_stopping: bool,
    is_prepared_demo: bool,
    speaker: str,
    interim_text: str,
    scenario: str,
    on_scenario_change: any,
    on_speaker_change: any,
    on_start: any,
    on_stop: any,
    on_cancel_retry: any,
    on_prepared_demo: any,
    on_discard: any
) -> JsxElement {
    can_start: bool = voiceCanStart(is_requesting, is_recording);
    has_voice_content: bool = (
        is_recording or is_prepared_demo or transcription_status == "completed"
    );
    status_label: str = transcription_status.replace("_", " ");

    return
        <section
            className="panel multimodal-panel voice-panel"
            aria-labelledby="voice-heading"
        >
            <div className="section-heading">
                <div>
                    <p className="eyebrow">Multimodal input</p>
                    <h2 id="voice-heading">Voice Encounter</h2>
                </div>
                <span
                    className={"section-chip " + (
                        "section-chip--active" if is_recording else ""
                    )}
                    role="status"
                    aria-live="polite"
                >
                    {status_label}
                </span>
            </div>
            <div className="multimodal-toolbar">
                <div className="multimodal-toolbar__primary">
                    <button
                        className="button button--primary"
                        type="button"
                        disabled={not can_start}
                        aria-busy={is_requesting}
                        onClick={on_start}
                    >
                        {(
                            "Requesting microphone…"
                                if is_requesting
                                else "Start Recording"
                        )}
                    </button>
                    <button
                        className="button button--secondary"
                        type="button"
                        disabled={not is_recording or is_stopping}
                        aria-busy={is_stopping}
                        onClick={on_stop}
                    >
                        {("Stopping…" if is_stopping else "Stop Recording")}
                    </button>
                    <div
                        className="recording-timer"
                        aria-label={"Recording time " + formatRecordingTime(
                            recording_seconds
                        )}
                    >
                        <span
                            className={"recording-timer__dot " + (
                                "recording-timer__dot--active" if is_recording else ""
                            )}
                            aria-hidden="true"
                        ></span>
                        <time>{formatRecordingTime(recording_seconds)}</time>
                    </div>
                </div>
                <label className="scenario-control">
                    <span>Current speaker</span>
                    <select
                        value={speaker}
                        disabled={is_requesting or is_stopping}
                        onChange={on_speaker_change}
                        aria-label="Current transcript speaker"
                    >
                        <option value="Doctor">Doctor</option>
                        <option value="Patient">Patient</option>
                    </select>
                </label>
                <label className="scenario-control">
                    <span>Demo path</span>
                    <select
                        value={scenario}
                        disabled={is_requesting or is_recording}
                        onChange={on_scenario_change}
                    >
                        <option value="browser">Browser microphone</option>
                        <option value="permission_denied">Permission denied</option>
                        <option value="unsupported">Unsupported browser</option>
                        <option value="recoverable_error">Recoverable error</option>
                    </select>
                </label>
            </div>
            {(
                <div className="voice-interim" role="status" aria-live="polite">
                    <span>{speaker} · Interim</span>
                    <p>{interim_text}</p>
                </div>
                    if len(interim_text) > 0
                    else None
            )}
            <div className="status-grid">
                <div>
                    <span>Microphone permission</span>
                    <strong>{permission_state.replace("_", " ")}</strong>
                </div>
                <div>
                    <span>Transcription</span>
                    <strong>{status_label}</strong>
                </div>
                <div>
                    <span>Audio handling</span>
                    <strong>Local browser only</strong>
                </div>
            </div>
            {(
                <p className="prepared-label" role="status">
                    Prepared demo · no microphone recording occurred
                </p>
                    if is_prepared_demo
                    else None
            )}
            {(
                <div
                    className="permission-message permission-message--error"
                    role="alert"
                >
                    <strong>Microphone access was denied.</strong>
                    <p>
                        Enable microphone access in the browser, try again, or load the prepared voice demo.
                    </p>
                </div>
                    if permission_state == "denied"
                    else (
                        <div className="permission-message" role="status">
                            <strong>
                                Microphone recording is unavailable in this browser.
                            </strong>
                            <p>The prepared voice demo remains available.</p>
                        </div>
                            if permission_state == "unsupported"
                            else (
                                <div
                                    className="permission-message permission-message--error"
                                    role="alert"
                                >
                                    <strong>
                                        The microphone request did not complete.
                                    </strong>
                                    <p>
                                        This is a recoverable demo state. Try again or use prepared content.
                                    </p>
                                </div>
                                    if permission_state == "recoverable_error"
                                    else None
                            )
                    )
            )}
            <div className="multimodal-secondary-actions">
                <button
                    className="button button--secondary"
                    type="button"
                    disabled={is_recording}
                    onClick={on_cancel_retry}
                >
                    Cancel and Retry
                </button>
                <button
                    className="button button--secondary"
                    type="button"
                    disabled={is_recording}
                    onClick={on_prepared_demo}
                >
                    Load Prepared Voice Demo
                </button>
                <button
                    className="text-button"
                    type="button"
                    disabled={not has_voice_content
                    and permission_state == "not_requested"}
                    onClick={on_discard}
                >
                    Discard Recording
                </button>
            </div>
            <p className="panel-footnote">
                Browser speech recognition keeps interim text local. Only final, nonblank transcript chunks are sent to the documented Jac action; raw microphone audio is never uploaded.
            </p>
        </section>;
}
