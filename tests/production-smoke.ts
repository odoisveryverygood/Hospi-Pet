// Run against npm run preview -- --port 4173 after npm run build. Uses synthetic browser devices.
import { chromium } from '@playwright/test';
import assert from 'node:assert/strict';
const browser = await chromium.launch({ args: ['--use-fake-device-for-media-stream', '--use-fake-ui-for-media-stream'] });
try {
  const context = await browser.newContext({ permissions: ['microphone', 'camera'] });
  const page = await context.newPage(); const errors: string[] = []; page.on('pageerror', (error) => errors.push(error.message));
  await page.goto('http://127.0.0.1:4173/?lab=1');
  await page.getByRole('button', { name: 'New encounter' }).click();
  await page.getByLabel('Encounter title', { exact: true }).fill('Production smoke');
  await page.getByRole('button', { name: 'Create encounter', exact: true }).click();
  await page.locator('#start').click(); await page.waitForFunction(() => document.querySelector('#phase')?.textContent === 'recording');
  await page.waitForTimeout(600); await page.locator('#stop').click();
  await page.waitForFunction(() => document.querySelector('#phase')?.textContent === 'completed' && document.querySelector('#save-status')?.textContent === 'Saved in this browser');
  await page.locator('#engineering summary').click();
  assert.equal(await page.locator('[data-pane="lab"]').count(), 0);
  await page.locator('[data-pane="provenance"]').click();
  assert.equal(await page.locator('.provenance-source').count(), 1);
  await page.locator('#continue-review').click(); await page.locator('#finalize').click();
  await page.waitForFunction(() => document.querySelector('#encounter-status')?.textContent?.includes('Finalized'));
  await page.screenshot({path:'test-results/production-smoke.png',fullPage:true});
  assert.deepEqual(errors, []);
  console.log('PASS: production recording, source fingerprint, review/finalization, no page errors, and ?lab=1 exposes no Capture Lab.');
} finally { await browser.close(); }
