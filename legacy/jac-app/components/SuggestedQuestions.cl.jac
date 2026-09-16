"""Clinician-controlled question review from backend DTOs."""

def:pub SuggestedQuestions(
    questions: list[dict[str, any]],
    question_states: dict[str, str],
    pending_question_id: str,
    detail_question_id: str,
    detail_mode: str,
    on_dismiss: any,
    on_answered: any,
    on_detail: any
) -> JsxElement {
    return
        <section
            className="suggested-questions"
            aria-labelledby="suggested-questions-heading"
        >
            <div className="intelligence-subheading">
                <div>
                    <h3 id="suggested-questions-heading">Suggested Questions</h3>
                    <p>Clinician-only prompts grounded in accepted facts.</p>
                </div>
                <span>{str(len(questions))} questions</span>
            </div>
            {(
                <div className="suggested-question-list">
                    {[
                        <article className="suggested-question" key={question["id"]}>
                            <div className="suggested-question__heading">
                                <div>
                                    <span className="clinician-only-badge">
                                        Clinician only
                                    </span>
                                    <h4>{question["question"]}</h4>
                                </div>
                                <span
                                    className={"question-status question-status--" + (
                                        question_states[question["id"]]
                                            if question["id"] in question_states
                                            else question["status"]
                                    )}
                                >
                                    {(
                                        question_states[question["id"]]
                                            if question["id"] in question_states
                                            else question["status"]
                                    )}
                                </span>
                            </div>
                            {(
                                <div className="suggested-question__detail">
                                    {(
                                        <div>
                                            <strong>Related source</strong>
                                            <div className="source-id-list">
                                                {[
                                                    <code key={source_id}>
                                                        {source_id}
                                                    </code>
                                                    for source_id in question[
                                                        "source_fact_ids"
                                                    ]
                                                ]}
                                            </div>
                                        </div>
                                            if detail_mode == "source"
                                            else <div>
                                                <strong>Why it was generated</strong>
                                                <p>{question["explanation"]}</p>
                                                <div className="source-id-list">
                                                    {[
                                                        <code key={gap_id}>
                                                            {gap_id}
                                                        </code>
                                                        for gap_id in question[
                                                            "related_gap_ids"
                                                        ]
                                                    ]}
                                                </div>
                                            </div>
                                    )}
                                </div>
                                    if detail_question_id == question["id"]
                                    else None
                            )}
                            <div className="suggested-question__actions">
                                <button
                                    className="button button--secondary"
                                    type="button"
                                    disabled={len(pending_question_id) > 0}
                                    onClick={lambda (_e: MouseEvent) { on_dismiss(
                                        question["id"]
                                    ); }}
                                >
                                    {(
                                        "Updating…"
                                            if pending_question_id == question["id"]
                                            else "Dismiss"
                                    )}
                                </button>
                                <button
                                    className="button button--secondary"
                                    type="button"
                                    disabled={len(pending_question_id) > 0}
                                    onClick={lambda (_e: MouseEvent) { on_answered(
                                        question["id"]
                                    ); }}
                                >
                                    Mark Answered
                                </button>
                                <button
                                    className="text-action"
                                    type="button"
                                    aria-expanded={detail_question_id == question["id"]
                                    and detail_mode == "source"}
                                    onClick={lambda (_e: MouseEvent) { on_detail(
                                        question["id"], "source"
                                    ); }}
                                >
                                    Show Related Source
                                </button>
                                <button
                                    className="text-action"
                                    type="button"
                                    aria-expanded={detail_question_id == question["id"]
                                    and detail_mode == "why"}
                                    onClick={lambda (_e: MouseEvent) { on_detail(
                                        question["id"], "why"
                                    ); }}
                                >
                                    Show Why It Was Generated
                                </button>
                            </div>
                        </article> for question in questions
                    ]}
                </div>
                    if len(questions) > 0
                    else <div className="intelligence-empty">
                        <h4>No suggested questions</h4>
                        <p>No backend clarification questions are currently open.</p>
                    </div>
            )}
        </section>;
}
