import { vi } from 'vitest';
export class TestTrack extends EventTarget {
  readyState = 'live';
  listeners = new Set<EventListenerOrEventListenerObject>();
  stop = vi.fn(() => { this.readyState = 'ended'; });
  override addEventListener(type: string, listener: EventListenerOrEventListenerObject | null): void {
    if (listener) this.listeners.add(listener); super.addEventListener(type, listener);
  }
  override removeEventListener(type: string, listener: EventListenerOrEventListenerObject | null): void {
    if (listener) this.listeners.delete(listener); super.removeEventListener(type, listener);
  }
}
export function mediaStream() {
  const track = new TestTrack();
  return { track, stream: { getTracks: () => [track], getAudioTracks: () => [track], getVideoTracks: () => [track] } as unknown as MediaStream };
}
export class TestRecorder extends EventTarget {
  state = 'inactive'; mimeType = 'audio/webm';
  start() { this.state = 'recording'; }
  stop() { this.state = 'inactive'; }
  finish(text = 'actual boundary fixture') {
    this.dispatchEvent(Object.assign(new Event('dataavailable'), { data: new Blob([text], { type: this.mimeType }) }));
    this.dispatchEvent(new Event('stop'));
  }
}
export function deferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (error: unknown) => void;
  const promise = new Promise<T>((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
}
export async function microtasks() { for (let i = 0; i < 12; i++) await Promise.resolve(); }
export const frame = { blob: new Blob(['jpeg fixture'], { type: 'image/jpeg' }), width: 640, height: 480 };
