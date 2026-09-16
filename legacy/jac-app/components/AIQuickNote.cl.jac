"""Clearly unverified live conversation summary."""

def:pub AIQuickNote(
    note: dict[str, any], status: str, pending_action: str, on_generate: any
) -> JsxElement {
    has_note: bool = "id" in note;
    loading: bool = status == "loading";

    return
        <section
            className="panel intelligence-panel quick-note"
            aria-labelledby="quick-note-heading"
        >
            <div className="section-heading">
                <div>
                    <p className="eyebrow">Conversation aid</p>
                    <h2 id="quick-note-heading">AI Quick Note</h2>
                </div>
                <span className="unverified-draft-badge">Unverified Draft</span>
            </div>
            <p className="quick-note__required-label">
                AI conversation draft — not yet clinician verified.
            </p>
            {(
                <div className="quick-note__body">
                    <p className="quick-note__summary">{note["summary"]}</p>
                    <div>
                        <h3>Key points</h3>
                        <ul>
                            {[
                                <li key={point}>{point}</li>
                                for point in note["key_points"]
                            ]}
                        </ul>
                    </div>
                    <div className="quick-note__meta">
                        <span>{str(len(note["source_chunk_ids"]))} sources</span>
                        <span>Mode: {note["model_mode"]}</span>
                        {(
                            <span className="provider-fallback-badge">
                                Provider fallback
                            </span>
                                if note["fallback_used"]
                                else None
                        )}
                    </div>
                </div>
                    if has_note
                    else <div
                        className={"intelligence-empty intelligence-empty--" + status}
                        role="status"
                    >
                        <h3>
                            {(
                                "Preparing the unverified draft…"
                                    if loading
                                    else (
                                        "Quick note could not be generated"
                                            if status == "recoverable_error"
                                            else "No quick note generated"
                                    )
                            )}
                        </h3>
                        <p>
                            Generate a backend summary after final transcript chunks are available.
                        </p>
                    </div>
            )}
            <div className="intelligence-panel__actions">
                <button
                    className="button button--secondary"
                    type="button"
                    disabled={len(pending_action) > 0}
                    onClick={on_generate}
                >
                    {("Generating…" if loading else "Generate Quick Note")}
                </button>
            </div>
        </section>;
}
