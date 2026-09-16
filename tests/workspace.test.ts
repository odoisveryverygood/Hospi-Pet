import { afterEach, beforeEach, expect, it, vi } from 'vitest';
import { Workspace } from '../src/workspace';
import { MicrophoneSession } from '../src/microphone-session';
import { CameraSession } from '../src/camera-session';
import type { Encounter } from '../src/domain/encounter';
import type { EncounterRepository } from '../src/storage/encounter-store';
import { deferred, frame, mediaStream, microtasks, TestRecorder } from './media-fakes';

class MemoryRepository implements EncounterRepository {
  rows = new Map<string, Encounter>();
  fail = false;
  list = async () => ({ encounters: [...this.rows.values()], invalidCount: 0 });
  save = vi.fn(async (record: Encounter) => {
    if (this.fail) throw new DOMException('', 'QuotaExceededError');
    const saved = { ...record, revision: record.revision + 1 };
    this.rows.set(saved.id, saved); return saved;
  });
  async delete(id: string) { this.rows.delete(id); }
  async clear() { this.rows.clear(); }
  async removeInvalid() {}
  close() {}
}
function setup() {
  const repo = new MemoryRepository();
  const audioStreams: ReturnType<typeof mediaStream>[] = [];
  const cameraStreams: ReturnType<typeof mediaStream>[] = [];
  const recorders: TestRecorder[] = [];
  const media = {
    supported: () => true,
    getUserMedia: vi.fn(async () => { const item = mediaStream(); audioStreams.push(item); return item.stream; }),
    createRecorder: () => { const item = new TestRecorder(); recorders.push(item); return item as unknown as MediaRecorder; },
  };
  const cameraPort = {
    supported: () => true,
    getUserMedia: vi.fn(async () => { const item = mediaStream(); cameraStreams.push(item); return item.stream; }),
    encode: vi.fn(async () => frame),
  };
  const workspace = new Workspace(repo, new MicrophoneSession(media), new CameraSession(cameraPort));
  return { repo, workspace, media, cameraPort, audioStreams, cameraStreams, recorders };
}
const video = {} as HTMLVideoElement;
beforeEach(() => vi.useFakeTimers());
afterEach(() => { vi.clearAllTimers(); vi.useRealTimers(); });
it('create → voice + photo + written notes → review → finalize → next encounter isolates every source', async () => {
  const h = setup(); await h.workspace.create('First'); const firstId = h.workspace.snapshot.active!.id;
  h.workspace.startVoice(); await microtasks(); h.workspace.microphone.stop(); h.recorders[0]!.finish('first clip'); await h.workspace.flush();
  h.workspace.openCamera(); await microtasks(); h.workspace.camera.capture(video); await microtasks(); await h.workspace.flush();
  h.workspace.updateNotes('Written context'); await h.workspace.review();
  expect(h.workspace.snapshot.screen).toBe('review'); await h.workspace.finalize();
  const first = h.workspace.snapshot.active!; expect(first.status).toBe('finalized'); expect(first.images).toHaveLength(1);
  expect(await first.audio!.blob.text()).toBe('first clip'); expect(first.audio!.captureSessionId).toBeTruthy();
  expect(h.workspace.diagnostics.microphone.activeTracks).toBe(0); expect(h.workspace.diagnostics.camera.activeTracks).toBe(0);
  expect(h.workspace.diagnostics.microphone.timers + h.workspace.diagnostics.camera.timers + h.workspace.diagnostics.saveTimer).toBe(0);
  await h.workspace.create('Second'); expect(h.workspace.snapshot.active!.id).not.toBe(firstId);
  expect(h.workspace.snapshot.active!.audio).toBeNull(); expect(h.workspace.snapshot.active!.images).toEqual([]); expect(h.workspace.snapshot.active!.notes).toBe('');
  h.workspace.startVoice(); await microtasks(); h.workspace.microphone.stop(); h.recorders[1]!.finish('second clip'); await h.workspace.flush();
  expect(await h.workspace.snapshot.active!.audio!.blob.text()).toBe('second clip'); expect(await h.repo.rows.get(firstId)!.audio!.blob.text()).toBe('first clip');
  expect(h.workspace.snapshot.active!.audio!.captureSessionId).not.toBe(first.audio!.captureSessionId); h.workspace.dispose();
});
it('switch encounters while permission is pending: late grant never attaches to the new encounter', async () => {
  const h = setup(); const pending = deferred<MediaStream>(); const late = mediaStream(); h.media.getUserMedia.mockReturnValueOnce(pending.promise);
  await h.workspace.create('First'); h.workspace.startVoice(); await microtasks(); await h.workspace.create('Second');
  pending.resolve(late.stream); await microtasks(); expect(late.track.readyState).toBe('ended'); expect(h.workspace.snapshot.active!.audio).toBeNull();
  expect(h.recorders).toHaveLength(0); h.workspace.dispose();
});
it('old camera encode promise cannot attach to the next encounter', async () => {
  const h = setup(); const pending = deferred<typeof frame>(); h.cameraPort.encode.mockReturnValueOnce(pending.promise);
  await h.workspace.create('First'); h.workspace.openCamera(); await microtasks(); h.workspace.camera.capture(video);
  await h.workspace.create('Second'); pending.resolve(frame); await microtasks(); expect(h.workspace.snapshot.active!.images).toEqual([]);
  expect(h.cameraStreams[0]!.track.readyState).toBe('ended'); h.workspace.dispose();
});
it('finalize is blocked while capture is active and does not abandon capture', async () => {
  const h = setup(); await h.workspace.create('Live'); h.workspace.startVoice(); await microtasks(); await h.workspace.finalize();
  expect(h.workspace.snapshot.active!.status).toBe('draft'); expect(h.workspace.microphone.snapshot.phase).toBe('recording'); h.workspace.dispose();
});
it('finalized records reject media, note, and removal edits', async () => {
  const h = setup(); await h.workspace.create('Final'); h.workspace.updateNotes('Original'); await h.workspace.finalize();
  h.workspace.updateNotes('Modified'); h.workspace.startVoice(); h.workspace.openCamera(); h.workspace.discardVoice();
  expect(h.workspace.snapshot.active!.notes).toBe('Original'); expect(h.media.getUserMedia).not.toHaveBeenCalled(); expect(h.cameraPort.getUserMedia).not.toHaveBeenCalled(); h.workspace.dispose();
});
it('failed save retains dirty data; retry persists it without creating duplicate encounters', async () => {
  const h = setup(); await h.workspace.create('Retry'); h.repo.fail = true; h.workspace.updateNotes('Keep this text');
  expect(await h.workspace.flush()).toBe(false); expect(h.workspace.snapshot.dirty).toBe(true); expect(h.workspace.snapshot.storageError).toContain('still in this page');
  h.repo.fail = false; expect(await h.workspace.flush()).toBe(true); expect(h.repo.rows.size).toBe(1); expect(h.workspace.snapshot.dirty).toBe(false); h.workspace.dispose();
});
it('failed finalization remains a saved draft and can retry', async () => {
  const h = setup(); await h.workspace.create('Retry finalization'); h.workspace.updateNotes('Notes'); await h.workspace.flush(); h.repo.fail = true;
  await h.workspace.finalize(); expect(h.workspace.snapshot.active!.status).toBe('draft'); h.repo.fail = false;
  await h.workspace.finalize(); expect(h.workspace.snapshot.active!.status).toBe('finalized'); h.workspace.dispose();
});
it('navigation flushes debounced notes before opening another encounter', async () => {
  const h = setup(); await h.workspace.create('First'); const id = h.workspace.snapshot.active!.id;
  h.workspace.updateNotes('Last keystroke'); await h.workspace.create('Second'); expect(h.repo.rows.get(id)!.notes).toBe('Last keystroke');
  expect(vi.getTimerCount()).toBe(0); h.workspace.dispose();
});
it('an in-flight save followed by new edits cannot incorrectly clear dirty state', async () => {
  const h = setup(); await h.workspace.create('Editing'); const pending = deferred<Encounter>();
  h.repo.save.mockImplementationOnce(async (record) => { await pending.promise; const saved = { ...record, revision: record.revision + 1 }; h.repo.rows.set(saved.id, saved); return saved; });
  h.workspace.updateNotes('Version one'); const flushing = h.workspace.flush(); h.workspace.updateNotes('Version two');
  pending.resolve(h.workspace.snapshot.active!); await flushing;
  expect(h.repo.rows.get(h.workspace.snapshot.active!.id)!.notes).toBe('Version two'); expect(h.workspace.snapshot.dirty).toBe(false); h.workspace.dispose();
});
it('deleting during a save waits for it, preventing resurrection', async () => {
  const h = setup(); await h.workspace.create('Delete'); const id = h.workspace.snapshot.active!.id;
  h.workspace.updateNotes('pending note'); const flushing = h.workspace.flush(); const deletion = h.workspace.deleteEncounter(id);
  await flushing; await deletion; expect(h.repo.rows.has(id)).toBe(false); await vi.runAllTimersAsync(); expect(h.repo.rows.size).toBe(0); h.workspace.dispose();
});
it('ending and disposing a workspace releases both devices and all owned timers', async () => {
  const h = setup(); await h.workspace.create('Dispose'); h.workspace.startVoice(); h.workspace.openCamera(); await microtasks(); h.workspace.updateNotes('pending edit');
  h.workspace.dispose(); expect(h.audioStreams[0]!.track.readyState).toBe('ended'); expect(h.cameraStreams[0]!.track.readyState).toBe('ended');
  expect(vi.getTimerCount()).toBe(0); expect(h.workspace.diagnostics.saveTimer).toBe(0);
});
it('photo attachments enforce the four-source product limit', async () => {
  const h = setup(); await h.workspace.create('Photos');
  for (let i = 0; i < 4; i++) { h.workspace.openCamera(); await microtasks(); h.workspace.camera.capture(video); await microtasks(); await h.workspace.flush(); }
  h.workspace.openCamera(); expect(h.cameraPort.getUserMedia).toHaveBeenCalledTimes(4); expect(h.workspace.snapshot.active!.images).toHaveLength(4); h.workspace.dispose();
});
