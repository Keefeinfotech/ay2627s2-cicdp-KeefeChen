import { afterEach, describe, expect, it, vi } from "vitest";
import {
  isCaptchaEnabled,
  verifyTurnstileToken,
} from "../../src/shared/utils/captcha";

const originalSecret = process.env.TURNSTILE_SECRET_KEY;
const originalCaptcha = process.env.CAPTCHA_ENABLED;

afterEach(() => {
  process.env.TURNSTILE_SECRET_KEY = originalSecret;
  process.env.CAPTCHA_ENABLED = originalCaptcha;
  vi.restoreAllMocks();
});

describe("Turnstile verification", () => {
  it("fails closed without a server secret", async () => {
    delete process.env.TURNSTILE_SECRET_KEY;
    await expect(verifyTurnstileToken("token")).resolves.toEqual({
      success: false,
      reason: "captcha_not_configured",
    });
  });

  it("sends the token and client IP to Cloudflare", async () => {
    process.env.TURNSTILE_SECRET_KEY = "secret";
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(
        new Response(JSON.stringify({ success: true }), { status: 200 })
      );

    await expect(
      verifyTurnstileToken("token", "203.0.113.1")
    ).resolves.toEqual({ success: true });

    const [, options] = fetchMock.mock.calls[0];
    const body = options?.body as URLSearchParams;
    expect(body.get("secret")).toBe("secret");
    expect(body.get("response")).toBe("token");
    expect(body.get("remoteip")).toBe("203.0.113.1");
  });

  it("returns Cloudflare error codes", async () => {
    process.env.TURNSTILE_SECRET_KEY = "secret";
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(
        JSON.stringify({ success: false, "error-codes": ["invalid-input"] }),
        { status: 200 }
      )
    );

    await expect(verifyTurnstileToken("token")).resolves.toEqual({
      success: false,
      reason: "invalid-input",
    });
  });

  it("handles a non-2xx verification response", async () => {
    process.env.TURNSTILE_SECRET_KEY = "secret";
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response("unavailable", { status: 503 })
    );

    await expect(verifyTurnstileToken("token")).resolves.toEqual({
      success: false,
      reason: "captcha_http_503",
    });
  });

  it("handles a network failure", async () => {
    process.env.TURNSTILE_SECRET_KEY = "secret";
    vi.spyOn(globalThis, "fetch").mockRejectedValue(new Error("offline"));

    await expect(verifyTurnstileToken("token")).resolves.toEqual({
      success: false,
      reason: "captcha_unreachable",
    });
  });

  it("reports whether CAPTCHA is enabled", () => {
    process.env.CAPTCHA_ENABLED = "true";
    expect(isCaptchaEnabled()).toBe(true);
    process.env.CAPTCHA_ENABLED = "false";
    expect(isCaptchaEnabled()).toBe(false);
  });
});
