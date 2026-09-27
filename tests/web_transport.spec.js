const { test, expect } = require('@playwright/test');

test('isolates bounded web requests and cancellation', async ({ page }) => {
  const seen = [];
  page.on('request', (request) => {
    seen.push({
      url: request.url(),
      method: request.method(),
      headers: request.headers(),
      postData: request.postData(),
      redirectedFrom: request.redirectedFrom() ? request.redirectedFrom().url() : '',
    });
  });
  await page.goto(process.env.GD_NETWORK_WEB_URL);
  await page.waitForFunction(() => window.__gdNetworkEvidence !== undefined, null, { timeout: 15000 });
  const evidence = await page.evaluate(() => window.__gdNetworkEvidence);
  expect(evidence).toMatchObject({
    success: true,
    first_count: 9,
    cancel_count: 1,
    capacity: 'capacity_exceeded',
    clients: 2,
    zero_bytes: 0,
    zero_success: true,
    json_body: '{}',
    redirect_error: 'redirect_error',
  });
  const token = 'secret-token-not-in-body';
  const zero = seen.filter((request) => request.method === 'POST' && request.url.endsWith('/zero'));
  expect(zero).toHaveLength(1);
  expect(zero[0].postData ?? '').toBe('');
  expect(zero[0].headers.authorization).toBe(`Bearer ${token}`);
  expect(zero[0].headers['content-type']).toContain('application/json');
  if (zero[0].headers['content-length'] !== undefined) {
    expect(zero[0].headers['content-length']).toBe('0');
  }
  for (const [name, value] of Object.entries(zero[0].headers)) {
    if (name !== 'authorization') {
      expect(String(value)).not.toContain(token);
    }
  }
  const jsonPost = seen.filter((request) => request.method === 'POST' && request.url.endsWith('/json-empty'));
  expect(jsonPost).toHaveLength(1);
  expect(jsonPost[0].postData).toBe('{}');
  expect(jsonPost[0].headers.authorization).toBe(`Bearer ${token}`);
  expect(jsonPost[0].postData).not.toContain(token);
  const redirect = seen.filter((request) => request.url.includes('/redirect-cross'));
  expect(redirect).toHaveLength(1);
  expect(redirect[0].headers.authorization).toBe(`Bearer ${token}`);
  const sinkPort = process.env.GD_NETWORK_SINK_PORT;
  // Chromium returns an opaque redirect and does not contact the target.
  // Playwright still emits a request event for that hop; a real second fetch
  // would not be redirectedFrom and would hit the sink, which the shell checks.
  const followed = seen.filter((request) => request.url.includes('/must-not-follow') || (sinkPort && request.url.includes(`:${sinkPort}/`)));
  for (const request of followed) {
    expect(request.redirectedFrom).toContain('/redirect-cross');
    expect(request.headers.authorization).toBeUndefined();
  }
  expect(JSON.stringify(evidence)).not.toContain(token);
  await page.screenshot({ path: 'dist/web-acceptance.png', fullPage: true });
});
