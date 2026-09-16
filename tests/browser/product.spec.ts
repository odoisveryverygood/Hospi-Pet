import { expect, test } from '@playwright/test';
import { createEncounter, decodeAudio, installMediaProbe, photo, record, released, saved } from './helpers';

test.beforeEach(async ({ page }) => { await installMediaProbe(page); await page.goto('/'); });

test('two complete encounters preserve real media, isolated sources, history and deletion', async ({ page }) => {
  const errors: string[] = []; page.on('pageerror', (error) => errors.push(error.message));
  await createEncounter(page, 'Practice follow-up');
  const firstId = await page.locator('#diag-encounter').textContent();
  await record(page); await photo(page);
  const firstCapture = await page.locator('#diag-capture').textContent();
  await page.locator('#notes').fill('Synthetic practice visit: questions for the next conversation.');
  await page.locator('#continue-review').click();
  await expect(page.locator('#review-notes')).toContainText('Synthetic practice visit');
  await page.locator('#finalize').click();
  await expect(page.locator('#encounter-status')).toHaveText('Finalized · local');
  await expect(page.locator('#diag-tracks')).toHaveText('0 / 0');
  await expect(page.locator('#diag-timers')).toHaveText('0 / 0 / 0');
  await released(page);
  await page.locator('#next-encounter').click();
  expect(await page.evaluate(() => window.probe.urls.size)).toBe(0);
  await createEncounter(page, 'Second practice visit');
  expect(await page.locator('#diag-encounter').textContent()).not.toBe(firstId);
  await expect(page.locator('#notes')).toHaveValue('');
  await expect(page.locator('#image-grid img')).toHaveCount(0);
  await expect(page.locator('#playback')).toBeHidden();
  await record(page);
  expect(await page.locator('#diag-capture').textContent()).not.toBe(firstCapture);
  await page.locator('#continue-review').click(); await page.locator('#finalize').click();
  await expect(page.locator('#encounter-status')).toContainText('Finalized');
  await page.reload();
  await expect(page.locator('.encounter-row')).toHaveCount(2);
  await page.getByRole('button', { name: /Practice follow-up/ }).click();
  await expect(page.locator('#review-notes')).toContainText('Synthetic practice visit');
  await expect(page.locator('#capture-step')).toBeDisabled();
  await decodeAudio(page, '#review-audio');
  await expect.poll(() => page.locator('#review-images img').evaluate((img: HTMLImageElement) => img.naturalWidth)).toBeGreaterThan(0);
  page.on('dialog', (dialog) => dialog.accept());
  await page.locator('#delete-encounter').click();
  await expect(page.locator('.encounter-row')).toHaveCount(1);
  await page.getByRole('button', { name: /Second practice visit/ }).click();
  await expect(page.locator('#review-notes')).toHaveText('No written notes were added.');
  await expect(page.locator('#review-images img')).toHaveCount(0);
  await decodeAudio(page, '#review-audio');
  await page.locator('#delete-encounter').click();
  await expect(page.getByText('No encounters yet')).toBeVisible(); await page.reload();
  await expect(page.getByText('No encounters yet')).toBeVisible();
  expect(errors).toEqual([]);
});

test('camera denial, retry, repeated photos and simultaneous capture teardown release native tracks', async ({ page }) => {
  await createEncounter(page, 'Camera recovery');
  await page.evaluate(() => {
    const native = navigator.mediaDevices.getUserMedia.bind(navigator.mediaDevices); let first = true;
    navigator.mediaDevices.getUserMedia = (constraints) => {
      if (constraints?.video && first) { first = false; return Promise.reject(new DOMException('test', 'NotAllowedError')); }
      return native(constraints);
    };
  });
  await page.locator('#open-camera').click();
  await expect(page.locator('#camera-error')).toContainText('permission denied');
  for (let i = 1; i <= 3; i++) { await photo(page); await expect(page.locator('#image-grid img')).toHaveCount(i); await released(page); }
  await page.getByRole('button', { name: 'Remove photo 2' }).click();
  await expect(page.locator('#image-grid img')).toHaveCount(2);
  await page.locator('#start').click(); await expect(page.locator('#phase')).toHaveText('recording');
  await page.locator('#open-camera').click(); await expect(page.locator('#camera-phase')).toHaveText('preview');
  await page.locator('#back-history').click(); await released(page);
  expect(await page.evaluate(() => window.probe.urls.size)).toBe(0);
  await page.getByRole('button', { name: /Camera recovery/ }).click();
  await expect(page.locator('#phase')).toHaveText('idle');
  await expect(page.locator('#image-grid img')).toHaveCount(2);
});

test('failed atomic write keeps notes in memory, reports unsaved state, and retries', async ({ page }) => {
  await createEncounter(page, 'Storage recovery');
  await page.evaluate(() => {
    const native = IDBObjectStore.prototype.put; let fail = true;
    IDBObjectStore.prototype.put = function (...args: Parameters<IDBObjectStore['put']>) {
      if (fail) { fail = false; throw new DOMException('test quota', 'QuotaExceededError'); }
      return native.apply(this, args);
    };
  });
  await page.locator('#notes').fill('Do not lose this synthetic note.');
  await expect(page.locator('#storage-message')).toContainText('storage is full');
  await expect(page.locator('#save-status')).toHaveText('Save needs attention');
  await expect(page.locator('#notes')).toHaveValue('Do not lose this synthetic note.');
  await page.locator('#retry-save').click(); await saved(page); await page.reload();
  await page.getByRole('button', { name: /Storage recovery/ }).click();
  await expect(page.locator('#notes')).toHaveValue('Do not lose this synthetic note.');
});

test('competing tabs cannot silently overwrite a newer revision', async ({ page, context }) => {
  await createEncounter(page, 'Shared draft');
  const other = await context.newPage(); await other.goto('/');
  await other.getByRole('button', { name: /Shared draft/ }).click();
  await page.locator('#notes').fill('Newer saved note'); await saved(page);
  await other.locator('#notes').fill('Stale tab edit');
  await expect(other.locator('#storage-message')).toContainText('changed in another tab');
  await expect(other.locator('#notes')).toHaveValue('Stale tab edit');
  other.once('dialog', (dialog) => dialog.accept()); await other.locator('#reload-saved').click();
  await expect(other.locator('#notes')).toHaveValue('Newer saved note');
  await other.close();
});

test('corrupted records are isolated and removed only explicitly', async ({ page }) => {
  await createEncounter(page, 'Valid record'); await page.locator('#back-history').click();
  await page.evaluate(() => new Promise<void>((resolve, reject) => {
    const open = indexedDB.open('hospipet-encounters', 1);
    open.onsuccess = () => { const db = open.result; const tx = db.transaction('encounters', 'readwrite');
      tx.objectStore('encounters').put({ id: 'broken', schemaVersion: -1 });
      tx.oncomplete = () => { db.close(); resolve(); }; tx.onerror = () => reject(tx.error);
    };
  }));
  await page.locator('#refresh-history').click();
  await expect(page.locator('#invalid-message')).toContainText('1 local record(s)');
  await expect(page.locator('.encounter-row')).toHaveCount(1);
  page.once('dialog', (dialog) => dialog.accept()); await page.locator('#remove-invalid').click();
  await expect(page.locator('#invalid-records')).toBeHidden();
  await expect(page.locator('.encounter-row')).toHaveCount(1);
});

test('loaded application captures and saves offline with no content-bearing network requests', async ({ page, context }) => {
  const requests: string[] = [];
  page.on('request', (request) => { if (/^https?:/.test(request.url())) requests.push(`${request.method()} ${request.url()}`); });
  await context.setOffline(true);
  await createEncounter(page, 'Offline practice'); await record(page); await photo(page);
  await page.locator('#notes').fill('Synthetic offline note');
  await page.locator('#continue-review').click(); await page.locator('#finalize').click();
  await expect(page.locator('#encounter-status')).toContainText('Finalized');
  await released(page);
  await page.locator('#next-encounter').click();
  await page.getByRole('button', { name: /Offline practice/ }).click();
  await decodeAudio(page, '#review-audio');
  expect(requests).toEqual([]);
  await page.getByText('Privacy & local data', { exact: true }).click();
  page.once('dialog', (dialog) => dialog.accept()); await page.locator('#clear-data').click();
  await expect(page.getByText('No encounters yet')).toBeVisible();
});
