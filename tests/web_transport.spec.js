const { test, expect } = require('@playwright/test');

test('isolates bounded web requests and cancellation', async ({ page }) => {
  await page.goto(process.env.GD_NETWORK_WEB_URL);
  await page.waitForFunction(() => window.__gdNetworkEvidence !== undefined, null, { timeout: 15000 });
  const evidence = await page.evaluate(() => window.__gdNetworkEvidence);
  expect(evidence).toMatchObject({
    success: true,
    first_count: 9,
    cancel_count: 1,
    capacity: 'capacity_exceeded',
    clients: 2,
  });
  await page.screenshot({ path: 'dist/web-acceptance.png', fullPage: true });
});
