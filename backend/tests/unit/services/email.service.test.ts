import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("nodemailer", () => ({
  default: {
    createTransport: vi.fn(() => ({
      verify: vi.fn().mockResolvedValue(undefined),
      sendMail: vi.fn().mockResolvedValue({ messageId: "1" }),
    })),
  },
}));

import { sendVerificationEmail, verifyEmailTransport } from "../../../src/services/email.service";

describe("email service", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("verifies the email transport", async () => {
    await expect(verifyEmailTransport()).resolves.toBeUndefined();
  });

  it("sends a verification email", async () => {
    await expect(
      sendVerificationEmail("ada@example.com", "https://example.com/verify")
    ).resolves.toBeUndefined();
  });
});
