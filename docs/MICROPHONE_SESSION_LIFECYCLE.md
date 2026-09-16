# Microphone session lifecycle

## Failure class

A session is more than a UI boolean. Permission resolution, recorder events,
timeouts, transcription/backend responses, and rendering can occur in different
orders. A callback can arrive after cancel or teardown. If it reads shared
“current session” state, it can attach an old stream, append old text, finalize
a new session, or leave a backend gate active after the UI appears idle.

The original app created a backend capture before requesting microphone access.
Its backend refuses a second active capture. Therefore incomplete cancellation
can block a later attempt even when the microphone hardware works normally.
This is a source-supported failure path, not proof of a specific observed incident.

## Historical claim and repository evidence

**Historical claim:** the author diagnosed a stale-session defect that prevented
microphone use. **Verified history:** `0ed7023`, `f7d0881`, `be40a7b`, and `82b9211`
change capture IDs, cleanup, speech finalization, and recovery. Inspect with:

```bash
git show be40a7b -- frontend.impl.jac
git show 82b9211 -- frontend.impl.jac
```

For example, `82b9211` passes the response's local `new_capture_id` directly into
the permission request instead of rereading reactive `capture_session_id`.
`be40a7b` retrieves an ID from sessionStorage but also removes finalization's
identity guard and queue wait. Those exact old/new code differences are known.
The original causal trace, reproduction, and failing regression test are absent.
Do not claim this repair proves the historical root cause.

**Current verified behavior:** new tests exercise the maintained controller,
including stale callbacks from an old recorder while the next session records.
The old full-stack implementation is archived under `legacy/jac-app/`. The
controller now supplies the maintained encounter notebook. It does not call
the old speech/backend pipeline; it is an improvement made during review.

## State and ownership

```text
idle/completed/error --start--> requesting_permission
requesting_permission --grant+recorder.start--> recording
recording --stop or 60-second limit--> stopping
stopping --final data then stop event--> completed
active state --failure--> error
any live state --cancel--> idle
any state --dispose--> terminal disposed instance (idle snapshot)
```

Start is ignored while an owner or unresolved acquisition exists. Duplicate
stop is ignored outside recording. Cancel during permission invalidates the
owner immediately. A browser request may still be pending; that exception is
explicit in `permissionPending`. We serialize rather than opening multiple
permission requests. Dismiss the prompt, wait for settlement, or reload.

One `Owner` holds a monotonically numbered generation, stream, recorder, chunk
list/byte count, timeout handles, and listener removers. Resource references are
ordinary controller fields, not render state. The UI receives immutable snapshot
copies and cannot change lifecycle state by assigning a boolean.

## Invariants

- At most one current owner, one pending getUserMedia request, and one owned
  recorder. Each successful new start creates a fresh generation.
- In idle/completed/error: no **owned** live tracks, recorder reference, timer,
  or media listener. Completed retains only a bounded Blob for local playback.
- Permission may outlive cancellation/error/disposal because getUserMedia has
  no abort mechanism. A late stream is stopped before recorder creation; no
  retired result is adopted. There is no promise the UI must await to cancel.
- Start clears the previous clip, error, and elapsed time. No transcript exists
  in the maintained app, so none can silently carry between sessions.
- Stop disables restart until encoding finishes or the watchdog releases the
  owner. Microphone tracks stop immediately; the final Blob arrives asynchronously.
- Release first invalidates ownership, then clears timers and listeners, stops
  the recorder safely, and stops every track in `finally`. It clears references
  and chunk storage. An exceptional recorder.stop cannot bypass track release.
- Disposal removes subscribers and capture resources. Pending promises still
  run their track-release continuation but cannot update the disposed view.
- Playback URLs are revoked on replacement, discard, and page exit. The encounter
  workspace now saves completed Blobs in IndexedDB. Releasing capture resources
  does not delete saved sources; explicit deletion does. No upload or transcript
  service is used.

## Race protection and bounded recovery

Every media event and timer closes over its concrete owner and checks identity,
not just a state string. Removed listeners can still have already queued work;
identity guards therefore remain necessary. Tests explicitly invoke a saved
retired callback to verify this boundary.

A 15-second permission deadline invalidates the owner but cannot close the
browser prompt. A 2-second stop watchdog releases a recorder that fails to
emit `stop`. Recording uses 250 ms chunks, a 60-second limit, and an 8 MiB byte
limit to avoid unbounded accumulation. Limits are checked when the event loop
runs; this is not a hard real-time or OS-level resource guarantee. One unusually
large browser chunk exists before the byte limit can reject it.

Errors distinguish denied permission, no device, device busy/unavailable,
unsupported browser, recorder initialization/start failure, runtime error,
disconnection, stop failure, and timeout. A released error state can retry,
except while a browser permission request remains unresolved. No automatic
permission retry or hidden microphone restart occurs.

The view disposes on `pagehide` and remounts an idle controller on persisted
`pageshow`. Operating-system process termination is outside JavaScript control;
the browser owns hardware cleanup in that case. Separate tabs have separate
controllers; the application does not claim cross-tab hardware exclusivity.
Atomic storage revisions do protect encounters from silent competing-tab writes.

## What the tests prove

`tests/microphone-session.test.ts` drives the real controller with stateful
browser boundary doubles and fake time. Assertions examine stopped tracks,
removed listeners, recorder state/calls, chunk isolation, and outstanding timers.
No test replaces the controller or implements a second state machine.

`tests/browser/capture.spec.ts` runs the same controller in Chromium with its
fake device. Native getUserMedia, MediaStreamTrack, MediaRecorder, Blob encoding,
and audio decoding run. Test instrumentation observes real resources. The
three-session test requires each clip to decode and every earlier track to end.
Denial is injected deterministically; this does not test an OS permission dialog.
Page-cache restoration uses synthetic lifecycle events; separate real navigation
checks pagehide cleanup. These are deliberately distinct evidence scopes.

## Product integration and camera ownership

`Workspace` keeps this controller instance across encounter switches, preserving
pending-permission serialization. Each attempt binds an encounter ID, a capture
UUID, and the expected controller generation. A completion must match both
encounter and generation before its Blob can be attached. Navigation clears the
binding before canceling. IndexedDB persistence has a separate lifetime from
microphone ownership; only completed clips persist, never an active stream.

Camera uses the same ownership discipline in its own controller:
`idle/completed/error → requesting_permission → preview → capturing → completed`.
Cancel returns to idle and failure to error. A 15-second permission deadline,
60-second preview limit and 5-second encoding deadline bound abandoned work.
The view borrows the stream; only the controller owns tracks. The canvas copies
the frame synchronously before tracks stop; late asynchronous encoding must still
match the owner. Take photo is disabled until a usable frame has loaded.

Finalization requires inactive capture, flushes notes, and commits the encounter
before reporting success. All owned media/save timers and live tracks are zero.
Unresolved browser permission promises are the same documented exception as above;
late grants still cannot attach to a finalized/different encounter.

`tests/camera-session.test.ts` tests repeated preview/capture, permission and encode
races, teardown, timeouts and device failures. `tests/workspace.test.ts` combines
both real controllers with boundary doubles, including old media results after
switching encounters. `tests/encounter-store.test.ts` uses IndexedDB semantics
through fake-indexeddb; native persistence is verified by the browser product suite.

## Manual hardware procedure (not automated evidence)

1. `npm ci && npm run dev`; open localhost and create an encounter. Close other
   applications using the microphone if necessary. Use non-sensitive speech.
2. Allow microphone permission, record 3–5 seconds, stop, play the clip.
   Check that the browser's active capture indicator turns off.
3. Immediately start/stop two more sessions. Check current-only audio and a
   fresh generation/time counter each time.
4. Block site microphone permission and retry. Check the explicit denial message.
   Restore permission and retry. Repeat with the input unplugged if possible.
5. Start recording, navigate away, then back. Check capture stopped and the page
   can start a new session. Cancel while a permission prompt is pending; grant
   it late and verify capture is released rather than starting silently.
6. Repeat in target browsers. Record browser/OS/device and actual outcomes;
   the automated Chromium run alone does not verify Safari or Firefox.

## API references

- [getUserMedia and unresolved permission requests](https://developer.mozilla.org/en-US/docs/Web/API/MediaDevices/getUserMedia)
- [MediaRecorder.stop and final data ordering](https://developer.mozilla.org/en-US/docs/Web/API/MediaRecorder/stop)
- [Playwright browser installation and test CLI](https://playwright.dev/docs/test-cli)
