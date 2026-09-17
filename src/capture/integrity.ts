import type { Encounter, AudioSource, ImageSource } from '../domain/encounter';
export interface Fingerprint { algorithm: 'SHA-256'; digest: string; bytes: number; mime: string }
export function validFingerprint(value: unknown): value is Fingerprint {
  if (!value || typeof value !== 'object') return false;
  const f = value as Partial<Fingerprint>;
  return Object.keys(value).every((key) => ['algorithm', 'digest', 'bytes', 'mime'].includes(key)) && f.algorithm === 'SHA-256'
    && typeof f.digest === 'string' && /^[a-f0-9]{64}$/.test(f.digest) && Number.isSafeInteger(f.bytes) && Number(f.bytes) > 0
    && typeof f.mime === 'string' && f.mime.length <= 120;
}
export async function fingerprint(blob: Blob): Promise<Fingerprint> {
  const bytes = await blob.arrayBuffer();
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return { algorithm: 'SHA-256', digest: Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, '0')).join(''), bytes: blob.size, mime: blob.type };
}
export type IntegrityStatus = 'verified' | 'mismatch' | 'unavailable' | 'legacy-unhashed';
export async function verifySource(source: AudioSource | ImageSource): Promise<IntegrityStatus> {
  if (!source.fingerprint) return 'legacy-unhashed';
  try {
    const actual = await fingerprint(source.blob);
    return actual.digest === source.fingerprint.digest && actual.bytes === source.fingerprint.bytes && actual.mime === source.fingerprint.mime ? 'verified' : 'mismatch';
  } catch { return 'unavailable'; }
}
/** Hash before opening IDB transactions; WebCrypto awaits must not hold a transaction open. */
export async function fingerprintNewSources(encounter: Encounter): Promise<Encounter> {
  async function source<T extends AudioSource | ImageSource>(value: T): Promise<T> {
    // Only new, journaled sources get an initial digest. Never re-baseline legacy or corrupt media silently.
    if (value.fingerprint || !encounter.journal?.events.some((e) => e.type === 'encounter_created' || (e.type === 'source_attached' && e.sourceId === value.id))) return value;
    return { ...value, fingerprint: await fingerprint(value.blob) };
  }
  return { ...encounter, audio: encounter.audio ? await source(encounter.audio) : null, images: await Promise.all(encounter.images.map(source)) };
}
