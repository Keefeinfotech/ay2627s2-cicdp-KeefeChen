import nodemailer from "nodemailer";

const smtpPort = Number(process.env.SMTP_PORT || 587);

const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST,
  port: smtpPort,
  secure: smtpPort === 465,
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
});

export async function verifyEmailTransport(): Promise<void> {
  await transporter.verify();
}

export async function sendVerificationEmail(
  recipient: string,
  verificationUrl: string
): Promise<void> {
  await transporter.sendMail({
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
          <a href="${verificationUrl}"
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