import type { Encounter } from '../domain/encounter';
import { validJournal } from './events';
import type { Journal } from './events';
import { validFingerprint } from './integrity';
import type { Fingerprint } from './integrity';
export interface SourceMetadata {
  id: string; kind: 'audio' | 'image'; encounterId: string; sessionId: string;
  createdAt: string; creationEventId: string | null; bytes: number; mime: string;
  fingerprint: Fingerprint | null;
}
export interface Relationship { from: string; relation: 'owns' | 'produced' | 'fingerprinted' | 'reviewed'; to: string }
export function sources(encounter: Encounter): SourceMetadata[] {
  return [...(encounter.audio ? [{ ...encounter.audio, kind: 'audio' as const }] : []), ...encounter.images.map((image) => ({ ...image, kind: 'image' as const }))].map((source) => ({
    id: source.id, kind: source.kind, encounterId: encounter.id, sessionId: source.captureSessionId,
    createdAt: source.createdAt, creationEventId: encounter.journal?.events.find((e) => e.type === 'source_attached' && e.sourceId === source.id)?.id ?? null,
    bytes: source.blob.size, mime: source.blob.type, fingerprint: source.fingerprint ?? null,
  }));
}
export function relationships(encounterId: string, metadata: SourceMetadata[], journal: Journal | null): Relationship[] {
  const links: Relationship[] = [];
  for (const session of new Set(metadata.map((s) => s.sessionId))) links.push({ from: encounterId, relation: 'owns', to: session });
  for (const source of metadata) {
    links.push({ from: source.sessionId, relation: 'produced', to: source.id });
    if (source.fingerprint) links.push({ from: source.id, relation: 'fingerprinted', to: `sha256:${source.fingerprint.digest}` });
    // A review only refers to sources that actually existed at its sequence position.
    const creation = journal?.events.find((e) => e.id === source.creationEventId);
    for (const event of journal?.events ?? []) if ((event.type === 'reviewed' || event.type === 'finalized') && creation && creation.sequence < event.sequence) links.push({ from: event.id, relation: 'reviewed', to: source.id });
  }
  return links;
}
export interface Manifest {
  manifestVersion: 1; application: 'Hospi-Pet'; applicationVersion: '0.1.0';
  encounter: { id: string; revision: number; status: 'draft' | 'finalized'; createdAt: string; finalizedAt: string | null };
  journal: Journal | null; sources: SourceMetadata[]; relationships: Relationship[];
}
export function manifest(encounter: Encounter): Manifest {
  const metadata = sources(encounter);
  return { manifestVersion: 1, application: 'Hospi-Pet', applicationVersion: '0.1.0',
    encounter: { id: encounter.id, revision: encounter.revision, status: encounter.status, createdAt: encounter.createdAt, finalizedAt: encounter.finalizedAt },
    journal: encounter.journal ?? null, sources: metadata, relationships: relationships(encounter.id, metadata, encounter.journal ?? null) };
}
const object = (v: unknown): v is Record<string, unknown> => !!v && typeof v === 'object' && !Array.isArray(v);
const exact = (v: Record<string, unknown>, names: string[]) => Object.keys(v).length === names.length && names.every((name) => Object.hasOwn(v, name));
const id = (v: unknown): v is string => typeof v === 'string' && /^[a-zA-Z0-9_-]{1,100}$/.test(v);
const date = (v: unknown) => typeof v === 'string' && Number.isFinite(Date.parse(v));
/** Read-only schema validator. Manifests are not trusted as content or imported into live state. */
export function validManifest(value: unknown): value is Manifest {
  if (!object(value) || !exact(value, ['manifestVersion', 'application', 'applicationVersion', 'encounter', 'journal', 'sources', 'relationships'])
    || value.manifestVersion !== 1 || value.application !== 'Hospi-Pet' || value.applicationVersion !== '0.1.0') return false;
  const e = value.encounter;
  if (!object(e) || !exact(e, ['id', 'revision', 'status', 'createdAt', 'finalizedAt']) || !id(e.id) || !Number.isSafeInteger(e.revision)
    || Number(e.revision) < 0 || !['draft', 'finalized'].includes(String(e.status)) || !date(e.createdAt)
    || (e.status === 'finalized' ? !date(e.finalizedAt) : e.finalizedAt !== null)) return false;
  if (value.journal !== null && !validJournal(value.journal, e.id)) return false;
  if (!Array.isArray(value.sources) || value.sources.length > 5) return false;
  const ids = new Set<string>();
  for (const s of value.sources) {
    if (!object(s) || !exact(s, ['id', 'kind', 'encounterId', 'sessionId', 'createdAt', 'creationEventId', 'bytes', 'mime', 'fingerprint'])
      || !id(s.id) || ids.has(s.id) || !id(s.sessionId) || s.encounterId !== e.id || !['audio', 'image'].includes(String(s.kind))
      || !date(s.createdAt) || !Number.isSafeInteger(s.bytes) || Number(s.bytes) <= 0 || Number(s.bytes) > (s.kind === 'audio' ? 8 : 1) * 1024 * 1024
      || typeof s.mime !== 'string' || s.mime.length > 120 || !s.mime.startsWith(`${s.kind}/`)
      || (s.fingerprint !== null && !validFingerprint(s.fingerprint))) return false;
    ids.add(s.id);
    if (s.creationEventId !== null) {
      if (!id(s.creationEventId) || !(value.journal as Journal | null)?.events.some((event) => event.id === s.creationEventId && event.type === 'source_attached' && event.sourceId === s.id && event.sessionId === s.sessionId && event.kind === s.kind && event.bytes === s.bytes && event.mime === s.mime)) return false;
    }
  }
  if (value.sources.filter((s: SourceMetadata) => s.kind === 'audio').length > 1 || value.sources.filter((s: SourceMetadata) => s.kind === 'image').length > 4) return false;
  return JSON.stringify(value.relationships) === JSON.stringify(relationships(e.id, value.sources as SourceMetadata[], value.journal as Journal | null));
}
export function serializeManifest(encounter: Encounter): string {
  const output = manifest(encounter);
  if (!validManifest(output)) throw new Error('Manifest validation failed; no export was created.');
  return JSON.stringify(output, null, 2) + '\n';
}
