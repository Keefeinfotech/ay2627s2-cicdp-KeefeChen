/**
 * File Name: api-blackbox.spec.ts
 * Description: Black-box API contract checks through the public HTTP
 * surface. The suite has no knowledge of internals — it asserts on status
 * codes, response bodies and headers only. Mirrors the contract enforced by
 * the backend suite, but against the real deployed stack (not mocks).
 *
 * Target via E2E_API_URL (default http://localhost:3000). Set
 * E2E_CAPTCHA_ENABLED=true when the target runs with Turnstile enabled
 * (e.g. production); the auth assertions then expect the captcha gate
 * instead of the underlying credential/validation contract.
 *
 * A global precheck (global-setup.ts) fails fast with instructions when the
 * stack is unreachable instead of timing out every test.
 */

import { expect, test } from "@playwright/test";

const API_URL = process.env.E2E_API_URL ?? "http://localhost:3000";

/**
 * The compose stack runs with CAPTCHA_ENABLED=false, but the deployed Render
 * environment runs with it enabled (Turnstile). In that case the auth routes
 * reject unverifiable requests with a captcha error before credentials are
 * evaluated, which is the correct production behaviour. The assertions below
 * therefore accept either the underlying contract or the captcha gate, and
 * always check that account enumeration is impossible.
 */
const CAPTCHA_ENABLED = process.env.E2E_CAPTCHA_ENABLED === "true";

test.describe("API black-box contract", () => {
  test("unknown routes return a structured 404", async ({ request }) => {
    const response = await request.get(`${API_URL}/api/__auxilia_e2e_missing__`);
    expect(response.status()).toBe(404);
    const body = await response.json();
    expect(body.code).toBe("NOT_FOUND");
  });

  test("authenticated endpoints reject anonymous callers with 401", async ({
    request,
  }) => {
    const response = await request.get(`${API_URL}/api/tasks`);
    expect(response.status()).toBe(401);
    const body = await response.json();
    expect(body.code).toBe("UNAUTHORIZED");
  });

  test("AI chat rejects anonymous callers with 401", async ({ request }) => {
    const response = await request.post(`${API_URL}/api/ai/chat`, {
      data: { message: "hello" },
    });
    expect(response.status()).toBe(401);
    const body = await response.json();
    expect(body.code).toBe("UNAUTHORIZED");
  });

  test("signup rejects malformed payloads", async ({ request }) => {
    const response = await request.post(`${API_URL}/api/auth/signup`, {
      data: { email: "not-an-email", password: "short" },
    });
    const body = await response.json();

    if (CAPTCHA_ENABLED) {
      // Production: Turnstile rejects the request before schema validation.
      expect(response.status()).toBe(400);
      expect(body.code).toBe("CAPTCHA_REQUIRED");
      return;
    }

    expect(response.status()).toBe(400);
    expect(body.code).toBe("VALIDATION_ERROR");
  });

  test("login does not enumerate accounts", async ({ request }) => {
    const response = await request.post(`${API_URL}/api/auth/login`, {
      data: { email: "definitely-not-registered@example.com", password: "WrongP@ss1234" },
    });
    const body = await response.json();

    if (CAPTCHA_ENABLED) {
      // Production: Turnstile rejects the request before the credential check.
      expect(response.status()).toBe(400);
      expect(body.code).toBe("CAPTCHA_REQUIRED");
    } else {
      expect(response.status()).toBe(401);
      expect(body.code).toBe("UNAUTHORIZED");
    }
    expect(JSON.stringify(body)).not.toMatch(/no account|user not found/i);
  });

  test("responses carry the security headers", async ({ request }) => {
    const response = await request.get(`${API_URL}/api/health`);
    const headers = response.headers();
    expect(headers["x-content-type-options"]).toBe("nosniff");
    expect(headers["x-powered-by"]).toBeUndefined();
  });

  test("error responses never leak stack traces", async ({ request }) => {
    const response = await request.get(`${API_URL}/api/__auxilia_e2e_missing__`);
    const text = await response.text();
    expect(text).not.toContain("    at ");
    expect(text).not.toContain("node_modules");
  });
});
