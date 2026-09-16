"""Synthetic-document camera, upload, preview, and extraction controls."""

import from .MultimodalState { documentCanAnalyze, sourceTargetId }


def:pub DocumentCaptureSection(
    permission_state: str,
    source_type: str,
    file_name: str,
    preview_url: str,
    camera_active: bool,
    is_requesting: bool,
    is_processing: bool,
    extraction_stage: str,
    extraction_message: str,
    extracted_text: str,
    document_label: str,
    document_source_id: str,
    highlighted_source_id: str,
    scenario: str,
    on_scenario_change: any,
    on_open_camera: any,
    on_file_change: any,
    on_take_photo: any,
    on_retake: any,
    on_analyze: any
) -> JsxElement {
    has_preview: bool = len(preview_url) > 0;
    can_analyze: bool = documentCanAnalyze(has_preview, is_processing);
    status_text: str = (
        extraction_stage.replace("_", " ")
            if extraction_stage != "idle"
            else "Waiting for a synthetic document"
    );

    return
        <section
            className="panel multimodal-panel document-panel"
            aria-labelledby="document-heading"
        >
            <div className="section-heading">
                <div>
                    <p className="eyebrow">Image input</p>
                    <h2 id="document-heading">Document Capture</h2>
                </div>
                <span className="safety-label">
                    For synthetic clinical documents only
                </span>
            </div>
            <p className="multimodal-intro">
                Use a lab-order sheet, referral sheet, appointment card, or after-visit summary created for this demonstration. JPEG, PNG, and WebP files are limited to 1 MiB by the contract.
            </p>
            <div className="multimodal-toolbar">
                <div className="multimodal-toolbar__primary">
                    <button
                        className="button button--primary"
                        type="button"
                        disabled={is_requesting or is_processing or camera_active}
                        aria-busy={is_requesting}
                        onClick={on_open_camera}
                    >
                        {("Requesting camera…" if is_requesting else "Open Camera")}
                    </button>
                    <label
                        className={"button button--secondary upload-button " + (
                            "button--disabled" if is_requesting or is_processing else ""
                        )}
                    >
                        Upload Image
                        <input
                            type="file"
                            accept="image/jpeg,image/png,image/webp"
                            disabled={is_processing}
                            onChange={on_file_change}
                        />
                    </label>
                    <button
                        className="button button--secondary"
                        type="button"
                        disabled={not camera_active or is_processing}
                        onClick={on_take_photo}
                    >
                        Take Photo
                    </button>
                </div>
                <label className="scenario-control">
                    <span>Extraction demo</span>
                    <select
                        value={scenario}
                        disabled={is_processing}
                        onChange={on_scenario_change}
                    >
                        <option value="lab_success">Lab order success</option>
                        <option value="referral_success">Referral success</option>
                        <option value="conflict_success">Conflicting follow-up</option>
                        <option value="unsupported_document">
                            Unsupported document
                        </option>
                        <option value="unreadable_document">Unreadable image</option>
                        <option value="recoverable_error">
                            Recoverable processing error
                        </option>
                    </select>
                </label>
            </div>
            <div className="status-grid status-grid--document">
                <div>
                    <span>Camera permission</span>
                    <strong>{permission_state.replace("_", " ")}</strong>
                </div>
                <div>
                    <span>Extraction status</span>
                    <strong>{status_text}</strong>
                </div>
                <div>
                    <span>Processing</span>
                    <strong>Jac graph extraction</strong>
                </div>
            </div>
            {(
                <div
                    className="permission-message permission-message--error"
                    role="alert"
                >
                    <strong>Camera access was denied.</strong>
                    <p>
                        Enable access in browser settings or upload a synthetic image instead.
                    </p>
                </div>
                    if permission_state == "denied"
                    else (
                        <div className="permission-message" role="status">
                            <strong>Camera capture is not supported.</strong>
                            <p>Upload Image remains available.</p>
                        </div>
                            if permission_state == "unsupported"
                            else (
                                <div
                                    className="permission-message permission-message--error"
                                    role="alert"
                                >
                                    <strong>The camera request failed.</strong>
                                    <p>Try again or upload a synthetic document.</p>
                                </div>
                                    if permission_state == "recoverable_error"
                                    else None
                            )
                    )
            )}
            {(
                <div className="document-preview">
                    <video
                        id="document-camera-video"
                        className="document-preview__media"
                        autoPlay={True}
                        playsInline={True}
                        muted={True}
                        aria-label="Live camera preview for a synthetic clinical document"
                    ></video>
                    <div className="document-preview__meta">
                        <strong>Live camera</strong>
                        <span>
                            Frame the synthetic document, then select Take Photo.
                        </span>
                    </div>
                </div>
                    if camera_active
                    else (
                        <div className="document-preview">
                            <img
                                className="document-preview__media"
                                src={preview_url}
                                alt={"Preview of synthetic clinical document" + (
                                    ": " + file_name if len(file_name) > 0 else ""
                                )}
                            />
                            <div className="document-preview__meta">
                                <div>
                                    <span>{source_type}</span>
                                    <strong>
                                        {(
                                            file_name
                                                if len(file_name) > 0
                                                else "Captured synthetic document"
                                        )}
                                    </strong>
                                </div>
                                <button
                                    className="text-button"
                                    type="button"
                                    disabled={is_processing}
                                    onClick={on_retake}
                                >
                                    Retake or remove
                                </button>
                            </div>
                        </div>
                            if has_preview
                            else <div className="document-empty">
                                <strong>No document selected</strong>
                                <p>
                                    Camera and uploads remain local to this browser preview.
                                </p>
                            </div>
                    )
            )}
            <div className="document-actions">
                <button
                    className="button button--primary"
                    type="button"
                    disabled={not can_analyze}
                    aria-busy={is_processing}
                    onClick={on_analyze}
                >
                    {("Analyzing document…" if is_processing else "Analyze Document")}
                </button>
                <span role="status" aria-live="polite">{extraction_message}</span>
            </div>
            {(
                <div
                    className="extraction-stages"
                    aria-label="Document extraction progress"
                >
                    {[
                        <span
                            className={"extraction-stage " + (
                                "extraction-stage--active"
                                    if stage == extraction_stage
                                    else ""
                            )}
                            key={stage}
                        >
                            {stage.replace("_", " ")}
                        </span>
                        for stage in [
                            "preparing_image",
                            "reading_document",
                            "creating_candidates",
                            "ready_for_review"
                        ]
                    ]}
                </div>
                    if is_processing or extraction_stage == "ready_for_review"
                    else None
            )}
            {(
                <div
                    id={sourceTargetId(document_source_id)}
                    className={"extracted-document " + (
                        "source-highlight"
                            if highlighted_source_id == document_source_id
                            else ""
                    )}
                    tabIndex={-1}
                >
                    <div className="extracted-document__heading">
                        <div>
                            <p className="eyebrow">Extracted document text</p>
                            <h3>{document_label}</h3>
                        </div>
                        <span className="review-required">
                            Clinician review required
                        </span>
                    </div>
                    <dl className="source-summary">
                        <div>
                            <dt>Source</dt>
                            <dd>{source_type}</dd>
                        </div>
                        <div>
                            <dt>Status</dt>
                            <dd>Unverified extraction</dd>
                        </div>
                    </dl>
                    <pre>{extracted_text}</pre>
                </div>
                    if len(extracted_text) > 0
                    else None
            )}
            <p className="panel-footnote">
                No face, body, emotion, skin, biometric, identity, or diagnostic image analysis is performed.
            </p>
        </section>;
}
