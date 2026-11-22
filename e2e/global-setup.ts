/**
 * File Name: global-setup.ts
 * Description: Preflight precheck and warm-up for the E2E suite.
 *
 * The suite is black-box and expects the docker-compose stack (or a deployed
 * environment via E2E_BASE_URL / E2E_API_URL) to be reachable. Without it,
 * every request would burn the 60s test timeout into an opaque ECONNREFUSED.
 * This probe exits with an actionable message instead.
 *
 * It also guards against "something else is listening on the port" (e.g. an IDE
 * server on 8080) by requiring a 200 from the Auxilia health endpoint.
 *
 * Deployed Render free-tier services sleep when idle and answer 503 while
 * waking up. When E2E_BASE_URL is set, the probe retries both the API and the
 * frontend until they answer 200 (or 60s elapse) so a cold start is absorbed
 * before the tests begin instead of failing the first few tests.
 */

import { request, type APIRequestContext } from "@playwright/test";

const API_URL = process.env.E2E_API_URL ?? "http://localhost:3000";
const WEB_URL = process.env.E2E_BASE_URL;
const DEPLOYED = Boolean(WEB_URL);
const MAX_ATTEMPTS = DEPLOYED ? 12 : 1; // 12 × 5s = 60s of cold-start patience
const RETRY_DELAY_MS = 5_000;

async function waitForOk(
  context: APIRequestContext,
  url: string,
): Promise<void> {
  let lastError = "no response";
  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
    try {
      const response = await context.get(url, { timeout: 10_000 });
      if (response.status() === 200) return;
      lastError = `HTTP ${response.status()} from ${url}`;
    } catch (error) {
      lastError = error instanceof Error ? error.message : String(error);
    }
    if (attempt < MAX_ATTEMPTS) {
      await new Promise((resolve) => setTimeout(resolve, RETRY_DELAY_MS));
    }
  }
  throw precheckError(API_URL, lastError);
}

export default async function globalSetup(): Promise<void> {
  const apiContext = await request.newContext();
  try {
    await waitForOk(apiContext, `${API_URL}/api/health`);
  } finally {
    await apiContext.dispose();
  }

  if (WEB_URL) {
    const webContext = await request.newContext();
    try {
      await waitForOk(webContext, WEB_URL);
    } finally {
      await webContext.dispose();
    }
  }
}

function precheckError(apiUrl: string, detail: string): Error {
  return new Error(
    [
      `\n\nE2E precheck failed: could not reach the Auxilia stack.`,
      `Detail: ${detail}`,
      ``,
      `Start the stack first, e.g.:`,
      `  docker compose up -d --build`,
      `  # wait for /api/health to return 200 before running the suite`,
      ``,
      `Or point the suite at a deployed environment:`,
      `  E2E_API_URL=https://your-host E2E_BASE_URL=https://your-host npm test`,
      ``,
      `A deployed free-tier service may be waking up; retry the suite in a minute.`,
      `API under test: ${apiUrl}`,
      ``,
    ].join("\n"),
  );
}
