"""Compact accessible progress indicator for the three-screen workflow."""

def:pub EncounterProgress(patient_name: str) -> JsxElement {
    return
        <section className="insights-context" aria-labelledby="insights-patient">
            <div>
                <p className="eyebrow">Current patient</p>
                <h2 id="insights-patient">{patient_name}</h2>
            </div>
            <nav className="encounter-progress" aria-label="Encounter progress">
                <ol>
                    <li
                        className="encounter-progress__step encounter-progress__step--complete"
                    >
                        <span className="encounter-progress__marker" aria-hidden="true">
                            ✓
                        </span>
                        <span>
                            <strong>Encounter &amp; Verification</strong>
                            <small>Complete</small>
                        </span>
                    </li>
                    <li
                        className="encounter-progress__step encounter-progress__step--current"
                        aria-current="step"
                    >
                        <span className="encounter-progress__marker" aria-hidden="true">
                            2
                        </span>
                        <span>
                            <strong>Clinical Insights</strong>
                            <small>Current</small>
                        </span>
                    </li>
                    <li className="encounter-progress__step">
                        <span className="encounter-progress__marker" aria-hidden="true">
                            3
                        </span>
                        <span>
                            <strong>Verified Encounter Review</strong>
                            <small>Upcoming</small>
                        </span>
                    </li>
                </ol>
            </nav>
        </section>;
}
