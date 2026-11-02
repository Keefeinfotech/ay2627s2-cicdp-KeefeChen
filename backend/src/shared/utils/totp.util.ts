import { authenticator } from "otplib";
import QRCode from "qrcode";
import { createHash, randomBytes } from "node:crypto";

const APP_NAME = "Auxilia";

authenticator.options = {
  step: 30,
  window: 1,
};

export function generateTotpSecret(): string {
  return authenticator.generateSecret();
}

export function generateTotpUri(
  email: string,
  secret: string,
): string {
  return authenticator.keyuri(
    email,
    APP_NAME,
    secret,
  );
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

  return authenticator.verify({
    token: code,
    secret,
  });
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