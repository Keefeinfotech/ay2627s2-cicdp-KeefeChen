/**
 * File Name: global-setup.ts
 * Description: Fast precheck for the E2E suite.
 *
 * 1. Waits for the API to become healthy. Local runs probe once; a slow
 *    cold start (e.g. a free-tier Render deployment) gets a bounded warm-up
 *    retry instead of an immediate failure. If the target stays unreachable,
 *    the suite fails fast with instructions instead of 7 x 60s of
 *    ECONNREFUSED.
 * 2. Detects whether the target enforces the Turnstile CAPTCHA gate on the
 *    auth routes (production does) by issuing one deliberately invalid login
 *    and inspecting the response. The result is written to .e2e-state.json
 *    so the spec can assert the right contract without the caller having to
 *    remember to set E2E_CAPTCHA_ENABLED. The environment variable, when set
 *    explicitly, always wins over detection.
 * 3. Guards against "something else is listening on the port" (e.g. an IDE
 *    server on 8080) by requiring a 200 from /api/health.
 */

import { request, type FullConfig } from "@playwright/test";
import { writeFile } from "node:fs/promises";
import path from "node:path";

const API_URL = process.env.E2E_API_URL ?? "http://localhost:3000";
const HEALTH_ATTEMPTS = Number(process.env.E2E_HEALTH_ATTEMPTS ?? 15);
const RETRY_DELAY_MS = 2_000;
// Resolved the same way in both global-setup.ts and the spec: the process
// working directory is the directory the suite is launched from (e2e/ for
// `npm test`), so both sides always agree on the path.
const STATE_PATH = path.resolve(process.cwd(), ".e2e-state.json");

export default async function globalSetup(_config: FullConfig): Promise<void> {
  const context = await request.newContext({ baseURL: API_URL });
  try {
    // ------------------------------------------------------------------
    // 1. Health probe (with bounded warm-up for cold starts)
    // ------------------------------------------------------------------
    let healthy = false;
    let lastStatus = 0;
    let lastError = "";
    for (let attempt = 1; attempt <= HEALTH_ATTEMPTS; attempt += 1) {
      try {
        const response = await context.get("/api/health", { timeout: 5_000 });
        lastStatus = response.status();
        if (lastStatus === 200) {
          healthy = true;
          break;
        }
      } catch (error) {
        lastError = error instanceof Error ? error.message : String(error);
      }
      if (attempt < HEALTH_ATTEMPTS) {
        await new Promise((resolve) => setTimeout(resolve, RETRY_DELAY_MS));
      }
    }

    if (!healthy) {
      throw precheckError(
        API_URL,
        lastStatus
          ? `HTTP ${lastStatus} from ${API_URL}/api/health (expected 200). ` +
              `Something else may be listening on this port, or the service failed to boot.`
          : lastError || "no response",
      );
    }

    // ------------------------------------------------------------------
    // 2. Detect the CAPTCHA gate with one invalid login
    // ------------------------------------------------------------------
    let captchaEnabled = false;
    try {
      const probe = await context.post("/api/auth/login", {
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
    await context.dispose();
  }
}

function precheckError(apiUrl: string, detail: string): Error {
  return new Error(
    [
      `\n\nE2E precheck failed: could not reach the Auxilia API at ${apiUrl}.`,
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
    ].join("\n"),
  );
}
