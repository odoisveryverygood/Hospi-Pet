/** User-captured sources, never inferred clinical facts. Versioned for local storage. */
export interface AudioSource {
  id: string;
  captureSessionId: string;
  generation: number;
  createdAt: string;
  elapsedSeconds: number;
  blob: Blob;
}
export interface ImageSource {
  id: string;
  captureSessionId: string;
  createdAt: string;
  width: number;
  height: number;
  blob: Blob;
}
export interface Encounter {
  schemaVersion: 1;
  id: string;
  revision: number;
  title: string;
  createdAt: string;
  updatedAt: string;
  finalizedAt: string | null;
  status: 'draft' | 'finalized';
  notes: string;
  audio: AudioSource | null;
  images: ImageSource[];
  transcript: { status: 'unavailable'; reason: 'local-only' };
}
export const LIMITS = { encounters: 20, images: 4, imageBytes: 1024 * 1024, audioBytes: 8 * 1024 * 1024, notes: 10_000, title: 120 } as const;

export function newEncounter(title: string, id = crypto.randomUUID(), now = new Date().toISOString()): Encounter {
  return { schemaVersion: 1, id, revision: 0, title: title.trim() || 'Untitled encounter', createdAt: now, updatedAt: now, finalizedAt: null, status: 'draft', notes: '', audio: null, images: [], transcript: { status: 'unavailable', reason: 'local-only' } };
}
export function hasSources(encounter: Encounter): boolean {
  return !!encounter.audio || encounter.images.length > 0 || encounter.notes.trim().length > 0;
}
export function finalizeEncounter(encounter: Encounter): Encounter {
  if (!hasSources(encounter)) throw new Error('Add a recording, photo, or written note before finalizing.');
  if (encounter.status !== 'draft') throw new Error('This encounter is already finalized.');
  const now = new Date().toISOString();
  return { ...encounter, status: 'finalized', updatedAt: now, finalizedAt: now };
}
function object(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}
function text(value: unknown, limit: number): value is string { return typeof value === 'string' && value.length <= limit; }
function id(value: unknown): value is string { return typeof value === 'string' && /^[a-zA-Z0-9_-]{1,100}$/.test(value); }
function date(value: unknown): value is string { return typeof value === 'string' && Number.isFinite(Date.parse(value)); }
function media(value: unknown, kind: 'audio' | 'image', limit: number): value is Blob {
  return value instanceof Blob && value.size > 0 && value.size <= limit && value.type.startsWith(kind + '/');
}
/** IndexedDB is an untrusted input boundary too (old versions, devtools, failed migrations). */
export function isEncounter(value: unknown): value is Encounter {
  if (!object(value) || value.schemaVersion !== 1 || !id(value.id) || !Number.isInteger(value.revision) || Number(value.revision) < 0
    || !text(value.title, LIMITS.title) || !value.title.trim() || !text(value.notes, LIMITS.notes)
    || !date(value.createdAt) || !date(value.updatedAt) || !['draft', 'finalized'].includes(String(value.status))
    || !Array.isArray(value.images) || value.images.length > LIMITS.images
    || !object(value.transcript) || value.transcript.status !== 'unavailable' || value.transcript.reason !== 'local-only') return false;
  if (value.status === 'finalized' ? !date(value.finalizedAt) : value.finalizedAt !== null) return false;
  if (value.audio !== null) {
    const a = value.audio;
    if (!object(a) || !id(a.id) || !id(a.captureSessionId) || !date(a.createdAt) || !Number.isInteger(a.generation)
      || Number(a.generation) < 1 || typeof a.elapsedSeconds !== 'number' || !Number.isFinite(a.elapsedSeconds)
      || a.elapsedSeconds < 0 || !media(a.blob, 'audio', LIMITS.audioBytes)) return false;
  }
  const imageIds = new Set<string>();
  for (const image of value.images) {
    if (!object(image) || !id(image.id) || imageIds.has(image.id) || !id(image.captureSessionId) || !date(image.createdAt)
      || !Number.isInteger(image.width) || !Number.isInteger(image.height) || Number(image.width) <= 0 || Number(image.height) <= 0
      || Number(image.width) > 1280 || Number(image.height) > 1280 || !media(image.blob, 'image', LIMITS.imageBytes)) return false;
    imageIds.add(image.id);
  }
  return value.status !== 'finalized' || hasSources(value as unknown as Encounter);
}
/** Human-readable manifest plus content written by the user; never an AI summary. */
export function encounterOutput(encounter: Encounter) {
  return {
    schemaVersion: encounter.schemaVersion, id: encounter.id, title: encounter.title,
    status: encounter.status, createdAt: encounter.createdAt, finalizedAt: encounter.finalizedAt,
    notes: { origin: 'user-written', text: encounter.notes }, transcript: encounter.transcript,
    audio: encounter.audio ? { id: encounter.audio.id, captureSessionId: encounter.audio.captureSessionId,
      generation: encounter.audio.generation, createdAt: encounter.audio.createdAt, elapsedSeconds: encounter.audio.elapsedSeconds,
      bytes: encounter.audio.blob.size, mimeType: encounter.audio.blob.type } : null,
    images: encounter.images.map(({ blob, ...metadata }) => ({ ...metadata, bytes: blob.size, mimeType: blob.type })),
  };
}
