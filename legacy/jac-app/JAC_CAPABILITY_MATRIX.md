# Jac 0.34.7 capability matrix

This matrix records capabilities actually probed on macOS arm64 with
`/Users/aradhyamishra/.local/bin/jac` version 0.34.7. Installed guides,
compiler diagnostics, and minimal runtime tests are the compatibility
authority.

Status: **supported** means compiled and ran; **partial** means usable with a
documented limitation; **unsupported** means absent or unreliable here.

| Capability | Status | Used | Verified decision |
|---|---|---:|---|
| Persistent root-reachable nodes | Supported | Yes | Jac-managed `.jac/data`; reload test preserves accepted fact. |
| Typed edges | Supported | Yes | All domain relationships are typed. |
| Endpoint-constrained edges | Supported | Yes | Used for domain-to-domain edges. |
| Root as a constrained edge endpoint | Partial | No | `HasSession` is meaningful but untyped; target is filtered to `DemoSession`. |
| Explicit `visit`, `here`, walker state | Supported | Yes | Core operations are visit-driven. |
| Typed reports | Supported | Yes | One `BackendResponse` is reported per internal walker. |
| Edge entry abilities | Partial | No | 0.34.7 requires explicit edge-object visits; traces record followed edges during node traversal. |
| Domain graph queries | Supported | Yes | Used for projections and scoped lookups; mutations remain walker-owned. |
| `def:pub` generated functions | Supported | Yes | All 13 actions reachable at `/function/*`. |
| Public walkers | Supported | Fixture only | Stable demo contract remains generated functions. |
| `walker:priv` | Supported | Fixture only | Anonymous request receives 401; authenticated fixture succeeds. |
| Per-user roots | Supported | Fixture only | Alice and Bob retain separate marker graphs. |
| `JacTestClient` | Supported | Yes | Endpoint envelope, invalid call, persistence reload, and auth verified. |
| Swagger/OpenAPI | Supported | Yes | Real server exposes `/docs` and `/openapi.json`. |
| Health endpoints | Supported | Yes | Real server health route is release-smoke-tested. |
| `jac start --no-client` | Supported | Yes | Real server stop/restart tested in a temporary copied workspace. |
| `jac start --faux` | Partial | No | Prints route report, then 0.34.7 cleanup raises missing `server_close`. |
| `/graph` visualization | Supported | Judge-only | Real server returned the graph viewer HTML with HTTP 200 before and after restart. |
| `jac dot` | Partial | Judge-only | CLI generates valid DOT, but against the tested generated-service store it rendered only `Root`; use `/graph` and relationship DTOs for this 0.34.7 demo. |
| Jac local persistence | Supported | Yes | No second database added. |
| Client codespace and `sv import` | Supported | Frontend-owned | Contract documented; frontend files untouched. |
| `by llm()` | Supported | Optional | Never on mandatory deterministic path. |
| Typed plain-object LLM returns | Supported | Yes | LLM functions return no graph nodes. |
| String-backed enums | Supported | Yes | Safety enums serialize existing string values. |
| `sem` declarations | Supported | Yes | Applied to safety-sensitive enums, data, inputs, and outputs. |
| MockLLM | Supported | Yes | Valid and malformed keyless acceptance modes. |
| Structured-output retry | Supported | Yes | Exactly one corrective retry. |
| `jac.toml` model configuration | Supported | Yes | Environment-only key/model configuration. |
| Local model download | Supported but omitted | No | No cached model; 2.5 GB minimum download is unnecessary for the demo. |
| Cloud provider | Supported but optional | No release dependency | No credential created; missing key falls back. |
| ModelPool/tool calling | Omitted | No | Adds no reliability value and would weaken mutation boundaries. |
| AI-guided graph traversal | Unsupported for this design | No | All traversal and mutation are deterministic. |
| Jac test blocks | Supported | Yes | Full suite plus entry-only integration verifier. |
| `jac fmt . --check` / `jac check .` | Supported | Yes | Required release gates. |
| Structural code map / database inspection | Supported | Audit only | Used to audit shapes; never a second source of truth. |

Official cross-references:

- <https://docs.jaseci.org/reference/language/osp/>
- <https://docs.jaseci.org/tutorials/ai/structured-outputs/>
- <https://docs.jaseci.org/tutorials/fullstack/auth/>

Capabilities intentionally omitted are not product promises.
