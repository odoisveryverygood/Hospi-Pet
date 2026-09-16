import { expect } from '@playwright/test';
import type { Page } from '@playwright/test';
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

export async function installMediaProbe(page: Page) {
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
}

export async function createEncounter(page: Page, title: string) {
  await page.getByRole('button', { name: 'New encounter' }).click();
  await page.getByLabel('Encounter title', { exact: true }).fill(title);
  await page.getByRole('button', { name: 'Create encounter', exact: true }).click();
  await expect(page.locator('#phase')).toHaveText('idle');
}
export async function record(page: Page) {
  await page.locator('#start').click();
  await expect(page.locator('#phase')).toHaveText('recording');
  await page.waitForTimeout(500); // Native encoder needs a non-empty interval.
  await page.locator('#stop').click();
  await expect(page.locator('#phase')).toHaveText('completed');
  await saved(page);
  await decodeAudio(page, '#audio');
}
export async function decodeAudio(page: Page, selector: string) {
  expect(await page.locator(selector).evaluate(async (audio: HTMLAudioElement) => {
    const blob = await fetch(audio.src).then((r) => r.blob());
    const context = new AudioContext();
    try { return (await context.decodeAudioData(await blob.arrayBuffer())).duration; }
    finally { await context.close(); }
  })).toBeGreaterThan(0);
}
export async function photo(page: Page) {
  await page.locator('#open-camera').click();
  await expect.poll(() => page.locator('#camera-video').evaluate((v: HTMLVideoElement) => v.videoWidth)).toBeGreaterThan(0);
  await page.locator('#take-photo').click();
  await expect(page.locator('#camera-phase')).toHaveText('completed');
  await expect.poll(() => page.locator('#image-grid img').last().evaluate((img: HTMLImageElement) => img.naturalWidth)).toBeGreaterThan(0);
  await saved(page);
}
export async function saved(page: Page) { await expect(page.locator('#save-status')).toHaveText('Saved in this browser'); }
export async function released(page: Page) {
  expect(await page.evaluate(() => ({
    tracks: window.probe.streams.flatMap((s) => s.getTracks()).filter((t) => t.readyState !== 'ended').length,
    recorders: window.probe.recorders.filter((r) => r.state !== 'inactive').length,
    listeners: [...window.probe.listeners.values()].reduce((n, set) => n + set.size, 0),
  }))).toEqual({ tracks: 0, recorders: 0, listeners: 0 });
}
