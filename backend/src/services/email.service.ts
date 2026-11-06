import nodemailer, { type Transporter } from "nodemailer";

import { isSmtpConfigured } from "../config/environment.js";

const smtpPort = Number(process.env.SMTP_PORT || 587);

let transporter: Transporter | null = null;

const getTransporter = (): Transporter => {
  if (!transporter) {
    transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: smtpPort,
      secure: smtpPort === 465,
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
      },
    });
  }
  return transporter;
};

const escapeHtml = (value: string): string =>
  value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");

export async function verifyEmailTransport(): Promise<void> {
  await getTransporter().verify();
}

export async function sendVerificationEmail(
  recipient: string,
  verificationUrl: string
): Promise<void> {
  const safeUrl = escapeHtml(verificationUrl);
  await getTransporter().sendMail({
    from: process.env.EMAIL_FROM,
    to: recipient,
    subject: "Verify your Auxilia email address",

    text: [
      "Welcome to Auxilia.",
      "",
      "Please verify your email address using this link:",
      verificationUrl,
      "",
      "This link expires in 30 minutes.",
      "If you did not create this account, you can ignore this email.",
    ].join("\n"),

    html: `
      <div style="font-family: Arial, sans-serif; max-width: 520px;">
        <h2>Welcome to Auxilia</h2>
        <p>Please verify your email address to continue.</p>
        <p>
          <a href="${safeUrl}"
             style="display:inline-block;padding:12px 20px;
                    background:#2563eb;color:#fff;
                    text-decoration:none;border-radius:6px;">
            Verify email address
          </a>
        </p>
        <p>This link expires in 30 minutes.</p>
        <p>If you did not create this account, ignore this email.</p>
      </div>
    `,
  });
}

/**
 * Delivers a group invitation. Returns false when SMTP is not configured so
 * the caller can fall back to manual delivery without failing the request.
 */
export async function sendGroupInvitationEmail(input: {
  recipient: string;
  acceptUrl: string;
  groupName: string;
  role: string;
}): Promise<boolean> {
  if (!isSmtpConfigured()) {
    return false;
  }

  const safeAcceptUrl = escapeHtml(input.acceptUrl);
  const safeGroupName = escapeHtml(input.groupName);
  const safeRole = escapeHtml(input.role.toLowerCase());

  await getTransporter().sendMail({
    from: process.env.EMAIL_FROM,
    to: input.recipient,
    subject: `You're invited to join ${input.groupName} on Auxilia`,
    text: [
      `You have been invited to join "${input.groupName}" as a ${input.role.toLowerCase()}.`,
      "",
      "Accept the invitation with this link:",
      input.acceptUrl,
      "",
      "This link expires in 7 days and can only be used by this email address.",
      "If you were not expecting this invitation, you can ignore this email.",
    ].join("\n"),
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 520px;">
        <h2>Join ${safeGroupName}</h2>
        <p>
          You have been invited to join <strong>${safeGroupName}</strong>
          as a ${safeRole}.
        </p>
        <p>
          <a href="${safeAcceptUrl}"
             style="display:inline-block;padding:12px 20px;
                    background:#2563eb;color:#fff;
                    text-decoration:none;border-radius:6px;">
            Accept invitation
          </a>
        </p>
        <p>This link expires in 7 days and can only be used by this email address.</p>
        <p>If you were not expecting this invitation, you can ignore this email.</p>
      </div>
    `,
  });

  return true;
}
