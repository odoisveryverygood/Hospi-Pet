"""Frontend-only navigation between implemented Hospi-Pet screens."""

def:pub VerificationNavigation(can_continue: bool, on_continue: any) -> JsxElement {
    return
        <nav
            className="workflow-navigation workflow-navigation--verification"
            aria-label="Screen navigation"
        >
            <div>
                <p>Next step</p>
                <span>Review accepted facts and identify missing information.</span>
            </div>
            <button
                className="button button--primary"
                type="button"
                disabled={not can_continue}
                onClick={on_continue}
            >
                Continue to Clinical Insights
            </button>
        </nav>;
}


def:pub InsightsNavigation(
    can_continue: bool, on_back: any, on_continue: any
) -> JsxElement {
    return
        <nav className="workflow-navigation" aria-label="Screen navigation">
            <button
                className="button button--secondary"
                type="button"
                onClick={on_back}
            >
                Back to Verification
            </button>
            <div className="workflow-navigation__future">
                <button
                    className="button button--primary"
                    type="button"
                    aria-describedby="results-status"
                    disabled={not can_continue}
                    onClick={on_continue}
                >
                    Continue to Verified Review
                </button>
                <span id="results-status">
                    {(
                        "Open the backend-supported review"
                            if can_continue
                            else "Accept encounter evidence to continue"
                    )}
                </span>
            </div>
        </nav>;
}


def:pub ResultsNavigation(on_back: any) -> JsxElement {
    return
        <nav className="workflow-navigation" aria-label="Screen navigation">
            <button
                className="button button--secondary"
                type="button"
                onClick={on_back}
            >
                Back to Clinical Insights
            </button>
            <div className="workflow-navigation__future">
                <button
                    className="button button--primary"
                    type="button"
                    aria-describedby="encounter-completion-status"
                    disabled={True}
                >
                    Complete Encounter
                </button>
                <span id="encounter-completion-status">
                    Completion workflow not implemented
                </span>
            </div>
        </nav>;
}
