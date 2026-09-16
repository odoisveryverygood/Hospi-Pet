import { afterEach, beforeEach, expect, it, vi } from 'vitest';
import { CameraSession } from '../src/camera-session';
import { deferred, frame, mediaStream, microtasks } from './media-fakes';
const video = {} as HTMLVideoElement;
function setup() {
  const streams: ReturnType<typeof mediaStream>[] = [];
  const port = {
    supported: vi.fn(() => true),
    getUserMedia: vi.fn(async () => { const stream = mediaStream(); streams.push(stream); return stream.stream; }),
    encode: vi.fn(async () => frame),
  };
  const session = new CameraSession(port);
  return { streams, port, session };
}
function released(h: ReturnType<typeof setup>) {
  for (const { track } of h.streams) { expect(track.readyState).toBe('ended'); expect(track.stop).toHaveBeenCalledTimes(1); expect(track.listeners.size).toBe(0); }
  expect(h.session.diagnostics.activeTracks).toBe(0); expect(h.session.diagnostics.timers).toBe(0);
  expect(vi.getTimerCount()).toBe(0);
}
beforeEach(() => vi.useFakeTimers());
afterEach(() => { vi.clearAllTimers(); vi.useRealTimers(); });
it('grant → preview → photograph → immediate track release → completed image', async () => {
  const h = setup(); h.session.open(); await microtasks();
  expect(h.session.snapshot.phase).toBe('preview'); expect(h.session.previewStream).toBe(h.streams[0]!.stream);
  h.session.capture(video); expect(h.streams[0]!.track.readyState).toBe('ended'); await microtasks();
  expect(h.session.snapshot.image).toEqual(frame); expect(h.session.snapshot.phase).toBe('completed'); released(h);
});
it('denial gives a specific error and retry succeeds', async () => {
  const h = setup(); h.port.getUserMedia.mockRejectedValueOnce(new DOMException('', 'NotAllowedError'));
  h.session.open(); await microtasks(); expect(h.session.snapshot.error).toContain('permission denied'); released(h);
  h.session.open(); await microtasks(); expect(h.session.snapshot.phase).toBe('preview'); h.session.cancel(); released(h);
});
it('20 camera sessions release every track, timer, and listener', async () => {
  const h = setup();
  for (let i = 0; i < 20; i++) { h.session.open(); await microtasks(); h.session.capture(video); await microtasks(); released(h); }
  expect(h.port.getUserMedia).toHaveBeenCalledTimes(20);
});
it('duplicate open/capture cannot acquire twice or encode twice', async () => {
  const h = setup(); h.session.open(); h.session.open(); await microtasks(); h.session.capture(video); h.session.capture(video); await microtasks();
  expect(h.port.getUserMedia).toHaveBeenCalledTimes(1); expect(h.port.encode).toHaveBeenCalledTimes(1); released(h);
});
it('canceling permission stops a late stream without entering preview', async () => {
  const h = setup(); const pending = deferred<MediaStream>(); const late = mediaStream();
  h.port.getUserMedia.mockReturnValueOnce(pending.promise); h.session.open(); await microtasks(); h.session.cancel(); h.session.open();
  expect(h.port.getUserMedia).toHaveBeenCalledTimes(1); pending.resolve(late.stream); await microtasks();
  expect(late.track.stop).toHaveBeenCalledTimes(1); expect(h.session.snapshot.phase).toBe('idle'); expect(h.session.snapshot.permissionPending).toBe(false); released(h);
});
it('late image encoding cannot contaminate a later camera session', async () => {
  const h = setup(); const pending = deferred<typeof frame>(); h.port.encode.mockReturnValueOnce(pending.promise);
  h.session.open(); await microtasks(); h.session.capture(video); h.session.cancel(); h.session.open(); await microtasks();
  pending.resolve(frame); await microtasks(); expect(h.session.snapshot.phase).toBe('preview'); expect(h.session.snapshot.image).toBeNull();
  h.session.cancel(); released(h);
});
it('disposed preview releases resources and removes subscribers', async () => {
  const h = setup(); const observer = vi.fn(); h.session.subscribe(observer); h.session.open(); await microtasks();
  h.session.dispose(); const calls = observer.mock.calls.length; h.session.open(); h.session.dispose();
  expect(observer).toHaveBeenCalledTimes(calls); released(h);
});
it('disposed pending permission releases late stream', async () => {
  const h = setup(); const pending = deferred<MediaStream>(); const late = mediaStream(); h.port.getUserMedia.mockReturnValueOnce(pending.promise);
  h.session.open(); await microtasks(); h.session.dispose(); pending.resolve(late.stream); await microtasks();
  expect(late.track.readyState).toBe('ended'); released(h);
});
it('permission timeout releases owner; retry waits for the unresolved browser request', async () => {
  const h = setup(); const pending = deferred<MediaStream>(); h.port.getUserMedia.mockReturnValueOnce(pending.promise);
  h.session.open(); await microtasks(); await vi.advanceTimersByTimeAsync(15_000);
  expect(h.session.snapshot.error).toContain('timed out'); expect(h.session.snapshot.permissionPending).toBe(true);
  pending.reject(new DOMException('', 'NotAllowedError')); await microtasks(); released(h);
});
it('abandoned preview closes at 60 seconds', async () => {
  const h = setup(); h.session.open(); await microtasks(); await vi.advanceTimersByTimeAsync(60_000);
  expect(h.session.snapshot.error).toContain('60 seconds'); released(h);
});
it('encoding timeout rejects late callbacks and releases tracks', async () => {
  const h = setup(); const pending = deferred<typeof frame>(); h.port.encode.mockReturnValueOnce(pending.promise);
  h.session.open(); await microtasks(); h.session.capture(video); await vi.advanceTimersByTimeAsync(5000);
  expect(h.session.snapshot.error).toContain('encoding timed out'); pending.resolve(frame); await microtasks(); expect(h.session.snapshot.image).toBeNull(); released(h);
});
it('disconnect errors are recoverable and remove track listeners', async () => {
  const h = setup(); h.session.open(); await microtasks(); h.streams[0]!.track.dispatchEvent(new Event('ended'));
  expect(h.session.snapshot.error).toContain('disconnected'); released(h);
});
it('encode failures and oversized images release tracks', async () => {
  const h = setup(); h.port.encode.mockRejectedValueOnce(new Error('Invalid frame'));
  h.session.open(); await microtasks(); h.session.capture(video); await microtasks(); expect(h.session.snapshot.error).toBe('Invalid frame'); released(h);
  h.port.encode.mockResolvedValueOnce({ ...frame, blob: new Blob([new Uint8Array(1024 * 1024 + 1)], { type: 'image/jpeg' }) });
  h.session.open(); await microtasks(); h.session.capture(video); await microtasks(); expect(h.session.snapshot.error).toContain('oversized'); released(h);
});
it('unsupported browser and missing device errors do not invent a preview', async () => {
  const h = setup(); h.port.supported.mockReturnValueOnce(false); h.session.open(); expect(h.session.snapshot.error).toContain('unsupported');
  h.port.getUserMedia.mockRejectedValueOnce(new DOMException('', 'NotFoundError')); h.session.open(); await microtasks(); expect(h.session.snapshot.error).toContain('No camera'); released(h);
});

it('a subscriber canceling at acquisition does not leave an ownerless timer or request', () => {
  const camera = new CameraSession({ supported: () => true, getUserMedia: vi.fn(), encode: vi.fn() });
  camera.subscribe((state) => { if (state.phase === 'requesting_permission') camera.cancel(); });
  camera.open();
  expect(camera.snapshot.phase).toBe('idle');
  expect(camera.diagnostics.timers).toBe(0);
  expect(vi.getTimerCount()).toBe(0);
});
