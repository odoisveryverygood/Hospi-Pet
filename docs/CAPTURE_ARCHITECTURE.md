# Capture, events and provenance

Hospi-Pet is a local encounter notebook. Its normal flow remains create → record
→ optional document photo → review → local history. The engineering views explain
what happened to those sources; they do not generate clinical conclusions.

```text
Browser hardware
      ↓
Media controller (one owner, generation, timers, listeners, tracks)
      ↓
Capture session (UUID bound to encounter + controller generation)
      ↓
Content-free event journal ───────────────→ read-only lifecycle replay
      ↓
Source (Blob + session + creation event)
      ↓
Encounter (sources + user-written notes + bounded journal)
      ↓
SHA-256 → atomic IndexedDB row + optimistic revision
      ↓
Reopen verification → provenance view → metadata manifest
```

## Ownership and asynchronous boundaries

`MicrophoneSession` and `CameraSession` retain their existing ownership guards and
cleanup. Instrumentation reports real request, acquisition, phase, track-release,
final-data, resource-release and stale-callback facts. It does not issue capture commands. Permission
requests remain serialized because browser prompts cannot be aborted. Stop
releases microphone tracks before waiting for final encoder data; camera capture
releases tracks after copying the frame, before asynchronous image encoding ends.

`Workspace` binds each controller generation to a session UUID and encounter ID.
It severs live bindings before navigation cleanup. Source attachment requires the
same owner, generation, draft and active encounter. Events carry the original
session identity too. A late result for another encounter is visible only in a
bounded **runtime** diagnostic buffer; it cannot mutate the current encounter's
journal, sources or revision. It does not rewrite an inactive record behind the
user's back. Such observations disappear on refresh. The most recent 64 session
bindings and 64 runtime signals are retained; aggregate stale counts are for the
mounted controllers, not all historical browser activity.

## Events are facts, not a second command system

Journal version 1 uses a small discriminated vocabulary: encounter creation,
capture facts, source attachment/removal, note-length checkpoints, review, finalization,
persistence failure/retry and invariant failure. Each event has a UUID, owning
encounter ID, sequence and wall-clock timestamp. Capture facts also contain a
session UUID, generation and resource counts. No note text, audio chunks, images,
URLs, arbitrary exceptions or free-form metadata are included.

Sequence defines order. Displayed millisecond offsets use the wall clock and can
move backwards if that clock changes; they are not precision benchmarks.
`data_received` records a nonempty recorder data event received during stopping,
not every 250 ms chunk. `source_attached` means accepted into in-memory encounter
state. The separate save indicator establishes whether the transaction committed.
`reviewed` means the review screen was opened, not that a clinician approved facts.
`finalized` is saved atomically with final status and published only after success.

The first 512 events are retained. Subsequent facts increment an explicit omitted
counter. Replay and provenance warn when history is incomplete; no fabricated
checkpoint restores missing detail. Media and notes can still be saved, but a
source whose creation event exceeded this bound has an unavailable creation-event
reference. Existing source bounds remain: one 8 MiB / 60-second audio clip, four
1 MiB images, 10,000 note characters and 20 encounters. Note edits coalesce at save boundaries: a checkpoint reports the current length
at the write attempt, not every keystroke or its original timing. Capture events
retain their individual sequence and timestamps.

## Persistence and schema compatibility

The existing IndexedDB store and row schema remain version 1. New journal and
fingerprint fields are optional, strictly validated additions. Legacy records
remain readable without invented capture history. New records start with a real
creation event; old records only gain facts as new actions happen.

WebCrypto runs **before** opening a readwrite transaction. Metadata, Blobs, events
and digests are then stored in one atomic row. Revision comparison occurs inside
the transaction. An older tab cannot silently overwrite a newer revision. A
failed hash/write leaves the current changes visibly unsaved and retryable. New
edits arriving during a write remain dirty; the save loop persists them next.
Fingerprints from completed writes merge only into matching current source IDs.

Reopen hashes the active encounter's sources, not the entire history. Results are
published only while that encounter is still active and the workspace is mounted.
A mismatch is visible outside developer mode and blocks finalization. Re-recording
or removing an affected source clears that source's verification result. Records
without a previous fingerprint are labeled legacy/unhashed, not “verified.” Old
unhashed sources are not silently re-baselined by editing an old encounter.

SHA-256 covers Blob bytes; byte size and MIME type are also compared. This detects
unexpected changes relative to a stored fingerprint. It is **not authentication**:
someone who can modify both the Blob and digest can forge a consistent record.
There is no encryption, signature or compliance claim.

## Provenance and replay

The provenance view derives encounter → session → source → fingerprint relations
from saved source metadata. It links the actual creation event and subsequent
review/finalization events. Source timestamps identify attachment completion;
request/start timing lives in the journal. Written notes are explicitly user
originated. Removed media leaves lifecycle facts but its bytes are no longer kept.

Replay is a pure fold over an event prefix. It shows lifecycle state, session IDs,
resource counts observed at those events, available source IDs, note lengths and
ignored callbacks. It does not reconstruct content, call controllers, change live
state or perform I/O. Missing legacy/bounded history stays unknown or partial.
Play advances one event per 600 ms rather than reproducing elapsed recording time.
An abrupt page exit can leave cleanup facts unpersisted: a recorded active state
is a historical observation, never a claim that hardware is active after reload.
Its single UI timer is cleared on pause, pane change, collapse and view disposal;
it is separate from capture/save timers and explicitly shown in replay controls.

## Invariants and failure injection

Runtime checks flag resources retained in idle/completed/error states and live
hardware in a finalized encounter. Failures are sticky, structured codes in
diagnostics, with a journal event when the active draft can record one. Tests
inject a violation to prove this path is not an always-green indicator. Resource
counts observe owned controller resources; native browser probes independently
check all streams/recorders/listeners in acceptance tests.

Development mode with `?lab=1` dynamically loads Capture Lab. Production builds
exclude the lab and its network observer. Faults wrap the existing `MediaPort`,
`CameraPort` and `EncounterRepository`; ordinary controller/workspace paths process
the failure. One armed fault is consumed once:

- microphone permission delay, denial or device error;
- camera denial or delayed real frame encoding;
- recorder error or held native final-data/stop callbacks;
- delayed storage write, quota failure or injected revision-conflict error.

Manual release avoids nondeterministic delay durations and hidden lab timers.
At most eight callbacks may be held; additional operations continue without delay
and report that queue limit. A lab epoch rejects callback-buffer updates after
reset or disposal, including promise continuations already queued for delivery.
Stop twice calls the real controller twice. Navigating while a callback is held
exercises the real ownership boundary. The lab can redeliver the last two released
recorder callbacks to exercise already-retired generation guards. This is an
intentional adapter fault, not a claim that every browser redelivers events this
way. It retains those callbacks (and potentially their media) only in development,
until replaced, a successful local deletion/reset, or page teardown. A held microphone gate delays acquisition itself;
it does not hold a live unowned stream. Teardown releases gates and prevents a
pending acquisition from opening hardware afterward.

The injected storage-conflict scenario tests workspace recovery from the typed
error. The existing two-tab browser test separately verifies real IDB conflicts.
See [CHAOS_MATRIX.md](CHAOS_MATRIX.md) for expectations and automated coverage.

## Privacy and export

Default capture has no backend/provider calls. In lab mode the privacy inspector
counts page fetch and XHR calls during active capture, storing no URLs or bodies.
Blob fetches, static resources, WebSockets/HMR, OS and extension traffic are outside
that observation. It is page-wide instrumentation, not proof of zero network
traffic. Browser tests also exercise loaded capture offline and inspect requests.

Export is a validated, deterministic JSON manifest with application/schema
versions, encounter IDs/status/revision/timestamps, events, source metadata,
fingerprints and derived relationships. It excludes media, title and note text.
Timestamps and identifiers still deserve care. Exported files are outside browser
data deletion. `validManifest` checks an exact allowlisted schema and relationships;
there is deliberately **no import into live storage** and no media archive mode.

`TranscriptProvider` is only an optional on-device adapter contract, including
source/encounter/provider/time provenance and cancellation. No implementation is
configured, invoked or claimed as tested transcription.
