"""Original inline-SVG Hospi-Pet therapy dog."""

def:pub HospiPetDog(
    assistant_state: str,
    message_visible: bool,
    on_activate: any,
    is_transitioning: bool,
    is_running: bool
) -> JsxElement {
    interaction_class: str = (
        "mascot-interaction" + (" mascot-interaction--running" if is_running else "") + (
            " mascot-interaction--active" if message_visible else ""
        )
    );

    return
        <div className={interaction_class}>
            <span className="hospi-pet-mic-indicator" aria-hidden="true">
                <span></span>
            </span>
            <span className="hospi-pet-document-scan" aria-hidden="true">
                <span></span>
            </span>
            <div
                id="hospi-pet-greeting"
                className="hospi-pet-bubble"
                role="status"
                aria-live="polite"
                aria-hidden={not message_visible}
            >
                Hey, how are you doing?
            </div>
            <button
                className={"hospi-pet-dog hospi-pet-dog--" + assistant_state + (
                    " hospi-pet-dog--running" if is_running else ""
                )}
                type="button"
                aria-label={"Hospi-Pet assistant. Current state: " + assistant_state}
                aria-expanded={message_visible}
                aria-controls="hospi-pet-greeting"
                aria-busy={is_transitioning}
                data-running={("true" if is_running else "false")}
                data-pose={(
                    "seated"
                        if message_visible
                        else ("running" if is_running else "standing")
                )}
                onClick={on_activate}
                onKeyDown={lambda (e: KeyboardEvent) { if e.key == "Enter"
                or e.key == " " {
                    e.preventDefault();
                    on_activate();
                } elif e.key == "Escape" and message_visible {
                    e.preventDefault();
                    on_activate();
                } }}
            >
                <span className="hospi-pet-dog__focus-label">
                    Activate Hospi-Pet assistant
                </span>
                <svg
                    className="hospi-pet-dog__svg"
                    viewBox="0 0 420 420"
                    aria-hidden="true"
                    focusable="false"
                >
                    <defs>
                        <radialGradient id="fur-head" cx="42%" cy="32%" r="68%">
                            <stop offset="0%" stopColor="#b9784d"/>
                            <stop offset="58%" stopColor="#8a4e2f"/>
                            <stop offset="100%" stopColor="#62331f"/>
                        </radialGradient>
                        <radialGradient id="fur-body" cx="45%" cy="24%" r="78%">
                            <stop offset="0%" stopColor="#a8633d"/>
                            <stop offset="100%" stopColor="#59301f"/>
                        </radialGradient>
                        <linearGradient id="fur-ear" x1="0" y1="0" x2="1" y2="1">
                            <stop offset="0%" stopColor="#754129"/>
                            <stop offset="100%" stopColor="#48271a"/>
                        </linearGradient>
                        <radialGradient id="muzzle" cx="50%" cy="35%" r="70%">
                            <stop offset="0%" stopColor="#d8a27c"/>
                            <stop offset="100%" stopColor="#ad7452"/>
                        </radialGradient>
                    </defs>
                    <g className="dog-sound-waves">
                        <path d="M79 170 C55 188 55 224 79 242"/>
                        <path d="M56 149 C20 179 20 235 56 264"/>
                        <path d="M341 170 C365 188 365 224 341 242"/>
                        <path d="M364 149 C400 179 400 235 364 264"/>
                    </g>
                    <ellipse
                        className="dog-floor-shadow"
                        cx="214"
                        cy="368"
                        rx="111"
                        ry="18"
                    />
                    <g className="dog-tail">
                        <path
                            d="M303 286 C363 248 395 277 374 318 C361 342 337 346 321 330"
                            fill="none"
                            stroke="#6d3b25"
                            strokeWidth="35"
                            strokeLinecap="round"
                        />
                        <path
                            d="M318 278 C355 258 375 273 370 298"
                            fill="none"
                            stroke="#9c5b38"
                            strokeWidth="13"
                            strokeLinecap="round"
                        />
                        <circle cx="373" cy="306" r="17" fill="#784329"/>
                        <circle cx="360" cy="320" r="15" fill="#8d5031"/>
                    </g>
                    <g className="dog-body-group">
                        <ellipse
                            className="dog-body-base"
                            cx="213"
                            cy="293"
                            rx="105"
                            ry="89"
                            fill="url(#fur-body)"
                        />
                        <g className="dog-back-leg dog-back-leg--left">
                            <circle cx="140" cy="273" r="31" fill="#724027"/>
                            <circle cx="153" cy="328" r="35" fill="#8d5132"/>
                        </g>
                        <g className="dog-back-leg dog-back-leg--right">
                            <circle cx="284" cy="275" r="34" fill="#6a3a25"/>
                            <circle cx="276" cy="329" r="37" fill="#754229"/>
                        </g>
                        <g className="dog-torso">
                            <path
                                d="M171 254 C188 236 237 235 256 257 L263 337 C240 360 184 360 162 337 Z"
                                fill="#a96843"
                            />
                            <g className="dog-chest-curls">
                                <circle cx="179" cy="271" r="24" fill="#bd815b"/>
                                <circle cx="211" cy="265" r="27" fill="#c58c66"/>
                                <circle cx="244" cy="274" r="24" fill="#b97854"/>
                                <circle cx="193" cy="302" r="27" fill="#b97854"/>
                                <circle cx="229" cy="304" r="29" fill="#c38962"/>
                                <circle cx="179" cy="332" r="22" fill="#a96946"/>
                                <circle cx="215" cy="337" r="26" fill="#b87852"/>
                                <circle cx="249" cy="331" r="22" fill="#a96843"/>
                            </g>
                        </g>
                        <g className="dog-front-leg dog-front-leg--left">
                            <ellipse cx="156" cy="350" rx="38" ry="20" fill="#6e3c27"/>
                            <ellipse cx="155" cy="345" rx="25" ry="10" fill="#a86642"/>
                        </g>
                        <g className="dog-front-leg dog-front-leg--right">
                            <ellipse cx="269" cy="350" rx="38" ry="20" fill="#6e3c27"/>
                            <ellipse cx="269" cy="345" rx="25" ry="10" fill="#a86642"/>
                        </g>
                    </g>
                    <g className="dog-head">
                        <g className="dog-ear dog-ear--left">
                            <path
                                d="M129 121 C84 125 66 173 83 222 C95 258 129 250 151 220 C168 196 166 145 129 121 Z"
                                fill="url(#fur-ear)"
                            />
                            <circle cx="102" cy="153" r="25" fill="#744028"/>
                            <circle cx="96" cy="185" r="27" fill="#633520"/>
                            <circle cx="110" cy="216" r="24" fill="#7f482b"/>
                        </g>
                        <g className="dog-ear dog-ear--right">
                            <path
                                d="M288 121 C333 125 351 173 334 222 C322 258 288 250 266 220 C249 196 251 145 288 121 Z"
                                fill="url(#fur-ear)"
                            />
                            <circle cx="315" cy="153" r="25" fill="#744028"/>
                            <circle cx="321" cy="185" r="27" fill="#633520"/>
                            <circle cx="307" cy="216" r="24" fill="#7f482b"/>
                        </g>
                        <ellipse
                            cx="208"
                            cy="177"
                            rx="101"
                            ry="92"
                            fill="url(#fur-head)"
                        />
                        <g className="dog-head-curls">
                            <circle cx="142" cy="118" r="30" fill="#8d5133"/>
                            <circle cx="171" cy="99" r="32" fill="#a4603c"/>
                            <circle cx="207" cy="94" r="34" fill="#ad6b46"/>
                            <circle cx="243" cy="100" r="32" fill="#985637"/>
                            <circle cx="275" cy="120" r="29" fill="#81472d"/>
                            <circle cx="132" cy="151" r="29" fill="#9b5b39"/>
                            <circle cx="284" cy="153" r="28" fill="#754029"/>
                            <circle cx="130" cy="188" r="27" fill="#854a2d"/>
                            <circle cx="288" cy="190" r="27" fill="#6d3a25"/>
                            <circle cx="145" cy="221" r="29" fill="#8c4f31"/>
                            <circle cx="272" cy="222" r="30" fill="#754128"/>
                        </g>
                        <g className="dog-eyes">
                            <ellipse cx="171" cy="170" rx="20" ry="24" fill="#f4dfcf"/>
                            <ellipse cx="245" cy="170" rx="20" ry="24" fill="#f4dfcf"/>
                            <ellipse cx="173" cy="173" rx="12" ry="16" fill="#3a241b"/>
                            <ellipse cx="243" cy="173" rx="12" ry="16" fill="#3a241b"/>
                            <circle cx="177" cy="167" r="4.5" fill="#fffaf2"/>
                            <circle cx="247" cy="167" r="4.5" fill="#fffaf2"/>
                        </g>
                        <ellipse cx="180" cy="215" rx="48" ry="39" fill="url(#muzzle)"/>
                        <ellipse cx="237" cy="215" rx="48" ry="39" fill="url(#muzzle)"/>
                        <ellipse cx="208" cy="200" rx="26" ry="19" fill="#2a1c18"/>
                        <ellipse
                            cx="202"
                            cy="194"
                            rx="8"
                            ry="4"
                            fill="#655048"
                            opacity="0.72"
                        />
                        <g className="dog-mouth">
                            <path
                                d="M208 218 C208 233 193 238 181 231"
                                fill="none"
                                stroke="#3a211a"
                                strokeWidth="4"
                                strokeLinecap="round"
                            />
                            <path
                                d="M208 218 C208 233 223 238 235 231"
                                fill="none"
                                stroke="#3a211a"
                                strokeWidth="4"
                                strokeLinecap="round"
                            />
                            <path
                                className="dog-happy-mouth"
                                d="M190 237 C201 250 219 250 230 237"
                                fill="none"
                                stroke="#3a211a"
                                strokeWidth="4"
                                strokeLinecap="round"
                            />
                            <path
                                className="dog-tongue"
                                d="M199 240 C201 262 216 262 218 240 Z"
                                fill="#d47a75"
                            />
                        </g>
                        <circle cx="151" cy="208" r="10" fill="#d48667" opacity="0.26"/>
                        <circle cx="265" cy="208" r="10" fill="#d48667" opacity="0.26"/>
                    </g>
                </svg>
            </button>
            <span className="hospi-pet-announcement" aria-live="polite">
                {("Hey, how are you doing?" if message_visible else "")}
            </span>
        </div>;
}
