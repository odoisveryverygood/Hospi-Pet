import type { Workspace } from '../workspace';
import type { CaptureLab, Scenario } from '../capture/lab';
import { eventLabel, replay } from '../capture/events';
import { sources, serializeManifest } from '../capture/manifest';
import { escapeText, find } from './dom';
export class EngineeringView {
  private unsubscribe = () => {};
  private cursor = 0;
  private timer: ReturnType<typeof setInterval> | null = null;
  private eventKey = '';
  private pane = 'timeline';
  private exportUrl: string | null = null;
  private onKey = (event: KeyboardEvent) => { if (event.key === 'Escape') this.pause(); };
  constructor(private root: HTMLElement, private workspace: Workspace, private lab?: CaptureLab) {
    root.innerHTML = `<details id="engineering"><summary>Capture timeline & provenance <span class="caption">Optional engineering views</span></summary>
      <p class="muted">Inspect the real capture lifecycle. Events contain identifiers and resource counts, never recordings, images or note text.</p>
      <nav class="engineering-nav" aria-label="Engineering views">${['timeline', 'provenance', 'replay', 'privacy', ...(lab ? ['lab'] : [])].map((pane) => `<button class="secondary" data-pane="${pane}" aria-pressed="false">${pane === 'lab' ? 'Capture Lab' : pane[0]!.toUpperCase() + pane.slice(1)}</button>`).join('')}</nav>
      <p id="journal-limit" class="notice" hidden></p><p id="integrity-warning" class="notice error" role="alert" hidden></p>
      <section data-panel="timeline"><h2>Event timeline</h2><p class="caption">Wall-clock offsets from encounter creation; sequence numbers establish ordering. Source attached means accepted in memory; “Saved in this browser” confirms the atomic storage commit.</p><ol id="event-list" class="event-list" tabindex="0" aria-label="Capture events, scroll for more"></ol></section>
      <section data-panel="provenance" hidden><h2>Source provenance</h2><p class="caption">Encounter → capture session → source → integrity fingerprint → review. Digests identify bytes; they do not authenticate a source.</p><div id="provenance-list"></div><p id="notes-origin"></p><button id="export-manifest" class="secondary">Export metadata manifest</button><p class="caption">JSON includes identifiers, timestamps, lifecycle events and hashes. No media, title or note text. Exported files are not removed by clearing browser data.</p><p id="export-result" role="status"></p></section>
      <section data-panel="replay" hidden><h2>Lifecycle replay</h2><p class="caption">Read-only projection of recorded facts. No devices are acquired. Missing history stays unknown. Play advances one event every 600 ms, not at original recording speed.</p><div class="controls"><button id="replay-play">Play</button><button id="replay-pause" class="secondary">Pause</button><button id="replay-prev" class="secondary">Previous event</button><button id="replay-next" class="secondary">Next event</button><button id="replay-restart" class="text-button">Restart</button></div><p id="replay-position" role="status"></p><pre id="replay-state"></pre></section>
      <section data-panel="privacy" hidden><h2>Privacy inspection</h2><p id="network-observation"></p><dl class="diagnostic-grid"><div><dt>Active devices · mic / camera tracks</dt><dd id="privacy-devices"></dd></div><div><dt>Storage in this encounter</dt><dd id="privacy-storage"></dd></div><div><dt>Network boundary</dt><dd>No capture backend, analytics or speech provider is configured. Browser resources, development HMR, extensions and OS traffic are outside this claim.</dd></div></dl><p>IndexedDB contains media, notes, lifecycle metadata and fingerprints. Delete this encounter using its Delete button, or use Privacy & local data → Clear all local data.</p><p>Transcript provider: <strong>Not configured</strong>. No transcript has been generated.</p></section>
      ${lab ? `<section data-panel="lab" hidden><h2>Capture Lab · development only</h2><p>Arms one failure at a real controller or storage boundary. Use synthetic content. Held callbacks survive encounter navigation until released; they own no lab timers. Refresh resets the lab.</p><label for="lab-scenario">Next fault</label><select id="lab-scenario">${lab.scenarios.map((scenario) => `<option value="${scenario}">${scenario}</option>`).join('')}</select><div class="controls"><button id="lab-arm">Arm next operation</button><button id="lab-release" class="secondary">Release pending callbacks</button><button id="lab-redeliver" class="secondary">Redeliver retired recorder callbacks</button><button id="lab-double-stop" class="text-button">Stop twice</button></div><p id="lab-status" role="status"></p><p class="caption">Delay microphone before Start; delay final data before Start then Stop; delay camera encoding before Take photo; storage faults before editing notes. Navigate to a second encounter before releasing to test stale ownership. Recorder finalization times out after 2 seconds; camera encoding after 5 seconds.</p></section>` : ''}
    </details>`;
    root.addEventListener('keydown', this.onKey);
    for (const button of root.querySelectorAll<HTMLButtonElement>('[data-pane]')) button.addEventListener('click', () => {
      this.pane = button.dataset.pane!; this.pause(); this.update();
    });
    find(root, '#engineering').addEventListener('toggle', () => { if (!find<HTMLDetailsElement>(root, '#engineering').open) this.pause(); });
    find(root, '#replay-play').addEventListener('click', () => {
      if (this.timer !== null) return;
      if (this.cursor >= this.events.length) this.cursor = 0;
      this.timer = setInterval(() => { this.cursor = Math.min(this.cursor + 1, this.events.length); if (this.cursor >= this.events.length) this.pause(); this.updateReplay(); }, 600);
      this.updateReplay();
    });
    find(root, '#replay-pause').addEventListener('click', () => this.pause());
    find(root, '#replay-prev').addEventListener('click', () => { this.pause(); this.cursor = Math.max(0, this.cursor - 1); this.updateReplay(); });
    find(root, '#replay-next').addEventListener('click', () => { this.pause(); this.cursor = Math.min(this.events.length, this.cursor + 1); this.updateReplay(); });
    find(root, '#replay-restart').addEventListener('click', () => { this.pause(); this.cursor = 0; this.updateReplay(); });
    find(root, '#export-manifest').addEventListener('click', () => {
      const active = workspace.snapshot.active;
      if (!active) return;
      try {
        const text = serializeManifest(active);
        if (this.exportUrl) URL.revokeObjectURL(this.exportUrl);
        this.exportUrl = URL.createObjectURL(new Blob([text], { type: 'application/json' }));
        const link = document.createElement('a'); link.href = this.exportUrl; link.download = `hospipet-${active.id}.json`; link.click();
        find(root, '#export-result').textContent = 'Validated metadata manifest downloaded. Media and note text were excluded.';
      } catch { find(root, '#export-result').textContent = 'Manifest validation failed; no export was created.'; }
    });
    if (lab) {
      this.unsubscribe = lab.subscribe(() => this.update());
      find(root, '#lab-arm').addEventListener('click', () => { lab.arm(find<HTMLSelectElement>(root, '#lab-scenario').value as Scenario); this.update(); });
      find(root, '#lab-release').addEventListener('click', () => { lab.release(); this.update(); });
      find(root, '#lab-redeliver').addEventListener('click', () => lab.redeliver());
      find(root, '#lab-double-stop').addEventListener('click', () => { workspace.microphone.stop(); workspace.microphone.stop(); this.update(); });
    }
    this.update();
  }
  private get events() { return this.workspace.snapshot.active?.journal?.events ?? []; }
  private pause() { if (this.timer !== null) clearInterval(this.timer); this.timer = null; this.updateReplay(); }
  private updateReplay() {
    find(this.root, '#replay-position').textContent = `${this.cursor} / ${this.events.length} events · ${this.timer === null ? 'Paused' : 'Playing'} · ${this.timer === null ? 0 : 1} replay timer`;
    find(this.root, '#replay-state').textContent = JSON.stringify(replay(this.events, this.cursor), null, 2);
  }
  update() {
    const active = this.workspace.snapshot.active;
    if (!active) return;
    for (const panel of this.root.querySelectorAll<HTMLElement>('[data-panel]')) panel.hidden = panel.dataset.panel !== this.pane;
    for (const button of this.root.querySelectorAll('[data-pane]')) button.setAttribute('aria-pressed', String((button as HTMLElement).dataset.pane === this.pane));
    const journal = active.journal;
    const warning = !journal ? 'Legacy encounter: no historical lifecycle journal was recorded.' : journal.omitted ? `${journal.omitted} events omitted after the 512-event limit. Replay is a partial history; sources remain available.` : '';
    find(this.root, '#journal-limit').textContent = warning; find(this.root, '#journal-limit').hidden = !warning;
    const key = `${active.id}/${this.events.length}`;
    if (this.eventKey !== key) {
      this.eventKey = key;
      const list = find(this.root, '#event-list');
      list.replaceChildren(...this.events.map((event) => {
        const row = document.createElement('li');
        const offset = (event.at - Date.parse(active.createdAt)) / 1000;
        const time = document.createElement('code'); time.textContent = `${event.sequence}. ${offset.toFixed(3)}s`;
        const label = document.createElement('span'); label.textContent = eventLabel(event);
        const detail = document.createElement('small'); detail.textContent = event.type === 'capture' ? `session ${event.sessionId} · generation ${event.signal.generation} · ${event.signal.tracks} tracks · ${event.signal.timers} timers` : event.type === 'source_attached' ? `${event.sourceId} · ${event.bytes} bytes` : '';
        row.append(time, label, detail); return row;
      }));
    }
    const diagnostics = this.workspace.diagnostics;
    const metadata = sources(active);
    const mismatches = Object.values(diagnostics.integrity).filter((status) => status === 'mismatch').length;
    find(this.root, '#integrity-warning').hidden = !mismatches;
    find(this.root, '#integrity-warning').textContent = `${mismatches} source integrity failure(s). Stored bytes or metadata do not match their recorded fingerprint. Do not rely on these sources.`;
    find(this.root, '#provenance-list').innerHTML = metadata.map((source) => {
      const creation = this.events.find((event) => event.id === source.creationEventId);
      const reviews = this.events.filter((e) => (e.type === 'reviewed' || e.type === 'finalized') && creation && e.sequence > creation.sequence);
      return `<article class="provenance-source"><h3>${source.kind === 'audio' ? 'Audio recording' : 'Document photo'}</h3><ol class="provenance-chain"><li><strong>Encounter</strong><code>${escapeText(source.encounterId)}</code></li><li><strong>Capture session</strong><code>${escapeText(source.sessionId)}</code></li><li><strong>Source</strong><code>${escapeText(source.id)}</code><span>${escapeText(source.createdAt)} · ${source.bytes} bytes · ${escapeText(source.mime)}</span></li><li><strong>Creation event</strong><code>${escapeText(source.creationEventId ?? 'Unavailable — legacy or bounded history')}</code></li><li><strong>SHA-256</strong><code>${source.fingerprint?.digest ?? 'No fingerprint recorded'}</code><span class="integrity-status">${diagnostics.integrity[source.id] ?? (source.fingerprint ? 'Fingerprinted on save · verified on reopen' : 'Awaiting save or legacy source')}</span></li><li><strong>Review references</strong><span>${reviews.length ? reviews.map((e) => `${e.type} · event ${e.sequence}`).join(', ') : 'No recorded review of this source'}</span></li></ol></article>`;
    }).join('') || '<p class="muted">No media sources yet. Record audio or attach a document photo.</p>';
    find(this.root, '#notes-origin').textContent = `Notes: user-written, ${active.notes.length} characters. Note text is excluded from diagnostic events and exports.`;
    find<HTMLButtonElement>(this.root, '#export-manifest').disabled = this.workspace.snapshot.dirty || this.workspace.snapshot.saving || this.workspace.snapshot.busy;
    find(this.root, '#network-observation').textContent = this.lab?.requests ? `Development observation during active capture: ${this.lab.requests.fetchCalls} page fetch calls; ${this.lab.requests.xhrCalls} page XHR sends. Excludes Blob fetches, static resources, WebSockets, extensions and OS traffic. Counts are page-wide, not proof about every network channel.` : 'Network observation is off. Enable the development Capture Lab (?lab=1) to observe page fetch/XHR calls during capture.';
    find(this.root, '#privacy-devices').textContent = `${diagnostics.microphone.activeTracks} / ${diagnostics.camera.activeTracks}`;
    find(this.root, '#privacy-storage').textContent = `${metadata.length} media sources · ${metadata.reduce((n, s) => n + s.bytes, 0)} media bytes · ${this.events.length} events · ${new Blob([JSON.stringify(journal ?? null)]).size} journal bytes · notes`;
    if (this.lab) find(this.root, '#lab-status').textContent = `${this.lab.last} · ${this.lab.pending} pending callbacks`;
    this.updateReplay();
  }
  dispose() { this.unsubscribe(); this.pause(); this.root.removeEventListener('keydown', this.onKey); if (this.exportUrl) URL.revokeObjectURL(this.exportUrl); }
}
