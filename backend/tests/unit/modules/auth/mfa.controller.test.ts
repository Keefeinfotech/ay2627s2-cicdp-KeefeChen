import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  getStatus: vi.fn(),
  beginSetup: vi.fn(),
  verifySetup: vi.fn(),
  disable: vi.fn(),
}));

vi.mock("../../../../src/modules/auth/mfa/mfa.services.js", () => ({
  mfaService: mocks,
}));

vi.mock("../../../../src/modules/auth/mfa/mfa.validation.js", () => ({
  verifyMfaSchema: { shape: { body: { parse: vi.fn((v: unknown) => v) } } },
  disableMfaSchema: { shape: { body: { parse: vi.fn((v: unknown) => v) } } },
}));

import { mfaController } from "../../../../src/modules/auth/mfa/mfa.controller.js";

const ok = () => ({ status: vi.fn().mockReturnThis(), json: vi.fn().mockReturnThis() });

describe("mfaController", () => {
  beforeEach(() => vi.clearAllMocks());

  it("returns status", async () => {
    mocks.getStatus.mockResolvedValue({ enabled: false, enabledAt: null });
    const res = ok();
    await mfaController.status({ userId: "u1" } as never, res as never, vi.fn() as never);
    expect(mocks.getStatus).toHaveBeenCalledWith("u1");
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("rejects unauthenticated status", async () => {
    const res = ok();
    await mfaController.status({} as never, res as never, vi.fn() as never);
    expect(res.status).toHaveBeenCalledWith(401);
  });

  it("starts setup", async () => {
    mocks.beginSetup.mockResolvedValue({ qrCodeDataUrl: "data:", manualEntryKey: "K", expiresAt: new Date() });
    const res = ok();
    await mfaController.setup({ userId: "u1" } as never, res as never, vi.fn() as never);
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("verifies setup", async () => {
    mocks.verifySetup.mockResolvedValue({ recoveryCodes: ["a"] });
    const res = ok();
    await mfaController.verify({ userId: "u1", body: { code: "123456" } } as never, res as never, vi.fn() as never);
    expect(mocks.verifySetup).toHaveBeenCalledWith("u1", { code: "123456" });
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("disables mfa", async () => {
    mocks.disable.mockResolvedValue(undefined);
    const res = ok();
    await mfaController.disable({ userId: "u1", body: { code: "123456" } } as never, res as never, vi.fn() as never);
    expect(mocks.disable).toHaveBeenCalledWith("u1", { code: "123456" });
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("forwards errors", async () => {
    const err = new Error("boom");
    mocks.getStatus.mockRejectedValue(err);
    const next = vi.fn();
    await mfaController.status({ userId: "u1" } as never, ok() as never, next as never);
    expect(next).toHaveBeenCalledWith(err);
  });
});
