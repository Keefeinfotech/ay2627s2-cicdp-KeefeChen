/**
 * File Name: global-setup.ts
 * Description: Preflight precheck and warm-up for the E2E suite.
 *
 * 1. Waits for the API to become healthy. Local runs probe once by default; a
 *    slow cold start (e.g. a free-tier Render deployment) gets a bounded
 *    warm-up retry instead of an immediate failure. Set E2E_BASE_URL to also
 *    warm the frontend and use longer deployed retry defaults.
 * 2. Detects whether the target enforces the Turnstile CAPTCHA gate on the
 *    auth routes (production does) by issuing one deliberately invalid login
 *    and inspecting the response. The result is written to .e2e-state.json
 *    so specs can assert the right contract without the caller having to
 *    remember to set E2E_CAPTCHA_ENABLED. The environment variable, when set
 *    explicitly, always wins over detection.
 * 3. Guards against "something else is listening on the port" (e.g. an IDE
 *    server on 8080) by requiring a 200 from /api/health.
 */

import { request, type APIRequestContext, type FullConfig } from "@playwright/test";
import { writeFile } from "node:fs/promises";
import path from "node:path";

const API_URL = process.env.E2E_API_URL ?? "http://localhost:3000";
const WEB_URL = process.env.E2E_BASE_URL;
const DEPLOYED = Boolean(WEB_URL);
const HEALTH_ATTEMPTS = Number(
  process.env.E2E_HEALTH_ATTEMPTS ?? (DEPLOYED ? 12 : 15),
);
const RETRY_DELAY_MS = Number(process.env.E2E_RETRY_DELAY_MS ?? (DEPLOYED ? 5_000 : 2_000));
// Resolved the same way in both global-setup.ts and the spec: the process
// working directory is the directory the suite is launched from (e2e/ for
// `npm test`), so both sides always agree on the path.
const STATE_PATH = path.resolve(process.cwd(), ".e2e-state.json");

async function waitForOk(
  context: APIRequestContext,
  url: string,
): Promise<void> {
  let lastStatus = 0;
  let lastError = "no response";
  for (let attempt = 1; attempt <= HEALTH_ATTEMPTS; attempt += 1) {
    try {
      const response = await context.get(url, { timeout: 10_000 });
      lastStatus = response.status();
      if (lastStatus === 200) return;
      lastError = `HTTP ${lastStatus} from ${url}`;
    } catch (error) {
      lastError = error instanceof Error ? error.message : String(error);
    }
    if (attempt < HEALTH_ATTEMPTS) {
      await new Promise((resolve) => setTimeout(resolve, RETRY_DELAY_MS));
    }
  }
  throw precheckError(
    API_URL,
    lastStatus
      ? `HTTP ${lastStatus} from ${url} (expected 200). ` +
          `Something else may be listening on this port, or the service failed to boot.`
      : lastError,
  );
}

export default async function globalSetup(_config: FullConfig): Promise<void> {
  const apiContext = await request.newContext({ baseURL: API_URL });
  try {
    await waitForOk(apiContext, `${API_URL}/api/health`);

    // Detect the CAPTCHA gate with one invalid login.
    let captchaEnabled = false;
    try {
      const probe = await apiContext.post("/api/auth/login", {
        data: {
          email: "e2e-probe@invalid.example.com",
          password: "e2e-probe-not-a-real-password",
        },
        failOnStatusCode: false,
        timeout: 10_000,
      });
      const probeBody = await probe.json().catch(() => ({}));
      captchaEnabled =
        probe.status() === 400 &&
        (probeBody as { code?: string }).code === "CAPTCHA_REQUIRED";
    } catch {
      // Probe failed for a transport reason: fall back to env/file default.
      captchaEnabled = process.env.E2E_CAPTCHA_ENABLED === "true";
    }

    await writeFile(
      STATE_PATH,
      JSON.stringify({ apiUrl: API_URL, captchaEnabled }),
      "utf8",
    );
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
      `  # production auto-detects the Turnstile CAPTCHA gate; set`,
      `  # E2E_CAPTCHA_ENABLED=true to override manually`,
      ``,
      `A deployed free-tier service may be waking up; retry the suite in a minute.`,
      `API under test: ${apiUrl}`,
      ``,
    ].join("\n"),
  );
}
