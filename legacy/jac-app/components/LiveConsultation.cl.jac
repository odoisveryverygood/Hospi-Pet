"""Original and translated consultation rows from backend actions."""

def:pub LiveConsultation(
    rows: list[dict[str, any]],
    status: str,
    recording_state: str,
    pending_action: str,
    on_load: any
) -> JsxElement {
    loading: bool = status == "loading";
    has_rows: bool = len(rows) > 0;

    return
        <section
            className="panel intelligence-panel live-consultation"
            aria-labelledby="live-consultation-heading"
        >
            <div className="section-heading">
                <div>
                    <p className="eyebrow">Bilingual encounter</p>
                    <h2 id="live-consultation-heading">Live Consultation</h2>
                </div>
                <div className="intelligence-status-stack">
                    <span
                        className={"intelligence-status intelligence-status--" + recording_state}
                    >
                        Recording: {recording_state.replace("_", " ")}
                    </span>
                    <span
                        className={"intelligence-status intelligence-status--" + status}
                        role="status"
                    >
                        Translation: {status.replace("_", " ")}
                    </span>
                </div>
            </div>
            <div className="consultation-column-headings" aria-hidden="true">
                <span>Original transcript</span>
                <span>Translated transcript</span>
            </div>
            {(
                <div className="translated-transcript-list">
                    {[
                        <article className="translated-row" key={row["id"]}>
                            <div className="translated-row__original">
                                <div className="translated-row__meta">
                                    <strong>{row["speaker"]}</strong>
                                    <span>
                                        {row["source_language"]} · #{str(
                                            row["sequence"]
                                        )}
                                    </span>
                                </div>
                                <p>{row["original_text"]}</p>
                            </div>
                            <div className="translated-row__translation">
                                <div className="translated-row__meta">
                                    <strong>{row["target_language"]}</strong>
                                    <span
                                        className={"translation-badge translation-badge--" + row[
                                            "status"
                                        ]}
                                    >
                                        {row["status"]}
                                    </span>
                                </div>
                                <p>{row["translated_text"]}</p>
                                {(
                                    <span className="provider-fallback-badge">
                                        Provider fallback
                                    </span>
                                        if row["fallback_used"]
                                        else None
                                )}
                            </div>
                        </article> for row in rows
                    ]}
                </div>
                    if has_rows
                    else <div
                        className={"intelligence-empty intelligence-empty--" + status}
                        role="status"
                    >
                        <h3>
                            {(
                                "Loading translated transcript…"
                                    if loading
                                    else (
                                        "Translation temporarily unavailable"
                                            if status == "recoverable_error"
                                            else "No translated transcript loaded"
                                    )
                            )}
                        </h3>
                        <p>
                            The original consultation remains available while translated rows are loaded from the Jac backend.
                        </p>
                    </div>
            )}
            <div className="intelligence-panel__actions">
                <button
                    className="button button--secondary"
                    type="button"
                    disabled={len(pending_action) > 0}
                    onClick={on_load}
                >
                    {("Loading Translation…" if loading else "Load Translation")}
                </button>
            </div>
        </section>;
}
