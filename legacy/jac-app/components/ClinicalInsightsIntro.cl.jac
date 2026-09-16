"""Screen 2 title and verified encounter context."""

def:pub ClinicalInsightsIntro -> JsxElement {
    return
        <section
            className="encounter-welcome insights-intro"
            aria-labelledby="insights-title"
        >
            <div className="encounter-welcome__content">
                <p className="eyebrow">Hospi-Pet workflow</p>
                <h1 id="insights-title">Clinical Insights</h1>
                <p>
                    Confirm the accepted evidence boundary before opening the backend-supported encounter review.
                </p>
            </div>
        </section>;
}
