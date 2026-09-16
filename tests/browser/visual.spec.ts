import { expect, test } from '@playwright/test';
import { mkdir } from 'node:fs/promises';
import { createEncounter, installMediaProbe, photo, saved } from './helpers';

for (const [name, width, height] of [['desktop', 1280, 900], ['tablet', 820, 1100], ['mobile', 390, 844]] as const) {
  test(`responsive workflow and keyboard focus at ${name} width`, async ({ page }) => {
    await page.setViewportSize({ width, height }); await installMediaProbe(page); await page.goto('/');
    const errors: string[] = []; page.on('pageerror', (error) => errors.push(error.message));
    await mkdir('test-results/visual', { recursive: true });
    const snapshot = async (screen: string) => {
      expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(width);
      await page.screenshot({ path: `test-results/visual/${name}-${screen}.png`, fullPage: true });
    };
    await expect(page.getByText('No encounters yet')).toBeVisible(); await snapshot('empty');
    await page.getByRole('button', { name: 'New encounter' }).click();
    await expect(page.getByLabel('Encounter title', { exact: true })).toBeFocused(); await snapshot('create');
    await page.getByRole('button', { name: 'Cancel', exact: true }).click();
    await createEncounter(page, 'Practice follow-up visit'); await snapshot('capture');
    await page.locator('#start').click(); await expect(page.locator('#phase')).toHaveText('recording'); await snapshot('recording');
    await page.locator('#stop').click(); await expect(page.locator('#phase')).toHaveText('completed');
    await page.locator('#open-camera').click(); await expect(page.locator('#camera-phase')).toHaveText('preview');
    await expect(page.locator('#take-photo')).toBeEnabled(); await snapshot('camera');
    await page.locator('#close-camera').click(); await photo(page);
    await page.locator('#notes').fill('Practice visit only. Keep the recording and document together for review.'); await saved(page); await snapshot('sources');
    await page.locator('#continue-review').click(); await expect(page.locator('#review-heading')).toBeFocused(); await snapshot('review');
    await page.getByText('Structured encounter record', { exact: true }).click();
    await page.locator('#diagnostics summary').click();
    await page.getByText('Privacy & local data', { exact: true }).click(); await snapshot('details');
    await page.locator('#finalize').click(); await expect(page.locator('#encounter-status')).toContainText('Finalized'); await snapshot('finalized');
    await page.locator('#next-encounter').click(); await expect(page.locator('.encounter-row')).toHaveCount(1); await snapshot('history');
    await page.getByRole('button', { name: /Practice follow-up visit/ }).click();
    await expect(page.locator('#review-heading')).toHaveText('Encounter saved');
    expect(errors).toEqual([]);
  });
}

test('permission error screen remains readable and usable at mobile width', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 }); await page.goto('/'); await createEncounter(page, 'Permission recovery');
  await page.evaluate(() => { navigator.mediaDevices.getUserMedia = () => Promise.reject(new DOMException('test', 'NotAllowedError')); });
  await page.locator('#start').click(); await expect(page.locator('#error')).toBeVisible();
  await page.locator('#open-camera').click(); await expect(page.locator('#camera-error')).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBe(390);
  await mkdir('test-results/visual', { recursive: true });
  await page.screenshot({ path: 'test-results/visual/mobile-errors.png', fullPage: true });
  await expect(page.locator('#start')).toBeEnabled();
  await expect(page.locator('#open-camera')).toBeEnabled();
});
