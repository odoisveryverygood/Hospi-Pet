"""One structured summary containing accepted Screen 1 facts only."""

import from .Screen1State { acceptedFactValue, verifiedFactCount }


def:pub VerifiedPatientSummary(
    patient: dict[str, str], facts: list[dict[str, str]], decisions: dict[str, str]
) -> JsxElement {
    symptom: str = acceptedFactValue(facts, decisions, "fact-symptom");
    duration: str = acceptedFactValue(facts, decisions, "fact-duration");
    pain: str = acceptedFactValue(facts, decisions, "fact-pain");
    medication: str = acceptedFactValue(facts, decisions, "fact-medication");
    allergy: str = acceptedFactValue(facts, decisions, "fact-allergy");
    history: str = acceptedFactValue(facts, decisions, "fact-history");
    verified_count: int = verifiedFactCount(facts, decisions);

    return
        <section
            className="panel verified-summary"
            aria-labelledby="verified-summary-heading"
        >
            <div className="section-heading">
                <div>
                    <p className="eyebrow">Accepted information only</p>
                    <h2 id="verified-summary-heading">Verified Patient Summary</h2>
                </div>
                <span className="section-chip">{str(verified_count)} verified</span>
            </div>
            <div className="verified-summary__lead">
                <p>Patient</p>
                <strong>{patient["name"]}</strong>
                <span>Main complaint</span>
                <h3>{symptom}</h3>
            </div>
            <dl className="verified-summary__clinical">
                <div>
                    <dt>Confirmed symptoms</dt>
                    <dd>{symptom}</dd>
                </div>
                <div>
                    <dt>Symptom duration</dt>
                    <dd>{duration}</dd>
                </div>
                <div>
                    <dt>Pain level</dt>
                    <dd>{pain}</dd>
                </div>
            </dl>
            <dl className="verified-summary__details">
                <div>
                    <dt>Medications</dt>
                    <dd>{medication}</dd>
                </div>
                <div>
                    <dt>Allergies</dt>
                    <dd>{allergy}</dd>
                </div>
                <div>
                    <dt>Relevant medical history</dt>
                    <dd>{history}</dd>
                </div>
            </dl>
        </section>;
}
