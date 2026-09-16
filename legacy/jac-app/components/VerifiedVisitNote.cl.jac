"""Document-style preview composed only from locally accepted candidates."""

import from .MultimodalState {
    acceptedCandidates,
    candidateSourceId,
    candidatesForGroup,
    hasAcceptedConflict,
    unresolvedCandidateCount,
    uniqueAcceptedSourceCount
}


def VisitNoteGroup(
    title: str,
    empty_text: str,
    candidates: list[dict[str, any]],
    source_metadata: dict[str, dict[str, str]],
    on_trace: any
) -> JsxElement {
    return
        <section className="visit-note__group" aria-label={title}>
            <h3>{title}</h3>
            {(
                <div className="visit-note__rows">
                    {[
                        <div className="visit-note__row" key={candidate["id"]}>
                            <div>
                                <strong>{candidate["value"]}</strong>
                                <span>
                                    {(
                                        source_metadata[candidateSourceId(candidate)][
                                            "source_label"
                                        ]
                                            if candidateSourceId(
                                                candidate
                                            ) in source_metadata
                                            else "Source unavailable"
                                    )}
                                </span>
                            </div>
                            <div className="visit-note__row-actions">
                                <span className="verified-state">
                                    <span aria-hidden="true">✓</span>
                                    Accepted locally
                                </span>
                                <button
                                    className="trace-button"
                                    type="button"
                                    onClick={lambda (e: MouseEvent) { on_trace(
                                        candidateSourceId(candidate)
                                    ); }}
                                >
                                    Trace to Source
                                </button>
                            </div>
                        </div> for candidate in candidates
                    ]}
                </div>
                    if len(candidates) > 0
                    else <p className="visit-note__empty">{empty_text}</p>
            )}
        </section>;
}


def:pub VerifiedVisitNote(
    candidates: list[dict[str, any]],
    decisions: dict[str, str],
    source_metadata: dict[str, dict[str, str]],
    note_status: str,
    note_error: str,
    on_trace: any
) -> JsxElement {
    accepted: list[dict[str, any]] = acceptedCandidates(candidates, decisions);
    concerns: list[dict[str, any]] = candidatesForGroup(
        candidates, decisions, "concerns"
    );
    instructions: list[dict[str, any]] = candidatesForGroup(
        candidates, decisions, "instructions"
    );
    labs: list[dict[str, any]] = candidatesForGroup(candidates, decisions, "labs");
    referrals: list[dict[str, any]] = candidatesForGroup(
        candidates, decisions, "referrals"
    );
    follow_up: list[dict[str, any]] = candidatesForGroup(
        candidates, decisions, "follow_up"
    );
    source_count: int = uniqueAcceptedSourceCount(candidates, decisions);
    unresolved_count: int = unresolvedCandidateCount(candidates, decisions);
    has_conflict: bool = hasAcceptedConflict(candidates, decisions);

    return
        <section
            className="panel visit-note"
            aria-labelledby="visit-note-heading"
            aria-busy={note_status == "loading"}
        >
            <div className="section-heading">
                <div>
                    <p className="eyebrow">Clinician-reviewed output</p>
                    <h2 id="visit-note-heading">Verified Visit Note</h2>
                </div>
                <span className="review-required">Clinician review required</span>
            </div>
            <p className="visit-note__disclaimer">
                Hospi-Pet organizes candidate information. A clinician must verify the final visit note.
            </p>
            <div className="visit-note__summary">
                <div>
                    <span>Accepted items</span>
                    <strong>{len(accepted)}</strong>
                </div>
                <div>
                    <span>Unique sources</span>
                    <strong>{source_count}</strong>
                </div>
                <div>
                    <span>Unresolved</span>
                    <strong>{unresolved_count}</strong>
                </div>
            </div>
            {(
                <div
                    className="note-status note-status--loading"
                    role="status"
                    aria-live="polite"
                >
                    Organizing the accepted details…
                </div>
                    if note_status == "loading"
                    else (
                        <div className="note-status note-status--error" role="alert">
                            <strong>Visit-note preview could not be refreshed.</strong>
                            <span>{note_error}</span>
                        </div>
                            if note_status == "recoverable_error"
                            else None
                    )
            )}
            {(
                <div className="visit-note__empty-state">
                    <h3>No verified details yet</h3>
                    <p>
                        Accept a candidate to add it to this clinician-review preview.
                    </p>
                </div>
                    if len(accepted) == 0
                    else <div className="visit-note__document">
                        <VisitNoteGroup
                            title="Patient-stated concerns"
                            empty_text="No patient-stated concerns have been accepted."
                            candidates={concerns}
                            source_metadata={source_metadata}
                            on_trace={on_trace}
                        />
                        <VisitNoteGroup
                            title="Confirmed instructions"
                            empty_text="No clinician instructions have been accepted."
                            candidates={instructions}
                            source_metadata={source_metadata}
                            on_trace={on_trace}
                        />
                        <VisitNoteGroup
                            title="Laboratory orders"
                            empty_text="No laboratory orders have been accepted."
                            candidates={labs}
                            source_metadata={source_metadata}
                            on_trace={on_trace}
                        />
                        <VisitNoteGroup
                            title="Referrals"
                            empty_text="No referrals have been accepted."
                            candidates={referrals}
                            source_metadata={source_metadata}
                            on_trace={on_trace}
                        />
                        <VisitNoteGroup
                            title="Follow-up"
                            empty_text="No follow-up information has been accepted."
                            candidates={follow_up}
                            source_metadata={source_metadata}
                            on_trace={on_trace}
                        />
                    </div>
            )}
            <section className="visit-note__gaps" aria-labelledby="gaps-heading">
                <h3 id="gaps-heading">Outstanding gaps</h3>
                <ul>
                    {(
                        <li className="gap-item gap-item--conflict">
                            <strong>Conflicting sources require review</strong>
                            <span>
                                Accepted follow-up values differ; neither source was selected automatically.
                            </span>
                        </li>
                            if has_conflict
                            else None
                    )}{(
                        <li>
                            <strong>
                                {str(unresolved_count) + " candidate" + (
                                    "" if unresolved_count == 1 else "s"
                                ) + " still require a decision"}
                            </strong>
                            <span>
                                Accept or reject each item before treating the note as complete.
                            </span>
                        </li>
                            if unresolved_count > 0
                            else None
                    )}{(
                        <li>
                            <strong>Follow-up timeframe was not verified</strong>
                            <span>No accepted follow-up source is available.</span>
                        </li>
                            if len(follow_up) == 0
                            else None
                    )}{(
                        <li>
                            <strong>Medication name requires confirmation</strong>
                            <span>
                                The contract demo preserves the instruction without inventing a medication name.
                            </span>
                        </li>
                            if len(instructions) > 0
                            else None
                    )}
                </ul>
            </section>
        </section>;
}
