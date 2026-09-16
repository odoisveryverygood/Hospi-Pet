"""Screen 3 — backend-supported Verified Encounter Review."""

import from .AssistantSection { AssistantSection }
import from .ResultsProgress { ResultsProgress }
import from .WorkflowNavigation { ResultsNavigation }


def ReviewGroup(title: str, items: list[str], empty_text: str) -> JsxElement {
    return
        <section className="result-review-group">
            <h3>{title}</h3>
            {(
                <ul>{[<li key={item}>{item}</li> for item in items]}</ul>
                    if len(items) > 0
                    else <p>{empty_text}</p>
            )}
        </section>;
}


def:pub ResultsScreen(
    patient: dict[str, str],
    packet_status: str,
    packet: dict[str, any],
    analysis: dict[str, any],
    clinician_note: dict[str, any],
    english_plan: dict[str, any],
    spanish_plan: dict[str, any],
    source_trace: list[dict[str, any]],
    questions: list[dict[str, any]],
    care_gaps: list[dict[str, any]],
    conflicts: list[dict[str, any]],
    stale: bool,
    message_visible: bool,
    on_mascot_activate: any,
    on_back: any,
    on_generate: any
) -> JsxElement {
    loading: bool = packet_status == "loading";
    has_packet: bool = "id" in packet;
    has_analysis: bool = "id" in analysis;

    return
        <div className="results-screen">
            <ResultsProgress
                patient_name={(
                    patient["name"] if "name" in patient else "Synthetic encounter"
                )}
            />
            <AssistantSection
                assistant_state={(
                    "analyzing" if loading else ("complete" if has_packet else "idle")
                )}
                status_text={(
                    "Preparing verified encounter review"
                        if loading
                        else (
                            "Review packet ready"
                                if has_packet
                                else "Waiting for verified analysis"
                        )
                )}
                friendly_message={(
                    "Organizing the backend-verified review packet."
                        if loading
                        else (
                            "The verified encounter review is ready."
                                if has_packet
                                else "Complete verified analysis first."
                        )
                )}
                message_visible={message_visible}
                on_activate={on_mascot_activate}
                is_transitioning={loading}
                is_running={False}
            />
            <section
                className="results-section panel"
                aria-labelledby="results-title"
                aria-busy={loading}
            >
                <div className="results-section__heading">
                    <div>
                        <p className="eyebrow">Screen 3</p>
                        <h1 id="results-title">Verified Encounter Review</h1>
                        <p>
                            Review backend-supported verified information, open items, and unverified drafts without creating a diagnosis in the browser.
                        </p>
                    </div>
                    <span className="results-review-label">
                        Clinician review required
                    </span>
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
                    <div
                        className="result-state result-state--loading"
                        role="status"
                        aria-live="polite"
                    >
                        <span className="result-state__indicator" aria-hidden="true"></span>
                        <div>
                            <h2>Preparing verified encounter review…</h2>
                            <p>
                                The Jac backend is assembling the current evidence-bound packet.
                            </p>
                        </div>
                    </div>
                        if loading
                        else (
                            <div className="final-review-grid">
                                <ReviewGroup
                                    title="Verified"
                                    items={packet["verified_items"]}
                                    empty_text="No verified items were returned."
                                />
                                <ReviewGroup
                                    title="Needs Review"
                                    items={packet["requires_review_items"]}
                                    empty_text="No review items were returned."
                                />
                                <ReviewGroup
                                    title="Unverified Drafts"
                                    items={packet["unverified_items"]}
                                    empty_text="No unverified drafts were returned."
                                />
                                <ReviewGroup
                                    title="Verified Summary"
                                    items={(
                                        [analysis["summary"]["summary"]]
                                            if has_analysis
                                            and analysis["summary"] is not None
                                            else []
                                    )}
                                    empty_text="No current verified summary."
                                />
                                <ReviewGroup
                                    title="Care Gaps"
                                    items={[gap["message"] for gap in care_gaps]}
                                    empty_text="No active care gaps."
                                />
                                <ReviewGroup
                                    title="Clarification Questions"
                                    items={[
                                        question["question"] for question in questions
                                    ]}
                                    empty_text="No clarification questions."
                                />
                                <ReviewGroup
                                    title="Conflicts"
                                    items={[
                                        conflict["explanation"]
                                        for conflict in conflicts
                                    ]}
                                    empty_text="No evidence conflicts."
                                />
                                <ReviewGroup
                                    title="Clinician Note"
                                    items={(
                                        [
                                            clinician_note["confirmed_instructions"],
                                            clinician_note["laboratory_orders"],
                                            clinician_note["referrals"],
                                            clinician_note["follow_up"]
                                        ]
                                            if "id" in clinician_note
                                            else []
                                    )}
                                    empty_text="No clinician note has been generated."
                                />
                                <ReviewGroup
                                    title="English Patient Plan"
                                    items={(
                                        english_plan["checklist"]
                                            if "language" in english_plan
                                            else []
                                    )}
                                    empty_text="No approved English plan."
                                />
                                <ReviewGroup
                                    title="Spanish Patient Plan"
                                    items={(
                                        spanish_plan["checklist"]
                                            if "language" in spanish_plan
                                            else []
                                    )}
                                    empty_text="No approved Spanish plan."
                                />
                                <ReviewGroup
                                    title="Source Tracing"
                                    items={[
                                        str(trace["source_type"]) + ": " + str(
                                            trace["source_excerpt"]
                                        ) for trace in source_trace
                                    ]}
                                    empty_text="Load a source trace from Verified Intelligence."
                                />
                                <div className="evidence-boundary">
                                    <div>
                                        <strong>Graph version</strong>
                                        <span>{str(packet["graph_version"])}</span>
                                    </div>
                                    <div>
                                        <strong>Source facts</strong>
                                        <span>
                                            {str(len(packet["source_fact_ids"]))}
                                        </span>
                                    </div>
                                    <div>
                                        <strong>Status</strong>
                                        <span>For clinician review only</span>
                                    </div>
                                </div>
                            </div>
                                if has_packet
                                else <div
                                    className={"result-state " + (
                                        "result-state--error"
                                            if packet_status == "recoverable_error"
                                            else "result-state--missing"
                                    )}
                                    role="status"
                                >
                                    <div>
                                        <h2>
                                            {(
                                                "We couldn’t load the review packet."
                                                    if packet_status == "recoverable_error"
                                                    else "Complete verified analysis to create the review packet."
                                            )}
                                        </h2>
                                        <p>
                                            No diagnosis or fabricated result is shown when the backend has not returned a packet.
                                        </p>
                                    </div>
                                    <button
                                        className="button button--primary"
                                        type="button"
                                        disabled={not has_analysis or stale}
                                        onClick={on_generate}
                                    >
                                        Generate Final Review
                                    </button>
                                </div>
                        )
                )}
                <p className="results-section__disclaimer">
                    Hospi-Pet organizes backend-returned information. It does not confirm a diagnosis or replace professional judgment.
                </p>
            </section>
            <ResultsNavigation on_back={on_back}/>
        </div>;
}
