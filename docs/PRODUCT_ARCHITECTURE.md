# Hospi-Pet product architecture

## Original intent, inferred from implementation

Hospi-Pet's original UI sits over a Jac project called **Pa-Co CareGraph**.
It models a **human consultation**, using the synthetic patient Maya Rivera.
The dog in `components/HospiPetDog.cl.jac` is a companion/mascot; this is not
implemented as a veterinary diagnosis system.

The intended user is someone documenting and reviewing a visit. The original
flow is consultation → proposed facts → clinician acceptance/rejection → care
obligations and source-linked review. Voice and document capture supply evidence;
they are not independent media utilities. This interpretation comes from the
components, frontend handlers, graph models and walkers, rather than accepting
readiness claims in the old README.

All 146 archived files were inspected for this pass. The [inventory](LEGACY_INVENTORY.md)
records the inspected surface; original contents remain unchanged. File paths
in the following table are relative to `legacy/jac-app/`.

| Area | Actual implementation / boundary | Maintained decision |
| --- | --- | --- |
| Visit UI | `frontend.impl.jac`, `LiveConsultation`, `ClinicianVerification`, `FinalReview`: synthetic encounter, pending facts, decisions and review | Retain the encounter → sources → explicit review sequence |
| Voice | Audio `getUserMedia`, browser `SpeechRecognition`, transcript queues, backend capture IDs; no original MediaRecorder or audio playback | Use the existing reviewed MediaRecorder controller for real saved clips |
| Documents | `DocumentCaptureSection`, canvas capture, 1 MiB uploads, `multimodal_walkers.sv.jac`, deterministic synthetic extraction fixtures | Recover video-only preview → canvas photo → attach source; no OCR claim |
| Care graph | `models.sv.jac`, `walkers.sv.jac`: typed nodes/edges, candidate verification, provenance, care obligations and documentation gaps | Preserve research; do not expose unverified graph/clinical buttons in the maintained app |
| Encounter/capture identity | Frontend logical session name; backend encounter/capture IDs and active-capture gate; auth via Jac root context | Local encounter UUID plus separate capture UUID and controller generation |
| Backend boundary | `api/backend.cl.jac` and endpoint modules bridge compiled Jac client to server walkers, login and persistence | No backend required by `src/`; IndexedDB owns local encounter records |
| Intelligence | `intelligence_*`, `ai.sv.jac`, `patient_agent.sv.jac`: model seams, mock/disabled modes, sourced notes/questions/translation, speech synthesis | No inferred findings, prepared transcript, translation or generated note masquerading as capture |
| Synthetic data | `demo_assets`, `handoff/*fixtures`, `mock_data`: prepared transcript, document images, expected extraction and response examples | Available as historical research; never preloaded as user-captured results |
| Tests/deployment | Jac tests include meaningful graph/root isolation assertions; old browser-state tests duplicate helpers; Railway/Vercel configuration is historical | Maintain TypeScript/controller, storage and native Chromium gates at root |

The Jac archive is not a working dependency of the new app. Typechecking and
reload/persistence failures found in the [original audit](REPO_AUDIT.md) remain
unrepaired. Optional provider paths and historical benchmark claims remain
unverified. No modern code should be represented as the original hackathon code.

## Small maintained product

An **encounter notebook** keeps a visit's source recording, document photos and
user-written context together. The useful outcome is a reviewable local record,
not a medical conclusion. Home shows actual saved drafts/finalized records;
an empty database shows an empty state, not a synthetic dashboard.

```text
History → Create encounter → Capture audio / optional photos / written notes
                                   ↓
                              Review sources
                                   ↓
                        Finalize → Reopen from history
```

A draft saves completed sources automatically. Review is blocked during active
capture. Finalization requires at least one source or a written note, flushes
pending edits, then commits the finalized record. The UI only declares success
after the IndexedDB transaction completes. Finalized records are read-only in
the application; they can be reopened or deleted. This is not tamper-proof storage.

## Implementation boundaries

```text
main.ts (page lifetime)
  ├─ ui/history-view.ts + ui/encounter-view.ts (DOM, focus, playback URLs)
  └─ workspace.ts (encounter binding, navigation, save sequencing)
       ├─ microphone-session.ts → native getUserMedia + MediaRecorder
       ├─ camera-session.ts     → native getUserMedia + canvas encoder
       ├─ domain/encounter.ts   → validation + source manifest
       └─ storage/encounter-store.ts → IndexedDB, atomic revisions
```

Vite and strict TypeScript; no runtime npm dependency, framework, API key or
server process beyond serving static assets. The views borrow media and render
snapshots. Only the controllers stop capture resources. The view owns and
revokes playback/image object URLs. Workspace owns one 400 ms notes-save timer.

### Encounter identity and stale work

An encounter UUID identifies the saved record. Each recording/photo attempt gets
a separate capture UUID. Controller generations increase within a mounted
workspace and are not persistent global IDs. A completed source carries its
capture UUID, generation for audio, creation time, MIME/size and actual Blob.

Workspace accepts completed media only when both the encounter ID and expected
controller generation match its capture binding. Navigation severs that binding
**before** cancellation publishes state. Controllers also check concrete owner
identity on asynchronous work. One controller of each kind survives encounter
switches, so an unresolved permission request cannot create a second acquisition.
Finalization/disposal stops both devices and clears owned timers/listeners.
A browser permission request itself cannot be aborted; late grants are stopped.

### Persistence and recovery

IndexedDB stores a versioned row containing metadata and Blobs together. Small
localStorage strings would be unsuitable for audio/photo bytes. Limits: 20
encounters, one 60-second / 8 MiB clip and four ≤1 MiB photos per encounter;
photos are scaled to at most 1280 px on the longer side. These limits bound this
prototype, not browser storage availability.

Saves are serialized. An edit counter preserves edits made while a save is in
flight. An atomic read/check/write of the stored revision rejects competing-tab
updates and writes to a deleted record; it does not silently merge private
content. A conflict keeps unsaved input visible and offers an explicit reload.
Quota/write failures stay visibly unsaved and retryable. Navigation flushes notes;
delete waits for any in-flight save. Reload starts from history, not a resumed
microphone. An unfinished recording is not saved until Stop completes.

Runtime validation isolates malformed rows. Valid records still load; unreadable
rows are preserved until explicit removal. There is no migration from the Jac
backend and no backup/export/import feature. IndexedDB can be cleared or evicted
by the browser. Local storage is not encrypted by this app.

### Transcription decision

Original speech recognition was investigated but is **not enabled** here.
Browser SpeechRecognition has uneven availability and can use a remote browser
vendor service; there is no portable, dependable local-only contract for this
prototype. Audio must not depend on it. The UI and schema explicitly say
transcription is unavailable; written notes never become a fake transcript.
A future optional adapter would need explicit network consent, the same capture
identity guard, a clear unavailable/error state and independent teardown tests.
[MDN SpeechRecognition](https://developer.mozilla.org/en-US/docs/Web/API/SpeechRecognition).

### Privacy and diagnostics

Maintained source contains no content upload, analytics, speech service, external
font or provider integration. CSP disallows third-party connections; the Vite
development socket is for development reloads. Browser acceptance completes a
loaded encounter flow offline and observes no HTTP requests during that flow.
This is bounded evidence about this application, not a claim about browser
extensions, operating-system behavior or compliance. Initial asset downloads and
package installation use the network; offline cold-start is not implemented.

The privacy panel explains activation, retention and deletion. Diagnostics expose
IDs, states, active track counts, owned timers, recorder state, transitions and
recoverable capture errors. They do not display audio bytes, images or notes.
The separately opened structured record intentionally includes user-written notes.

## Deliberate omissions

No graph inference, clinical recommendations, OCR, generated transcript, paid
service, account system, synchronization, waveform, continuous/background recording
or medical compliance claim. These omissions keep capture and source review
usable without reviving every historical experiment.
