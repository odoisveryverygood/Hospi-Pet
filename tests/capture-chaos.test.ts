import { afterAll, afterEach, expect, it, vi } from 'vitest';
import { mkdir, writeFile } from 'node:fs/promises';
import { CaptureLab } from '../src/capture/lab';
import type { Scenario } from '../src/capture/lab';
import { Workspace } from '../src/workspace';
import { MicrophoneSession } from '../src/microphone-session';
import { CameraSession } from '../src/camera-session';
import type { Encounter } from '../src/domain/encounter';
import { deferred, frame, mediaStream, microtasks, TestRecorder } from './media-fakes';
const cleanups: (() => void)[] = [];
const matrix: { scenario: string; expected: string; resources: string; data: string; result: string }[] = [];
afterEach(() => { cleanups.splice(0).forEach((fn) => fn()); vi.useRealTimers(); });
afterAll(async () => { await mkdir('test-results', { recursive: true }); await writeFile('test-results/chaos-matrix.json', JSON.stringify(matrix, null, 2) + '\n'); });
function setup() {
  const lab = new CaptureLab(); const rows = new Map<string, Encounter>();
  const streams: ReturnType<typeof mediaStream>[] = []; const recorders: TestRecorder[] = [];
  const acquire = async () => { const item = mediaStream(); streams.push(item); return item.stream; };
  const repo = lab.repository({ list: async () => ({ encounters: [...rows.values()], invalidCount: 0 }), save: async (e) => { const saved = { ...e, revision: e.revision + 1 }; rows.set(e.id, saved); return saved; }, delete: async (id) => { rows.delete(id); }, clear: async () => { rows.clear(); }, removeInvalid: async () => {}, close: () => {} });
  const mic = new MicrophoneSession(lab.media({ supported: () => true, getUserMedia: acquire, createRecorder: () => { const r = new TestRecorder(); recorders.push(r); return r as unknown as MediaRecorder; } }));
  const camera = new CameraSession(lab.camera({ supported: () => true, getUserMedia: acquire, encode: async () => frame }));
  const workspace = new Workspace(repo, mic, camera);
  cleanups.push(() => { workspace.dispose(); lab.dispose(); });
  const released = () => {
    expect(streams.every((s) => s.track.readyState === 'ended')).toBe(true);
    expect(mic.diagnostics.activeTracks + camera.diagnostics.activeTracks + mic.diagnostics.timers + camera.diagnostics.timers).toBe(0);
    expect(workspace.diagnostics.invariantFailures).toEqual([]);
  };
  return { lab, rows, workspace, mic, camera, recorders, streams, released };
}
for (const scenario of ['microphone-denied', 'microphone-failure', 'recorder-error', 'camera-denied'] as Scenario[]) {
  it(`chaos: ${scenario} uses real controller cleanup and retry`, async () => {
    const h = setup(); await h.workspace.create('Fault recovery'); h.lab.arm(scenario);
    const camera = scenario === 'camera-denied';
    if (camera) h.workspace.openCamera(); else h.workspace.startVoice();
    await microtasks(); expect((camera ? h.camera : h.mic).snapshot.phase).toBe('error'); h.released();
    if (camera) { h.workspace.openCamera(); await microtasks(); expect(h.camera.snapshot.phase).toBe('preview'); h.workspace.cancelCamera(); }
    else { h.workspace.startVoice(); await microtasks(); expect(h.mic.snapshot.phase).toBe('recording'); h.workspace.discardVoice(); }
    await h.workspace.flush(); h.released();
    matrix.push({ scenario, expected: 'error → retry → capture → idle', resources: '0 tracks / capture timers', data: 'no failed source attached', result: 'PASS' });
  });
}
it('chaos: delayed permission after navigation cannot change the second encounter', async () => {
  const h = setup(); await h.workspace.create('First'); h.lab.arm('microphone-delay'); h.workspace.startVoice(); await microtasks();
  expect(h.lab.pending).toBe(1); await h.workspace.create('Second'); const before = JSON.stringify(h.workspace.snapshot.active);
  h.lab.release(); await microtasks();
  expect(JSON.stringify(h.workspace.snapshot.active)).toBe(before); expect(h.workspace.diagnostics.ignoredStaleCallbacks).toBe(1); h.released();
  expect(h.workspace.diagnostics.recentSignals.at(-1)!.encounterId).not.toBe(h.workspace.snapshot.active!.id);
  matrix.push({ scenario: 'late microphone grant', expected: 'second encounter idle', resources: '0 tracks / capture timers', data: 'second encounter byte-for-byte unchanged', result: 'PASS' });
});
it('chaos: queued final recorder callbacks after a new encounter cannot attach old audio', async () => {
  const h = setup(); await h.workspace.create('First'); h.lab.arm('final-data-delay'); h.workspace.startVoice(); await microtasks();
  h.mic.stop(); h.mic.stop(); h.recorders[0]!.finish(); await microtasks(); expect(h.lab.pending).toBe(2);
  await h.workspace.create('Second'); const before = JSON.stringify(h.workspace.snapshot.active); h.lab.release(); await microtasks();
  expect(JSON.stringify(h.workspace.snapshot.active)).toBe(before); expect(h.workspace.diagnostics.ignoredStaleCallbacks).toBe(2); h.released();
  matrix.push({ scenario: 'late final data + duplicate stop', expected: 'second encounter idle', resources: '0 tracks / capture timers', data: 'old callbacks ignored', result: 'PASS' });
});
it('chaos: camera encoding across encounter switch releases tracks before the callback', async () => {
  const h = setup(); await h.workspace.create('First'); h.workspace.openCamera(); await microtasks();
  h.lab.arm('camera-encode-delay'); h.camera.capture({} as HTMLVideoElement); await microtasks(); expect(h.streams[0]!.track.readyState).toBe('ended');
  await h.workspace.create('Second'); const before = JSON.stringify(h.workspace.snapshot.active); h.lab.release(); await microtasks();
  expect(JSON.stringify(h.workspace.snapshot.active)).toBe(before); expect(h.workspace.diagnostics.ignoredStaleCallbacks).toBe(1); h.released();
  matrix.push({ scenario: 'late camera encode', expected: 'second encounter idle', resources: '0 tracks / capture timers', data: 'old image not attached', result: 'PASS' });
});
for (const scenario of ['storage-failure', 'storage-conflict'] as const) {
  it(`chaos: ${scenario} preserves unsaved changes and never claims success`, async () => {
    const h = setup(); await h.workspace.create('Storage'); h.lab.arm(scenario); h.workspace.updateNotes('Keep this');
    expect(await h.workspace.flush()).toBe(false); expect(h.workspace.snapshot.dirty).toBe(true); expect(h.workspace.snapshot.storageError).toBeTruthy();
    expect(h.rows.get(h.workspace.snapshot.active!.id)!.notes).toBe('');
    expect(await h.workspace.flush()).toBe(true); expect(h.rows.get(h.workspace.snapshot.active!.id)!.notes).toBe('Keep this'); h.released();
    matrix.push({ scenario, expected: 'visible error → explicit retry', resources: '0 tracks / capture timers', data: 'unsaved notes preserved', result: 'PASS' });
  });
}
it('chaos: delayed write observes pending writes and persists later edits before leaving', async () => {
  const h = setup(); await h.workspace.create('Storage'); h.lab.arm('storage-delay'); h.workspace.updateNotes('One'); const save = h.workspace.flush();
  expect(h.workspace.diagnostics.pendingWrites).toBe(1); h.workspace.updateNotes('Two'); h.lab.release(); await save;
  expect(h.workspace.diagnostics.pendingWrites).toBe(0); expect(h.rows.get(h.workspace.snapshot.active!.id)!.notes).toBe('Two');
  await h.workspace.home(); expect(h.workspace.diagnostics.saveTimer).toBe(0); h.released();
  matrix.push({ scenario: 'delayed write + subsequent edit', expected: 'saved latest revision', resources: '0 tracks / timers', data: 'latest edit persisted', result: 'PASS' });
});
it('held final data times out safely; releasing afterward cannot resurrect a source', async () => {
  vi.useFakeTimers(); const h = setup(); await h.workspace.create('Timeout'); h.lab.arm('final-data-delay'); h.workspace.startVoice(); await microtasks();
  h.mic.stop(); h.recorders[0]!.finish(); await vi.advanceTimersByTimeAsync(2001);
  expect(h.mic.snapshot.phase).toBe('error'); h.lab.release(); await microtasks(); expect(h.workspace.snapshot.active!.audio).toBeNull(); h.released();
});
it('runtime invariant monitor exposes an injected controller violation without content', async () => {
  const h = setup(); await h.workspace.create('Invariant');
  const normal = h.mic.diagnostics;
  vi.spyOn(h.mic, 'diagnostics', 'get').mockReturnValue({ ...normal, activeTracks: 1 });
  h.workspace.updateNotes('PRIVATE');
  expect(h.workspace.diagnostics.invariantFailures).toContain('microphone_resources');
  expect(JSON.stringify(h.workspace.snapshot.active!.journal)).not.toContain('PRIVATE');
});
it('disposing the lab with held acquisition does not open a device afterward', async () => {
  const h = setup(); await h.workspace.create('Dispose'); h.lab.arm('microphone-delay'); h.workspace.startVoice(); await microtasks();
  h.workspace.dispose(); h.lab.dispose(); await microtasks(); expect(h.streams).toHaveLength(0); expect(h.lab.pending).toBe(0);
});
it('teardown during hash verification prevents results from being published', async () => {
  const h = setup(); const gate = deferred<ArrayBuffer>();
  await h.workspace.create('First'); const firstId = h.workspace.snapshot.active!.id;
  const source = { id: 'old', captureSessionId: 'old-session', generation: 1, createdAt: new Date().toISOString(), elapsedSeconds: 1, blob: new Blob(['a'], { type: 'audio/webm' }), fingerprint: { algorithm: 'SHA-256' as const, digest: '0'.repeat(64), bytes: 1, mime: 'audio/webm' } };
  vi.spyOn(source.blob, 'arrayBuffer').mockReturnValue(gate.promise);
  h.rows.set(firstId, { ...h.workspace.snapshot.active!, audio: source });
  await h.workspace.home(); const opening = h.workspace.open(firstId); await microtasks();
  h.workspace.dispose(); gate.resolve(new TextEncoder().encode('a').buffer); await opening;
  expect(h.workspace.diagnostics.integrity).toEqual({});
});
it('real controller facts order release before final data and attachment; finalization projects zero hardware', async () => {
  const h = setup(); await h.workspace.create('Ordering'); h.workspace.startVoice(); await microtasks(); h.mic.stop(); h.recorders[0]!.finish();
  await h.workspace.flush(); await h.workspace.review(); await h.workspace.finalize();
  const events = h.workspace.snapshot.active!.journal!.events;
  const position = (action: string) => events.findIndex((e) => e.type === 'capture' && e.signal.action === action);
  expect(position('recording')).toBeLessThan(position('stopping'));
  expect(position('stopping')).toBeLessThan(position('tracks_released'));
  expect(position('tracks_released')).toBeLessThan(position('data_received'));
  expect(position('completed')).toBeLessThan(events.findIndex((e) => e.type === 'source_attached'));
  expect(events.at(-1)!.type).toBe('finalized'); h.released();
  expect(h.workspace.diagnostics.saveTimer).toBe(0);
});

it('typing coalesces into one content-free note checkpoint per save boundary', async () => {
  const h = setup(); await h.workspace.create('Typing');
  for (let i = 1; i <= 600; i++) h.workspace.updateNotes('x'.repeat(i));
  expect(h.workspace.snapshot.active!.journal!.events).toHaveLength(1);
  await h.workspace.flush();
  const checkpoints = h.workspace.snapshot.active!.journal!.events.filter((e) => e.type === 'notes_checkpoint');
  expect(checkpoints).toHaveLength(1); expect(checkpoints[0]).toMatchObject({ characters: 600 });
  expect(JSON.stringify(checkpoints)).not.toContain('xxxx');
});
it('lab callback storage has a hard bound and releases every queued encoder result', async () => {
  const h = setup(); const port = h.lab.camera({ supported: () => true, getUserMedia: async () => mediaStream().stream, encode: async () => frame });
  const results: Promise<typeof frame>[] = [];
  for (let i = 0; i < 10; i++) { h.lab.arm('camera-encode-delay'); results.push(port.encode({} as HTMLVideoElement)); }
  await microtasks(); expect(h.lab.pending).toBe(8); expect(h.lab.last).toContain('queue limit');
  h.lab.release(); expect(await Promise.all(results)).toHaveLength(10); expect(h.lab.pending).toBe(0);
});
it('queued recorder promise continuations cannot repopulate lab buffers after reset or disposal', async () => {
  for (const dispose of [false, true]) {
    const h = setup(); await h.workspace.create('Lab teardown'); h.lab.arm('final-data-delay'); h.workspace.startVoice(); await microtasks();
    h.mic.stop(); h.recorders[0]!.finish(); await microtasks(); expect(h.lab.pending).toBe(2);
    h.workspace.dispose(); if (dispose) h.lab.dispose(); else h.lab.reset(); await microtasks();
    expect(h.lab.retainedCallbacks).toBe(0); expect(h.lab.pending).toBe(0); h.released();
  }
});
