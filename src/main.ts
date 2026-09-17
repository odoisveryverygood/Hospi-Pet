import { MicrophoneSession } from './microphone-session';
import { CameraSession } from './camera-session';
import type { CaptureLab } from './capture/lab';
import { IndexedEncounterStore } from './storage/encounter-store';
import { Workspace } from './workspace';
import { find } from './ui/dom';
import type { View } from './ui/dom';
import { HistoryView } from './ui/history-view';
import { EncounterView } from './ui/encounter-view';
import './style.css';

const root = find(document, '#app');
root.innerHTML = `
  <a class="skip-link" href="#content">Skip to workspace</a>
  <header class="app-header"><a href="/" class="brand" aria-label="Hospi-Pet home"><span class="brand-mark" aria-hidden="true">h<span>·</span></span><span>Hospi-Pet<small>Encounter notebook</small></span></a><span class="local-label"><span aria-hidden="true">●</span> Local prototype</span></header>
  <div class="app-body"><section id="storage-notice" class="notice error" hidden aria-labelledby="storage-heading"><h2 id="storage-heading">Local storage needs attention</h2><p id="storage-message" role="alert"></p><div class="actions"><button id="retry-save" class="secondary">Retry</button><button id="reload-saved" class="text-button">Reload saved copy</button></div></section><div id="content"></div>
  <details class="privacy-panel"><summary>Privacy & local data</summary><div class="privacy-content"><div><h2>You control capture</h2><p>The microphone is active only while recording. The camera is active only during its preview. Stop, close, switching encounters, and leaving the page release their tracks.</p></div><div><h2>Stored in this browser</h2><p>Completed audio, photos, and notes are saved in IndexedDB on this browser and site address. There is no account, upload, analytics, transcription service, or cloud backup. Use synthetic information only; this is not a clinical record system.</p></div><div><h2>Remove your data</h2><p>Delete an encounter to remove its stored sources, or clear everything below. Browser settings can also clear this site’s data. Local storage can be evicted and is not encrypted by this app.</p><button id="clear-data" class="text-button danger">Clear all local data</button></div></div></details>
  <footer class="app-footer"><span>Capture → review → keep the sources.</span><span>No diagnosis or generated medical conclusions.</span></footer></div>
`;
const content = find(root, '#content');
let workspace: Workspace;
let lab: CaptureLab | undefined;
let makeLab: (() => CaptureLab) | undefined;
let view: View | null = null;
let key = '';
let unsubscribe = () => {};
function mount(): void {
  try {
    lab = makeLab?.();
    const repository = new IndexedEncounterStore();
    workspace = new Workspace(lab ? lab.repository(repository) : repository, new MicrophoneSession(lab?.media()), new CameraSession(lab?.camera()));
    lab?.inspectNetwork(() => workspace.captureBusy);
    unsubscribe = workspace.subscribe((state) => {
      const nextKey = state.active?.id ?? 'history';
      if (key !== nextKey || !view) {
        view?.dispose();
        key = nextKey;
        view = state.active ? new EncounterView(content, workspace, lab) : new HistoryView(content, workspace);
        find<HTMLElement>(content, 'h1').focus({ preventScroll: true });
      } else view.update();
      find(root, '#storage-notice').hidden = !state.storageError;
      find(root, '#storage-message').textContent = state.storageError;
      find<HTMLButtonElement>(root, '#retry-save').disabled = state.busy || state.saving;
      find(root, '#reload-saved').hidden = !state.active;
      find<HTMLButtonElement>(root, '#clear-data').disabled = state.busy || state.loading;
    });
    void workspace.refresh();
  } catch (error) {
    console.error(error);
    content.innerHTML = '<section class="empty"><h1>Hospi-Pet could not start</h1><p>Reload this page in a browser with IndexedDB enabled. Existing saved encounters have not been deleted. Technical details are available in the developer console.</p></section>';
  }
}
find(root, '.brand').addEventListener('click', (event) => { event.preventDefault(); if (workspace) void workspace.home(); });
find(root, '#retry-save').addEventListener('click', () => { if (workspace.snapshot.active) void workspace.flush(); else void workspace.refresh(); });
find(root, '#reload-saved').addEventListener('click', () => {
  if (window.confirm('Discard unsaved changes and reload the saved encounter?')) void workspace.reloadSaved();
});
find(root, '#clear-data').addEventListener('click', () => {
  if (workspace && window.confirm('Permanently delete all Hospi-Pet encounters, audio, photos, and notes stored in this browser?')) void workspace.clearLocalData().then(() => { if (!workspace.snapshot.active) lab?.reset(); });
});
window.addEventListener('beforeunload', (event) => {
  if (workspace && (workspace.snapshot.dirty || workspace.snapshot.saving || workspace.snapshot.busy)) { event.preventDefault(); event.returnValue = ''; }
});
window.addEventListener('pagehide', () => { unsubscribe(); workspace?.dispose(); lab?.dispose(); view?.dispose(); view = null; key = ''; });
window.addEventListener('pageshow', (event) => { if (event.persisted) mount(); });
async function boot() {
  if (import.meta.env.DEV && new URLSearchParams(location.search).get('lab') === '1') {
    const { CaptureLab } = await import('./capture/lab'); makeLab = () => new CaptureLab();
  }
  mount();
}
void boot().catch(() => { content.textContent = 'Development tools could not load. Reload without ?lab=1.'; });
