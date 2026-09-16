"""Accessible centered Hospi-Pet assistant presentation."""

import from .HospiPetDog { HospiPetDog }


def:pub AssistantSection(
    assistant_state: str,
    status_text: str,
    friendly_message: str,
    message_visible: bool,
    on_activate: any,
    is_transitioning: bool,
    is_running: bool
) -> JsxElement {
    status_dot_class: str = (
        "status-dot status-dot--active"
            if is_transitioning
            else "status-dot status-dot--ready"
    );

    return
        <section
            className={"assistant-section assistant-section--" + assistant_state}
            aria-labelledby="assistant-heading"
        >
            <div className="assistant-stage">
                <HospiPetDog
                    assistant_state={assistant_state}
                    message_visible={message_visible}
                    on_activate={on_activate}
                    is_transitioning={is_transitioning}
                    is_running={is_running}
                />
            </div>
            <div className="assistant-copy">
                <p className="assistant-status">
                    <span className={status_dot_class} aria-hidden="true"></span>
                    <span>{status_text}</span>
                </p>
                <h2 id="assistant-heading">Hospi-Pet assistant</h2>
                <p className="assistant-message" role="status" aria-live="polite">
                    {friendly_message}
                </p>
                <p className="assistant-hint">
                    Select Hospi-Pet for a friendly check-in.
                </p>
            </div>
        </section>;
}
