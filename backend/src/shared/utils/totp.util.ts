import { generateSecret, generateURI, verifySync } from "otplib";
import QRCode from "qrcode";
import { createHash, randomBytes } from "node:crypto";

const APP_NAME = "Auxilia";

export function generateTotpSecret(): string {
  return generateSecret();
}

export function generateTotpUri(
  email: string,
  secret: string,
): string {
  return generateURI({
    issuer: APP_NAME,
    label: email,
    secret,
    period: 30,
  });
}

export async function generateTotpQrCode(
  email: string,
  secret: string,
): Promise<string> {
  const uri = generateTotpUri(email, secret);

  return QRCode.toDataURL(uri);
}

export function verifyTotpCode(
  secret: string,
  code: string,
): boolean {
  if (!/^\d{6}$/.test(code)) {
    return false;
  }

  return verifySync({
    token: code,
    secret,
    period: 30,
    // v12 `window: 1` allowed +/- one 30s step
    epochTolerance: 30,
  }).valid;
}

export function generateRecoveryCodes(
  count = 10,
): string[] {
  return Array.from({ length: count }, () =>
    randomBytes(5).toString("hex").toUpperCase(),
  );
}

export function hashRecoveryCode(code: string): string {
  return createHash("sha256")
    .update(code.trim().toUpperCase())
    .digest("hex");
}
