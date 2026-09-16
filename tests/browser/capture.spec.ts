import { expect, test } from '@playwright/test';
import type { Page } from '@playwright/test';

import { installMediaProbe } from './helpers';
test.beforeEach(async ({ page }) => installMediaProbe(page));

test('three native microphone/recorder sessions produce playable audio and fully release resources', async ({ page }) => {
  const exceptions: string[] = [];
  const external: string[] = [];
  page.on('pageerror', (error) => exceptions.push(error.message));
  page.on('request', (request) => { if (/^https?:/.test(request.url()) && new URL(request.url()).hostname !== '127.0.0.1') external.push(request.url()); });
  await openEncounter(page);
  for (let i = 1; i <= 3; i++) {
    await page.getByRole('button', { name: 'Start microphone', exact: true }).click();
    await expect(page.locator('#phase')).toHaveText('recording');
    await expect(page.locator('#generation')).toHaveText(String(i));
    await expect(page.locator('#playback')).toBeHidden();
    await page.waitForTimeout(500); // Intentionally collect native encoder output.
    await page.getByRole('button', { name: 'Stop recording', exact: true }).click();
    await expect(page.locator('#phase')).toHaveText('completed');
    await expect(page.locator('#playback')).toBeVisible();
    await expect.poll(() => page.locator('#audio').evaluate((el: HTMLAudioElement) => el.readyState)).toBeGreaterThanOrEqual(1);
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
  await openEncounter(page);
  await page.locator('#start').evaluate((button: HTMLButtonElement) => { button.click(); button.click(); });
  await expect(page.locator('#phase')).toHaveText('recording');
  await page.locator('#stop').evaluate((button: HTMLButtonElement) => { button.click(); button.click(); });
  await expect(page.locator('#phase')).toHaveText('completed');
  expect(await page.evaluate(() => window.probe.recorders.length)).toBe(1);
});

test('deterministically injected denial shows recovery; retry uses the native device', async ({ page }) => {
  await openEncounter(page);
  await page.evaluate(() => {
    const native = navigator.mediaDevices.getUserMedia.bind(navigator.mediaDevices);
    let first = true;
    navigator.mediaDevices.getUserMedia = (constraints) => {
      if (first) { first = false; return Promise.reject(new DOMException('test denial', 'NotAllowedError')); }
      return native(constraints);
    };
  });
  await page.locator('#start').click(); await expect(page.locator('#error')).toContainText('permission denied');
  await page.locator('#start').click(); await expect(page.locator('#phase')).toHaveText('recording');
  await page.locator('#stop').click(); await expect(page.locator('#phase')).toHaveText('completed');
});

test('cancel an unresolved request: late real stream is immediately stopped, then retry works', async ({ page }) => {
  await openEncounter(page);
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
  await openEncounter(page); await page.locator('#start').click(); await expect(page.locator('#phase')).toHaveText('recording');
  await page.evaluate(() => window.addEventListener('pagehide', () => {
    // Registered after the app, observes its cleanup; test instrumentation only.
    sessionStorage.setItem('teardown-observation', JSON.stringify({
      ended: window.probe.streams.every((s) => s.getTracks().every((t) => t.readyState === 'ended')),
      inactive: window.probe.recorders.every((r) => r.state === 'inactive'),
      listeners: [...window.probe.listeners.values()].reduce((n, set) => n + set.size, 0),
    }));
  }));
  await expect(page.locator('#save-status')).toHaveText('Saved in this browser');
  await page.goto('/?after-navigation');
  expect(await page.evaluate(() => JSON.parse(sessionStorage.getItem('teardown-observation')!))).toEqual({ ended: true, inactive: true, listeners: 0 });
  await page.getByRole('button', { name: /Microphone lifecycle regression/ }).click();
  await expect(page.locator('#phase')).toHaveText('idle');
});

test('page-cache restoration remounts an idle, usable controller', async ({ page }) => {
  await openEncounter(page); await page.locator('#start').click(); await expect(page.locator('#phase')).toHaveText('recording');
  await page.evaluate(() => {
    window.dispatchEvent(new PageTransitionEvent('pagehide', { persisted: true }));
    window.dispatchEvent(new PageTransitionEvent('pageshow', { persisted: true }));
  });
  await page.getByRole('button', { name: /Microphone lifecycle regression/ }).click();
  await expect(page.locator('#phase')).toHaveText('idle');
  await page.locator('#start').click(); await expect(page.locator('#phase')).toHaveText('recording');
  await page.locator('#discard').click(); await expect(page.locator('#phase')).toHaveText('idle');
  expect(await page.evaluate(() => window.probe.streams.every((s) => s.getTracks().every((t) => t.readyState === 'ended')))).toBe(true);
});

async function openEncounter(page: Page) {
  await page.goto('/');
  await page.getByRole('button', { name: 'New encounter', exact: false }).click();
  await page.getByLabel('Encounter title', { exact: true }).fill('Microphone lifecycle regression');
  await page.getByRole('button', { name: 'Create encounter', exact: true }).click();
  await expect(page.locator('#phase')).toHaveText('idle');
}
