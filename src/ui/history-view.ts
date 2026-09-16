import type { Workspace } from '../workspace';
import { bytes, escapeText, find, readableDate } from './dom';
import type { View } from './dom';

export class HistoryView implements View {
  constructor(private readonly root: HTMLElement, private readonly workspace: Workspace) {
    root.innerHTML = `
      <section class="page-heading"><div><p class="eyebrow">Your workspace</p><h1 tabindex="-1">Encounters</h1><p>Keep a visit’s recording, document photos, and notes together.</p></div><button id="new-encounter">New encounter <span aria-hidden="true">＋</span></button></section>
      <form id="create-form" class="new-form" hidden>
        <h2>Start an encounter</h2><p class="muted">Use a practice visit or synthetic information. This prototype is not for clinical records.</p>
        <label for="encounter-title">Encounter title</label><input id="encounter-title" maxlength="120" required placeholder="e.g. Practice follow-up visit" autocomplete="off">
        <div class="actions"><button type="submit">Create encounter</button><button id="cancel-create" class="secondary" type="button">Cancel</button></div>
      </form>
      <div id="history-loading" class="empty" role="status">Opening local history…</div>
      <section id="history-empty" class="empty" hidden><div class="empty-mark" aria-hidden="true">↗</div><h2>No encounters yet</h2><p>Start with a short voice recording. Add a document photo or your own notes, review the sources, then save a finalized record.</p><p class="muted">Everything stays in this browser. No account required.</p></section>
      <section id="history-content" aria-label="Saved encounters" hidden><div class="list-heading"><h2>Local history</h2><span id="history-count"></span></div><ul id="history-list" class="history-list"></ul></section>
      <div id="invalid-records" class="notice" hidden><p id="invalid-message"></p><button id="remove-invalid" class="secondary">Remove unreadable records</button></div>
      <div class="history-foot"><p>Drafts can be resumed. Finalized encounters keep their sources read-only.</p><button id="refresh-history" class="text-button">Refresh history</button></div>
    `;
    const form = find<HTMLFormElement>(root, '#create-form');
    const title = find<HTMLInputElement>(root, '#encounter-title');
    find(root, '#new-encounter').addEventListener('click', () => { form.hidden = false; title.focus(); });
    find(root, '#cancel-create').addEventListener('click', () => { form.hidden = true; find(root, '#new-encounter').focus(); });
    form.addEventListener('submit', (event) => { event.preventDefault(); if (title.value.trim()) void workspace.create(title.value); });
    find(root, '#refresh-history').addEventListener('click', () => { void workspace.refresh(); });
    find(root, '#remove-invalid').addEventListener('click', () => {
      if (window.confirm('Delete only the unreadable local records? Valid encounters will be kept.')) void workspace.removeInvalid();
    });
    find(root, '#history-list').addEventListener('click', (event) => {
      const target = event.target instanceof Element ? event.target.closest<HTMLButtonElement>('[data-open]') : null;
      if (target?.dataset.open) void workspace.open(target.dataset.open);
    });
    this.update();
  }
  update(): void {
    const state = this.workspace.snapshot;
    find(this.root, '#history-loading').hidden = !state.loading;
    find(this.root, '#history-empty').hidden = state.loading || state.encounters.length > 0 || !!state.storageError;
    find(this.root, '#history-content').hidden = state.loading || !state.encounters.length;
    find<HTMLButtonElement>(this.root, '#new-encounter').disabled = state.busy || state.loading || !!state.storageError;
    find<HTMLButtonElement>(this.root, '[type=submit]').disabled = state.busy;
    find(this.root, '#history-count').textContent = `${state.encounters.length} / 20 encounters`;
    find(this.root, '#history-list').innerHTML = state.encounters.map((record) => {
      const total = (record.audio?.blob.size ?? 0) + record.images.reduce((n, image) => n + image.blob.size, 0);
      return `<li><button class="encounter-row" data-open="${escapeText(record.id)}" ${state.busy ? 'disabled' : ''}>
        <span class="row-icon" aria-hidden="true">${record.status === 'draft' ? '◷' : '✓'}</span>
        <span class="row-main"><strong>${escapeText(record.title)}</strong><span>${record.audio ? '1 voice recording' : 'No recording'} · ${record.images.length} ${record.images.length === 1 ? 'photo' : 'photos'} · ${bytes(total)}</span></span>
        <span class="row-date">${readableDate(record.updatedAt)}</span><span class="status-tag">${record.status === 'draft' ? 'Draft' : 'Finalized'}</span><span class="row-arrow" aria-hidden="true">→</span></button></li>`;
    }).join('');
    find(this.root, '#invalid-records').hidden = !state.invalidCount;
    find(this.root, '#invalid-message').textContent = `${state.invalidCount} local record(s) could not be read. They have been kept intact and excluded from history. You can remove them explicitly.`;
  }
  dispose(): void { /* No page-level resources owned by this view. */ }
}
