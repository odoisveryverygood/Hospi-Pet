"""Frontend-only candidate fact verification section."""

import from .FactCard { FactCard }
import from .MultimodalState { decisionFor }


def:pub CandidateFactsSection(
    facts: list[dict[str, any]],
    decisions: dict[str, str],
    source_metadata: dict[str, dict[str, str]],
    trace_message: str,
    is_transitioning: bool,
    on_accept: any,
    on_reject: any,
    on_trace: any
) -> JsxElement {
    facts_visible: bool = len(facts) > 0;
    badge_text: str = (
        str(len(facts)) + " facts"
            if facts_visible
            else ("Analyzing" if is_transitioning else "Not loaded")
    );

    return
        <section
            className="panel candidate-section"
            aria-labelledby="candidate-heading"
            aria-busy={is_transitioning and not facts_visible}
        >
            <div className="section-heading">
                <div>
                    <p className="eyebrow">Verification queue</p>
                    <h2 id="candidate-heading">Unverified candidate facts</h2>
                </div>
                <span
                    className={"section-chip " + (
                        "" if facts_visible else "section-chip--muted"
                    )}
                >
                    {badge_text}
                </span>
            </div>
            <p className="candidate-section__intro">
                Confidence reflects extraction certainty, not medical correctness. Clinician verification is required.
            </p>
            {(
                <p className="trace-message" role="status" aria-live="polite">
                    {trace_message}
                </p>
                    if len(trace_message) > 0
                    else None
            )}
            {(
                <div className="fact-grid">
                    {[
                        <FactCard
                            key={fact["id"]}
                            fact={fact}
                            decision={decisionFor(decisions, fact["id"])}
                            source_metadata={source_metadata}
                            on_accept={on_accept}
                            on_reject={on_reject}
                            on_trace={on_trace}
                        /> for fact in facts
                    ]}
                </div>
                    if facts_visible
                    else <div
                        className={"candidate-empty " + (
                            "candidate-empty--loading" if is_transitioning else ""
                        )}
                    >
                        <div>
                            <h3>
                                {(
                                    "Reviewing the consultation"
                                        if is_transitioning
                                        else "No facts to verify"
                                )}
                            </h3>
                            <p>
                                {(
                                    "Candidate facts will appear after Hospi-Pet reviews the conversation."
                                        if is_transitioning
                                        else "Load the sample encounter to begin clinician verification."
                                )}
                            </p>
                        </div>
                    </div>
            )}
        </section>;
}
