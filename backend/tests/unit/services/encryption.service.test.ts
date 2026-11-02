import { describe, expect, it } from "vitest";

import { decryptSecret, encryptSecret } from "../../../src/services/encryption.service";

describe("encryption service", () => {
  const KEY = "0".repeat(64);

  beforeEach(() => {
    process.env.MFA_ENCRYPTION_KEY = KEY;
  });

  it("throws when the encryption key is missing", () => {
    delete process.env.MFA_ENCRYPTION_KEY;
    expect(() => encryptSecret("secret")).toThrow();
  });

  it("encrypts and decrypts a secret", () => {
    const encrypted = encryptSecret("top-secret");
    const decrypted = decryptSecret(encrypted);

    expect(decrypted).toBe("top-secret");
  });

  it("throws when decrypting an invalid payload", () => {
    process.env.MFA_ENCRYPTION_KEY = KEY;
    expect(() => decryptSecret("invalid")).toThrow();
  });
});
