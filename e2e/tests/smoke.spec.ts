/**
 * File Name: smoke.spec.ts
 * Description: Post-deploy smoke checks (black box). Mirrors and extends the
 * checks in scripts/smoke-test.mjs, but exercises the whole serving path,
 * including the frontend SPA, CSP headers and the API health endpoint.
 */

import { expect, test } from "@playwright/test";

const API_URL = process.env.E2E_API_URL ?? "http://localhost:3000";

test.describe("system smoke", () => {
  test("frontend serves the app shell over HTTP 200", async ({ page }) => {
    const response = await page.goto("/", { waitUntil: "domcontentloaded" });
    expect(response).not.toBeNull();
    expect(response!.ok()).toBeTruthy();
    await expect(page).toHaveTitle(/Auxilia/i);
  });

  test("Flutter web engine boots (canvas or semantics root present)", async ({
    page,
    browserName,
  }) => {
    // WebKit (MiniBrowser on Windows CI) cannot boot Flutter's CanvasKit/WASM
    // engine reliably; it still covers HTTP/CSP/headers and the API contract
    // in the other specs. Rendering is verified on Chromium and Firefox.
    test.skip(browserName === "webkit", "CanvasKit does not boot under WebKitGTK on CI");
    test.setTimeout(90_000);
    await page.goto("/", { waitUntil: "domcontentloaded" });
    // CanvasKit renders into a <canvas>; html renderer/semantics exposes
    // flt-semantics elements instead. Either proves the engine started.
    const canvas = page.locator("canvas").first();
    const semanticsRoot = page.locator("flt-semantics").first();
    await expect(canvas.or(semanticsRoot)).toBeAttached({ timeout: 30_000 });
  });

  test("frontend ships a strict Content-Security-Policy", async ({ page }) => {
    const response = await page.goto("/", { waitUntil: "domcontentloaded" });
    const csp = response?.headers()["content-security-policy"] ?? "";
    expect(csp).toContain("default-src 'self'");
    // 'wasm-unsafe-eval' is required for the CanvasKit WASM engine and is
    // not the same directive as 'unsafe-eval'. Styles may use 'unsafe-inline'
    // (Flutter injects inline style elements) but scripts may not.
    const scriptSrc = csp.split(";").find((d) => d.trim().startsWith("script-src")) ?? "";
    expect(scriptSrc).not.toContain("'unsafe-eval'");
    expect(scriptSrc).not.toContain("'unsafe-inline'");
  });

  test("API health endpoint reports ok", async ({ request }) => {
    const response = await request.get(`${API_URL}/api/health`);
    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body).toMatchObject({ status: "ok" });
  });

  test("SPA falls back to index.html for unknown client-side routes", async ({
    page,
  }) => {
    const response = await page.goto("/some/deep/client/route", { waitUntil: "domcontentloaded" });
    // Nginx serves the app shell; the router resolves the route client-side.
    expect(response).not.toBeNull();
    expect(response!.status()).toBe(200);
  });
});
