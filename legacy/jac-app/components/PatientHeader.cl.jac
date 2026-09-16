"""Synthetic patient and encounter context for Screen 1."""

def:pub PatientHeader(patient: dict[str, str]) -> JsxElement {
    return
        <section className="patient-header" aria-labelledby="patient-heading">
            <div className="patient-header__identity">
                <div className="patient-header__context">
                    <p className="eyebrow">Current encounter</p>
                    <div className="review-ready" role="status">
                        <span
                            className="status-dot status-dot--ready"
                            aria-hidden="true"
                        ></span>
                        <span>{patient["review_status"]}</span>
                    </div>
                </div>
                <h1 id="patient-heading">{patient["name"]}</h1>
                <div className="patient-header__summary">
                    <span>{patient["encounter_type"]}</span>
                    <span aria-hidden="true">•</span>
                    <span>{patient["consultation_status"]}</span>
                </div>
                <p className="patient-header__note">
                    Fictional patient record for demonstration only
                </p>
            </div>
            <div className="patient-header__details">
                <dl className="encounter-meta">
                    <div className="encounter-meta__item">
                        <dt>Visit ID</dt>
                        <dd>{patient["visit_id"]}</dd>
                    </div>
                    <div className="encounter-meta__item">
                        <dt>Date</dt>
                        <dd>{patient["encounter_date"]}</dd>
                    </div>
                </dl>
            </div>
        </section>;
}
