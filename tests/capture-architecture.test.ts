import { expect, it } from 'vitest';
import { IDBFactory } from 'fake-indexeddb';
import { appendEvent, MAX_EVENTS, replay, validJournal } from '../src/capture/events';
import { fingerprint, verifySource } from '../src/capture/integrity';
import { inspectInvariants } from '../src/capture/invariants';
import { manifest, serializeManifest, validManifest } from '../src/capture/manifest';
import { isEncounter, newEncounter } from '../src/domain/encounter';
import { IndexedEncounterStore } from '../src/storage/encounter-store';
function sample() {
  const record = newEncounter('Private title');
  record.notes = 'PRIVATE NOTE TEXT';
  record.audio = { id: 'audio1', captureSessionId: 'session1', generation: 1, createdAt: record.createdAt, elapsedSeconds: 2, blob: new Blob(['abc'], { type: 'audio/webm' }) };
  record.journal = appendEvent(record.journal, record.id, { type: 'source_attached', sourceId: 'audio1', sessionId: 'session1', kind: 'audio', bytes: 3, mime: 'audio/webm' });
  return record;
}
it('event sequence stays authoritative when the wall clock moves backwards; replay prefixes are deterministic', () => {
  let journal = appendEvent(undefined, 'encounter', { type: 'encounter_created' }, 100);
  journal = appendEvent(journal, 'encounter', { type: 'notes_checkpoint', characters: 4 }, 50);
  expect(journal.events.map((e) => e.sequence)).toEqual([1, 2]);
  expect(replay(journal.events, 1).notesCharacters).toBe(0);
  expect(replay(journal.events, 2)).toEqual(replay(journal.events, 2));
  expect(replay(journal.events, 2).notesCharacters).toBe(4);
});
it('stale capture facts are visible in replay but cannot replace the current owner', () => {
  let journal = appendEvent(undefined, 'encounter', { type: 'capture', device: 'microphone', sessionId: 'new', signal: { action: 'recording', generation: 2, at: 2, phase: 'recording', tracks: 1, timers: 2 } });
  journal = appendEvent(journal, 'encounter', { type: 'capture', device: 'microphone', sessionId: 'old', signal: { action: 'stale_ignored', generation: 1, at: 3, phase: 'idle', tracks: 0, timers: 0 } });
  expect(replay(journal.events)).toMatchObject({ ignored: 1, microphone: { sessionId: 'new', phase: 'recording', tracks: 1 } });
});
it('bounded journal retains its prefix and counts omitted facts rather than pretending replay is complete', () => {
  let journal = appendEvent(undefined, 'encounter', { type: 'encounter_created' });
  for (let i = 0; i < MAX_EVENTS + 10; i++) journal = appendEvent(journal, 'encounter', { type: 'notes_checkpoint', characters: i });
  expect(journal.events).toHaveLength(MAX_EVENTS); expect(journal.omitted).toBe(11); expect(validJournal(journal, 'encounter')).toBe(true);
  expect(new Blob([JSON.stringify(journal)]).size).toBeLessThan(150_000);
});
it('journal validation rejects foreign owners, raw payloads, invalid sequence and unbounded metadata', () => {
  const e = sample(); const journal = e.journal!;
  expect(validJournal(journal, 'foreign')).toBe(false);
  expect(validJournal({ ...journal, events: [{ ...journal.events[0], rawAudio: 'private' }] }, e.id)).toBe(false);
  expect(validJournal({ ...journal, events: [{ ...journal.events[0], sequence: 7 }] }, e.id)).toBe(false);
  expect(isEncounter({ ...e, journal: { ...journal, omitted: -1 } })).toBe(false);
});
it('SHA-256 matches a known vector and detects same-size content mutation', async () => {
  const e = sample(); e.audio!.fingerprint = await fingerprint(e.audio!.blob);
  expect(e.audio!.fingerprint.digest).toBe('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  expect(await verifySource(e.audio!)).toBe('verified');
  expect(await verifySource({ ...e.audio!, blob: new Blob(['abd'], { type: 'audio/webm' }) })).toBe('mismatch');
  expect(await verifySource({ ...e.audio!, blob: new Blob(['abc'], { type: 'audio/ogg' }) })).toBe('mismatch');
});
it('legacy records stay readable and missing historical fingerprints are explicit', async () => {
  const e = sample(); delete e.journal;
  expect(isEncounter(e)).toBe(true); expect(await verifySource(e.audio!)).toBe('legacy-unhashed');
  const store = new IndexedEncounterStore('legacy', new IDBFactory());
  expect((await store.save(e)).audio!.fingerprint).toBeUndefined(); store.close();
});
it('hashing occurs before atomic IDB save; reopen verifies media and journal together', async () => {
  const factory = new IDBFactory(); const store = new IndexedEncounterStore('hashes', factory);
  const saved = await store.save(sample()); expect(saved.audio!.fingerprint?.digest).toHaveLength(64); store.close();
  const next = new IndexedEncounterStore('hashes', factory); const restored = (await next.list()).encounters[0]!;
  expect(restored.journal).toEqual(saved.journal); expect(await verifySource(restored.audio!)).toBe('verified');
  await next.delete(restored.id); expect((await next.list()).encounters).toEqual([]); next.close();
});
it('manifest follows actual provenance and exports neither media nor written content', async () => {
  const e = sample(); e.audio!.fingerprint = await fingerprint(e.audio!.blob);
  e.journal = appendEvent(e.journal, e.id, { type: 'reviewed' });
  const output = manifest(e); expect(validManifest(output)).toBe(true);
  expect(output.sources[0]!.creationEventId).toBe(e.journal.events[1]!.id);
  expect(output.relationships.map((r) => r.relation)).toEqual(['owns', 'produced', 'fingerprinted', 'reviewed']);
  const text = serializeManifest(e); expect(text).toBe(serializeManifest(e));
  expect(text).not.toContain('PRIVATE NOTE'); expect(text).not.toContain('Private title'); expect(text).not.toContain('blob');
});
it('manifest validation rejects fabricated edges, foreign sources and injected fields', () => {
  const output = manifest(sample());
  expect(validManifest({ ...output, relationships: [] })).toBe(false);
  expect(validManifest({ ...output, sources: [{ ...output.sources[0], encounterId: 'foreign' }] })).toBe(false);
  expect(validManifest({ ...output, rawMedia: 'do not allow' })).toBe(false);
  expect(validManifest({ ...output, sources: [{ ...output.sources[0], creationEventId: 'invented' }] })).toBe(false);
});
it('source removal changes replay availability without deleting historical provenance events', () => {
  const e = sample(); e.journal = appendEvent(e.journal, e.id, { type: 'source_removed', sourceId: 'audio1' });
  expect(replay(e.journal.events, 2).sources).toEqual(['audio1']); expect(replay(e.journal.events).sources).toEqual([]);
});
it('invariant failures are structured and cannot pass as idle or finalized', () => {
  const idle = { state: 'idle', activeTracks: 0, timers: 0, listeners: 0 };
  expect(inspectInvariants(idle, idle, false)).toEqual([]);
  expect(inspectInvariants({ ...idle, activeTracks: 1 }, { ...idle, timers: 1 }, true)).toEqual(['microphone_resources', 'camera_resources', 'finalized_hardware']);
});
it('a hashing failure prevents the IDB write rather than storing a partially fingerprinted source', async () => {
  const { vi } = await import('vitest');
  const store = new IndexedEncounterStore('hash-failure', new IDBFactory());
  const digest = vi.spyOn(crypto.subtle, 'digest').mockRejectedValueOnce(new Error('Injected crypto failure'));
  await expect(store.save(sample())).rejects.toThrow('Injected crypto failure');
  expect((await store.list()).encounters).toEqual([]); digest.mockRestore(); store.close();
});

it('stored vector images are rejected so opening a captured photo cannot execute SVG scripts', () => {
  const e = newEncounter('Validation');
  e.images = [{ id: 'svg', captureSessionId: 'session', createdAt: e.createdAt, width: 1, height: 1, blob: new Blob(['<svg/>'], { type: 'image/svg+xml' }) }];
  expect(isEncounter(e)).toBe(false);
});
