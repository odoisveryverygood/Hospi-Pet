import { EngineeringView } from './engineering-view';
import type { CaptureLab } from '../capture/lab';
import { encounterOutput, hasSources } from '../domain/encounter';
import type { Workspace } from '../workspace';
import { bytes, escapeText, find, readableDate, ViewUrls } from './dom';
import type { View } from './dom';

export class EncounterView implements View {
  private engineering: EngineeringView;
  private urls = new ViewUrls();
  private currentAudio: Blob | null = null;
  private imageKey = '';
  private preview: MediaStream | null = null;
  private disposed = false;
  private previousScreen: string | null = null;
  private wasFinalized = false;
  private frameReady = () => { if (!this.disposed) this.update(); };
  constructor(private readonly root: HTMLElement, private readonly workspace: Workspace, lab?: CaptureLab) {
    root.innerHTML = `
      <button id="back-history" class="text-button back-link">← All encounters</button>
      <section class="page-heading encounter-heading"><div><p id="encounter-date" class="eyebrow"></p><h1 id="encounter-name" tabindex="-1"></h1><p id="encounter-subtitle"></p></div><span id="encounter-status" class="status-tag"></span></section>
      <nav class="steps" aria-label="Encounter workflow"><button id="capture-step">01 <span>Capture sources</span></button><button id="review-step">02 <span>Review & finalize</span></button><span id="save-status" role="status" aria-live="polite"></span></nav>
      <p id="source-integrity-warning" class="notice error" role="alert" hidden></p>
      <div id="capture-layout" class="capture-layout">
        <div class="capture-main">
          <section class="surface voice-surface" aria-labelledby="voice-heading">
            <div class="section-heading"><div><p class="eyebrow">Source 01</p><h2 id="voice-heading" tabindex="-1">Voice recording</h2></div><span id="phase" role="status" aria-live="polite"></span></div>
            <p class="muted">Capture a short part of the encounter. Re-recording replaces the previous clip.</p>
            <div class="recording-status"><span id="recording-dot" class="recording-dot" aria-hidden="true"></span><strong id="capture-state">Inactive</strong><span class="recording-time"><span id="seconds">0</span><small> / 60 seconds</small></span></div>
            <div class="controls"><button id="start">Start microphone</button><button id="stop" class="secondary" disabled>Stop recording</button><button id="discard" class="text-button">Discard / cancel</button></div>
            <p id="error" class="notice error" role="alert" hidden></p><p id="pending" class="notice" hidden>A browser permission request is still pending. Dismiss the prompt before retrying, or reload if it never settles.</p>
            <div id="playback" class="playback" hidden><label for="audio">Current recording</label><audio id="audio" controls preload="metadata"></audio><p id="clip-info" class="caption"></p></div>
            <p class="caption">Microphone access starts only when you choose Start. Stop releases its tracks immediately. Maximum 8 MiB.</p>
          </section>
          <section class="surface" aria-labelledby="camera-heading">
            <div class="section-heading"><div><p class="eyebrow">Optional source</p><h2 id="camera-heading">Document photos</h2></div><span id="camera-phase" role="status" aria-live="polite"></span></div>
            <p class="muted">Keep a photo of a practice document with the encounter. Images are attached as sources; no text or medical findings are extracted.</p>
            <div class="controls"><button id="open-camera" class="secondary">Open camera</button><button id="take-photo" hidden>Take photo</button><button id="close-camera" class="text-button" hidden>Close camera</button></div>
            <div id="camera-preview" class="camera-preview" hidden><video id="camera-video" autoplay playsinline muted aria-label="Live camera preview"></video><p>Frame a synthetic document, then take a photo.</p></div>
            <p id="camera-error" class="notice error" role="alert" hidden></p><p id="camera-pending" class="notice" hidden>Camera permission is still pending. Dismiss the browser prompt or reload before retrying.</p>
            <div id="image-grid" class="image-grid"></div><p id="image-count" class="caption"></p>
          </section>
        </div>
        <aside class="notes-panel"><p class="eyebrow">Written by you</p><h2>Encounter notes</h2><label for="notes">What should stay with this visit?</label><textarea id="notes" rows="10" maxlength="10000" placeholder="Add context, questions, or a source description in your own words."></textarea><p class="caption">Notes save after a short pause. They are not generated from the recording.</p><div class="transcript-note"><h3>Transcription is unavailable</h3><p>This local prototype records audio without a speech service. Your recording remains playable; no transcript is fabricated.</p></div></aside>
      </div>
      <section id="review-layout" hidden>
        <div class="review-intro"><h2 id="review-heading" tabindex="-1">Review the encounter</h2><p id="review-description">Check the sources and your notes before finalizing. Finalization organizes this record; it does not verify medical information.</p></div>
        <div class="review-grid"><section class="surface"><h3>Captured sources</h3><div id="review-sources"></div><div id="review-playback" hidden><label for="review-audio">Encounter recording</label><audio id="review-audio" controls preload="metadata"></audio></div><div id="review-images" class="image-grid"></div></section><section class="surface"><h3>Your written notes</h3><p id="review-notes" class="written-notes"></p><p class="caption">Source: entered by the user. No automatic transcription or inference.</p></section></div>
        <details class="structured-output"><summary>Structured encounter record</summary><p class="caption">Source metadata and user-written notes. Media remains in IndexedDB; raw bytes are not included here.</p><pre id="structured-output"></pre></details>
      </section>
      <p id="empty-review" class="notice" hidden>Add a recording, photo, or written note before finalizing.</p>
      <div class="encounter-actions"><button id="delete-encounter" class="text-button danger">Delete encounter</button><div class="actions"><button id="edit-capture" class="secondary" hidden>Back to capture</button><button id="continue-review">Review encounter →</button><button id="finalize" hidden>Finalize encounter</button><button id="next-encounter" hidden>Back to history</button></div></div>
      <details id="diagnostics" class="diagnostics"><summary>Developer diagnostics <span>Resource state only</span></summary><p id="invariant-status" class="notice" role="status"></p><dl class="diagnostic-grid"><div><dt>Encounter ID</dt><dd id="diag-encounter"></dd></div><div><dt>Capture session ID</dt><dd id="diag-capture"></dd></div><div><dt>Session generation</dt><dd id="generation">0</dd></div><div><dt>Active tracks · microphone / camera</dt><dd id="diag-tracks"></dd></div><div><dt>Recorder state</dt><dd id="diag-recorder"></dd></div><div><dt>Owned timers · microphone / camera / save</dt><dd id="diag-timers"></dd></div><div><dt>Last microphone transition</dt><dd id="diag-transition"></dd></div><div><dt>Last camera transition</dt><dd id="diag-camera"></dd></div><div><dt>Last recoverable errors · microphone / camera</dt><dd id="diag-error"></dd></div></dl></details>
    `;
    const engineeringRoot = document.createElement('div'); root.append(engineeringRoot);
    this.engineering = new EngineeringView(engineeringRoot, workspace, lab);
    const telemetry = document.createElement('pre'); telemetry.id = 'resource-telemetry'; find(root, '#diagnostics').append(telemetry);
    const on = (selector: string, fn: () => void) => find(root, selector).addEventListener('click', fn);
    on('#back-history', () => { void workspace.home(); });
    on('#start', () => workspace.startVoice());
    on('#stop', () => workspace.microphone.stop());
    on('#discard', () => workspace.discardVoice());
    on('#open-camera', () => workspace.openCamera());
    on('#take-photo', () => workspace.camera.capture(find<HTMLVideoElement>(root, '#camera-video')));
    on('#close-camera', () => workspace.cancelCamera());
    on('#continue-review', () => { void workspace.review(); });
    on('#review-step', () => { void workspace.review(); });
    on('#capture-step', () => workspace.editCapture());
    on('#edit-capture', () => workspace.editCapture());
    on('#finalize', () => { void workspace.finalize(); });
    on('#next-encounter', () => { void workspace.home(); });
    on('#delete-encounter', () => {
      const current = workspace.snapshot.active;
      if (current && window.confirm('Delete this encounter and its locally stored audio, photos, and notes? This cannot be undone.')) void workspace.deleteEncounter(current.id).then(() => { if (!workspace.snapshot.active) lab?.reset(); });
    });
    find<HTMLTextAreaElement>(root, '#notes').addEventListener('input', (event) => workspace.updateNotes((event.target as HTMLTextAreaElement).value));
    find(root, '#image-grid').addEventListener('click', (event) => {
      const button = event.target instanceof Element ? event.target.closest<HTMLButtonElement>('[data-remove-image]') : null;
      if (button?.dataset.removeImage) workspace.removeImage(button.dataset.removeImage);
    });
    find(root, '#camera-video').addEventListener('loadeddata', this.frameReady);
    this.update();
  }
  private text(selector: string, value: string) { find(this.root, selector).textContent = value; }
  private disabled(selector: string, disabled: boolean) { find<HTMLButtonElement>(this.root, selector).disabled = disabled; }
  update(): void {
    const state = this.workspace.snapshot;
    const record = state.active;
    if (!record) return;
    const mic = this.workspace.microphone.snapshot;
    const camera = this.workspace.camera.snapshot;
    const finalized = record.status === 'finalized';
    const review = state.screen === 'review';
    this.text('#encounter-date', readableDate(record.createdAt));
    this.text('#encounter-name', record.title);
    this.text('#encounter-status', finalized ? 'Finalized · local' : 'Draft · local');
    this.text('#encounter-subtitle', finalized ? 'A saved encounter with the sources you captured.' : 'Capture the encounter, keep its context, and review it together.');
    this.text('#save-status', state.storageError ? 'Save needs attention' : state.saving ? 'Saving locally…' : state.dirty ? 'Unsaved changes…' : 'Saved in this browser');
    find(this.root, '#capture-layout').hidden = review;
    find(this.root, '#review-layout').hidden = !review;
    if (this.previousScreen !== null && this.previousScreen !== state.screen) find(this.root, review ? '#review-heading' : '#voice-heading').focus();
    this.previousScreen = state.screen;
    find(this.root, '#capture-step').setAttribute('aria-current', review ? 'false' : 'step');
    find(this.root, '#review-step').setAttribute('aria-current', review ? 'step' : 'false');
    this.disabled('#capture-step', finalized || state.busy);
    this.disabled('#review-step', this.workspace.captureBusy || state.busy);
    this.text('#phase', mic.phase);
    this.text('#seconds', String(mic.seconds));
    this.text('#capture-state', mic.phase === 'recording' ? 'Microphone active' : mic.phase === 'requesting_permission' ? 'Waiting for permission' : mic.phase === 'stopping' ? 'Finishing recording' : 'Microphone inactive');
    find(this.root, '#recording-dot').classList.toggle('active', mic.phase === 'recording');
    this.disabled('#start', finalized || state.busy || mic.permissionPending || ['requesting_permission', 'recording', 'stopping'].includes(mic.phase));
    this.disabled('#stop', state.busy || mic.phase !== 'recording');
    this.disabled('#discard', state.busy || finalized || (!record.audio && mic.phase === 'idle' && !mic.permissionPending));
    this.text('#error', mic.error ?? ''); find(this.root, '#error').hidden = !mic.error;
    find(this.root, '#pending').hidden = !mic.permissionPending || mic.phase === 'requesting_permission';
    const audio = record.audio?.blob ?? null;
    if (audio !== this.currentAudio) {
      for (const selector of ['#audio', '#review-audio']) {
        const element = find<HTMLAudioElement>(this.root, selector);
        element.pause(); element.removeAttribute('src'); element.load();
        if (audio) element.src = this.urls.url(audio);
      }
      this.currentAudio = audio;
    }
    // Pause playback when changing step; do not reset it on recording timer updates.
    if (review) find<HTMLAudioElement>(this.root, '#audio').pause();
    else find<HTMLAudioElement>(this.root, '#review-audio').pause();
    find(this.root, '#playback').hidden = !audio;
    find(this.root, '#review-playback').hidden = !audio;
    this.text('#clip-info', audio ? `${bytes(audio.size)} · ${audio.type} · current encounter only` : '');
    this.text('#camera-phase', camera.phase.replaceAll('_', ' '));
    this.disabled('#open-camera', finalized || state.busy || camera.permissionPending || record.images.length >= 4 || ['preview', 'requesting_permission', 'capturing'].includes(camera.phase));
    find(this.root, '#take-photo').hidden = camera.phase !== 'preview';
    find(this.root, '#close-camera').hidden = !['requesting_permission', 'preview', 'capturing'].includes(camera.phase);
    find(this.root, '#camera-preview').hidden = !['preview', 'capturing'].includes(camera.phase);
    const previewVideo = find<HTMLVideoElement>(this.root, '#camera-video');
    this.disabled('#take-photo', state.busy || previewVideo.readyState < 2 || !previewVideo.videoWidth);
    const stream = this.workspace.camera.previewStream;
    if (stream !== this.preview) {
      this.preview = stream;
      const video = find<HTMLVideoElement>(this.root, '#camera-video'); video.srcObject = stream;
      if (stream) void video.play().catch(() => {
        if (!this.disposed && this.workspace.camera.previewStream === stream) this.workspace.camera.previewFailed();
      });
    }
    this.text('#camera-error', camera.error ?? ''); find(this.root, '#camera-error').hidden = !camera.error;
    find(this.root, '#camera-pending').hidden = !camera.permissionPending || camera.phase === 'requesting_permission';
    this.text('#image-count', `${record.images.length} / 4 photos attached · up to 1 MiB each`);
    const imageKey = record.images.map((image) => image.id).join(',');
    if (this.imageKey !== imageKey) {
      this.imageKey = imageKey;
      for (const selector of ['#image-grid', '#review-images']) find(this.root, selector).innerHTML = record.images.map((image, index) => `
        <figure><a href="${this.urls.url(image.blob)}" target="_blank" rel="noopener" aria-label="Open document photo ${index + 1}"><img src="${this.urls.url(image.blob)}" alt="Captured document photo ${index + 1}"></a><figcaption>Photo ${index + 1} · ${image.width} × ${image.height}${selector === '#image-grid' ? `<button class="text-button" data-remove-image="${escapeText(image.id)}" aria-label="Remove photo ${index + 1}">Remove</button>` : ''}</figcaption></figure>`).join('');
    }
    this.urls.keep([...(audio ? [audio] : []), ...record.images.map((image) => image.blob)]);
    const notes = find<HTMLTextAreaElement>(this.root, '#notes');
    if (document.activeElement !== notes) notes.value = record.notes;
    notes.disabled = finalized || state.busy;
    this.text('#review-heading', finalized ? 'Encounter saved' : 'Review the encounter');
    this.text('#review-description', finalized ? `Finalized ${readableDate(record.finalizedAt!)}. Sources are preserved as captured; this is not a clinical assessment.` : 'Check the sources and your notes before finalizing. Finalization organizes this record; it does not verify medical information.');
    find(this.root, '#review-sources').innerHTML = `<dl class="source-manifest"><div><dt>Voice recording</dt><dd>${audio ? `1 clip · ${bytes(audio.size)}` : 'Not captured'}</dd></div><div><dt>Document photos</dt><dd>${record.images.length} attached</dd></div><div><dt>Transcript</dt><dd>Unavailable · no speech service</dd></div></dl>`;
    this.text('#review-notes', record.notes.trim() || 'No written notes were added.');
    this.text('#structured-output', JSON.stringify(encounterOutput(record), null, 2));
    find(this.root, '#continue-review').hidden = review;
    find(this.root, '#edit-capture').hidden = !review || finalized;
    find(this.root, '#finalize').hidden = !review || finalized;
    find(this.root, '#next-encounter').hidden = !finalized;
    this.disabled('#continue-review', this.workspace.captureBusy || state.busy);
    this.disabled('#finalize', state.busy || !hasSources(record));
    find(this.root, '#empty-review').hidden = !review || finalized || hasSources(record);
    this.disabled('#delete-encounter', state.busy);
    this.disabled('#back-history', state.busy);
    const diagnostics = this.workspace.diagnostics;
    const damaged = Object.values(diagnostics.integrity).includes('mismatch');
    find(this.root, '#source-integrity-warning').hidden = !damaged;
    this.text('#source-integrity-warning', 'Source integrity check failed. Stored media differs from its fingerprint. Inspect Provenance before relying on this encounter. Finalization is blocked.');
    this.disabled('#finalize', damaged || state.busy || !hasSources(record));
    this.text('#invariant-status', diagnostics.invariantFailures.length ? `Invariant failure observed: ${diagnostics.invariantFailures.join(', ')}` : 'All checked invariants hold. Counts describe resources owned by this workspace.');
    find(this.root, '#invariant-status').classList.toggle('error', diagnostics.invariantFailures.length > 0);
    this.text('#diag-encounter', record.id);
    this.text('#diag-capture', diagnostics.captureSessionId ?? 'No capture yet');
    this.text('#generation', String(mic.generation));
    this.text('#diag-tracks', `${diagnostics.microphone.activeTracks} / ${diagnostics.camera.activeTracks}`);
    this.text('#diag-recorder', diagnostics.microphone.recorderState);
    this.text('#diag-timers', `${diagnostics.microphone.timers} / ${diagnostics.camera.timers} / ${diagnostics.saveTimer}`);
    this.text('#diag-transition', diagnostics.microphone.lastTransition);
    this.text('#diag-camera', diagnostics.camera.lastTransition);
    this.text('#diag-error', `${diagnostics.microphone.lastError ?? 'None'} / ${diagnostics.camera.lastError ?? 'None'}`);
    this.text('#resource-telemetry', JSON.stringify({ revision: diagnostics.revision, pendingWrites: diagnostics.pendingWrites, lastEvent: diagnostics.lastEvent?.type ?? null, ignoredStaleCallbacks: diagnostics.ignoredStaleCallbacks, invariants: diagnostics.invariantFailures.length ? diagnostics.invariantFailures : 'All checked invariants hold', recentSignals: diagnostics.recentSignals.slice(-3) }, null, 2));
    this.engineering.update();
    if (finalized && !this.wasFinalized) find(this.root, '#review-heading').focus();
    this.wasFinalized = finalized;
  }
  dispose(): void {
    this.disposed = true;
    this.engineering.dispose();
    for (const element of this.root.querySelectorAll('audio')) { element.pause(); element.removeAttribute('src'); element.load(); }
    const video = find<HTMLVideoElement>(this.root, '#camera-video');
    video.removeEventListener('loadeddata', this.frameReady); video.srcObject = null;
    this.urls.dispose();
  }
}
