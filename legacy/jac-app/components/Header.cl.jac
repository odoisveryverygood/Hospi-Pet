"""Hospi-Pet application header."""

import from .DemoControls { DemoControls }


def:pub Header(
    screen_label: str,
    load_demo: any,
    reset_demo: any,
    demo_loaded: bool,
    is_transitioning: bool
) -> JsxElement {
    return
        <header className="site-header">
            <div className="site-header__inner">
                <div className="brand-lockup">
                    <div className="brand-mark" aria-hidden="true">
                        <svg viewBox="0 0 32 32" focusable="false">
                            <ellipse cx="16" cy="19" rx="7.4" ry="6.2"/>
                            <circle cx="8.5" cy="12" r="3.1"/>
                            <circle cx="14" cy="8.5" r="3.1"/>
                            <circle cx="20" cy="8.5" r="3.1"/>
                            <circle cx="25" cy="12" r="3.1"/>
                        </svg>
                    </div>
                    <div>
                        <p className="brand-name">Hospi-Pet</p>
                        <p className="screen-label">{screen_label}</p>
                    </div>
                </div>
                <DemoControls
                    load_demo={load_demo}
                    reset_demo={reset_demo}
                    demo_loaded={demo_loaded}
                    is_transitioning={is_transitioning}
                />
            </div>
        </header>;
}
