/** Optional extension point only. No provider is configured or invoked by this application. */
export interface TranscriptProvider {
  readonly id: string;
  readonly locality: 'on-device';
  transcribe(source: { id: string; encounterId: string; blob: Blob }, signal: AbortSignal): Promise<TranscriptResult>;
}
export interface TranscriptResult {
  text: string;
  derivedFrom: string;
  encounterId: string;
  provider: string;
  createdAt: string;
}
