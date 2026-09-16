"""Frontend-only controls for loading and resetting the Screen 1 demo."""

import from .Screen1State { canResetDemo }


def:pub DemoControls(
    load_demo: any, reset_demo: any, demo_loaded: bool, is_transitioning: bool
) -> JsxElement {
    load_label: str = (
        "Loading Demo…"
            if is_transitioning
            else ("Demo Loaded" if demo_loaded else "Load Demo")
    );
    reset_disabled: bool = not canResetDemo(demo_loaded, is_transitioning);

    return
        <div className="demo-controls">
            <button
                className="button button--primary"
                type="button"
                aria-label={load_label}
                aria-busy={is_transitioning}
                disabled={is_transitioning or demo_loaded}
                onClick={load_demo}
            >
                {load_label}
            </button>
            <button
                className="button button--secondary"
                type="button"
                aria-label="Reset demo encounter"
                disabled={reset_disabled}
                onClick={reset_demo}
            >
                Reset Demo
            </button>
        </div>;
}
