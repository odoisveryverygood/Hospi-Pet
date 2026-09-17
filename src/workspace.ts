import { appendEvent } from './capture/events';
import type { Device, CaptureSignal, EventFact } from './capture/events';
import { inspectInvariants } from './capture/invariants';
import { verifySource } from './capture/integrity';
import type { IntegrityStatus } from './capture/integrity';
import { MicrophoneSession } from './microphone-session';
import { CameraSession } from './camera-session';
import { finalizeEncounter, LIMITS, newEncounter } from './domain/encounter';
import type { Encounter } from './domain/encounter';
import type { EncounterRepository } from './storage/encounter-store';
import { storageMessage } from './storage/encounter-store';

type CaptureOwner = { encounterId: string; generation: number; id: string };
export interface WorkspaceState {
  encounters: Encounter[];
  active: Encounter | null;
  screen: 'history' | 'capture' | 'review';
  loading: boolean;
  busy: boolean;
  dirty: boolean;
  saving: boolean;
  storageError: string | null;
  invalidCount: number;
}

/** Product orchestration. Media controllers are reused; none of their lifecycle logic is duplicated. */
export class Workspace {
  private pendingWrites = 0;
  private pendingNoteCheckpoint = false;
  private captureOwners = new Map<string, CaptureOwner>();
  private recentSignals: { encounterId: string; sessionId: string; device: Device; signal: CaptureSignal }[] = [];
  private invariantFailures = new Set<string>();
  private integrityResults: Record<string, IntegrityStatus> = {};
  private state: WorkspaceState = { encounters: [], active: null, screen: 'history', loading: true, busy: false, dirty: false, saving: false, storageError: null, invalidCount: 0 };
  private listeners = new Set<(state: Readonly<WorkspaceState>) => void>();
  private disposed = false;
  private voiceOwner: CaptureOwner | null = null;
  private cameraOwner: CaptureOwner | null = null;
  private editVersion = 0;
  private saveTimer: ReturnType<typeof setTimeout> | null = null;
  private saving: Promise<boolean> | null = null;
  private unsubscribe: (() => void)[];

  constructor(readonly repository: EncounterRepository, readonly microphone = new MicrophoneSession(), readonly camera = new CameraSession()) {
    this.unsubscribe = [microphone.trace.subscribe((signal) => this.captureEvent('microphone', signal)), camera.trace.subscribe((signal) => this.captureEvent('camera', signal)), microphone.subscribe((capture) => {
      const owner = this.voiceOwner;
      if (owner && capture.phase === 'completed' && capture.generation === owner.generation
        && owner.encounterId === this.state.active?.id && this.state.active.status === 'draft') {
        this.voiceOwner = null;
        if (capture.clip?.size) {
          const audio = { id: crypto.randomUUID(), captureSessionId: owner.id, generation: owner.generation, createdAt: new Date().toISOString(), elapsedSeconds: capture.seconds, blob: capture.clip };
          this.record({ type: 'source_attached', sourceId: audio.id, sessionId: owner.id, kind: 'audio', bytes: audio.blob.size, mime: audio.blob.type });
          this.edit({ audio }, true);
        }
      }
      this.emit();
    }), camera.subscribe((capture) => {
      const owner = this.cameraOwner;
      if (owner && capture.phase === 'completed' && capture.generation === owner.generation && capture.image
        && owner.encounterId === this.state.active?.id && this.state.active.status === 'draft') {
        this.cameraOwner = null;
        const image = { id: crypto.randomUUID(), captureSessionId: owner.id, createdAt: new Date().toISOString(), ...capture.image };
        this.record({ type: 'source_attached', sourceId: image.id, sessionId: owner.id, kind: 'image', bytes: image.blob.size, mime: image.blob.type });
        this.edit({ images: [...this.state.active!.images, image] }, true);
      }
      this.emit();
    })];
  }
  get snapshot(): Readonly<WorkspaceState> { return { ...this.state }; }
  get diagnostics() {
    return { revision: this.state.active?.revision ?? null,
      pendingWrites: this.pendingWrites,
      ignoredStaleCallbacks: this.microphone.trace.ignored + this.camera.trace.ignored,
      invariantFailures: [...this.invariantFailures], integrity: { ...this.integrityResults },
      recentSignals: [...this.recentSignals], lastEvent: this.state.active?.journal?.events.at(-1) ?? null,
      encounterId: this.state.active?.id ?? null,
      captureSessionId: this.voiceOwner?.id ?? this.state.active?.audio?.captureSessionId ?? null,
      cameraSessionId: this.cameraOwner?.id ?? null, microphone: this.microphone.diagnostics, camera: this.camera.diagnostics,
      saveTimer: this.saveTimer === null ? 0 : 1, saving: this.state.saving };
  }
  get captureBusy(): boolean {
    return ['requesting_permission', 'recording', 'stopping'].includes(this.microphone.snapshot.phase)
      || ['requesting_permission', 'preview', 'capturing'].includes(this.camera.snapshot.phase);
  }
  subscribe(listener: (state: Readonly<WorkspaceState>) => void): () => void {
    this.listeners.add(listener); listener(this.snapshot); return () => { this.listeners.delete(listener); };
  }
  private emit() {
    if (this.disposed) return;
    for (const code of inspectInvariants(this.microphone.diagnostics, this.camera.diagnostics, this.state.active?.status === 'finalized')) {
      if (!this.invariantFailures.has(code)) { this.invariantFailures.add(code); this.record({ type: 'invariant_failed', code }); }
    }
    for (const listener of this.listeners) listener(this.snapshot);
  }
  private record(fact: EventFact, at = Date.now()) {
    const active = this.state.active;
    if (!active || active.status !== 'draft' || this.disposed) return;
    this.editVersion++;
    this.state = { ...this.state, active: { ...active, journal: appendEvent(active.journal, active.id, fact, at) }, dirty: true };
    this.clearSaveTimer();
    this.saveTimer = setTimeout(() => { this.saveTimer = null; void this.flush(); }, 400);
  }
  private bind(device: Device, owner: CaptureOwner) {
    this.captureOwners.set(`${device}/${owner.generation}`, owner);
    if (this.captureOwners.size > 64) this.captureOwners.delete(this.captureOwners.keys().next().value!);
  }
  private captureEvent(device: Device, signal: CaptureSignal) {
    if (this.disposed) return;
    const owner = this.captureOwners.get(`${device}/${signal.generation}`);
    if (!owner) return;
    this.recentSignals = [...this.recentSignals.slice(-63), { encounterId: owner.encounterId, sessionId: owner.id, device, signal }];
    // Late facts from another encounter are observable, but never mutate its successor's record.
    if (owner.encounterId === this.state.active?.id) this.record({ type: 'capture', device, sessionId: owner.id, signal }, signal.at);
    this.emit();
  }
  private async verifyIntegrity(active: Encounter) {
    const sources = [...(active.audio ? [active.audio] : []), ...active.images];
    const result = await Promise.all(sources.map(async (source) => [source.id, await verifySource(source)] as const));
    if (!this.disposed && this.state.active?.id === active.id) {
      const currentIds = new Set([this.state.active.audio?.id, ...this.state.active.images.map((image) => image.id)]);
      this.integrityResults = Object.fromEntries(result.filter(([id]) => currentIds.has(id))); this.emit();
    }
  }
  private update(patch: Partial<WorkspaceState>) { this.state = { ...this.state, ...patch }; this.emit(); }

  private async saveEncounter(encounter: Encounter) {
    this.pendingWrites++; this.emit();
    try { return await this.repository.save(encounter); }
    finally { this.pendingWrites--; this.emit(); }
  }
  async refresh(): Promise<void> {
    this.update({ loading: true });
    try {
      const result = await this.repository.list();
      if (!this.disposed) this.update({ ...result, loading: false, storageError: null });
    } catch (error) { if (!this.disposed) this.update({ loading: false, storageError: storageMessage(error) }); }
  }
  private async operation(work: () => Promise<void>): Promise<void> {
    if (this.state.busy || this.disposed) return;
    this.update({ busy: true });
    try { await work(); }
    catch (error) { if (!this.disposed) this.update({ storageError: storageMessage(error) }); }
    finally { if (!this.disposed) this.update({ busy: false }); }
  }
  async create(title: string): Promise<void> {
    if (title.trim().length > LIMITS.title) return;
    return this.operation(async () => {
      if (!await this.leave()) return;
      const next = await this.saveEncounter(newEncounter(title));
      if (this.disposed) return;
      this.editVersion = 0; this.pendingNoteCheckpoint = false;
      this.integrityResults = {};
      this.update({ active: next, screen: 'capture', dirty: false, storageError: null });
    });
  }
  async open(id: string): Promise<void> {
    return this.operation(async () => {
      if (!await this.leave()) return;
      const { encounters, invalidCount } = await this.repository.list();
      if (this.disposed) return;
      const active = encounters.find((row) => row.id === id);
      if (!active) { this.update({ encounters, invalidCount, active: null, screen: 'history', storageError: 'That encounter was removed or cannot be read. Refresh history.' }); return; }
      this.editVersion = 0; this.pendingNoteCheckpoint = false;
      this.integrityResults = {};
      this.update({ active, screen: active.status === 'draft' ? 'capture' : 'review', encounters, invalidCount, dirty: false, storageError: null });
      await this.verifyIntegrity(active);
    });
  }
  async home(): Promise<void> {
    return this.operation(async () => {
      if (!await this.leave() || this.disposed) return;
      this.update({ active: null, screen: 'history' }); await this.refresh();
    });
  }
  private endCapture() {
    // Sever encounter bindings BEFORE controller cleanup can publish anything.
    this.voiceOwner = null; this.cameraOwner = null;
    this.microphone.cancel(); this.camera.cancel();
  }
  private async leave() { this.endCapture(); return this.flush(); }
  private edit(patch: Partial<Pick<Encounter, 'title' | 'notes' | 'audio' | 'images'>>, immediate = false) {
    const active = this.state.active;
    if (!active || active.status !== 'draft' || this.disposed) return;
    if (patch.audio !== undefined && active.audio && patch.audio?.id !== active.audio.id) delete this.integrityResults[active.audio.id];
    if (patch.images) for (const image of active.images) if (!patch.images.some((next) => next.id === image.id)) delete this.integrityResults[image.id];
    this.editVersion++;
    this.update({ active: { ...active, ...patch, updatedAt: new Date().toISOString() }, dirty: true });
    this.clearSaveTimer();
    if (immediate) void this.flush();
    else { this.saveTimer = setTimeout(() => { this.saveTimer = null; void this.flush(); }, 400); this.emit(); }
  }
  updateNotes(notes: string): void {
    if (notes.length <= LIMITS.notes && !this.state.busy && this.state.active?.status === 'draft' && notes !== this.state.active.notes) {
      this.pendingNoteCheckpoint = true; this.edit({ notes });
    }
  }
  startVoice(): void {
    const active = this.state.active;
    const capture = this.microphone.snapshot;
    if (!active || active.status !== 'draft' || this.state.busy || capture.permissionPending
      || ['recording', 'requesting_permission', 'stopping'].includes(capture.phase)) return;
    this.voiceOwner = { encounterId: active.id, generation: capture.generation + 1, id: crypto.randomUUID() };
    this.bind('microphone', this.voiceOwner);
    if (active.audio) this.record({ type: 'source_removed', sourceId: active.audio.id });
    this.edit({ audio: null }, true);
    this.microphone.start();
  }
  discardVoice(): void {
    if (this.state.active?.status !== 'draft' || this.state.busy) return;
    if (this.state.active.audio) this.record({ type: 'source_removed', sourceId: this.state.active.audio.id });
    this.voiceOwner = null; this.microphone.cancel(); this.edit({ audio: null }, true);
  }
  openCamera(): void {
    const active = this.state.active;
    const capture = this.camera.snapshot;
    if (!active || active.status !== 'draft' || active.images.length >= LIMITS.images || this.state.busy
      || capture.permissionPending || ['requesting_permission', 'preview', 'capturing'].includes(capture.phase)) return;
    this.cameraOwner = { encounterId: active.id, generation: capture.generation + 1, id: crypto.randomUUID() };
    this.bind('camera', this.cameraOwner);
    this.camera.open();
  }
  cancelCamera(): void { this.cameraOwner = null; this.camera.cancel(); }
  removeImage(id: string): void {
    if (this.state.busy) return;
    if (this.state.active?.images.some((image) => image.id === id)) this.record({ type: 'source_removed', sourceId: id });
    this.edit({ images: this.state.active?.images.filter((image) => image.id !== id) ?? [] }, true);
  }
  async review(): Promise<void> {
    if (this.captureBusy) return;
    return this.operation(async () => { if (await this.flush()) { this.update({ screen: 'review' }); this.record({ type: 'reviewed' }); await this.flush(); } });
  }
  editCapture(): void { if (this.state.active?.status === 'draft' && !this.state.busy) this.update({ screen: 'capture' }); }
  async finalize(): Promise<void> {
    if (this.captureBusy || this.state.active?.status !== 'draft' || Object.values(this.integrityResults).includes('mismatch')) return;
    return this.operation(async () => {
      this.endCapture();
      if (!await this.flush() || !this.state.active) return;
      const next = finalizeEncounter(this.state.active);
      // Publish finalization only after the transaction commits; failure leaves a retryable draft.
      const saved = await this.saveEncounter(next);
      if (this.disposed) return;
      this.endCapture();
      this.update({ active: saved, screen: 'review', dirty: false, storageError: null });
    });
  }
  private clearSaveTimer() { if (this.saveTimer !== null) clearTimeout(this.saveTimer); this.saveTimer = null; }
  flush(): Promise<boolean> {
    this.clearSaveTimer();
    if (this.saving) return this.saving;
    if (!this.state.dirty || !this.state.active || this.disposed) return Promise.resolve(!this.state.dirty);
    if (this.state.storageError) this.record({ type: 'persistence', outcome: 'retry', revision: this.state.active.revision });
    this.clearSaveTimer();
    this.saving = this.persist().finally(() => { this.saving = null; if (!this.disposed) this.update({ saving: false }); });
    return this.saving;
  }
  private async persist(): Promise<boolean> {
    this.update({ saving: true });
    while (!this.disposed && this.state.dirty && this.state.active) {
      if (this.pendingNoteCheckpoint) {
        this.pendingNoteCheckpoint = false;
        this.record({ type: 'notes_checkpoint', characters: this.state.active.notes.length });
        this.clearSaveTimer();
      }
      const current = this.state.active!;
      const version = this.editVersion;
      try {
        const saved = await this.saveEncounter(current);
        if (this.disposed || this.state.active?.id !== current.id) return false;
        const active = this.state.active;
        const audio = active.audio && active.audio.id === saved.audio?.id ? { ...active.audio, fingerprint: saved.audio.fingerprint } : active.audio;
        const images = active.images.map((image) => ({ ...image, fingerprint: saved.images.find((item) => item.id === image.id)?.fingerprint ?? image.fingerprint }));
        this.update({ active: { ...active, audio, images, revision: saved.revision }, dirty: this.editVersion !== version, storageError: null });
      } catch (error) { if (!this.disposed) { this.record({ type: 'persistence', outcome: 'failed', revision: current.revision }); this.clearSaveTimer(); this.update({ storageError: storageMessage(error) }); } return false; }
    }
    return !this.disposed;
  }
  async reloadSaved(): Promise<void> {
    return this.operation(async () => {
      this.endCapture(); this.clearSaveTimer();
      if (this.saving) await this.saving;
      const id = this.state.active?.id;
      const result = await this.repository.list();
      if (this.disposed) return;
      const active = result.encounters.find((row) => row.id === id) ?? null;
      this.integrityResults = {}; this.pendingNoteCheckpoint = false;
      this.update({ ...result, active, dirty: false, storageError: null, screen: active ? (active.status === 'draft' ? 'capture' : 'review') : 'history' });
      if (active) await this.verifyIntegrity(active);
    });
  }
  async deleteEncounter(id: string): Promise<void> {
    return this.operation(async () => {
      this.endCapture(); this.clearSaveTimer();
      if (this.saving) await this.saving;
      await this.repository.delete(id);
      if (this.disposed) return;
      this.captureOwners.clear(); this.recentSignals = []; this.integrityResults = {}; this.pendingNoteCheckpoint = false;
      this.update({ active: null, screen: 'history', dirty: false, storageError: null }); await this.refresh();
    });
  }
  async clearLocalData(): Promise<void> {
    return this.operation(async () => {
      this.endCapture(); this.clearSaveTimer();
      if (this.saving) await this.saving;
      await this.repository.clear();
      if (this.disposed) return;
      this.captureOwners.clear(); this.recentSignals = []; this.integrityResults = {}; this.pendingNoteCheckpoint = false;
      this.update({ active: null, screen: 'history', dirty: false, storageError: null }); await this.refresh();
    });
  }
  async removeInvalid(): Promise<void> { return this.operation(async () => { await this.repository.removeInvalid(); await this.refresh(); }); }
  dispose(): void {
    if (this.disposed) return;
    this.disposed = true; this.voiceOwner = null; this.cameraOwner = null;
    this.clearSaveTimer(); this.unsubscribe.forEach((fn) => fn());
    this.microphone.dispose(); this.camera.dispose(); this.listeners.clear(); this.repository.close();
  }
}
