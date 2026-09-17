import { fingerprintNewSources } from '../capture/integrity';
import { isEncounter, LIMITS } from '../domain/encounter';
import type { Encounter } from '../domain/encounter';

export interface EncounterRepository {
  list(): Promise<{ encounters: Encounter[]; invalidCount: number }>;
  save(encounter: Encounter): Promise<Encounter>;
  delete(id: string): Promise<void>;
  clear(): Promise<void>;
  removeInvalid(): Promise<void>;
  close(): void;
}
export class StorageConflict extends Error {
  constructor() { super('This encounter changed in another tab. Reload the saved copy before editing again.'); }
}
export function storageMessage(error: unknown): string {
  if (error instanceof StorageConflict) return error.message;
  if (error instanceof DOMException && error.name === 'QuotaExceededError') return 'Browser storage is full. Your changes are still in this page. Delete an older encounter in another tab, then retry saving.';
  if (error instanceof Error && error.message.startsWith('Limit:')) return error.message;
  return 'Local storage is unavailable or the save failed. Keep this page open and retry. No successful save has been assumed.';
}

/** One atomic row per encounter (metadata + Blobs); transaction completion is the save boundary. */
export class IndexedEncounterStore implements EncounterRepository {
  private database: Promise<IDBDatabase> | null = null;
  private closed = false;
  constructor(private readonly name = 'hospipet-encounters', private readonly factory: IDBFactory = indexedDB) {}

  private open(): Promise<IDBDatabase> {
    if (this.closed) return Promise.reject(new Error('Storage closed'));
    if (!this.database) this.database = new Promise((resolve, reject) => {
      let abandoned = false;
      const request = this.factory.open(this.name, 1);
      request.onupgradeneeded = () => request.result.createObjectStore('encounters', { keyPath: 'id' });
      request.onerror = () => { this.database = null; reject(request.error); };
      request.onblocked = () => { abandoned = true; this.database = null; reject(new Error('Close other Hospi-Pet tabs and retry storage.')); };
      request.onsuccess = () => {
        const db = request.result;
        if (this.closed || abandoned) { db.close(); reject(new Error('Storage closed')); return; }
        db.onversionchange = () => { db.close(); this.database = null; };
        resolve(db);
      };
    });
    return this.database;
  }

  private async transaction<T>(mode: IDBTransactionMode, work: (store: IDBObjectStore, result: (value: T) => void, fail: (error: Error) => void) => void): Promise<T> {
    const db = await this.open();
    return new Promise((resolve, reject) => {
      const tx = db.transaction('encounters', mode);
      let value: T;
      let failure: Error | null = null;
      tx.oncomplete = () => resolve(value);
      tx.onabort = tx.onerror = () => reject(failure ?? tx.error ?? new Error('Local transaction failed'));
      try {
        work(tx.objectStore('encounters'), (next) => { value = next; }, (error) => { failure = error; tx.abort(); });
      } catch (error) { failure = error instanceof Error ? error : new Error('Invalid local record'); tx.abort(); }
    });
  }
  async list() {
    const rows = await this.transaction<unknown[]>('readonly', (store, result) => {
      const request = store.getAll(); request.onsuccess = () => result(request.result as unknown[]);
    });
    const encounters = rows.filter(isEncounter).sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));
    return { encounters, invalidCount: rows.length - encounters.length };
  }
  async save(encounter: Encounter): Promise<Encounter> {
    if (!isEncounter(encounter)) throw new Error('Invalid encounter');
    encounter = await fingerprintNewSources(encounter);
    return this.transaction('readwrite', (store, result, fail) => {
      const request = store.get(encounter.id);
      request.onsuccess = () => {
        const current: unknown = request.result;
        if (current !== undefined && (!isEncounter(current) || current.revision !== encounter.revision)
          || current === undefined && encounter.revision !== 0) { fail(new StorageConflict()); return; }
        const write = () => {
          const next = { ...encounter, revision: encounter.revision + 1 };
          try { store.put(next); result(next); }
          catch (error) { fail(error instanceof Error ? error : new Error('Local write failed')); }
        };
        if (current === undefined) {
          const count = store.count(); count.onsuccess = () => {
            if (count.result >= LIMITS.encounters) fail(new Error(`Limit: keep at most ${LIMITS.encounters} local encounters. Delete an older one first.`));
            else write();
          };
        } else write();
      };
    });
  }
  delete(id: string): Promise<void> { return this.transaction('readwrite', (store, result) => { store.delete(id); result(undefined); }); }
  clear(): Promise<void> { return this.transaction('readwrite', (store, result) => { store.clear(); result(undefined); }); }
  removeInvalid(): Promise<void> {
    return this.transaction('readwrite', (store, result) => {
      const request = store.openCursor(); request.onsuccess = () => {
        const cursor = request.result;
        if (!cursor) { result(undefined); return; }
        if (!isEncounter(cursor.value)) cursor.delete();
        cursor.continue();
      };
    });
  }
  close(): void {
    this.closed = true;
    if (this.database) void this.database.then((db) => db.close(), () => {});
  }
}
