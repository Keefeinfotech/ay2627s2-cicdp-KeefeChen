import {
  createGuardrails,
  generateSecret,
  generateURI,
  verifySync,
} from "otplib";
import QRCode from "qrcode";
import { createHash, randomBytes } from "node:crypto";

const APP_NAME = "Auxilia";

// otplib v13 expresses the verification window in seconds rather than
// 30-second steps. The previous v12 config used `window: 1`, which accepts
// tokens from one step before or after the current one (±30 seconds).
const TOTP_EPOCH_TOLERANCE_SECONDS = 30;

// otplib v12 generated 10-byte base32 secrets by default, while v13 requires
// at least 16 bytes. Relax the minimum only for verification so users enrolled
// before the upgrade keep working; newly generated secrets use the v13 default
// of 20 bytes.
const LEGACY_SECRET_GUARDRAILS = createGuardrails({
  MIN_SECRET_BYTES: 10,
});

export function generateTotpSecret(): string {
  return generateSecret();
}

export function generateTotpUri(email: string, secret: string): string {
  return generateURI({
    issuer: APP_NAME,
    label: email,
    secret,
  });
}

export async function generateTotpQrCode(
  email: string,
  secret: string,
): Promise<string> {
  const uri = generateTotpUri(email, secret);

  return QRCode.toDataURL(uri);
}

export function verifyTotpCode(secret: string, code: string): boolean {
  if (!/^\d{6}$/.test(code)) {
    return false;
  }

  try {
    return verifySync({
      secret,
      token: code,
      epochTolerance: TOTP_EPOCH_TOLERANCE_SECONDS,
      guardrails: LEGACY_SECRET_GUARDRAILS,
    }).valid;
  } catch {
    // v13 throws on malformed secrets; v12 simply returned false. Keep the
    // old fail-closed behaviour for corrupted or invalid stored secrets.
    return false;
  }
}

export function generateRecoveryCodes(count = 10): string[] {
  return Array.from({ length: count }, () =>
    randomBytes(5).toString("hex").toUpperCase(),
  );
}

export function hashRecoveryCode(code: string): string {
  return createHash("sha256").update(code.trim().toUpperCase()).digest("hex");
}
