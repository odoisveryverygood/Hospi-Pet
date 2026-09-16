"""Small safety disclaimer for the hackathon prototype."""

def:pub ProjectFooter -> JsxElement {
    return
        <footer className="project-footer">
            <p>
                Hospi-Pet hackathon prototype
                <span aria-hidden="true">•</span>
                Synthetic demonstration data only
                <span aria-hidden="true">•</span>
                Not for clinical use
            </p>
        </footer>;
}
