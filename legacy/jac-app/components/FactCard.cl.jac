"""One frontend-only candidate fact verification card."""

import from .MultimodalState { candidateSourceId }


def:pub FactCard(
    fact: dict[str, any],
    decision: str,
    source_metadata: dict[str, dict[str, str]],
    on_accept: any,
    on_reject: any,
    on_trace: any
) -> JsxElement {
    category_label: str = fact["category"].replace("_", " ");
    confidence_percent: str = str(round(fact["confidence"] * 100));
    source_id: str = candidateSourceId(fact);
    source_label: str = (
        source_metadata[source_id]["source_label"]
            if source_id in source_metadata
            else "Consultation transcript"
    );
    source_type: str = (
        source_metadata[source_id]["source_type"]
            if source_id in source_metadata
            else "Live transcript"
    );
    status_label: str = (
        "Accepted"
            if decision == "accepted"
            else ("Rejected" if decision == "rejected" else "Unverified")
    );
    status_symbol: str = (
        "✓" if decision == "accepted" else ("×" if decision == "rejected" else "○")
    );

    return
        <article className={"fact-card fact-card--" + decision}>
            <div className="fact-card__topline">
                <span className="fact-card__category">{category_label}</span>
                <span
                    className={"fact-card__status fact-card__status--" + decision}
                    role="status"
                >
                    <span aria-hidden="true">{status_symbol}</span>
                    {status_label}
                </span>
            </div>
            <h3>{fact["value"]}</h3>
            <div className="fact-card__source">
                <p>{source_type + " · " + source_label}</p>
                <blockquote>“{fact["source_text"]}”</blockquote>
            </div>
            <div
                className="confidence"
                aria-label={"Extraction confidence " + confidence_percent + " percent"}
            >
                <div className="confidence__label">
                    <span>Extraction confidence</span>
                    <strong>{confidence_percent}%</strong>
                </div>
                <div className="confidence__track">
                    <span style={{"width": confidence_percent + "%"}}></span>
                </div>
            </div>
            <div className="fact-card__actions">
                <button
                    className="decision-button decision-button--accept"
                    type="button"
                    aria-label={"Accept " + category_label + ": " + fact["value"]}
                    aria-pressed={decision == "accepted"}
                    onClick={lambda (e: MouseEvent) { on_accept(fact["id"]); }}
                >
                    <span aria-hidden="true">✓</span>
                    Accept
                </button>
                <button
                    className="decision-button decision-button--reject"
                    type="button"
                    aria-label={"Reject " + category_label + ": " + fact["value"]}
                    aria-pressed={decision == "rejected"}
                    onClick={lambda (e: MouseEvent) { on_reject(fact["id"]); }}
                >
                    <span aria-hidden="true">×</span>
                    Reject
                </button>
                <button
                    className="trace-button"
                    type="button"
                    onClick={lambda (e: MouseEvent) { on_trace(source_id); }}
                >
                    Trace to Source
                </button>
            </div>
        </article>;
}
