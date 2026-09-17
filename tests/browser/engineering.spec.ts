import { expect, test } from '@playwright/test';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { createEncounter, decodeAudio, installMediaProbe, photo, record, released, saved } from './helpers';
import { validManifest } from '../../src/capture/manifest';
async function pane(page: import('@playwright/test').Page, name: string) {
  await page.locator('#engineering').evaluate((element: HTMLDetailsElement) => { element.open = true; });
  await page.locator(`[data-pane="${name}"]`).click();
}
test('capture → provenance → replay → retired callback → integrity → deterministic export', async ({ page }) => {
  await installMediaProbe(page); await page.goto('/?lab=1'); await createEncounter(page, 'Source continuity');
  await pane(page, 'lab'); await page.locator('#lab-scenario').selectOption('final-data-delay'); await page.locator('#lab-arm').click();
  await page.locator('#start').click(); await expect(page.locator('#phase')).toHaveText('recording');
  await page.waitForTimeout(500);
  // Release final native events as soon as the adapter holds them, before the real 2s stop watchdog.
  await page.locator('#stop').click();
  await expect(page.locator('#lab-status')).toContainText('pending callbacks');
  await expect.poll(() => page.locator('#lab-status').textContent()).toMatch(/[12] pending callbacks/);
  await page.locator('#lab-release').click(); await expect(page.locator('#phase')).toHaveText('completed'); await saved(page); await decodeAudio(page, '#audio');
  await photo(page); await pane(page, 'provenance');
  await expect(page.locator('.provenance-source')).toHaveCount(2);
  await expect(page.locator('#provenance-list')).toContainText('Fingerprinted on save');
  expect(await page.locator('#provenance-list code').allTextContents()).toEqual(expect.arrayContaining([expect.stringMatching(/^[a-f0-9]{64}$/)]));
  await page.locator('#continue-review').click(); await page.locator('#finalize').click(); await expect(page.locator('#encounter-status')).toContainText('Finalized');
  await pane(page, 'timeline'); await expect(page.locator('#event-list')).toContainText('tracks released'); await expect(page.locator('#event-list')).toContainText('finalized');
  const beforeReplay = await page.evaluate(() => ({ streams: window.probe.streams.length, recorders: window.probe.recorders.length }));
  await pane(page, 'replay'); await page.locator('#replay-next').click(); await expect(page.locator('#replay-state')).toContainText('draft');
  await page.locator('#replay-play').click(); await expect(page.locator('#replay-position')).toContainText('Playing'); await page.locator('#replay-pause').click();
  await page.locator('#replay-prev').click(); await page.locator('#replay-restart').click(); await expect(page.locator('#replay-position')).toHaveText(/^0 \//);
  expect(await page.evaluate(() => ({ streams: window.probe.streams.length, recorders: window.probe.recorders.length }))).toEqual(beforeReplay); await released(page);
  await page.locator('#next-encounter').click(); await createEncounter(page, 'Second isolated encounter');
  await pane(page, 'lab');
  const before = await page.locator('#structured-output').textContent();
  const timelineBefore = await page.locator('#event-list').textContent();
  await page.locator('#lab-redeliver').click(); await expect(page.locator('#resource-telemetry')).toContainText('"ignoredStaleCallbacks": 2');
  expect(await page.locator('#structured-output').textContent()).toBe(before);
  expect(await page.locator('#event-list').textContent()).toBe(timelineBefore);
  await expect(page.locator('#resource-telemetry')).toContainText('All checked invariants hold'); await released(page);
  await record(page); await page.locator('#back-history').click(); await page.reload();
  await page.getByRole('button', { name: /Source continuity/ }).click(); await pane(page, 'provenance');
  await expect(page.locator('.integrity-status')).toHaveText(['verified', 'verified']);
  const download = page.waitForEvent('download'); await page.locator('#export-manifest').click();
  const file = await download; const exported = await readFile((await file.path())!, 'utf8'); expect(validManifest(JSON.parse(exported))).toBe(true);
  const again = page.waitForEvent('download'); await page.locator('#export-manifest').click(); expect(await readFile((await (await again).path())!, 'utf8')).toBe(exported);
  await pane(page, 'privacy'); await expect(page.locator('#network-observation')).toContainText('0 page fetch calls; 0 page XHR sends');
  await released(page); page.on('dialog', (dialog) => dialog.accept());
  await page.getByText('Privacy & local data', { exact: true }).click(); await page.locator('#clear-data').click(); await expect(page.getByText('No encounters yet')).toBeVisible();
});
for (const [name, width, height] of [['desktop', 1280, 900], ['tablet', 820, 1100], ['mobile', 390, 844]] as const) {
  test(`engineering views remain usable at ${name} width`, async ({ page }) => {
    await page.setViewportSize({ width, height }); await page.goto('/?lab=1'); await createEncounter(page, 'Provenance walkthrough');
    await record(page); await photo(page); await mkdir('test-results/visual', { recursive: true });
    for (const nameOfPane of ['timeline', 'provenance', 'replay', 'privacy', 'lab']) {
      await pane(page, nameOfPane);
      expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(width);
      await page.locator('#engineering').screenshot({ path: `test-results/visual/engineering-${name}-${nameOfPane}.png` });
    }
    await page.locator('#diagnostics summary').click(); await expect(page.locator('#resource-telemetry')).toContainText('All checked invariants hold');
    expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(width);
  });
}
test('reopen detects mutated Blob bytes and surfaces a visible integrity failure', async ({ page }) => {
  await page.goto('/'); await createEncounter(page, 'Integrity evidence'); await record(page); await page.locator('#back-history').click();
  await page.evaluate(async () => {
    await new Promise<void>((resolve, reject) => {
      const request = indexedDB.open('hospipet-encounters', 1); request.onerror = () => reject(request.error);
      request.onsuccess = () => {
        const db = request.result; const tx = db.transaction('encounters', 'readwrite'); const store = tx.objectStore('encounters');
        const rows = store.getAll(); rows.onsuccess = () => { const record = rows.result[0]; record.audio.blob = new Blob(['changed bytes'], { type: record.audio.blob.type }); store.put(record); };
        tx.oncomplete = () => { db.close(); resolve(); }; tx.onabort = () => reject(tx.error);
      };
    });
  });
  await page.getByRole('button', { name: /Integrity evidence/ }).click(); await expect(page.locator('#source-integrity-warning')).toBeVisible();
  await page.locator('#continue-review').click(); await expect(page.locator('#finalize')).toBeDisabled(); await pane(page, 'provenance'); await expect(page.locator('.integrity-status')).toHaveText('mismatch');
  await page.locator('#edit-capture').click(); await record(page); await expect(page.locator('#source-integrity-warning')).toBeHidden();
  await page.locator('#continue-review').click(); await expect(page.locator('#finalize')).toBeEnabled();
});
test('measure startup, bounded journal storage and repeated native resource cleanup', async ({ page }) => {
  await installMediaProbe(page); const began = Date.now(); await page.goto('/'); await expect(page.getByText('No encounters yet')).toBeVisible();
  const startupWallMs = Date.now() - began; const samples = [];
  await createEncounter(page, 'Repeated capture measurements');
  for (let i = 0; i < 5; i++) {
    await record(page); await released(page);
    samples.push(await page.evaluate(() => ({ tracks: window.probe.streams.flatMap((s) => s.getTracks()).filter((t) => t.readyState === 'live').length, objectUrls: window.probe.urls.size })));
  }
  const storage = await page.evaluate(async () => new Promise<{ events: number; journalBytes: number; mediaBytes: number }>((resolve, reject) => {
    const request = indexedDB.open('hospipet-encounters', 1); request.onerror = () => reject(request.error); request.onsuccess = () => {
      const db = request.result; const tx = db.transaction('encounters'); const rows = tx.objectStore('encounters').getAll();
      rows.onsuccess = () => { const record = rows.result[0]; resolve({ events: record.journal.events.length, journalBytes: new Blob([JSON.stringify(record.journal)]).size, mediaBytes: record.audio.blob.size }); };
      tx.oncomplete = () => db.close();
    };
  }));
  expect(samples.every((s) => s.tracks === 0 && s.objectUrls <= 1)).toBe(true);
  await mkdir('test-results', { recursive: true }); await writeFile('test-results/capture-measurements.json', JSON.stringify({ startupWallMs, samples, storage, note: 'One local development-server run; startup includes automation latency. Logical IDB payload, not on-disk or heap size.' }, null, 2));
});
test('development network observer counts real page fetch/XHR calls only during capture', async ({ page }) => {
  await page.goto('/?lab=1'); await createEncounter(page, 'Network observation');
  await page.locator('#start').click(); await expect(page.locator('#phase')).toHaveText('recording');
  await page.evaluate(async () => {
    await fetch('/');
    await new Promise<void>((resolve, reject) => { const request = new XMLHttpRequest(); request.open('GET', '/'); request.onload = () => resolve(); request.onerror = () => reject(new Error('XHR failed')); request.send(); });
  });
  await pane(page, 'privacy'); await expect(page.locator('#network-observation')).toContainText('1 page fetch calls; 1 page XHR sends');
  await page.locator('#discard').click(); await page.evaluate(() => fetch('/'));
  await expect(page.locator('#network-observation')).toContainText('1 page fetch calls; 1 page XHR sends');
});
test('replay owns one timer and clears it on collapse and encounter navigation', async ({ page }) => {
  await page.goto('/'); await createEncounter(page, 'Replay cleanup'); await record(page);
  await page.evaluate(() => {
    const original = window.setInterval; const clear = window.clearInterval; const active = new Set<number>();
    Object.assign(window, { replayIntervals: active });
    window.setInterval = ((handler: TimerHandler, timeout?: number) => { const id = original(handler, timeout); active.add(id); return id; }) as typeof window.setInterval;
    window.clearInterval = (id) => { if (typeof id === 'number') active.delete(id); clear(id); };
  });
  const intervals = () => page.evaluate(() => (window as unknown as { replayIntervals: Set<number> }).replayIntervals.size);
  await pane(page, 'replay'); await page.locator('#replay-play').click(); await page.locator('#replay-play').click(); expect(await intervals()).toBe(1);
  await page.locator('#engineering summary').click(); await expect.poll(intervals).toBe(0);
  await pane(page, 'replay'); await page.locator('#replay-play').click(); expect(await intervals()).toBe(1);
  await page.locator('#back-history').click(); expect(await intervals()).toBe(0);
});
