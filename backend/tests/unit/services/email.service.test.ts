import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  sendMail: vi.fn(),
  verify: vi.fn(),
  createTransport: vi.fn(),
  isSmtpConfigured: vi.fn(),
  warn: vi.fn(),
}));

vi.mock("nodemailer", () => ({
  default: { createTransport: mocks.createTransport },
}));

vi.mock("../../../src/config/environment.js", () => ({
  isSmtpConfigured: mocks.isSmtpConfigured,
}));

vi.mock("../../../src/config/logger.js", () => ({
  default: { warn: mocks.warn, info: vi.fn(), error: vi.fn() },
}));

describe("email.service", () => {
  beforeEach(() => {
    vi.resetModules();
    vi.clearAllMocks();
    mocks.createTransport.mockReturnValue({ sendMail: mocks.sendMail, verify: mocks.verify });
    process.env.EMAIL_FROM = "from@test.com";
  });

  it("sendPasswordResetEmail returns false when smtp not configured", async () => {
    mocks.isSmtpConfigured.mockReturnValue(false);
    const { sendPasswordResetEmail } = await import("../../../src/services/email.service.js");
    await expect(sendPasswordResetEmail("a@b.com", "http://reset")).resolves.toBe(false);
    expect(mocks.warn).toHaveBeenCalled();
  });

  it("sendPasswordResetEmail sends when configured", async () => {
    mocks.isSmtpConfigured.mockReturnValue(true);
    mocks.sendMail.mockResolvedValue({});
    const { sendPasswordResetEmail } = await import("../../../src/services/email.service.js");
    await expect(sendPasswordResetEmail("a@b.com", "http://reset")).resolves.toBe(true);
    expect(mocks.sendMail).toHaveBeenCalledWith(expect.objectContaining({ to: "a@b.com", subject: "Reset your Auxilia password" }));
  });

  it("verifyEmailTransport delegates to transporter.verify", async () => {
    mocks.verify.mockResolvedValue(true);
    const { verifyEmailTransport } = await import("../../../src/services/email.service.js");
    await verifyEmailTransport();
    expect(mocks.verify).toHaveBeenCalled();
  });

  it("sendVerificationEmail sends mail", async () => {
    mocks.sendMail.mockResolvedValue({});
    const { sendVerificationEmail } = await import("../../../src/services/email.service.js");
    await sendVerificationEmail("a@b.com", "http://verify");
    expect(mocks.sendMail).toHaveBeenCalledWith(expect.objectContaining({ to: "a@b.com", subject: "Verify your Auxilia email address" }));
  });

  it("sendGroupInvitationEmail returns false when smtp not configured", async () => {
    mocks.isSmtpConfigured.mockReturnValue(false);
    const { sendGroupInvitationEmail } = await import("../../../src/services/email.service.js");
    await expect(sendGroupInvitationEmail({ recipient: "a@b.com", acceptUrl: "http://acc", groupName: "G", role: "Member" })).resolves.toBe(false);
  });

  it("sendGroupInvitationEmail sends when configured", async () => {
    mocks.isSmtpConfigured.mockReturnValue(true);
    mocks.sendMail.mockResolvedValue({});
    const { sendGroupInvitationEmail } = await import("../../../src/services/email.service.js");
    await expect(sendGroupInvitationEmail({ recipient: "a@b.com", acceptUrl: "http://acc", groupName: "G", role: "Member" })).resolves.toBe(true);
    expect(mocks.sendMail).toHaveBeenCalledWith(expect.objectContaining({ to: "a@b.com" }));
  });
});
