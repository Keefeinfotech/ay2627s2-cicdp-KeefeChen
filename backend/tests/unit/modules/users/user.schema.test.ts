import { describe, expect, it } from "vitest";
import { userSchema } from "../../../../src/modules/users/user.schema.js";

describe("userSchema", () => {
  it("defines expected paths and defaults", () => {
    expect(userSchema.path("email")).toBeDefined();
    expect(userSchema.path("passwordHash")).toBeDefined();
    expect(userSchema.path("role")).toBeDefined();
    expect(userSchema.path("status")).toBeDefined();
    expect(userSchema.path("mfaEnabled")).toBeDefined();
  });

  it("toJSON transform removes sensitive fields", () => {
    const transform = (userSchema as any).options.toJSON.transform;
    const result = transform({}, {
      passwordHash: "x",
      emailVerificationTokenHash: "x",
      mfaSecretEncrypted: "x",
      mfaPendingSecretEncrypted: "x",
      mfaRecoveryCodeHashes: ["x"],
      mfaLastUsedStep: 1,
      passwordResetTokenHash: "x",
      failedLoginAttempts: 2,
      lockoutUntil: new Date(),
      email: "a@b.com",
    });
    expect(result.passwordHash).toBeUndefined();
    expect(result.emailVerificationTokenHash).toBeUndefined();
    expect(result.mfaSecretEncrypted).toBeUndefined();
    expect(result.mfaRecoveryCodeHashes).toBeUndefined();
    expect(result.passwordResetTokenHash).toBeUndefined();
    expect(result.failedLoginAttempts).toBeUndefined();
    expect(result.lockoutUntil).toBeUndefined();
    expect(result.email).toBe("a@b.com");
  });

  it("has expected indexes", () => {
    const indexes = userSchema.indexes();
    expect(indexes.length).toBeGreaterThanOrEqual(4);
  });
});
