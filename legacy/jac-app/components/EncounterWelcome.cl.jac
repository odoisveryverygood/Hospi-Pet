"""Polished initial state before a synthetic encounter is loaded."""

def:pub EncounterWelcome -> JsxElement {
    return
        <section className="encounter-welcome" aria-labelledby="welcome-heading">
            <div className="encounter-welcome__content">
                <p className="eyebrow">Hospi-Pet workflow</p>
                <h1 id="welcome-heading">Live Encounter</h1>
                <p>
                    Capture a consultation or synthetic document, then verify every candidate before it enters the visit-note preview.
                </p>
            </div>
            <ol className="welcome-steps" aria-label="Demo workflow">
                <li><span>01</span> Capture sources</li>
                <li><span>02</span> Review candidates</li>
                <li><span>03</span> Verify visit note</li>
            </ol>
        </section>;
}
