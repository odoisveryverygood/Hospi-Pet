"""Screen 2 — Clinical Insights, composed from shared frontend state."""

import from .AssistantSection { AssistantSection }
import from .ClinicalInsightsIntro { ClinicalInsightsIntro }
import from .EncounterProgress { EncounterProgress }
import from .VerifiedPatientSummary { VerifiedPatientSummary }
import from .ClinicalInsightsIncomplete { ClinicalInsightsIncomplete }
import from .WorkflowNavigation { InsightsNavigation }
import from .Screen1State { hasEnoughVerifiedFacts }


def:pub ClinicalInsightsScreen(
    patient: dict[str, str],
    facts: list[dict[str, str]],
    decisions: dict[str, str],
    insights_preparing: bool,
    message_visible: bool,
    on_mascot_activate: any,
    on_back: any,
    on_continue: any
) -> JsxElement {
    insights_available: bool = hasEnoughVerifiedFacts(facts, decisions);

    return
        <div className="clinical-insights-screen">
            <ClinicalInsightsIntro/>
            <EncounterProgress patient_name={patient["name"]}/>
            <AssistantSection
                assistant_state={("analyzing" if insights_preparing else "complete")}
                status_text={(
                    "Reviewing the verified details"
                        if insights_preparing
                        else "Accepted evidence ready"
                )}
                friendly_message={(
                    "Organizing the accepted facts and missing information."
                        if insights_preparing
                        else "Return to Live Encounter to run or refresh backend intelligence."
                )}
                message_visible={message_visible}
                on_activate={on_mascot_activate}
                is_transitioning={insights_preparing}
                is_running={insights_preparing}
            />
            <VerifiedPatientSummary
                patient={patient}
                facts={facts}
                decisions={decisions}
            />
            {(
                <div className="clinical-insights-content">
                    <section
                        className="panel insights-handoff"
                        aria-labelledby="insights-handoff-title"
                    >
                        <p className="eyebrow">Evidence boundary</p>
                        <h2 id="insights-handoff-title">
                            No frontend diagnosis is generated
                        </h2>
                        <p>
                            Care gaps, suggested questions, conflicts, notes, plans, and source traces are rendered only from the documented Verified Intelligence backend actions.
                        </p>
                    </section>
                </div>
                    if insights_available
                    else <ClinicalInsightsIncomplete/>
            )}
            <InsightsNavigation
                can_continue={insights_available and not insights_preparing}
                on_back={on_back}
                on_continue={on_continue}
            />
        </div>;
}
