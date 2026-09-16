"""Three-way final review packet separation required by the contract."""

def FinalReviewGroup(title: str, tone: str, items: list[str]) -> JsxElement {
    return
        <section className={"final-review-group final-review-group--" + tone}>
            <div>
                <h3>{title}</h3>
                <span>{str(len(items))}</span>
            </div>
            {(
                <ul>{[<li key={item}>{item}</li> for item in items]}</ul>
                    if len(items) > 0
                    else <p>No items returned in this category.</p>
            )}
        </section>;
}


def:pub FinalReview(
    packet: dict[str, any],
    status: str,
    stale: bool,
    pending_action: str,
    error_message: str,
    on_generate: any
) -> JsxElement {
    has_packet: bool = "id" in packet;
    loading: bool = status == "loading";

    return
        <section
            className="panel intelligence-panel final-review"
            aria-labelledby="final-review-heading"
        >
            <div className="section-heading">
                <div>
                    <p className="eyebrow">Evidence separation</p>
                    <h2 id="final-review-heading">Final Review</h2>
                </div>
                <button
                    className="button button--secondary"
                    type="button"
                    disabled={stale or len(pending_action) > 0}
                    onClick={on_generate}
                >
                    {("Preparing…" if loading else "Prepare Final Review")}
                </button>
            </div>
            {(
                <div className="stale-analysis-warning" role="alert">
                    <strong>
                        New verified information is available. Re-run analysis.
                    </strong>
                </div>
                    if stale
                    else None
            )}
            {(
                <div className="final-review-grid">
                    <FinalReviewGroup
                        title="Verified"
                        tone="verified"
                        items={packet["verified_items"]}
                    />
                    <FinalReviewGroup
                        title="Needs Review"
                        tone="review"
                        items={packet["requires_review_items"]}
                    />
                    <FinalReviewGroup
                        title="Unverified Drafts"
                        tone="draft"
                        items={packet["unverified_items"]}
                    />
                </div>
                    if has_packet
                    else <div
                        className={"intelligence-empty intelligence-empty--" + status}
                        role="status"
                    >
                        <h3>
                            {(
                                "Preparing final review…"
                                    if loading
                                    else (
                                        "Final review could not be prepared"
                                            if status == "recoverable_error"
                                            else "No final review packet"
                                    )
                            )}
                        </h3>
                        <p>
                            {(
                                error_message
                                    if len(error_message) > 0
                                    else "Run a current verified analysis before preparing final review."
                            )}
                        </p>
                    </div>
            )}
        </section>;
}
