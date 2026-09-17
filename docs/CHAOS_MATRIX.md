# Capture fault matrix

`npm test` runs the controller/workspace fault matrix and writes actual completed
assertions to `test-results/chaos-matrix.json`. Browser artifacts use the separate
`test-results/browser/` directory. A failed test still fails the command; this
report is not a substitute for the test runner result.

The matrix uses real controllers and workspace with stateful media/storage ports.
Chromium acceptance separately exercises native media and IndexedDB. Port fixtures
are synthetic; they are not claims about physical devices or OS permission prompts.

| Scenario | Expected recovery | Resources | Data outcome |
| --- | --- | --- | --- |
| Microphone denied | Error → retry → recording | Zero after cancel | No failed clip |
| Microphone device failure | Error → retry → recording | Zero after cancel | No failed clip |
| Recorder error | Error → retry | Tracks/timers/listeners released | No failed clip |
| Camera denied | Error → retry → preview | Zero after close | No failed image |
| Permission delivered after navigation | New encounter remains idle | Late stream stopped | New encounter unchanged |
| Final data delivered after navigation; Stop twice | New encounter remains idle | Old tracks/timers released | Old callbacks ignored |
| Camera encoding after navigation | New encounter remains idle | Tracks stop before encoding resolves | Old image rejected |
| Storage write failure | Visible unsaved state → retry | Capture unaffected | Notes preserved |
| Injected revision conflict | Visible conflict → retry/reload | Capture unaffected | No silent save claim |
| Delayed write + newer edit | Save loop commits latest edit | Pending write returns to zero | Latest notes persisted |

Additional assertions cover stop watchdog expiration, lab teardown with a held
acquisition, event ordering, runtime invariant failure, hash-operation failure,
corrupt stored content, bounded histories and manifest validation. The existing
real two-tab browser test covers an actual IndexedDB revision conflict rather
than merely the injected error.

## Manual lab

1. `npm ci && npm run dev`; open <http://127.0.0.1:5173/?lab=1>.
2. Create an encounter; expand **Capture timeline & provenance → Capture Lab**.
3. Choose one fault and **Arm next operation**. The next matching port call consumes it.
4. For delayed permission, Start, return to history and create another encounter.
   Release callbacks there. Inspect diagnostics: the late generation was ignored,
   no source appeared and no live tracks remain.
5. For recorder final data, arm before Start, then Stop. Release promptly for normal
   completion or wait past the 2-second watchdog for recovery. After a successful
   release, switch encounters and use **Redeliver retired recorder callbacks**.
6. For delayed camera encoding, arm before Take photo, navigate, then release.
7. For storage faults, arm after encounter creation and edit notes. Save failure
   stays visible; retry or explicitly reload the saved copy. A genuine conflict
   must be resolved by reloading the newer row, not by overwriting it.

The lab is absent from production builds. It uses no paid service, no fabricated
transcripts and no separate controller implementation.
