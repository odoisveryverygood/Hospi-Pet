"""Nine-card clinician note editor backed by Jac graph actions."""

def noteSectionSources(note: dict[str, any], section_type: str) -> list[str] {
    for section in note["note_sections"] {
        if section["section_type"] == section_type {
            return (section["source_fact_ids"] as list[str]) + (
                section["source_artifact_ids"] as list[str]
            );
        }
    }
    return [];
}


def:pub ClinicianNoteEditor(
    note: dict[str, any],
    status: str,
    edits: dict[str, str],
    pending_action: str,
    pending_section: str,
    trace_message: str,
    can_generate: bool,
    error_message: str,
    on_generate: any,
    on_change: any,
    on_save: any,
    on_approve: any,
    on_trace: any
) -> JsxElement {
    has_note: bool = "id" in note;
    loading: bool = status == "loading";
    source_fact_ids: list[str] = note["source_fact_ids"] if has_note else [];
    sections: list[dict[str, any]] = (
        [
            {
                "key": "patient_concerns",
                "heading": "Patient concerns",
                "content": note["patient_concerns"],
                "source_ids": noteSectionSources(note, "patient_concerns"),
                "editable": True
            },
            {
                "key": "confirmed_instructions",
                "heading": "Confirmed instructions",
                "content": note["confirmed_instructions"],
                "source_ids": noteSectionSources(note, "confirmed_instructions"),
                "editable": True
            },
            {
                "key": "medication_instructions",
                "heading": "Medication instructions",
                "content": note["medication_instructions"],
                "source_ids": noteSectionSources(note, "medication_instructions"),
                "editable": True
            },
            {
                "key": "laboratory_orders",
                "heading": "Laboratory orders",
                "content": note["laboratory_orders"],
                "source_ids": noteSectionSources(note, "laboratory_orders"),
                "editable": True
            },
            {
                "key": "referrals",
                "heading": "Referrals",
                "content": note["referrals"],
                "source_ids": noteSectionSources(note, "referrals"),
                "editable": True
            },
            {
                "key": "follow_up",
                "heading": "Follow-up",
                "content": note["follow_up"],
                "source_ids": noteSectionSources(note, "follow_up"),
                "editable": True
            },
            {
                "key": "unresolved_gaps",
                "heading": "Outstanding gaps",
                "content": note["unresolved_gaps"],
                "source_ids": noteSectionSources(note, "unresolved_gaps"),
                "editable": True
            },
            {
                "key": "source_evidence",
                "heading": "Source evidence",
                "content": str(len(source_fact_ids)) + " verified source facts",
                "source_ids": source_fact_ids,
                "editable": False
            },
            {
                "key": "review_status",
                "heading": "Review status",
                "content": (
                    "Approved by " + note["approved_by"]
                        if note["status"] == "approved"
                        else note["status"].replace("_", " ")
                ),
                "source_ids": [],
                "editable": False
            }
        ]
            if has_note
            else []
    );

    return
        <section
            className="panel note-editor"
            aria-labelledby="note-editor-heading"
            aria-busy={loading}
        >
            <div className="section-heading">
                <div>
                    <p className="eyebrow">Verified facts only</p>
                    <h2 id="note-editor-heading">Clinician Note</h2>
                </div>
                <span
                    className={"note-editor__status note-editor__status--" + status}
                    role="status"
                >
                    {(note["status"] if has_note else status).replace("_", " ")}
                </span>
            </div>
            <div className="note-editor__intro">
                <div>
                    <strong>Clinician-review draft — synthetic demonstration.</strong>
                    <p>
                        Nine focused cards preserve the backend note fields. This is not an official EHR note.
                    </p>
                </div>
                <div className="note-editor__primary-actions">
                    <button
                        className="button button--secondary"
                        type="button"
                        disabled={not can_generate or len(pending_action) > 0}
                        onClick={on_generate}
                    >
                        {(
                            "Generating…"
                                if pending_action == "generate"
                                else "Generate Note"
                        )}
                    </button>
                    <button
                        className="button button--primary"
                        type="button"
                        disabled={not has_note
                        or note["status"] == "approved"
                        or len(pending_action) > 0}
                        onClick={on_approve}
                    >
                        {(
                            "Approving…"
                                if pending_action == "approve"
                                else "Approve Note"
                        )}
                    </button>
                </div>
            </div>
            {(
                <div className="intelligence-inline-error" role="alert">
                    {error_message}
                </div>
                    if len(error_message) > 0
                    else None
            )}
            {(
                <div className="note-editor__cards">
                    {[
                        <article
                            className={"note-section-card " + (
                                "note-section-card--readonly"
                                    if not section["editable"]
                                    else ""
                            )}
                            key={section["key"]}
                        >
                            <div className="note-section-card__heading">
                                <span>{str(sections.index(section) + 1).zfill(2)}</span>
                                <h3>{section["heading"]}</h3>
                            </div>
                            {(
                                <textarea
                                    aria-label={section["heading"]}
                                    value={(
                                        edits[section["key"]]
                                            if section["key"] in edits
                                            else section["content"]
                                    )}
                                    disabled={note["status"] == "approved"
                                    or len(pending_action) > 0}
                                    onChange={lambda (e: any) { on_change(
                                        section["key"], e.target.value
                                    ); }}
                                ></textarea>
                                    if section["editable"]
                                    else <p
                                        className="note-section-card__readonly-value"
                                    >
                                        {section["content"]}
                                    </p>
                            )}
                            {(
                                <div className="source-id-list">
                                    {[
                                        <code key={source_id}>{source_id}</code>
                                        for source_id in section["source_ids"]
                                    ]}
                                </div>
                                    if len(section["source_ids"]) > 0
                                    else <p className="note-section-card__source-note">
                                        Section-level source mapping is not available for this section.
                                    </p>
                            )}
                            <div className="note-section-card__actions">
                                {(
                                    <button
                                        className="text-action"
                                        type="button"
                                        disabled={note["status"] == "approved"
                                        or len(pending_action) > 0}
                                        onClick={lambda (_e: MouseEvent) { on_save(
                                            section["key"]
                                        ); }}
                                    >
                                        {(
                                            "Saving…"
                                                if pending_section == section["key"]
                                                else "Save Section"
                                        )}
                                    </button>
                                        if section["editable"]
                                        else None
                                )}
                                <button
                                    className="trace-button"
                                    type="button"
                                    disabled={len(section["source_ids"]) == 0
                                    or len(pending_action) > 0}
                                    onClick={lambda (_e: MouseEvent) { on_trace(
                                        section["key"]
                                    ); }}
                                >
                                    Trace Source
                                </button>
                            </div>
                        </article> for section in sections
                    ]}
                </div>
                    if has_note
                    else <div
                        className={"intelligence-empty intelligence-empty--" + status}
                        role="status"
                    >
                        <h3>
                            {(
                                "Generating the clinician-review draft…"
                                    if loading
                                    else "No clinician note generated"
                            )}
                        </h3>
                        <p>Accept a candidate, then select Generate Note.</p>
                    </div>
            )}
            {(
                <p
                    className="note-editor__trace-message"
                    role="status"
                    aria-live="polite"
                >
                    {trace_message}
                </p>
                    if len(trace_message) > 0
                    else None
            )}
        </section>;
}
