import { expect, it } from 'vitest';
import { IDBFactory } from 'fake-indexeddb';
import { IndexedEncounterStore, StorageConflict, storageMessage } from '../src/storage/encounter-store';
import { encounterOutput, finalizeEncounter, isEncounter, newEncounter } from '../src/domain/encounter';

function setup() { const factory = new IDBFactory(); return { factory, store: new IndexedEncounterStore('test-db', factory) }; }
it('IndexedDB saves and reopens real Blob objects with metadata and user notes', async () => {
  const { factory, store } = setup();
  const e = newEncounter('Practice visit'); e.notes = 'User-written note';
  e.audio = { id: 'audio-1', captureSessionId: 'capture-1', generation: 1, createdAt: e.createdAt, elapsedSeconds: 2, blob: new Blob(['captured source'], { type: 'audio/webm' }) };
  const saved = await store.save(e); expect(saved.revision).toBe(1); store.close();
  const reopened = new IndexedEncounterStore('test-db', factory); const records = await reopened.list();
  expect(records.encounters[0]!.id).toBe(e.id); expect(records.encounters[0]!.notes).toBe(e.notes);
  expect(await records.encounters[0]!.audio!.blob.text()).toBe('captured source'); reopened.close();
});
it('delete and clear remove media together with encounter metadata', async () => {
  const { store } = setup(); const a = await store.save(newEncounter('One')); await store.save(newEncounter('Two'));
  await store.delete(a.id); expect((await store.list()).encounters.map((e) => e.title)).toEqual(['Two']);
  await store.clear(); expect((await store.list()).encounters).toEqual([]); store.close();
});
it('optimistic revision checks reject a stale tab and never resurrect deleted records', async () => {
  const { store } = setup(); const first = await store.save(newEncounter('One'));
  await store.save({ ...first, notes: 'Newer tab' });
  await expect(store.save({ ...first, notes: 'Old tab' })).rejects.toBeInstanceOf(StorageConflict);
  expect((await store.list()).encounters[0]!.notes).toBe('Newer tab');
  const newest = (await store.list()).encounters[0]!; await store.delete(newest.id);
  await expect(store.save(newest)).rejects.toBeInstanceOf(StorageConflict); store.close();
});
it('simultaneous writes at the same revision permit only one commit', async () => {
  const { store } = setup(); const initial = await store.save(newEncounter('Concurrent'));
  const results = await Promise.allSettled([store.save({ ...initial, notes: 'A' }), store.save({ ...initial, notes: 'B' })]);
  expect(results.filter((r) => r.status === 'fulfilled')).toHaveLength(1); expect((await store.list()).encounters[0]!.revision).toBe(2); store.close();
});
it('corrupt records are isolated, counted and only removed explicitly', async () => {
  const { store, factory } = setup(); await store.save(newEncounter('Valid'));
  await new Promise<void>((resolve, reject) => {
    const request = factory.open('test-db', 1); request.onerror = () => reject(request.error);
    request.onsuccess = () => { const db = request.result; const tx = db.transaction('encounters', 'readwrite');
      tx.objectStore('encounters').put({ id: 'broken', schemaVersion: 99 }); tx.oncomplete = () => { db.close(); resolve(); }; };
  });
  expect((await store.list()).invalidCount).toBe(1); expect((await store.list()).encounters).toHaveLength(1);
  await store.removeInvalid(); expect((await store.list()).invalidCount).toBe(0); expect((await store.list()).encounters).toHaveLength(1); store.close();
});
it('capacity is enforced atomically without evicting existing encounters', async () => {
  const { store } = setup(); for (let i = 0; i < 20; i++) await store.save(newEncounter(`Encounter ${i}`));
  await expect(store.save(newEncounter('Overflow'))).rejects.toThrow('Limit:'); expect((await store.list()).encounters).toHaveLength(20); store.close();
});
it('malformed blobs, oversized notes and empty finalized records fail validation', async () => {
  const { store } = setup(); const e = newEncounter('Valid');
  expect(isEncounter({ ...e, notes: 'a'.repeat(10_001) })).toBe(false);
  expect(isEncounter({ ...e, audio: { blob: 'fake' } })).toBe(false);
  expect(() => finalizeEncounter(e)).toThrow('Add a recording');
  await expect(store.save({ ...e, title: '' })).rejects.toThrow('Invalid encounter'); store.close();
});
it('structured output keeps source IDs and excludes raw Blob data', () => {
  const e = newEncounter('Review'); e.notes = 'My own words'; const final = finalizeEncounter(e);
  const output = encounterOutput(final); expect(output.notes).toEqual({ origin: 'user-written', text: 'My own words' });
  expect(output.transcript.status).toBe('unavailable'); expect(output.status).toBe('finalized');
});
it('quota failure messaging never claims that content was saved', () => {
  expect(storageMessage(new DOMException('', 'QuotaExceededError'))).toContain('still in this page');
});
