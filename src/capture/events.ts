/** Content-free facts. Sequence is authoritative; wall-clock times are observational. */
export const ACTIONS = ['request', 'acquired', 'recording', 'stopping', 'preview', 'capturing', 'completed', 'idle', 'error', 'tracks_released', 'resources_released', 'data_received', 'stale_ignored'] as const;
export type CaptureAction = typeof ACTIONS[number];
export type Device = 'microphone' | 'camera';
export interface CaptureSignal {
  action: CaptureAction; generation: number; at: number;
  phase: string; tracks: number; timers: number;
}
export class CaptureTrace {
  private listeners = new Set<(signal: CaptureSignal) => void>();
  ignored = 0;
  clear() { this.listeners.clear(); }
  subscribe(listener: (signal: CaptureSignal) => void) { this.listeners.add(listener); return () => { this.listeners.delete(listener); }; }
  emit(signal: CaptureSignal) {
    if (signal.action === 'stale_ignored') this.ignored++;
    for (const listener of this.listeners) listener(signal);
  }
}
export type EventFact =
  | { type: 'encounter_created' | 'reviewed' | 'finalized' }
  | { type: 'capture'; device: Device; sessionId: string; signal: CaptureSignal }
  | { type: 'source_attached'; sourceId: string; sessionId: string; kind: 'audio' | 'image'; bytes: number; mime: string }
  | { type: 'source_removed'; sourceId: string }
  | { type: 'notes_checkpoint'; characters: number }
  | { type: 'persistence'; outcome: 'failed' | 'retry'; revision: number }
  | { type: 'invariant_failed'; code: string };
export type EncounterEvent = EventFact & { id: string; encounterId: string; sequence: number; at: number };
export interface Journal { version: 1; events: EncounterEvent[]; omitted: number }
export const MAX_EVENTS = 512;
export function appendEvent(journal: Journal | undefined, encounterId: string, fact: EventFact, at = Date.now()): Journal {
  const current = journal ?? { version: 1, events: [], omitted: 0 };
  if (current.events.length >= MAX_EVENTS) return { ...current, omitted: Math.min(Number.MAX_SAFE_INTEGER, current.omitted + 1) };
  return { ...current, events: [...current.events, { ...fact, id: crypto.randomUUID(), encounterId, sequence: current.events.length + 1, at }] };
}
const obj = (x: unknown): x is Record<string, unknown> => typeof x === 'object' && x !== null && !Array.isArray(x);
const identifier = (x: unknown): x is string => typeof x === 'string' && /^[a-zA-Z0-9_-]{1,100}$/.test(x);
const count = (x: unknown): x is number => Number.isSafeInteger(x) && Number(x) >= 0;
const keys = (x: Record<string, unknown>, allowed: string[]) => Object.keys(x).every((key) => allowed.includes(key));
/** Strict allowlists prevent a corrupt event payload smuggling captured content into diagnostics/export. */
export function validJournal(value: unknown, encounterId: string): value is Journal {
  if (!obj(value) || !keys(value, ['version', 'events', 'omitted']) || value.version !== 1 || !count(value.omitted)
    || !Array.isArray(value.events) || value.events.length > MAX_EVENTS) return false;
  const ids = new Set<string>();
  return value.events.every((e: unknown, index: number) => {
    if (!obj(e) || !identifier(e.id) || ids.has(e.id) || e.encounterId !== encounterId || e.sequence !== index + 1
      || typeof e.at !== 'number' || !Number.isFinite(e.at) || e.at < 0) return false;
    ids.add(e.id);
    const base = ['id', 'encounterId', 'sequence', 'at', 'type'];
    switch (e.type) {
      case 'encounter_created': case 'reviewed': case 'finalized': return keys(e, base);
      case 'capture': {
        const s = e.signal;
        return keys(e, [...base, 'device', 'sessionId', 'signal']) && ['microphone', 'camera'].includes(String(e.device)) && identifier(e.sessionId)
          && obj(s) && keys(s, ['action', 'generation', 'at', 'phase', 'tracks', 'timers']) && ACTIONS.includes(s.action as CaptureAction)
          && count(s.generation) && typeof s.at === 'number' && Number.isFinite(s.at) && s.at >= 0
          && ['idle', 'requesting_permission', 'recording', 'stopping', 'preview', 'capturing', 'completed', 'error'].includes(String(s.phase))
          && count(s.tracks) && Number(s.tracks) <= 16 && count(s.timers) && Number(s.timers) <= 16;
      }
      case 'source_attached': return keys(e, [...base, 'sourceId', 'sessionId', 'kind', 'bytes', 'mime']) && identifier(e.sourceId) && identifier(e.sessionId)
        && ['audio', 'image'].includes(String(e.kind)) && count(e.bytes) && Number(e.bytes) <= 8 * 1024 * 1024
        && typeof e.mime === 'string' && /^(audio|image)\/[a-zA-Z0-9.;=+_ -]{1,100}$/.test(e.mime);
      case 'source_removed': return keys(e, [...base, 'sourceId']) && identifier(e.sourceId);
      case 'notes_checkpoint': return keys(e, [...base, 'characters']) && count(e.characters) && Number(e.characters) <= 10_000;
      case 'persistence': return keys(e, [...base, 'outcome', 'revision']) && ['failed', 'retry'].includes(String(e.outcome)) && count(e.revision);
      case 'invariant_failed': return keys(e, [...base, 'code']) && ['microphone_resources', 'camera_resources', 'finalized_hardware'].includes(String(e.code));
      default: return false;
    }
  });
}
export interface Projection {
  status: 'unknown' | 'draft' | 'reviewed' | 'finalized';
  microphone: { phase: string; sessionId: string | null; tracks: number };
  camera: { phase: string; sessionId: string | null; tracks: number };
  sources: string[]; ignored: number; notesCharacters: number;
}
/** Pure lifecycle projection. No media, storage, network, timers or text reconstruction. */
export function replay(events: readonly EncounterEvent[], count = events.length): Projection {
  const result: Projection = { status: 'unknown', microphone: { phase: 'unknown', sessionId: null, tracks: 0 }, camera: { phase: 'unknown', sessionId: null, tracks: 0 }, sources: [], ignored: 0, notesCharacters: 0 };
  for (const e of events.slice(0, Math.max(0, count))) {
    if (e.type === 'encounter_created') result.status = 'draft';
    if (e.type === 'reviewed') result.status = 'reviewed';
    if (e.type === 'finalized') result.status = 'finalized';
    if (e.type === 'notes_checkpoint') result.notesCharacters = e.characters;
    if (e.type === 'source_attached') result.sources.push(e.sourceId);
    if (e.type === 'source_removed') result.sources = result.sources.filter((id) => id !== e.sourceId);
    if (e.type === 'capture') {
      if (e.signal.action === 'stale_ignored') { result.ignored++; continue; }
      result[e.device] = { phase: e.signal.phase, sessionId: e.sessionId, tracks: e.signal.tracks };
    }
  }
  return result;
}
export function eventLabel(event: EncounterEvent): string {
  return event.type === 'capture' ? `${event.device} · ${event.signal.action.replaceAll('_', ' ')}` : event.type.replaceAll('_', ' ');
}
