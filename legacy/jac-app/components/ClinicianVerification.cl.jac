"""Evidence-first verification with original and translated sentences."""

import from .IntelligenceState { translatedSource }
import from .MultimodalState { decisionFor }


def:pub ClinicianVerification(
    candidates: list[dict[str, any]],
    decisions: dict[str, str],
    translated_rows: list[dict[str, any]],
    pending_action: str,
    on_accept: any,
    on_reject: any
) -> JsxElement {
    return
        <section
            className="panel intelligence-panel clinician-verification"
            aria-labelledby="clinician-verification-heading"
        >
            <div className="section-heading">
                <div>
                    <p className="eyebrow">Evidence before analysis</p>
                    <h2 id="clinician-verification-heading">Clinician Verification</h2>
                </div>
                <span className="section-chip">{str(len(candidates))} candidates</span>
            </div>
            {(
                <div className="verification-list">
                    {[
                        <article
                            className={"verification-row verification-row--" + decisionFor(
                                decisions, candidate["id"]
                            )}
                            key={candidate["id"]}
                        >
                            <div className="verification-row__value">
                                <span>{candidate["category"].replace("_", " ")}</span>
                                <h3>{candidate["value"]}</h3>
                            </div>
                            <div className="verification-row__evidence">
                                <div>
                                    <strong>Source sentence</strong>
                                    <p>{candidate["source_text"]}</p>
                                </div>
                                <div>
                                    <strong>Translated sentence</strong>
                                    <p>
                                        {translatedSource(
                                            translated_rows, candidate["source_text"]
                                        )}
                                    </p>
                                </div>
                            </div>
                            <div className="verification-row__decision">
                                <span
                                    className={"verification-state verification-state--" + decisionFor(
                                        decisions, candidate["id"]
                                    )}
                                    role="status"
                                >
                                    {decisionFor(decisions, candidate["id"]).replace(
                                        "_", " "
                                    )}
                                </span>
                                <div>
                                    <button
                                        className="decision-button decision-button--accept"
                                        type="button"
                                        disabled={len(pending_action) > 0}
                                        aria-pressed={decisionFor(
                                            decisions, candidate["id"]
                                        ) == "accepted"}
                                        onClick={lambda (_e: MouseEvent) { on_accept(
                                            candidate["id"]
                                        ); }}
                                    >
                                        Accept
                                    </button>
                                    <button
                                        className="decision-button decision-button--reject"
                                        type="button"
                                        disabled={len(pending_action) > 0}
                                        aria-pressed={decisionFor(
                                            decisions, candidate["id"]
                                        ) == "rejected"}
                                        onClick={lambda (_e: MouseEvent) { on_reject(
                                            candidate["id"]
                                        ); }}
                                    >
                                        Reject
                                    </button>
                                </div>
                            </div>
                        </article> for candidate in candidates
                    ]}
                </div>
                    if len(candidates) > 0
                    else <div className="intelligence-empty">
                        <h3>No candidates awaiting verification</h3>
                        <p>Load the backend-provided encounter to begin.</p>
                    </div>
            )}
        </section>;
}
