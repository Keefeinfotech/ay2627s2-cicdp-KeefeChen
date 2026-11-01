// Cloudflare Turnstile verification.
//
// Turnstile is Cloudflare's CAPTCHA replacement. The browser/app obtains a
// short-lived token from the widget and posts it with the login/signup request.
// The server verifies that token against Cloudflare's siteverify API using a
// secret key that must never be shipped to clients.
//
// Docs: https://developers.cloudflare.com/turnstile/get-started/server-side-validation/

const TURNSTILE_VERIFY_URL =
  "https://challenges.cloudflare.com/turnstile/v0/siteverify";

export interface CaptchaVerificationResult {
  success: boolean;
  // When false, the request should be rejected. `reason` is safe to log but
  // should not be echoed verbatim to end users.
  reason?: string;
}

/**
 * Verifies a Turnstile token with Cloudflare.
 *
 * This function never throws for expected validation failures; it returns
 * `success: false` so the calling middleware can respond with a clean 4xx.
 */
export const verifyTurnstileToken = async (
  token: string,
  remoteIp?: string
): Promise<CaptchaVerificationResult> => {
  const secret = process.env.TURNSTILE_SECRET_KEY?.trim();
  if (!secret) {
    return { success: false, reason: "captcha_not_configured" };
  }

  const body = new URLSearchParams();
  body.append("secret", secret);
  body.append("response", token);
  if (remoteIp) body.append("remoteip", remoteIp);

  try {
    const response = await fetch(TURNSTILE_VERIFY_URL, {
      method: "POST",
      body,
      signal: AbortSignal.timeout(5000),
    });

    if (!response.ok) {
      return { success: false, reason: `captcha_http_${response.status}` };
    }

    const data = (await response.json()) as {
      success?: boolean;
      "error-codes"?: string[];
    };

    if (data.success === true) {
      return { success: true };
    }

    return {
      success: false,
      reason: data["error-codes"]?.join(",") || "captcha_failed",
    };
  } catch {
    return { success: false, reason: "captcha_unreachable" };
  }
};

export const isCaptchaEnabled = (): boolean =>
  process.env.CAPTCHA_ENABLED === "true";
