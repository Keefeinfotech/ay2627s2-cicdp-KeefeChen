/**
 * File Name: global-setup.ts
 * Description: Fast fail-fast precheck for the E2E suite.
 *
 * The suite is black-box and expects the docker-compose stack (or a deployed
 * environment via E2E_BASE_URL / E2E_API_URL) to be reachable. Without it,
 * every request would burn the 60s test timeout into an opaque ECONNREFUSED.
 * This probe exits within seconds with an actionable message instead.
 *
 * Also guards against "something else is listening on the port" (e.g. an IDE
 * server on 8080) by requiring a 200 from the Auxilia health endpoint.
 */

import { request, type FullConfig } from "@playwright/test";

const API_URL = process.env.E2E_API_URL ?? "http://localhost:3000";

export default async function globalSetup(_config: FullConfig): Promise<void> {
  const context = await request.newContext({ baseURL: API_URL });
  try {
    let status = 0;
    try {
      const response = await context.get("/api/health", { timeout: 5_000 });
      status = response.status();
    } catch (error) {
      const detail = error instanceof Error ? error.message : String(error);
      throw precheckError(API_URL, detail);
    }

    if (status !== 200) {
      throw precheckError(
        API_URL,
        `HTTP ${status} from ${API_URL}/api/health (expected 200). ` +
          `Something else may be listening on this port.`,
      );
    }
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
      ``,
    ].join("\n"),
  );
}
