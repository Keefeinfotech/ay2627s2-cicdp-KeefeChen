import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  encryptSecret: vi.fn((v: string) => `enc:${v}`),
  decryptSecret: vi.fn((v: string) => v.replace("enc:", "")),
  generateRecoveryCodes: vi.fn(() => ["r1", "r2"]),
  generateTotpQrCode: vi.fn(async () => "data:qr"),
  generateTotpSecret: vi.fn(() => "SECRET"),
  hashRecoveryCode: vi.fn((v: string) => `h:${v}`),
  verifyTotpCode: vi.fn(() => true),
  findUserById: vi.fn(),
  findUserByIdWithMfaSecrets: vi.fn(),
  saveUser: vi.fn(async (u: unknown) => u),
}));

vi.mock("../../../../src/services/encryption.service.js", () => ({
  encryptSecret: mocks.encryptSecret,
  decryptSecret: mocks.decryptSecret,
}));

vi.mock("../../../../src/shared/utils/totp.util.js", () => ({
  generateRecoveryCodes: mocks.generateRecoveryCodes,
  generateTotpQrCode: mocks.generateTotpQrCode,
  generateTotpSecret: mocks.generateTotpSecret,
  hashRecoveryCode: mocks.hashRecoveryCode,
  verifyTotpCode: mocks.verifyTotpCode,
}));

vi.mock("../../../../src/modules/auth/auth.repository.js", () => ({
  findUserById: mocks.findUserById,
  findUserByIdWithMfaSecrets: mocks.findUserByIdWithMfaSecrets,
  saveUser: mocks.saveUser,
}));

import { mfaService } from "../../../../src/modules/auth/mfa/mfa.services.js";

const baseUser = () => ({
  id: "u1",
  email: "u@test.com",
  mfaEnabled: false,
  mfaEnabledAt: null,
  mfaPendingSecretEncrypted: null,
  mfaPendingExpiresAt: null,
  mfaSecretEncrypted: null,
  mfaRecoveryCodeHashes: [],
  mfaLastUsedStep: null,
});

describe("mfaService", () => {
  beforeEach(() => vi.clearAllMocks());

  it("returns status for existing user", async () => {
    mocks.findUserById.mockResolvedValue({ mfaEnabled: true, mfaEnabledAt: new Date("2026-01-01") });
    const res = await mfaService.getStatus("u1");
    expect(res.enabled).toBe(true);
  });

  it("throws when status user missing", async () => {
    mocks.findUserById.mockResolvedValue(null);
    await expect(mfaService.getStatus("u1")).rejects.toMatchObject({ code: "USER_NOT_FOUND" });
  });

  it("begins setup and stores pending secret", async () => {
    const user = baseUser();
    mocks.findUserByIdWithMfaSecrets.mockResolvedValue(user);
    const res = await mfaService.beginSetup("u1");
    expect(mocks.generateTotpSecret).toHaveBeenCalled();
    expect(mocks.saveUser).toHaveBeenCalled();
    expect(res.manualEntryKey).toBe("SECRET");
    expect(res.qrCodeDataUrl).toBe("data:qr");
  });

  it("rejects beginSetup when user missing", async () => {
    mocks.findUserByIdWithMfaSecrets.mockResolvedValue(null);
    await expect(mfaService.beginSetup("u1")).rejects.toMatchObject({ code: "USER_NOT_FOUND" });
  });

  it("rejects beginSetup when already enabled", async () => {
    mocks.findUserByIdWithMfaSecrets.mockResolvedValue({ ...baseUser(), mfaEnabled: true });
    await expect(mfaService.beginSetup("u1")).rejects.toMatchObject({ code: "MFA_ALREADY_ENABLED" });
  });

  it("verifies setup and enables MFA", async () => {
    const user = { ...baseUser(), mfaPendingSecretEncrypted: "enc:SECRET", mfaPendingExpiresAt: new Date(Date.now() + 60000) };
    mocks.findUserByIdWithMfaSecrets.mockResolvedValue(user);
    const res = await mfaService.verifySetup("u1", { code: "123456" } as never);
    expect(res.recoveryCodes).toEqual(["r1", "r2"]);
    expect(user.mfaEnabled).toBe(true);
    expect(mocks.saveUser).toHaveBeenCalled();
  });

  it("rejects verify when no setup in progress", async () => {
    mocks.findUserByIdWithMfaSecrets.mockResolvedValue(baseUser());
    await expect(mfaService.verifySetup("u1", { code: "123456" } as never)).rejects.toMatchObject({ code: "MFA_SETUP_NOT_STARTED" });
  });

  it("rejects expired setup", async () => {
    const user = { ...baseUser(), mfaPendingSecretEncrypted: "enc:SECRET", mfaPendingExpiresAt: new Date(Date.now() - 1000) };
    mocks.findUserByIdWithMfaSecrets.mockResolvedValue(user);
    await expect(mfaService.verifySetup("u1", { code: "123456" } as never)).rejects.toMatchObject({ code: "MFA_SETUP_EXPIRED" });
  });

  it("rejects invalid verification code", async () => {
    const user = { ...baseUser(), mfaPendingSecretEncrypted: "enc:SECRET", mfaPendingExpiresAt: new Date(Date.now() + 60000) };
    mocks.findUserByIdWithMfaSecrets.mockResolvedValue(user);
    mocks.verifyTotpCode.mockReturnValueOnce(false);
    await expect(mfaService.verifySetup("u1", { code: "000000" } as never)).rejects.toMatchObject({ code: "INVALID_MFA_CODE" });
  });

  it("disables MFA with valid totp code", async () => {
    const user = { ...baseUser(), mfaEnabled: true, mfaSecretEncrypted: "enc:SECRET", mfaRecoveryCodeHashes: ["h:r1"] };
    mocks.findUserByIdWithMfaSecrets.mockResolvedValue(user);
    mocks.verifyTotpCode.mockReturnValueOnce(true);
    await mfaService.disable("u1", { code: "123456" } as never);
    expect(user.mfaEnabled).toBe(false);
    expect(user.mfaSecretEncrypted).toBeNull();
  });

  it("disables MFA with recovery code", async () => {
    const user = { ...baseUser(), mfaEnabled: true, mfaSecretEncrypted: "enc:SECRET", mfaRecoveryCodeHashes: ["h:recovery"] };
    mocks.findUserByIdWithMfaSecrets.mockResolvedValue(user);
    mocks.verifyTotpCode.mockReturnValueOnce(false);
    await mfaService.disable("u1", { code: "recovery" } as never);
    expect(user.mfaEnabled).toBe(false);
  });

  it("rejects disable when not enabled", async () => {
    mocks.findUserByIdWithMfaSecrets.mockResolvedValue(baseUser());
    await expect(mfaService.disable("u1", { code: "123456" } as never)).rejects.toMatchObject({ code: "MFA_NOT_ENABLED" });
  });

  it("rejects disable with invalid code", async () => {
    const user = { ...baseUser(), mfaEnabled: true, mfaSecretEncrypted: "enc:SECRET", mfaRecoveryCodeHashes: [] };
    mocks.findUserByIdWithMfaSecrets.mockResolvedValue(user);
    mocks.verifyTotpCode.mockReturnValueOnce(false);
    await expect(mfaService.disable("u1", { code: "bad" } as never)).rejects.toMatchObject({ code: "INVALID_MFA_CODE" });
  });
});
