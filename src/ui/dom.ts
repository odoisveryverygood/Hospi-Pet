export function find<T extends HTMLElement = HTMLElement>(root: ParentNode, selector: string): T {
  const element = root.querySelector<T>(selector);
  if (!element) throw new Error(`Missing view element: ${selector}`);
  return element;
}
export function escapeText(text: string): string {
  return text.replace(/[&<>"']/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char]!);
}
export function readableDate(iso: string): string {
  return new Intl.DateTimeFormat(undefined, { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' }).format(new Date(iso));
}
export function bytes(size: number): string { return size >= 1024 * 1024 ? `${(size / 1024 / 1024).toFixed(1)} MiB` : `${Math.ceil(size / 1024)} KiB`; }
export interface View { update(): void; dispose(): void }
/** All URLs belong to a view, and are revoked when its source changes or it unmounts. */
export class ViewUrls {
  private values = new Map<Blob, string>();
  url(blob: Blob): string {
    const existing = this.values.get(blob);
    if (existing) return existing;
    const next = URL.createObjectURL(blob); this.values.set(blob, next); return next;
  }
  keep(blobs: Blob[]): void {
    for (const [blob, url] of this.values) if (!blobs.includes(blob)) { URL.revokeObjectURL(url); this.values.delete(blob); }
  }
  dispose(): void { this.keep([]); }
}
