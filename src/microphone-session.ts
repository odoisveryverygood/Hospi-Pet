import { CaptureTrace } from './capture/events';
import type { CaptureAction } from './capture/events';
export type Phase = 'idle' | 'requesting_permission' | 'recording' | 'stopping' | 'completed' | 'error';
export interface Snapshot {
  phase: Phase;
  generation: number;
  seconds: number;
  error: string | null;
  clip: Blob | null;
  /** Browser requests cannot be aborted. Serialize acquisitions until one settles. */
  permissionPending: boolean;
}
export interface MediaPort {
  supported(): boolean;
  getUserMedia(): Promise<MediaStream>;
  createRecorder(stream: MediaStream): MediaRecorder;
}
export const browserMedia: MediaPort = {
  supported: () => !!globalThis.navigator?.mediaDevices?.getUserMedia && typeof MediaRecorder !== 'undefined',
  getUserMedia: () => navigator.mediaDevices.getUserMedia({ audio: true }),
  createRecorder: (stream) => new MediaRecorder(stream),
};
interface Owner {
  id: number;
  stream: MediaStream | null;
  recorder: MediaRecorder | null;
  chunks: Blob[];
  bytes: number;
  timers: Set<ReturnType<typeof setTimeout>>;
  removeListeners: (() => void)[];
  startedAt: number;
}
const PERMISSION_TIMEOUT = 15_000;
const STOP_TIMEOUT = 2_000;
const MAX_DURATION = 60_000;
const MAX_BYTES = 8 * 1024 * 1024;

function acquisitionError(error: unknown): string {
  const name = error instanceof Error ? error.name : '';
  if (name === 'NotAllowedError' || name === 'SecurityError') return 'Microphone permission denied. Allow access in your browser settings, then retry.';
  if (name === 'NotFoundError') return 'No microphone found. Connect an audio input, then retry.';
  if (name === 'NotReadableError') return 'The microphone is unavailable or busy. Check your device, then retry.';
  return 'Could not open the microphone. Check browser permission and your audio device, then retry.';
}

/** One instance per mounted workspace. All asynchronous callbacks close over their owner. */
export class MicrophoneSession {
  readonly trace = new CaptureTrace();
  private signal(action: CaptureAction, generation = this.state.generation) {
    this.trace.emit({ action, generation, at: Date.now(), phase: this.state.phase, tracks: this.diagnostics.activeTracks, timers: this.diagnostics.timers });
  }
  private state: Snapshot = { phase: 'idle', generation: 0, seconds: 0, error: null, clip: null, permissionPending: false };
  private owner: Owner | null = null;
  private generation = 0;
  private disposed = false;
  private transition = 'initial → idle';
  private lastError: string | null = null;
  private subscribers = new Set<(state: Readonly<Snapshot>) => void>();

  constructor(private readonly media: MediaPort = browserMedia) {}

  get snapshot(): Readonly<Snapshot> { return { ...this.state }; }

  subscribe(listener: (state: Readonly<Snapshot>) => void): () => void {
    if (this.disposed) return () => {};
    this.subscribers.add(listener);
    listener(this.snapshot);
    return () => { this.subscribers.delete(listener); };
  }

  get diagnostics() {
    return { state: this.state.phase, recorderState: this.owner?.recorder?.state ?? 'inactive',
      activeTracks: this.owner?.stream?.getTracks().filter((track) => track.readyState === 'live').length ?? 0,
      timers: this.owner?.timers.size ?? 0, listeners: this.owner?.removeListeners.length ?? 0,
      lastTransition: this.transition, lastError: this.lastError };
  }

  private publish(patch: Partial<Snapshot>): void {
    if (patch.error) this.lastError = patch.error;
    if (patch.phase && patch.phase !== this.state.phase) this.transition = `${this.state.phase} → ${patch.phase}`;
    const changed = patch.phase && patch.phase !== this.state.phase;
    this.state = { ...this.state, ...patch };
    if (changed) this.signal(patch.phase === 'requesting_permission' ? 'request' : patch.phase!);
    for (const listener of this.subscribers) listener(this.snapshot);
  }

  private owns(owner: Owner): boolean { return !this.disposed && this.owner === owner; }

  start(): void {
    if (this.disposed || this.owner || this.state.permissionPending) return;
    const owner: Owner = { id: ++this.generation, stream: null, recorder: null, chunks: [], bytes: 0, timers: new Set(), removeListeners: [], startedAt: 0 };
    this.owner = owner;
    this.publish({ phase: 'requesting_permission', generation: owner.id, error: null, seconds: 0, clip: null });
    if (!this.owns(owner)) return; // A subscriber may synchronously cancel.
    if (!this.media.supported()) {
      this.fail(owner, 'This browser does not support microphone recording. Use a current browser on localhost or HTTPS.');
      return;
    }
    this.publish({ permissionPending: true });
    if (!this.owns(owner)) { this.publish({ permissionPending: false }); return; }
    const deadline = this.later(owner, () => this.fail(owner, 'Microphone request timed out. Dismiss the browser prompt; retry becomes available when it settles. Reload if the browser leaves it pending.'), PERMISSION_TIMEOUT);
    // Promise.resolve also catches an adapter that throws synchronously.
    void Promise.resolve().then(() => this.media.getUserMedia()).then((stream) => {
      this.cancelTimer(owner, deadline);
      if (!this.owns(owner)) {
        this.stopTracks(stream);
        this.signal('stale_ignored', owner.id);
        this.publish({ permissionPending: false });
        return;
      }
      owner.stream = stream;
      this.signal('acquired', owner.id);
      this.publish({ permissionPending: false });
      if (!this.owns(owner)) return;
      if (!stream.getAudioTracks().some((track) => track.readyState === 'live')) {
        this.fail(owner, 'The microphone returned no live audio track. Reconnect it and retry.');
        return;
      }
      try {
        const recorder = this.media.createRecorder(stream);
        owner.recorder = recorder;
        this.listen(owner, recorder, 'dataavailable', (event) => {
          const data = (event as BlobEvent).data;
          if (!data.size) return;
          owner.bytes += data.size;
          if (owner.bytes > MAX_BYTES) { this.fail(owner, 'Recording exceeded the 8 MiB demo limit. Start a shorter session.'); return; }
          owner.chunks.push(data);
          if (this.state.phase === 'stopping') this.signal('data_received', owner.id);
        });
        this.listen(owner, recorder, 'error', () => this.fail(owner, 'The recorder failed. Microphone resources were released; retry the session.'));
        this.listen(owner, recorder, 'stop', () => {
          if (this.state.phase !== 'stopping') {
            this.fail(owner, 'Recording ended unexpectedly. Check the microphone, then retry.');
            return;
          }
          const clip = new Blob(owner.chunks, { type: recorder.mimeType || owner.chunks[0]?.type || '' });
          this.release(owner);
          this.publish({ phase: 'completed', clip });
        });
        for (const track of stream.getTracks()) this.listen(owner, track, 'ended', () => this.fail(owner, 'The microphone disconnected. Reconnect it, then retry.'));
        recorder.start(250);
        owner.startedAt = Date.now();
        this.publish({ phase: 'recording' });
        if (!this.owns(owner)) return;
        const tick = () => {
          if (!this.owns(owner) || this.state.phase !== 'recording') return;
          this.publish({ seconds: Math.floor((Date.now() - owner.startedAt) / 1000) });
          if (this.owns(owner) && this.state.phase === 'recording') this.later(owner, tick, 250);
        };
        this.later(owner, tick, 250);
        this.later(owner, () => this.stop(), MAX_DURATION);
      } catch {
        this.fail(owner, 'The recorder could not initialize or start. Microphone resources were released; retry in a supported browser.');
      }
    }, (error: unknown) => {
      this.cancelTimer(owner, deadline);
      if (this.owns(owner)) this.fail(owner, acquisitionError(error));
      this.publish({ permissionPending: false });
    });
  }

  stop(): void {
    const owner = this.owner;
    if (!owner || this.disposed) return;
    if (this.state.phase === 'requesting_permission') { this.cancel(); return; }
    if (this.state.phase !== 'recording') return;
    this.clearTimers(owner);
    this.publish({ phase: 'stopping' });
    if (!this.owns(owner)) return;
    // Install the watchdog before stop: a faulty adapter could dispatch synchronously.
    this.later(owner, () => this.fail(owner, 'The recorder did not finish. Resources were released; retry the session.'), STOP_TIMEOUT);
    try {
      owner.recorder?.stop();
    } catch {
      this.fail(owner, 'The recorder could not stop cleanly. Resources were released; retry the session.');
    } finally {
      // Permission indicator goes off now, not after asynchronous encoding finishes.
      const hadTracks = owner.stream?.getTracks().some((track) => track.readyState === 'live');
      this.stopTracks(owner.stream);
      if (hadTracks) this.signal('tracks_released', owner.id);
      this.publish({});
    }
  }

  cancel(): void {
    if (this.disposed) return;
    if (this.owner) this.release(this.owner);
    this.publish({ phase: 'idle', seconds: 0, error: null, clip: null });
  }

  dispose(): void {
    if (this.disposed) return;
    if (this.owner) this.release(this.owner);
    this.disposed = true;
    this.subscribers.clear(); this.trace.clear();
    this.state = { ...this.state, phase: 'idle', seconds: 0, error: null, clip: null };
  }

  private listen(owner: Owner, target: EventTarget, type: string, callback: (event: Event) => void): void {
    const guarded: EventListener = (event) => { if (this.owns(owner)) callback(event); else this.signal('stale_ignored', owner.id); };
    target.addEventListener(type, guarded);
    owner.removeListeners.push(() => target.removeEventListener(type, guarded));
  }

  private later(owner: Owner, callback: () => void, delay: number): ReturnType<typeof setTimeout> {
    const timer = setTimeout(() => {
      owner.timers.delete(timer);
      if (this.owns(owner)) callback();
    }, delay);
    owner.timers.add(timer);
    return timer;
  }
  private cancelTimer(owner: Owner, timer: ReturnType<typeof setTimeout>): void {
    clearTimeout(timer);
    owner.timers.delete(timer);
  }
  private clearTimers(owner: Owner): void {
    for (const timer of owner.timers) clearTimeout(timer);
    owner.timers.clear();
  }
  private stopTracks(stream: MediaStream | null): void {
    for (const track of stream?.getTracks() ?? []) {
      if (track.readyState !== 'ended') track.stop();
    }
  }
  private release(owner: Owner): void {
    // Invalidate FIRST: stop can enqueue callbacks, including from a retiring owner.
    if (this.owner === owner) this.owner = null;
    this.clearTimers(owner);
    for (const remove of owner.removeListeners) remove();
    owner.removeListeners = [];
    try {
      if (owner.recorder && owner.recorder.state !== 'inactive') owner.recorder.stop();
    } catch {
      // Track release in finally is authoritative even when stop throws.
    } finally {
      this.stopTracks(owner.stream);
      owner.stream = null;
      owner.recorder = null;
      owner.chunks = [];
      this.signal('resources_released', owner.id);
    }
  }
  private fail(owner: Owner, message: string): void {
    if (!this.owns(owner)) return;
    this.release(owner);
    this.publish({ phase: 'error', error: message, clip: null });
  }
}
