import { observePageRequests } from './network';
import { browserMedia } from '../microphone-session';
import type { MediaPort } from '../microphone-session';
import { browserCamera } from '../camera-session';
import type { CameraPort } from '../camera-session';
import type { EncounterRepository } from '../storage/encounter-store';
import { StorageConflict } from '../storage/encounter-store';
export const SCENARIOS = ['microphone-delay', 'microphone-denied', 'microphone-failure', 'camera-denied', 'recorder-error', 'final-data-delay', 'camera-encode-delay', 'storage-delay', 'storage-failure', 'storage-conflict'] as const;
export type Scenario = typeof SCENARIOS[number];
/** Single-shot gates at existing ports. Loaded only in development via ?lab=1. */
export class CaptureLab {
  readonly scenarios = SCENARIOS;
  private listeners = new Set<() => void>();
  private network: ReturnType<typeof observePageRequests> | null = null;
  inspectNetwork(capturing: () => boolean) { this.network = observePageRequests(capturing, () => this.emit()); }
  get requests() { return this.network?.snapshot() ?? null; }
  subscribe(listener: () => void) { this.listeners.add(listener); return () => { this.listeners.delete(listener); }; }
  private emit() { for (const listener of this.listeners) listener(); }
  private armed: Scenario | null = null;
  private retired: (() => void)[] = [];
  redeliver() { for (const callback of this.retired) callback(); this.last = `Redelivered ${this.retired.length} recorder callback(s)`; this.emit(); }
  private gates: (() => void)[] = [];
  private disposed = false;
  private epoch = 0;
  reset() { this.epoch++; this.armed = null; this.retired = []; this.release(); }
  last = 'No fault injected';
  get pending() { return this.gates.length; }
  get scenario() { return this.armed; }
  arm(scenario: Scenario) { if (!this.disposed) { this.armed = scenario; this.last = `Armed: ${scenario}`; this.emit(); } }
  private take(scenario: Scenario) { if (this.armed !== scenario) return false; this.armed = null; this.last = `Injected: ${scenario}`; this.emit(); return true; }
  private hold<T>(value: T): Promise<T> {
    if (this.disposed) return Promise.resolve(value);
    return new Promise((resolve) => { this.gates.push(() => resolve(value)); this.emit(); });
  }
  release() { const gates = this.gates.splice(0); for (const release of gates) release(); this.last = `Released ${gates.length} pending callback(s)`; this.emit(); }
  dispose() { this.disposed = true; this.armed = null; this.release(); this.network?.dispose(); this.retired = []; this.listeners.clear(); }
  media(base: MediaPort = browserMedia): MediaPort {
    return { supported: () => base.supported(), getUserMedia: async () => {
      if (this.take('microphone-denied')) throw new DOMException('Lab denial', 'NotAllowedError');
      if (this.take('microphone-failure')) throw new DOMException('Lab device failure', 'NotReadableError');
      if (this.take('microphone-delay')) { const epoch = this.epoch; await this.hold(undefined); if (this.disposed || epoch !== this.epoch) throw new Error('Lab disposed'); }
      return base.getUserMedia();
    }, createRecorder: (stream) => {
      const recorder = base.createRecorder(stream);
      // Dispatch through the actual EventTarget, so the controller's ordinary error cleanup runs.
      if (this.take('recorder-error')) queueMicrotask(() => recorder.dispatchEvent(new Event('error')));
      const delayed = this.take('final-data-delay');
      if (!delayed) return recorder;
      const wrappers = new Map<EventListenerOrEventListenerObject, EventListener>();
      return new Proxy(recorder, { get: (target, key) => {
        if (key === 'addEventListener') return (type: string, listener: EventListenerOrEventListenerObject) => {
          const wrapped: EventListener = (event) => {
            const invoke = () => typeof listener === 'function' ? listener.call(target, event) : listener.handleEvent(event);
            if (target.state === 'inactive' && (type === 'dataavailable' || type === 'stop')) void this.hold(undefined).then(() => { this.retired = [...this.retired.slice(-1), invoke]; invoke(); });
            else invoke();
          };
          wrappers.set(listener, wrapped); target.addEventListener(type, wrapped);
        };
        if (key === 'removeEventListener') return (type: string, listener: EventListenerOrEventListenerObject) => {
          target.removeEventListener(type, wrappers.get(listener) ?? listener); wrappers.delete(listener);
        };
        const value: unknown = Reflect.get(target, key, target);
        return typeof value === 'function' ? value.bind(target) : value;
      } });
    } };
  }
  camera(base: CameraPort = browserCamera): CameraPort {
    return { supported: () => base.supported(), getUserMedia: async () => {
      if (this.take('camera-denied')) throw new DOMException('Lab denial', 'NotAllowedError');
      return base.getUserMedia();
    }, encode: async (video) => {
      const delay = this.take('camera-encode-delay');
      const image = await base.encode(video);
      return delay ? this.hold(image) : image;
    } };
  }
  repository(base: EncounterRepository): EncounterRepository {
    return { list: () => base.list(), delete: (id) => base.delete(id), clear: () => base.clear(), removeInvalid: () => base.removeInvalid(), close: () => base.close(), save: async (encounter) => {
      if (this.take('storage-failure')) throw new DOMException('Lab write failure', 'QuotaExceededError');
      if (this.take('storage-conflict')) throw new StorageConflict();
      if (this.take('storage-delay')) { const epoch = this.epoch; await this.hold(undefined); if (this.disposed || epoch !== this.epoch) throw new Error('Lab disposed'); }
      return base.save(encounter);
    } };
  }
}
