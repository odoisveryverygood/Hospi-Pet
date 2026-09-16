# Optional model setup

The production demo does not need a model. Deterministic and MockLLM modes are
mandatory and fully exercise the safety/fallback boundary.

## Environment

`.env.example` contains variable names and safe empty/default values only:

```text
PA_CO_AI_MODEL=
PA_CO_AI_API_KEY=
PA_CO_INTELLIGENCE_MODE=disabled
DEMO_TRACE_ENABLED=false
```

Never commit `.env`, provider keys, prompt logs, or model output containing
patient-identifying information.

For an already-authorized live provider:

```bash
export PA_CO_AI_MODEL="gpt-4o-mini"
export PA_CO_AI_API_KEY="<authorized provider key>"
export PA_CO_INTELLIGENCE_MODE="live"
```

Provider-standard variables such as `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, or
`GOOGLE_API_KEY` are also recognized by the configured model path.
`BYLLM_DEFAULT_MODEL` may override the model. No key is hardcoded in source or
`jac.toml`.

## Modes

| Mode | Purpose |
|---|---|
| `disabled` | No model call; deterministic prepared data and matching. |
| `mock` | Valid typed Jac MockLLM; keyless acceptance testing. |
| `mock_malformed` | Deliberately invalid model output; non-production recovery diagnostic. |
| `live` | Optional configured provider with validation and deterministic fallback. |

`PA_CO_INTELLIGENCE_MODE` controls the additive finalized-chunk translation
and live quick-summary adapter. Public request bodies cannot override it.
Tests may spawn internal walkers with an explicit mode to exercise
deterministic, MockLLM, and malformed-output behavior without changing server
configuration.

The configured temperature is `0.0`, output is capped, timeout is conservative,
and structured output receives one corrective retry.

## Allowed AI work

- Propose typed, unverified candidate facts.
- Classify an allowed candidate category.
- Translate or simplify an already approved brief.
- Select relevant IDs from supplied current verified references.
- Literally translate a finalized English/Spanish transcript chunk.
- Produce an explicitly unverified, source-ID-bound live conversation draft.
- Organize an allow-list of current verified graph facts.

AI cannot create or modify `VerifiedFact`, approve/reject, resolve gaps or
conflicts, diagnose, prescribe, change a dose, determine safety, triage, or
answer from general medical knowledge.

## Validation and fallback

Extraction requires all fields, an allowed enum, current-session chunk ID,
exact traceable evidence, confidence in range, no duplicate, no fabricated
details, no prohibited medical behavior, and no instruction-injection
language. Valid output is stored only as pending.

Translation must preserve names, dates, numbers, item counts/order, checklist
structure, and source IDs. Question IDs must belong to the current session and
be verified, visible, and non-conflicted. Deterministic code writes the final
answer.

Missing key, provider exception, timeout, malformed/empty output, unsupported
category, missing evidence, or invalid IDs never crash the demo:

- extraction loads five prepared pending candidates;
- finalized-chunk translation uses its prepared deterministic translation or
  a clearly labeled original-text fallback;
- patient-plan translation/simplification returns the approved English plan;
- question matching uses deterministic graph matching or the exact safe
  fallback.

## Verification

```bash
env -u OPENAI_API_KEY -u ANTHROPIC_API_KEY -u GOOGLE_API_KEY \
  -u PA_CO_AI_API_KEY -u BYLLM_DEFAULT_MODEL \
  /Users/aradhyamishra/.local/bin/jac run tests/production_demo.jac
```

This covers disabled, missing-key, valid mock, and malformed mock modes.

No cloud credential was created for this upgrade. No local model was
downloaded: the available Jac local models require at least a multi-gigabyte
download, unnecessary for a reliable keyless demo.
