/**
 * Email/SMTP preflight check.
 *
 * Usage:
 *   npm run smtp:test                 # verify the connection only
 *   npm run smtp:test -- you@gmail.com  # verify + send one real test email
 *
 * Exits non-zero with a precise, actionable diagnosis when the configuration
 * is missing, still contains the .env.example placeholder values, or Google
 * rejects the credentials — the usual Gmail failure is using the account
 * password instead of a 16-character Google App Password.
 */
import "dotenv/config";

import { isSmtpConfigured } from "../src/config/environment.js";
import {
  verifyEmailTransport,
  sendPasswordResetEmail,
} from "../src/services/email.service.js";

const PLACEHOLDERS = [
  "your-email@gmail.com",
  "your-google-app-password",
  "your-frontend.example.com",
  "your-domain.com",
  "example.com",
];

const fail = (message: string): never => {
  console.error(`\nSMTP preflight FAILED\n  ${message}\n`);
  printSetupGuide();
  process.exit(1);
};

const findPlaceholder = (label: string, value?: string): string | null => {
  const v = (value ?? "").trim().toLowerCase();
  return PLACEHOLDERS.some((p) => v.includes(p)) ? `${label}=${value}` : null;
};

const printSetupGuide = (): void => {
  console.error(
    [
      "How to configure Gmail SMTP for Auxilia:",
      "  1. Go to https://myaccount.google.com/security and enable 2-Step Verification.",
      "  2. Go to https://myaccount.google.com/apppasswords",
      "     and create an app password named 'Auxilia' (Mail).",
      "  3. Copy the 16-character password WITHOUT the spaces Google shows.",
      "  4. Set these in backend/.env (NOT .env.example):",
      "       SMTP_HOST=smtp.gmail.com",
      "       SMTP_PORT=587",
      "       SMTP_USER=<your full Gmail address>",
      "       SMTP_PASS=<the 16-character app password>",
      "       EMAIL_FROM=Auxilia <your full Gmail address>",
      "       APP_BASE_URL=http://localhost:8080",
      "",
      "  No 2FA or app password? Use a dev mail catcher instead (no credentials):",
      "    - Mailtrap (https://mailtrap.io) or Mailpit (docker run -p 8025:8025 axllent/mailpit)",
      "    - or leave SMTP_* unset: development logs the reset link to the console.",
      "",
    ].join("\n"),
  );
};

const main = async (): Promise<void> => {
  console.log("Auxilia SMTP preflight\n");

  if (!isSmtpConfigured()) {
    fail(
      "SMTP is not configured (SMTP_HOST/SMTP_USER/SMTP_PASS/EMAIL_FROM missing). " +
        "In development, password reset links are printed to the server console instead; " +
        "emails are never sent until SMTP is configured.",
    );
  }

  const placeholders = [
    findPlaceholder("SMTP_USER", process.env.SMTP_USER),
    findPlaceholder("SMTP_PASS", process.env.SMTP_PASS),
    findPlaceholder("EMAIL_FROM", process.env.EMAIL_FROM),
    findPlaceholder("APP_BASE_URL", process.env.APP_BASE_URL),
  ].filter((value): value is string => value !== null);
  if (placeholders.length > 0) {
    fail(
      `Placeholder value(s) detected — .env.example was copied without editing:\n    ${placeholders.join("\n    ")}`,
    );
  }

  console.log(`Host: ${process.env.SMTP_HOST}:${process.env.SMTP_PORT ?? 587}`);
  console.log(`User: ${process.env.SMTP_USER}`);
  console.log(`From: ${process.env.EMAIL_FROM}\n`);

  try {
    await verifyEmailTransport();
    console.log("SMTP connection verified. Credentials are valid.");
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    let hint = "See the guide below.";
    if (
      /535|BadCredentials|Username and Password not accepted/i.test(message)
    ) {
      hint =
        "Gmail rejected the credentials (535 BadCredentials). " +
        "You are almost certainly using your Gmail account password instead of a " +
        "16-character Google App Password, or the app password was pasted WITH spaces.";
    } else if (/ETIMEDOUT|ECONNREFUSED|ESOCKET|ENOTFOUND/i.test(message)) {
      hint =
        "Network problem reaching the SMTP server. Check SMTP_HOST/SMTP_PORT " +
        "(587 = STARTTLS, 465 = SSL), firewall, and VPN. Or port 587 may be blocked on your network.";
    } else if (
      /self-signed certificate|UNABLE_TO_VERIFY|certificate/i.test(message)
    ) {
      hint =
        "TLS verification failed. If you are on a corporate network with a TLS proxy, " +
        "use a dev mail catcher instead of a public relay.";
    }
    fail(`${hint}\n\n  Raw error: ${message}`);
  }

  const recipient = process.argv[2]?.trim();
  if (recipient) {
    console.log(`\nSending a test password-reset email to ${recipient} ...`);
    await sendPasswordResetEmail(
      recipient,
      "https://example.com/reset-password?token=smtp-test-token",
    );
    console.log("Test email sent. Check the inbox (and the spam folder).");
  }
  process.exit(0);
};

void main();
