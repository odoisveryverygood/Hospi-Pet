import { CaptureTrace } from './capture/events';
import type { CaptureAction } from './capture/events';
import { LIMITS } from './domain/encounter';
export interface CameraImage { blob: Blob; width: number; height: number }
export interface CameraSnapshot {
  phase: 'idle' | 'requesting_permission' | 'preview' | 'capturing' | 'completed' | 'error';
  generation: number;
  permissionPending: boolean;
  image: CameraImage | null;
  error: string | null;
}
export interface CameraPort {
  supported(): boolean;
  getUserMedia(): Promise<MediaStream>;
  encode(video: HTMLVideoElement): Promise<CameraImage>;
}
export const browserCamera: CameraPort = {
  supported: () => !!navigator.mediaDevices?.getUserMedia,
  getUserMedia: () => navigator.mediaDevices.getUserMedia({ video: { facingMode: { ideal: 'environment' } }, audio: false }),
  encode: (video) => {
    if (!video.videoWidth || !video.videoHeight) return Promise.reject(new Error('Camera frame is not ready. Open the camera again and wait for its preview.'));
    const scale = Math.min(1, 1280 / Math.max(video.videoWidth, video.videoHeight));
    const canvas = document.createElement('canvas');
    canvas.width = Math.max(1, Math.round(video.videoWidth * scale));
    canvas.height = Math.max(1, Math.round(video.videoHeight * scale));
    const context = canvas.getContext('2d');
    if (!context) return Promise.reject(new Error('Image capture is unavailable in this browser.'));
    context.drawImage(video, 0, 0, canvas.width, canvas.height);
    return new Promise((resolve, reject) => canvas.toBlob((blob) => {
      if (!blob || !blob.size || blob.size > LIMITS.imageBytes) reject(new Error('Image could not be saved within the 1 MiB limit. Try a simpler, well-lit frame.'));
      else resolve({ blob, width: canvas.width, height: canvas.height });
    }, 'image/jpeg', 0.85));
  },
};
interface Owner { generation: number; stream: MediaStream | null; timers: Set<ReturnType<typeof setTimeout>>; remove: (() => void)[] }

/** Camera owns acquisition/preview/encoding; the view only borrows previewStream. */
export class CameraSession {
  readonly trace = new CaptureTrace();
  private signal(action: CaptureAction, generation = this.state.generation) {
    this.trace.emit({ action, generation, at: Date.now(), phase: this.state.phase, tracks: this.diagnostics.activeTracks, timers: this.diagnostics.timers });
  }
  private state: CameraSnapshot = { phase: 'idle', generation: 0, permissionPending: false, image: null, error: null };
  private owner: Owner | null = null;
  private disposed = false;
  private subscribers = new Set<(state: Readonly<CameraSnapshot>) => void>();
  private transition = 'initial → idle';
  private lastError: string | null = null;
  constructor(private readonly port: CameraPort = browserCamera) {}
  get snapshot(): Readonly<CameraSnapshot> { return { ...this.state }; }
  get previewStream(): MediaStream | null { return this.owner?.stream ?? null; }
  get diagnostics() {
    return { state: this.state.phase, activeTracks: this.owner?.stream?.getTracks().filter((t) => t.readyState === 'live').length ?? 0,
      timers: this.owner?.timers.size ?? 0, listeners: this.owner?.remove.length ?? 0, lastTransition: this.transition, lastError: this.lastError };
  }
  subscribe(listener: (state: Readonly<CameraSnapshot>) => void): () => void {
    if (this.disposed) return () => {};
    this.subscribers.add(listener); listener(this.snapshot);
    return () => { this.subscribers.delete(listener); };
  }
  private publish(patch: Partial<CameraSnapshot>) {
    if (patch.error) this.lastError = patch.error;
    if (patch.phase && patch.phase !== this.state.phase) this.transition = `${this.state.phase} → ${patch.phase}`;
    const changed = patch.phase && patch.phase !== this.state.phase;
    this.state = { ...this.state, ...patch };
    if (changed) this.signal(patch.phase === 'requesting_permission' ? 'request' : patch.phase!);
    for (const listener of this.subscribers) listener(this.snapshot);
  }
  private owns(owner: Owner) { return !this.disposed && this.owner === owner; }
  open(): void {
    if (this.disposed || this.owner || this.state.permissionPending) return;
    const owner: Owner = { generation: this.state.generation + 1, stream: null, timers: new Set(), remove: [] };
    this.owner = owner;
    this.publish({ phase: 'requesting_permission', generation: this.state.generation + 1, error: null, image: null });
    if (!this.owns(owner)) return;
    if (!this.port.supported()) { this.fail(owner, 'Camera access is unsupported. Use a current browser on localhost or HTTPS.'); return; }
    this.publish({ permissionPending: true });
    const deadline = this.later(owner, () => this.fail(owner, 'Camera permission timed out. Dismiss the browser prompt before retrying; reload if it never settles.'), 15_000);
    void Promise.resolve().then(() => this.port.getUserMedia()).then((stream) => {
      clearTimeout(deadline); owner.timers.delete(deadline);
      if (!this.owns(owner)) { this.stopTracks(stream); this.signal('stale_ignored', owner.generation); this.publish({ permissionPending: false }); return; }
      owner.stream = stream;
      this.signal('acquired', owner.generation);
      if (!stream.getVideoTracks().some((t) => t.readyState === 'live')) {
        this.fail(owner, 'No live camera track was returned. Reconnect the camera and retry.');
        this.publish({ permissionPending: false }); return;
      }
      for (const track of stream.getTracks()) {
        const ended = () => { if (this.owns(owner)) this.fail(owner, 'Camera disconnected. Reconnect it and retry.'); };
        track.addEventListener('ended', ended); owner.remove.push(() => track.removeEventListener('ended', ended));
      }
      this.later(owner, () => this.fail(owner, 'Camera preview closed after 60 seconds. Open it again when ready.'), 60_000);
      this.publish({ phase: 'preview', permissionPending: false });
    }, (error: unknown) => {
      if (this.owns(owner)) {
        const name = error instanceof Error ? error.name : '';
        this.fail(owner, name === 'NotAllowedError' ? 'Camera permission denied. Allow access in site settings and retry.'
          : name === 'NotFoundError' ? 'No camera found. Connect a camera and retry.' : 'Camera unavailable or busy. Check your device and retry.');
      }
      this.publish({ permissionPending: false });
    });
  }
  capture(video: HTMLVideoElement): void {
    const owner = this.owner;
    if (!owner || this.state.phase !== 'preview' || this.disposed) return;
    this.clearTimers(owner);
    this.publish({ phase: 'capturing' });
    if (!this.owns(owner)) return;
    this.later(owner, () => this.fail(owner, 'Image encoding timed out. Open the camera to retry.'), 5000);
    let result: Promise<CameraImage>;
    try { result = this.port.encode(video); }
    catch { this.fail(owner, 'Could not capture this frame. Open the camera to retry.'); return; }
    finally { this.releaseStream(owner); this.publish({}); }
    void result.then((image) => {
      if (!this.owns(owner)) { this.signal('stale_ignored', owner.generation); return; }
      if (!image.blob.size || image.blob.size > LIMITS.imageBytes || !['image/jpeg', 'image/png', 'image/webp'].includes(image.blob.type)) {
        this.fail(owner, 'Image encoding returned an invalid or oversized image. Retry capture.'); return;
      }
      this.release(owner); this.publish({ phase: 'completed', image });
    }, (error: unknown) => { if (this.owns(owner)) this.fail(owner, error instanceof Error ? error.message : 'Image capture failed. Retry.'); });
  }
  previewFailed(): void { if (this.owner) this.fail(this.owner, 'Camera preview could not play. Open the camera again to retry.'); }
  cancel(): void {
    if (this.disposed) return;
    if (this.owner) this.release(this.owner);
    this.publish({ phase: 'idle', error: null, image: null });
  }
  dispose(): void {
    if (this.disposed) return;
    if (this.owner) this.release(this.owner);
    this.disposed = true; this.subscribers.clear(); this.trace.clear(); this.state = { ...this.state, phase: 'idle', image: null };
  }
  private later(owner: Owner, callback: () => void, delay: number) {
    const timer = setTimeout(() => { owner.timers.delete(timer); if (this.owns(owner)) callback(); }, delay);
    owner.timers.add(timer); return timer;
  }
  private clearTimers(owner: Owner) { for (const timer of owner.timers) clearTimeout(timer); owner.timers.clear(); }
  private stopTracks(stream: MediaStream) { for (const track of stream.getTracks()) if (track.readyState !== 'ended') track.stop(); }
  private releaseStream(owner: Owner) {
    for (const remove of owner.remove) remove(); owner.remove = [];
    if (owner.stream) { this.stopTracks(owner.stream); owner.stream = null; this.signal('tracks_released', owner.generation); }
  }
  private release(owner: Owner) {
    if (this.owner === owner) this.owner = null;
    this.clearTimers(owner); this.releaseStream(owner);
  }
  private fail(owner: Owner, error: string) {
    if (!this.owns(owner)) return;
    this.release(owner); this.publish({ phase: 'error', error, image: null });
  }
}
