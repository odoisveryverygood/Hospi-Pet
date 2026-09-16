# Jac 0.34.7 multimodal capability decision

Validated on macOS arm64 with `/Users/aradhyamishra/.local/bin/jac` 0.34.7.
Installed guides, installed package source, compiler probes, and small runtime
fixtures are the compatibility authority.

| Capability | Jac 0.34.7 | Proof | Use | Risk / fallback |
|---|---|---|---|---|
| `Image` from local path | Supported | Installed `jac-by-llm` guide and constructor fixture passed | Optional typed vision seam | Deterministic synthetic extraction |
| `Image` from bytes/data URL/file-like input | Supported | Runtime fixtures passed | Decode and validate data URLs before the seam | Reject malformed/oversized input |
| Typed `Image` + `by llm()` output | Supported | Guide documents typed objects/lists and image input | Optional `DocumentFactProposal` seam | One retry, then deterministic fallback |
| Direct `Video` input | Partial | Type exists; extra dependency required and `cv2` is absent | Not used | No large optional install |
| Native byLLM audio transcription | Unsupported | No installed audio type or guide/source path | Not used | Browser recognition or prepared transcript |
| Public walkers/functions and generated routes | Supported | Existing direct/server tests pass | Stable functions adapt to graph walkers | Structured failures |
| Multipart `UploadFile` | Supported | Installed endpoint classifier and real-server multipart request passed | P0 HTTP image input | Same validated ingestion walker; console logs metadata only |
| General request-size setting | Partial | No global installed-version setting found | Enforce 1 MiB decoded in application code | Frontend preflight too |
| Temporary files | Supported through Python interop | Standard `tempfile`; `Image` accepts path/file-like values | Validation/processing only | `finally` deletion; never return paths |
| Browser microphone/camera | Browser API, not server Jac | Client JS interop and `getUserMedia` | Frontend handoff | Permission state and prepared fallback |
| Browser speech recognition | Browser API, partial coverage | Web Speech `SpeechRecognition` | Optional live adapter emits normal chunks | Prepared transcript |
| Browser speech synthesis | Browser API | Web Speech `speechSynthesis` | Speak approved script only | Text remains usable |
| MockLLM | Supported | Existing keyless tests pass | Typed-seam tests | Deterministic mode |
| Local model | Possible but inappropriate | No cached model; candidates are about 2.5–5 GB and disk is limited | Not installed | Deterministic assets/MockLLM |
| Cloud vision/transcription | Not configured | Credential presence checked without printing values | No live-provider gate | Missing-key fallback |
| JacTestClient/OpenAPI | Supported | Existing generated-route tests pass | New endpoint smoke tests | Real `jac start` smoke |
| Async actions | Supported | Installed endpoint guide | Not required for P0 | Frontend can poll normal actions |
| Persistence | Supported | Existing restart tests | Persist graph metadata and evidence | Raw media explicitly excluded |

## Decisions

- Prepared or browser-produced text converges on one transcript walker.
- Documents use Jac's multipart `UploadFile` at the HTTP boundary. A
  non-public data-URL adapter supports deterministic direct tests; both paths
  converge on one validator, persist metadata/text only, and discard raw
  content immediately.
- Typed vision can propose pending facts only. It cannot verify facts, approve
  notes, resolve gaps, or create patient output.
- No video package, model weights, cloud key, recording, or second backend is
  added.

Official cross-checks:

- <https://docs.jaseci.org/tutorials/ai/multimodal/>
- <https://developer.mozilla.org/en-US/docs/Web/API/MediaDevices/getUserMedia>
- <https://developer.mozilla.org/en-US/docs/Web/API/SpeechRecognition>
- <https://developer.mozilla.org/en-US/docs/Web/API/SpeechSynthesis>
