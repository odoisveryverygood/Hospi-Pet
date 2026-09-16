import { expect, test } from '@playwright/test';

declare global {
  interface Window {
    probe: {
      streams: MediaStream[];
      recorders: MediaRecorder[];
      urls: Set<string>;
      listeners: Map<EventTarget, Set<EventListenerOrEventListenerObject>>;
    };
  }
}

test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => {
    window.probe = { streams: [], recorders: [], urls: new Set(), listeners: new Map() };
    const getMedia = navigator.mediaDevices.getUserMedia.bind(navigator.mediaDevices);
    navigator.mediaDevices.getUserMedia = async (constraints) => {
      const stream = await getMedia(constraints);
      window.probe.streams.push(stream);
      return stream;
    };
    const NativeRecorder = window.MediaRecorder;
    window.MediaRecorder = class extends NativeRecorder {
      constructor(stream: MediaStream, options?: MediaRecorderOptions) {
        super(stream, options); window.probe.recorders.push(this);
      }
    };
    const add = EventTarget.prototype.addEventListener;
    const remove = EventTarget.prototype.removeEventListener;
    EventTarget.prototype.addEventListener = function (type, callback, options) {
      if ((this instanceof MediaRecorder || this instanceof MediaStreamTrack) && callback) {
        const set = window.probe.listeners.get(this) ?? new Set();
        set.add(callback); window.probe.listeners.set(this, set);
      }
      add.call(this, type, callback, options);
    };
    EventTarget.prototype.removeEventListener = function (type, callback, options) {
      if (callback) window.probe.listeners.get(this)?.delete(callback);
      remove.call(this, type, callback, options);
    };
    const createUrl = URL.createObjectURL.bind(URL);
    const revokeUrl = URL.revokeObjectURL.bind(URL);
    URL.createObjectURL = (blob) => { const url = createUrl(blob); window.probe.urls.add(url); return url; };
    URL.revokeObjectURL = (url) => { window.probe.urls.delete(url); revokeUrl(url); };
  });
});

test('three native microphone/recorder sessions produce playable audio and fully release resources', async ({ page }) => {
  const exceptions: string[] = [];
  const external: string[] = [];
  page.on('pageerror', (error) => exceptions.push(error.message));
  page.on('request', (request) => { if (/^https?:/.test(request.url()) && new URL(request.url()).hostname !== '127.0.0.1') external.push(request.url()); });
  await page.goto('/');
  for (let i = 1; i <= 3; i++) {
    await page.getByRole('button', { name: 'Start microphone', exact: true }).click();
    await expect(page.locator('#phase')).toHaveText('recording');
    await expect(page.locator('#generation')).toHaveText(String(i));
    await expect(page.locator('#playback')).toBeHidden();
    await page.waitForTimeout(500); // Intentionally collect native encoder output.
    await page.getByRole('button', { name: 'Stop recording', exact: true }).click();
    await expect(page.locator('#phase')).toHaveText('completed');
    await expect(page.locator('#playback')).toBeVisible();
    await expect.poll(() => page.locator('audio').evaluate((el: HTMLAudioElement) => el.readyState)).toBeGreaterThanOrEqual(1);
    expect(await page.evaluate(async () => {
      const audio = document.querySelector('audio')!;
      const blob = await fetch(audio.src).then((r) => r.blob());
      const context = new AudioContext();
      try { const decoded = await context.decodeAudioData(await blob.arrayBuffer()); return decoded.duration; }
      finally { await context.close(); }
    })).toBeGreaterThan(0);
    expect(await page.evaluate(() => ({
      tracksEnded: window.probe.streams.every((s) => s.getTracks().every((t) => t.readyState === 'ended')),
      recordersInactive: window.probe.recorders.every((r) => r.state === 'inactive'),
      listeners: [...window.probe.listeners.values()].reduce((n, set) => n + set.size, 0),
      urls: window.probe.urls.size, recorders: window.probe.recorders.length,
    }))).toEqual({ tracksEnded: true, recordersInactive: true, listeners: 0, urls: 1, recorders: i });
  }
  await page.getByRole('button', { name: 'Discard / cancel' }).click();
  await expect(page.locator('#phase')).toHaveText('idle');
  expect(await page.evaluate(() => window.probe.urls.size)).toBe(0);
  await expect(page.getByRole('button', { name: 'Start microphone', exact: true })).toBeEnabled();
  expect(exceptions).toEqual([]); expect(external).toEqual([]);
  await page.screenshot({ path: 'test-results/capture-demo.png', fullPage: true });
});

test('rapid duplicate UI actions create only one recorder', async ({ page }) => {
  await page.goto('/');
  await page.locator('#start').evaluate((button: HTMLButtonElement) => { button.click(); button.click(); });
  await expect(page.locator('#phase')).toHaveText('recording');
  await page.locator('#stop').evaluate((button: HTMLButtonElement) => { button.click(); button.click(); });
  await expect(page.locator('#phase')).toHaveText('completed');
  expect(await page.evaluate(() => window.probe.recorders.length)).toBe(1);
});

test('deterministically injected denial shows recovery; retry uses the native device', async ({ page }) => {
  await page.goto('/');
  await page.evaluate(() => {
    const native = navigator.mediaDevices.getUserMedia.bind(navigator.mediaDevices);
    let first = true;
    navigator.mediaDevices.getUserMedia = (constraints) => {
      if (first) { first = false; return Promise.reject(new DOMException('test denial', 'NotAllowedError')); }
      return native(constraints);
    };
  });
  await page.locator('#start').click(); await expect(page.getByRole('alert')).toContainText('permission denied');
  await page.locator('#start').click(); await expect(page.locator('#phase')).toHaveText('recording');
  await page.locator('#stop').click(); await expect(page.locator('#phase')).toHaveText('completed');
});

test('cancel an unresolved request: late real stream is immediately stopped, then retry works', async ({ page }) => {
  await page.goto('/');
  await page.evaluate(() => {
    const native = navigator.mediaDevices.getUserMedia.bind(navigator.mediaDevices);
    navigator.mediaDevices.getUserMedia = async (constraints) => {
      const stream = await native(constraints);
      await new Promise((resolve) => setTimeout(resolve, 500));
      return stream;
    };
  });
  await page.locator('#start').click(); await page.locator('#discard').click();
  await expect(page.locator('#phase')).toHaveText('idle');
  await expect(page.locator('#start')).toBeEnabled();
  expect(await page.evaluate(() => window.probe.streams.every((s) => s.getTracks().every((t) => t.readyState === 'ended')))).toBe(true);
  expect(await page.evaluate(() => window.probe.recorders.length)).toBe(0);
  await page.locator('#start').click(); await expect(page.locator('#phase')).toHaveText('recording');
  await page.locator('#discard').click(); await expect(page.locator('#phase')).toHaveText('idle');
});

test('real page navigation cleans capture before the document leaves', async ({ page }) => {
  await page.goto('/'); await page.locator('#start').click(); await expect(page.locator('#phase')).toHaveText('recording');
  await page.evaluate(() => window.addEventListener('pagehide', () => {
    // Registered after the app, observes its cleanup; test instrumentation only.
    sessionStorage.setItem('teardown-observation', JSON.stringify({
      ended: window.probe.streams.every((s) => s.getTracks().every((t) => t.readyState === 'ended')),
      inactive: window.probe.recorders.every((r) => r.state === 'inactive'),
      listeners: [...window.probe.listeners.values()].reduce((n, set) => n + set.size, 0),
    }));
  }));
  await page.goto('/?after-navigation');
  expect(await page.evaluate(() => JSON.parse(sessionStorage.getItem('teardown-observation')!))).toEqual({ ended: true, inactive: true, listeners: 0 });
  await expect(page.locator('#phase')).toHaveText('idle');
});

test('page-cache restoration remounts an idle, usable controller', async ({ page }) => {
  await page.goto('/'); await page.locator('#start').click(); await expect(page.locator('#phase')).toHaveText('recording');
  await page.evaluate(() => {
    window.dispatchEvent(new PageTransitionEvent('pagehide', { persisted: true }));
    window.dispatchEvent(new PageTransitionEvent('pageshow', { persisted: true }));
  });
  await expect(page.locator('#phase')).toHaveText('idle');
  await page.locator('#start').click(); await expect(page.locator('#phase')).toHaveText('recording');
  await page.locator('#discard').click(); await expect(page.locator('#phase')).toHaveText('idle');
  expect(await page.evaluate(() => window.probe.streams.every((s) => s.getTracks().every((t) => t.readyState === 'ended')))).toBe(true);
});
