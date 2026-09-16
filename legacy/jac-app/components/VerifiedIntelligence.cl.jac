"""Verified-only intelligence workspace backed by Jac graph actions."""

import from .SuggestedQuestions { SuggestedQuestions }


def IntelligenceStringList(heading: str, items: list[str]) -> JsxElement {
    return
        <section className="intelligence-list">
            <h4>{heading}</h4>
            {(
                <ul>{[<li key={item}>{item}</li> for item in items]}</ul>
                    if len(items) > 0
                    else <p>None returned by the Jac backend.</p>
            )}
        </section>;
}


def:pub VerifiedIntelligence(
    status: str,
    analysis: dict[str, any],
    clinician_note: dict[str, any],
    final_review: dict[str, any],
    source_trace: list[dict[str, any]],
    trace_status: str,
    questions: list[dict[str, any]],
    question_states: dict[str, str],
    pending_question_id: str,
    detail_question_id: str,
    detail_mode: str,
    active_tab: str,
    stale: bool,
    can_analyze: bool,
    pending_action: str,
    error_message: str,
    on_analyze: any,
    on_tab: any,
    on_trace: any,
    on_dismiss_question: any,
    on_answer_question: any,
    on_question_detail: any,
    care_gap_status: str,
    care_gaps: list[dict[str, any]],
    patient_plan_status: str,
    english_patient_plan: dict[str, any],
    spanish_patient_plan: dict[str, any],
    patient_audio_status: str,
    patient_audio_script: dict[str, any],
    audit_status: str,
    audit_conflicts: list[dict[str, any]],
    on_check_gaps: any,
    on_resolve_gap: any,
    on_generate_plans: any,
    on_generate_audio: any,
    on_play_audio: any,
    on_run_audit: any,
    on_add_contradiction: any
) -> JsxElement {
    has_analysis: bool = "id" in analysis;
    loading: bool = status == "loading";
    tabs: list[dict[str, str]] = [
        {"id": "summary", "label": "Verified Summary"},
        {"id": "gaps", "label": "Care Gaps"},
        {"id": "questions", "label": "Suggested Questions"},
        {"id": "conflicts", "label": "Conflicts"},
        {"id": "note", "label": "Clinician Note"},
        {"id": "plan", "label": "Patient Plan"},
        {"id": "trace", "label": "Source Trace"}
    ];

    return
        <section
            className="panel intelligence-panel verified-intelligence"
            aria-labelledby="verified-intelligence-heading"
        >
            <div className="section-heading">
                <div>
                    <p className="eyebrow">Accepted evidence only</p>
                    <h2 id="verified-intelligence-heading">Verified Intelligence</h2>
                </div>
                <span className="verified-status">Live Jac graph</span>
            </div>
            <div className="analysis-action-row" aria-label="Jac care workflow actions">
                <button
                    className="button button--secondary"
                    type="button"
                    disabled={len(pending_action) > 0}
                    onClick={on_check_gaps}
                >
                    {(
                        "Checking…"
                            if care_gap_status == "loading"
                            else "Check Care Gaps"
                    )}
                </button>
                <button
                    className="button button--secondary"
                    type="button"
                    disabled={len(pending_action) > 0 or len(care_gaps) == 0}
                    onClick={on_resolve_gap}
                >
                    Resolve First Gap
                </button>
                <button
                    className="button button--secondary"
                    type="button"
                    disabled={len(pending_action) > 0 or len(care_gaps) > 0}
                    onClick={on_generate_plans}
                >
                    {(
                        "Generating…"
                            if patient_plan_status == "loading"
                            else "Generate English + Spanish Plans"
                    )}
                </button>
                <button
                    className="button button--secondary"
                    type="button"
                    disabled={len(pending_action) > 0
                    or "language" not in spanish_patient_plan}
                    onClick={on_generate_audio}
                >
                    Generate Patient Script
                </button>
                <button
                    className="button button--secondary"
                    type="button"
                    disabled={"text" not in patient_audio_script}
                    onClick={on_play_audio}
                >
                    Play Spanish Script
                </button>
                <button
                    className="button button--secondary"
                    type="button"
                    disabled={len(pending_action) > 0}
                    onClick={on_run_audit}
                >
                    {(
                        "Auditing…"
                            if audit_status == "loading"
                            else "Run Evidence Audit"
                    )}
                </button>
                <button
                    className="button button--secondary"
                    type="button"
                    disabled={len(pending_action) > 0}
                    onClick={on_add_contradiction}
                >
                    Add Synthetic Contradiction
                </button>
            </div>
            <div className="analysis-action-row">
                <div>
                    <p>
                        Analysis uses only clinician-accepted information returned by the documented Jac action.
                    </p>
                    <span>Pending and rejected candidates remain excluded.</span>
                </div>
                <button
                    className="button button--primary analyze-button"
                    type="button"
                    disabled={not can_analyze or len(pending_action) > 0}
                    onClick={on_analyze}
                >
                    {("Analyzing…" if loading else "Analyze Accepted Information")}
                </button>
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
                <div className="provider-fallback-notice" role="status">
                    Deterministic provider fallback is shown and remains reviewable.
                </div>
                    if status == "provider_fallback"
                    else None
            )}
            {(
                <div className="intelligence-inline-error" role="alert">
                    {error_message}
                </div>
                    if len(error_message) > 0 and has_analysis
                    else None
            )}
            {(
                <div className="analysis-workspace">
                    <nav
                        className="intelligence-tabs"
                        aria-label="Verified intelligence views"
                    >
                        {[
                            <button
                                key={tab["id"]}
                                type="button"
                                className={"intelligence-tab " + (
                                    "intelligence-tab--active"
                                        if active_tab == tab["id"]
                                        else ""
                                )}
                                aria-pressed={active_tab == tab["id"]}
                                onClick={lambda (_e: MouseEvent) { on_tab(tab["id"]); }}
                            >
                                {tab["label"]}
                            </button> for tab in tabs
                        ]}
                    </nav>
                    <div className="intelligence-tab-panel">
                        {(
                            <div className="verified-summary-view">
                                <p className="verified-summary-view__lead">
                                    {analysis["summary"]["summary"]}
                                </p>
                                <div className="verified-summary-grid">
                                    <IntelligenceStringList
                                        heading="Medications"
                                        items={analysis["summary"]["medications"]}
                                    />
                                    <IntelligenceStringList
                                        heading="Laboratory orders"
                                        items={analysis["summary"]["laboratory_orders"]}
                                    />
                                    <IntelligenceStringList
                                        heading="Referrals"
                                        items={analysis["summary"]["referrals"]}
                                    />
                                    <IntelligenceStringList
                                        heading="Follow-ups"
                                        items={analysis["summary"]["follow_ups"]}
                                    />
                                    <IntelligenceStringList
                                        heading="Outstanding tasks"
                                        items={analysis["summary"]["outstanding_tasks"]}
                                    />
                                </div>
                                <div className="evidence-boundary">
                                    <div>
                                        <strong>Accepted evidence</strong>
                                        <span>
                                            {str(
                                                len(analysis["accepted_fact_ids"])
                                            )} facts
                                        </span>
                                    </div>
                                    <div>
                                        <strong>Rejected evidence excluded</strong>
                                        <span>
                                            {str(
                                                len(
                                                    analysis[
                                                        "rejected_fact_ids_excluded"
                                                    ]
                                                )
                                            )} facts
                                        </span>
                                    </div>
                                    <div>
                                        <strong>Mode</strong>
                                        <span>{analysis["model_mode"]}</span>
                                    </div>
                                </div>
                            </div>
                                if active_tab == "summary"
                                else (
                                    <div>
                                        <IntelligenceStringList
                                            heading="Active care gaps"
                                            items={[
                                                gap["message"]
                                                for gap in (
                                                    care_gaps
                                                        if care_gap_status != "empty"
                                                        else analysis["care_gaps"]
                                                )
                                            ]}
                                        />
                                    </div>
                                        if active_tab == "gaps"
                                        else (
                                            <SuggestedQuestions
                                                questions={questions}
                                                question_states={question_states}
                                                pending_question_id={pending_question_id}
                                                detail_question_id={detail_question_id}
                                                detail_mode={detail_mode}
                                                on_dismiss={on_dismiss_question}
                                                on_answered={on_answer_question}
                                                on_detail={on_question_detail}
                                            />
                                                if active_tab == "questions"
                                                else (
                                                    <IntelligenceStringList
                                                        heading="Conflicts"
                                                        items={[
                                                            conflict["explanation"]
                                                            for conflict in (
                                                                audit_conflicts
                                                                    if audit_status != "empty"
                                                                    else analysis[
                                                                        "conflicts"
                                                                    ]
                                                            )
                                                        ]}
                                                    />
                                                        if active_tab == "conflicts"
                                                        else (
                                                            <div
                                                                className="clinician-note-view"
                                                            >
                                                                {(
                                                                    <div>
                                                                        <span
                                                                            className="unverified-draft-badge"
                                                                        >
                                                                            {clinician_note[
                                                                                "status"
                                                                            ]}
                                                                        </span>
                                                                        <h3>
                                                                            Clinician Note
                                                                        </h3>
                                                                        <dl>
                                                                            <div>
                                                                                <dt>
                                                                                    Confirmed instructions
                                                                                </dt>
                                                                                <dd>
                                                                                    {clinician_note[
                                                                                        "confirmed_instructions"
                                                                                    ]}
                                                                                </dd>
                                                                            </div>
                                                                            <div>
                                                                                <dt>
                                                                                    Laboratory orders
                                                                                </dt>
                                                                                <dd>
                                                                                    {clinician_note[
                                                                                        "laboratory_orders"
                                                                                    ]}
                                                                                </dd>
                                                                            </div>
                                                                            <div>
                                                                                <dt>
                                                                                    Referrals
                                                                                </dt>
                                                                                <dd>
                                                                                    {clinician_note[
                                                                                        "referrals"
                                                                                    ]}
                                                                                </dd>
                                                                            </div>
                                                                            <div>
                                                                                <dt>
                                                                                    Follow-up
                                                                                </dt>
                                                                                <dd>
                                                                                    {clinician_note[
                                                                                        "follow_up"
                                                                                    ]}
                                                                                </dd>
                                                                            </div>
                                                                        </dl>
                                                                    </div>
                                                                        if "id" in clinician_note
                                                                        else <div
                                                                            className="intelligence-empty"
                                                                        >
                                                                            <h3>
                                                                                No clinician note generated
                                                                            </h3>
                                                                            <p>
                                                                                Use Generate Note in the nine-section editor above.
                                                                            </p>
                                                                        </div>
                                                                )}
                                                            </div>
                                                                if active_tab == "note"
                                                                else (
                                                                    <div
                                                                        className="patient-plan-view"
                                                                    >
                                                                        {(
                                                                            <div>
                                                                                <h3>
                                                                                    Patient Plan
                                                                                </h3>
                                                                                <ul>
                                                                                    {[
                                                                                        <li
                                                                                            key={item}
                                                                                        >
                                                                                            {item}
                                                                                        </li>
                                                                                        for item in english_patient_plan[
                                                                                            "checklist"
                                                                                        ]
                                                                                    ]}
                                                                                </ul>
                                                                            </div>
                                                                                if "language" in english_patient_plan
                                                                                else <div
                                                                                    className="intelligence-empty"
                                                                                >
                                                                                    <h3>
                                                                                        No current patient plan
                                                                                    </h3>
                                                                                    <p>
                                                                                        Resolve active gaps, then generate both plans.
                                                                                    </p>
                                                                                </div>
                                                                        )}{(
                                                                            <div>
                                                                                <h3>
                                                                                    Plan para el paciente
                                                                                </h3>
                                                                                <ul>
                                                                                    {[
                                                                                        <li
                                                                                            key={item}
                                                                                        >
                                                                                            {item}
                                                                                        </li>
                                                                                        for item in spanish_patient_plan[
                                                                                            "checklist"
                                                                                        ]
                                                                                    ]}
                                                                                </ul>
                                                                            </div>
                                                                                if "language" in spanish_patient_plan
                                                                                else None
                                                                        )}{(
                                                                            <p
                                                                                className="provider-fallback-notice"
                                                                            >
                                                                                Approved browser speech script is ready.
                                                                            </p>
                                                                                if patient_audio_status == "success"
                                                                                else None
                                                                        )}
                                                                    </div>
                                                                        if active_tab == "plan"
                                                                        else <div
                                                                            className="source-trace-view"
                                                                        >
                                                                            <button
                                                                                className="button button--secondary"
                                                                                type="button"
                                                                                disabled={len(
                                                                                    pending_action
                                                                                ) > 0}
                                                                                onClick={on_trace}
                                                                            >
                                                                                {(
                                                                                    "Tracing…"
                                                                                        if trace_status == "loading"
                                                                                        else "Load Source Trace"
                                                                                )}
                                                                            </button>
                                                                            {[
                                                                                <article
                                                                                    className="trace-chain"
                                                                                    key={trace[
                                                                                        "item_id"
                                                                                    ]}
                                                                                >
                                                                                    <div>
                                                                                        <strong>
                                                                                            {trace[
                                                                                                "source_type"
                                                                                            ]}
                                                                                        </strong>
                                                                                        <span>
                                                                                            {(
                                                                                                "Complete"
                                                                                                    if trace[
                                                                                                        "complete"
                                                                                                    ]
                                                                                                    else "Incomplete"
                                                                                            )}
                                                                                        </span>
                                                                                    </div>
                                                                                    <blockquote>
                                                                                        {trace[
                                                                                            "source_excerpt"
                                                                                        ]}
                                                                                    </blockquote>
                                                                                    <ol>
                                                                                        {[
                                                                                            <li
                                                                                                key={str(
                                                                                                    step[
                                                                                                        "order"
                                                                                                    ]
                                                                                                )}
                                                                                            >
                                                                                                {step[
                                                                                                    "human_explanation"
                                                                                                ]}
                                                                                            </li>
                                                                                            for step in trace[
                                                                                                "ordered_steps"
                                                                                            ]
                                                                                        ]}
                                                                                    </ol>
                                                                                </article>
                                                                                for trace in source_trace
                                                                            ]}
                                                                        </div>
                                                                )
                                                        )
                                                )
                                        )
                                )
                        )}
                    </div>
                </div>
                    if has_analysis
                    else <div
                        className={"intelligence-empty intelligence-empty--" + status}
                        role="status"
                    >
                        <h3>
                            {(
                                "Analyzing accepted information…"
                                    if loading
                                    else (
                                        "Analysis needs attention"
                                            if status == "recoverable_error"
                                            else "No verified analysis yet"
                                    )
                            )}
                        </h3>
                        <p>
                            {(
                                error_message
                                    if len(error_message) > 0
                                    else "Accept at least one candidate, then run the prepared analysis."
                            )}
                        </p>
                    </div>
            )}
        </section>;
}
