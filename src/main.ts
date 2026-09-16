import { MicrophoneSession } from './microphone-session';
import './style.css';

const root = document.querySelector<HTMLElement>('#app');
if (!root) throw new Error('Missing application root');
root.innerHTML = `
  <header><span class="badge">LOCAL ENGINEERING DEMO</span><p class="wordmark">Hospi-Pet / Capture lab</p></header>
  <h1>A microphone session<br>should end cleanly.</h1>
  <p class="intro">Record a short clip. Stop. Start again. This focused demo makes microphone ownership and session boundaries visible.</p>
  <section aria-labelledby="capture-heading" class="panel">
    <div class="panel-heading"><h2 id="capture-heading">Microphone session</h2><span id="phase" role="status" aria-live="polite">idle</span></div>
    <dl><div><dt>Session generation</dt><dd id="generation">0</dd></div><div><dt>Elapsed</dt><dd><span id="seconds">0</span>s / 60s limit</dd></div><div><dt>Capture</dt><dd id="capture-state">Inactive</dd></div></dl>
    <div class="controls"><button id="start">Start microphone</button><button id="stop" disabled>Stop recording</button><button id="discard" class="secondary">Discard / cancel</button></div>
    <p id="error" role="alert" hidden></p><p id="pending" hidden>Browser permission is still pending. Dismiss its prompt before retrying. If it never settles, reload this page.</p>
    <div id="playback" hidden><label for="audio">Latest session · local playback</label><audio id="audio" controls></audio><p id="clip-info"></p></div>
    <p class="privacy">Audio stays in this page’s memory. Starting again or discarding removes the previous clip. No upload, speech recognition, transcript, account, API key, or healthcare data.</p>
  </section>
  <section class="details"><div><h2>Try three sessions</h2><p>Grant permission, record for 3–5 seconds, stop, then immediately start again. Repeat twice. Playback should contain only the latest session.</p></div><div><h2>Observe the boundary</h2><p>Stop releases microphone tracks immediately. Completion waits for the recorder’s final data. Cancel drops all captured data. Leaving this page releases capture too.</p></div></section>
  <footer>The original voice/camera encounter research is preserved in <code>legacy/jac-app/</code>. This demo tests microphone lifecycle only; it does not provide clinical functionality.</footer>
`;
function element<T extends HTMLElement>(selector: string): T {
  const found = document.querySelector<T>(selector);
  if (!found) throw new Error(`Missing ${selector}`);
  return found;
}
const start = element<HTMLButtonElement>('#start');
const stop = element<HTMLButtonElement>('#stop');
const discard = element<HTMLButtonElement>('#discard');
const audio = element<HTMLAudioElement>('#audio');
const playback = element<HTMLElement>('#playback');
let session: MicrophoneSession;
let unsubscribe: () => void = () => {};
let currentClip: Blob | null = null;
let clipUrl: string | null = null;
function clearPlayback(): void {
  audio.pause();
  audio.removeAttribute('src');
  audio.load();
  if (clipUrl) URL.revokeObjectURL(clipUrl);
  clipUrl = null;
  currentClip = null;
  playback.hidden = true;
}
function mount(): void {
  session = new MicrophoneSession();
  unsubscribe = session.subscribe((state) => {
    element('#phase').textContent = state.phase;
    element('#phase').dataset.phase = state.phase;
    element('#generation').textContent = String(state.generation);
    element('#seconds').textContent = String(state.seconds);
    element('#capture-state').textContent = state.phase === 'recording' ? 'Microphone active' : state.phase === 'requesting_permission' ? 'Waiting for permission' : 'Inactive';
    start.disabled = state.permissionPending || ['requesting_permission', 'recording', 'stopping'].includes(state.phase);
    stop.disabled = state.phase !== 'recording';
    discard.disabled = state.phase === 'idle' && !state.permissionPending;
    const error = element('#error');
    error.hidden = !state.error;
    error.textContent = state.error;
    element('#pending').hidden = !state.permissionPending || state.phase === 'requesting_permission';
    if (state.clip !== currentClip) {
      clearPlayback();
      if (state.clip) {
        currentClip = state.clip;
        clipUrl = URL.createObjectURL(state.clip);
        audio.src = clipUrl;
        playback.hidden = false;
        element('#clip-info').textContent = state.clip.size ? `${state.clip.size.toLocaleString()} bytes recorded in this session.` : 'No audio was produced. Try recording for a few seconds.';
      }
    }
  });
}
start.addEventListener('click', () => session.start());
stop.addEventListener('click', () => session.stop());
discard.addEventListener('click', () => session.cancel());
window.addEventListener('pagehide', () => { unsubscribe(); session.dispose(); clearPlayback(); });
// A document restored from the back-forward cache must be usable without resurrecting capture.
window.addEventListener('pageshow', (event) => { if (event.persisted) mount(); });
mount();
