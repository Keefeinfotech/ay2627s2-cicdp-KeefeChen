#!/usr/bin/env node
/**
 * Read-only smoke test for a deployed Auxilia API.
 *
 * Usage:
 *   node scripts/smoke-test.mjs https://api.example.com
 *   SMOKE_BASE_URL=https://api.example.com node scripts/smoke-test.mjs
 *
 * The script does not create accounts or mutate task data. Manual checks cover
 * signup/login and task CRUD because those require a dedicated smoke account.
 */

const baseUrl = (process.argv[2] ?? process.env.SMOKE_BASE_URL ?? '')
  .trim()
  .replace(/\/+$/, '');

if (!baseUrl) {
  console.error('Usage: node scripts/smoke-test.mjs <base-url>');
  process.exit(2);
}

const timeoutMs = Number(process.env.SMOKE_TIMEOUT_MS ?? 10000);
const controller = new AbortController();
const timeout = setTimeout(() => controller.abort(), timeoutMs);

const results = [];
const check = async (name, fn) => {
  try {
    await fn();
    results.push({ name, ok: true });
    console.log(`PASS ${name}`);
  } catch (error) {
    results.push({ name, ok: false, error });
    console.error(`FAIL ${name}: ${error instanceof Error ? error.message : String(error)}`);
  }
};

const expectStatus = async (response, allowed) => {
  if (!allowed.includes(response.status)) {
    const body = (await response.text()).slice(0, 300);
    throw new Error(`expected ${allowed.join('/')} but got ${response.status}: ${body}`);
  }
};

try {
  await check('GET /api/health returns 200', async () => {
    const response = await fetch(`${baseUrl}/api/health`, {
      headers: { Accept: 'application/json' },
      signal: controller.signal,
    });
    await expectStatus(response, [200]);
  });

  await check('POST /api/ai/chat without auth returns 401', async () => {
    const response = await fetch(`${baseUrl}/api/ai/chat`, {
      method: 'POST',
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ message: 'smoke test' }),
      signal: controller.signal,
    });
    await expectStatus(response, [401]);
  });

  await check('Unknown API route returns 404', async () => {
    const response = await fetch(`${baseUrl}/api/__auxilia_smoke_missing__`, {
      headers: { Accept: 'application/json' },
      signal: controller.signal,
    });
    await expectStatus(response, [404]);
  });
} finally {
  clearTimeout(timeout);
}

const failed = results.filter((result) => !result.ok).length;
console.log(`\nSmoke test: ${results.length - failed}/${results.length} checks passed.`);
process.exit(failed === 0 ? 0 : 1);
