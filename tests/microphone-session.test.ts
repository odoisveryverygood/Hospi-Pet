import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { MicrophoneSession } from '../src/microphone-session';
import type { MediaPort } from '../src/microphone-session';

class TrackedTarget extends EventTarget {
  listeners = new Map<string, Set<EventListenerOrEventListenerObject>>();
  override addEventListener(type: string, listener: EventListenerOrEventListenerObject | null): void {
    if (listener) {
      const set = this.listeners.get(type) ?? new Set();
      set.add(listener); this.listeners.set(type, set);
    }
    super.addEventListener(type, listener);
  }
  override removeEventListener(type: string, listener: EventListenerOrEventListenerObject | null): void {
    if (listener) this.listeners.get(type)?.delete(listener);
    super.removeEventListener(type, listener);
  }
  get listenerCount(): number { return [...this.listeners.values()].reduce((sum, set) => sum + set.size, 0); }
}
class Track extends TrackedTarget {
  readyState = 'live';
  stop = vi.fn(() => { this.readyState = 'ended'; });
}
class Recorder extends TrackedTarget {
  state = 'inactive';
  mimeType = 'audio/webm';
  start = vi.fn(() => { this.state = 'recording'; });
  stop = vi.fn(() => { this.state = 'inactive'; });
  data(text = 'this session'): void {
    this.dispatchEvent(Object.assign(new Event('dataavailable'), { data: new Blob([text], { type: this.mimeType }) }));
  }
  finish(): void { this.data(); this.dispatchEvent(new Event('stop')); }
}
function deferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (error: unknown) => void;
  const promise = new Promise<T>((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
}
function stream() {
  const tracks = [new Track(), new Track()];
  const value = { getTracks: () => tracks, getAudioTracks: () => tracks } as unknown as MediaStream;
  return { tracks, value };
}
function harness() {
  const streams: ReturnType<typeof stream>[] = [];
  const recorders: Recorder[] = [];
  const media = {
    supported: vi.fn(() => true),
    getUserMedia: vi.fn(async () => { const item = stream(); streams.push(item); return item.value; }),
    createRecorder: vi.fn(() => { const item = new Recorder(); recorders.push(item); return item as unknown as MediaRecorder; }),
  } satisfies MediaPort;
  const session = new MicrophoneSession(media);
  return { session, media, streams, recorders };
}
async function settle() { await Promise.resolve(); await Promise.resolve(); await Promise.resolve(); await Promise.resolve(); }
function clean(h: ReturnType<typeof harness>) {
  for (const item of h.streams) for (const track of item.tracks) {
    expect(track.readyState).toBe('ended'); expect(track.stop).toHaveBeenCalledTimes(1); expect(track.listenerCount).toBe(0);
  }
  for (const recorder of h.recorders) { expect(recorder.state).toBe('inactive'); expect(recorder.listenerCount).toBe(0); }
  expect(vi.getTimerCount()).toBe(0);
}

beforeEach(() => vi.useFakeTimers());
afterEach(() => { vi.clearAllTimers(); vi.useRealTimers(); });

describe('MicrophoneSession owns actual lifecycle decisions; only browser boundaries are faked', () => {
  it('A: grant → record → stop immediately releases tracks → final data → completed', async () => {
    const h = harness();
    h.session.start(); expect(h.session.snapshot.phase).toBe('requesting_permission');
    await settle(); expect(h.session.snapshot.phase).toBe('recording');
    await vi.advanceTimersByTimeAsync(1200); expect(h.session.snapshot.seconds).toBe(1);
    h.session.stop(); expect(h.session.snapshot.phase).toBe('stopping');
    expect(h.streams[0]!.tracks.every((t) => t.readyState === 'ended')).toBe(true);
    h.recorders[0]!.finish(); expect(h.session.snapshot.phase).toBe('completed');
    expect(await h.session.snapshot.clip!.text()).toBe('this session');
    expect(h.recorders[0]!.stop).toHaveBeenCalledTimes(1); clean(h);
  });
  it('B: denial is understandable and can be retried', async () => {
    const h = harness(); h.media.getUserMedia.mockRejectedValueOnce(new DOMException('', 'NotAllowedError'));
    h.session.start(); await settle(); expect(h.session.snapshot.error).toContain('permission denied'); clean(h);
    h.session.start(); await settle(); expect(h.session.snapshot.phase).toBe('recording'); h.session.cancel(); clean(h);
  });
  it('C: second session has fresh identity, time, chunks, and playback', async () => {
    const h = harness(); h.session.start(); await settle(); h.recorders[0]!.data('old');
    h.session.stop(); h.recorders[0]!.finish();
    h.session.start(); expect(h.session.snapshot.clip).toBeNull(); expect(h.session.snapshot.seconds).toBe(0);
    await settle(); expect(h.session.snapshot.generation).toBe(2);
    h.session.stop(); h.recorders[1]!.finish();
    expect(await h.session.snapshot.clip!.text()).toBe('this session'); clean(h);
  });
  it('D: 25 repeated sessions leave no tracks, listeners, recorders, or timers', async () => {
    const h = harness();
    for (let i = 0; i < 25; i++) {
      h.session.start(); await settle(); expect(h.session.snapshot.phase).toBe('recording');
      h.session.stop(); h.recorders[i]!.finish(); clean(h);
    }
    expect(h.media.getUserMedia).toHaveBeenCalledTimes(25);
  });
  it('E: queued callbacks from an old recorder cannot mutate or terminate the next session', async () => {
    const h = harness(); h.session.start(); await settle();
    const retired = [...h.recorders[0]!.listeners.entries()].map(([name, set]) => [name, [...set][0]!] as const);
    h.session.cancel(); h.session.start(); await settle();
    const before = h.session.snapshot;
    for (const [name, listener] of retired) (listener as EventListener)(Object.assign(new Event(name), { data: new Blob(['old data']) }));
    expect(h.session.snapshot).toEqual(before); expect(h.recorders[1]!.state).toBe('recording');
    h.session.stop(); h.recorders[1]!.finish(); expect(await h.session.snapshot.clip!.text()).toBe('this session'); clean(h);
  });
  it('F: teardown during recording is idempotent and cannot restart', async () => {
    const h = harness(); const observer = vi.fn(); h.session.subscribe(observer);
    h.session.start(); await settle(); h.session.dispose(); h.session.dispose(); clean(h);
    const calls = observer.mock.calls.length;
    h.session.start(); h.recorders[0]!.finish(); await vi.runAllTimersAsync();
    expect(observer).toHaveBeenCalledTimes(calls); expect(h.media.getUserMedia).toHaveBeenCalledTimes(1);
  });
  it('G: device failure followed by retry succeeds', async () => {
    const h = harness(); h.media.getUserMedia.mockRejectedValueOnce(new DOMException('', 'NotReadableError'));
    h.session.start(); await settle(); expect(h.session.snapshot.error).toContain('busy'); clean(h);
    h.session.start(); await settle(); h.session.stop(); h.recorders[0]!.finish(); clean(h);
  });
  it('H: duplicate starts/stops, including while stopping, create one recorder', async () => {
    const h = harness(); h.session.start(); h.session.start(); await settle(); h.session.start();
    h.session.stop(); h.session.stop(); h.session.start();
    expect(h.media.getUserMedia).toHaveBeenCalledTimes(1); expect(h.media.createRecorder).toHaveBeenCalledTimes(1);
    expect(h.recorders[0]!.stop).toHaveBeenCalledTimes(1); h.recorders[0]!.finish(); clean(h);
  });
  it('cancel during permission: late grant stops every track and never constructs a recorder', async () => {
    const h = harness(); const pending = deferred<MediaStream>(); const late = stream();
    h.media.getUserMedia.mockReturnValueOnce(pending.promise);
    h.session.start(); await settle(); h.session.stop(); expect(h.session.snapshot.phase).toBe('idle');
    h.session.start(); expect(h.media.getUserMedia).toHaveBeenCalledTimes(1);
    pending.resolve(late.value); await settle();
    expect(late.tracks.every((t) => t.stop.mock.calls.length === 1)).toBe(true);
    expect(h.media.createRecorder).not.toHaveBeenCalled(); expect(h.session.snapshot.phase).toBe('idle');
    expect(h.session.snapshot.permissionPending).toBe(false); h.session.start(); await settle(); h.session.cancel(); clean(h);
  });
  it('permission timeout keeps acquisitions serialized, releases a late stream, then permits retry', async () => {
    const h = harness(); const pending = deferred<MediaStream>(); const late = stream();
    h.media.getUserMedia.mockReturnValueOnce(pending.promise); h.session.start(); await settle();
    await vi.advanceTimersByTimeAsync(15_000); expect(h.session.snapshot.error).toContain('timed out');
    expect(h.session.snapshot.permissionPending).toBe(true); expect(vi.getTimerCount()).toBe(0);
    h.session.start(); expect(h.media.getUserMedia).toHaveBeenCalledTimes(1);
    pending.resolve(late.value); await settle(); expect(late.tracks.every((t) => t.readyState === 'ended')).toBe(true);
    h.session.start(); await settle(); h.session.cancel(); clean(h);
  });
  it('dispose during permission releases late streams without notifying disposed UI', async () => {
    const h = harness(); const pending = deferred<MediaStream>(); const late = stream(); const observer = vi.fn();
    h.media.getUserMedia.mockReturnValueOnce(pending.promise); h.session.subscribe(observer);
    h.session.start(); await settle(); h.session.dispose(); const count = observer.mock.calls.length;
    pending.resolve(late.value); await settle(); expect(observer).toHaveBeenCalledTimes(count);
    expect(late.tracks.every((t) => t.readyState === 'ended')).toBe(true); clean(h);
  });
  it('unsupported browser produces an error without requesting media', () => {
    const h = harness(); h.media.supported.mockReturnValue(false); h.session.start();
    expect(h.session.snapshot.error).toContain('does not support'); expect(h.media.getUserMedia).not.toHaveBeenCalled(); clean(h);
  });
  it('no input device produces a specific error', async () => {
    const h = harness(); h.media.getUserMedia.mockRejectedValueOnce(new DOMException('', 'NotFoundError'));
    h.session.start(); await settle(); expect(h.session.snapshot.error).toContain('No microphone'); clean(h);
  });
  it('a synchronous getUserMedia failure is contained', async () => {
    const h = harness(); h.media.getUserMedia.mockImplementationOnce(() => { throw new Error('adapter failed'); });
    h.session.start(); await settle(); expect(h.session.snapshot.error).toContain('Could not open'); clean(h);
  });
  it('recorder constructor failure releases the granted stream and permits retry', async () => {
    const h = harness(); h.media.createRecorder.mockImplementationOnce(() => { throw new Error('codec'); });
    h.session.start(); await settle(); expect(h.session.snapshot.error).toContain('initialize'); clean(h);
    h.session.start(); await settle(); h.session.cancel(); clean(h);
  });
  it('recorder start failure removes listeners and stops tracks', async () => {
    const h = harness(); const r = new Recorder(); h.recorders.push(r);
    r.start.mockImplementationOnce(() => { throw new Error('start failed'); });
    h.media.createRecorder.mockReturnValueOnce(r as unknown as MediaRecorder);
    h.session.start(); await settle(); expect(h.session.snapshot.phase).toBe('error'); clean(h);
  });
  it('recorder stop failure releases tracks even if recorder stays active', async () => {
    const h = harness(); h.session.start(); await settle();
    h.recorders[0]!.stop.mockImplementation(() => { throw new Error('stop failed'); });
    h.session.stop(); expect(h.session.snapshot.phase).toBe('error');
    expect(h.streams[0]!.tracks.every((t) => t.readyState === 'ended')).toBe(true);
    expect(h.recorders[0]!.listenerCount).toBe(0); expect(vi.getTimerCount()).toBe(0);
  });
  it('missing stop event hits watchdog; an old stop cannot complete a newer session', async () => {
    const h = harness(); h.session.start(); await settle(); h.session.stop();
    await vi.advanceTimersByTimeAsync(2000); expect(h.session.snapshot.error).toContain('did not finish'); clean(h);
    h.session.start(); await settle(); h.recorders[0]!.finish(); expect(h.session.snapshot.phase).toBe('recording');
    h.session.cancel(); clean(h);
  });
  it.each(['error', 'stop'])('unexpected recorder %s cleans up safely', async (event) => {
    const h = harness(); h.session.start(); await settle(); h.recorders[0]!.dispatchEvent(new Event(event));
    expect(h.session.snapshot.phase).toBe('error'); clean(h);
  });
  it('microphone disconnect releases all tracks and timers', async () => {
    const h = harness(); h.session.start(); await settle(); h.streams[0]!.tracks[0]!.dispatchEvent(new Event('ended'));
    expect(h.session.snapshot.error).toContain('disconnected'); clean(h);
  });
  it('recordings automatically stop at 60 seconds', async () => {
    const h = harness(); h.session.start(); await settle(); await vi.advanceTimersByTimeAsync(60_000);
    expect(h.session.snapshot.phase).toBe('stopping'); h.recorders[0]!.finish(); clean(h);
  });
  it('oversized recordings are discarded with cleanup', async () => {
    const h = harness(); h.session.start(); await settle();
    h.recorders[0]!.dispatchEvent(Object.assign(new Event('dataavailable'), { data: new Blob([new Uint8Array(8 * 1024 * 1024 + 1)]) }));
    expect(h.session.snapshot.error).toContain('8 MiB'); expect(h.session.snapshot.clip).toBeNull(); clean(h);
  });
  it('unsubscribe removes the view callback', () => {
    const h = harness(); const observer = vi.fn(); const unsubscribe = h.session.subscribe(observer);
    unsubscribe(); h.session.cancel(); expect(observer).toHaveBeenCalledTimes(1); clean(h);
  });
});
