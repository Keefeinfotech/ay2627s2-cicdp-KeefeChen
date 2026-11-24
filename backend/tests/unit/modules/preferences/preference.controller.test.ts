import type { NextFunction, Request, Response } from "express";
import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  get: vi.fn(),
  update: vi.fn(),
  updateNotifications: vi.fn(),
  updateAppearance: vi.fn(),
  updateTimezone: vi.fn(),
}));

vi.mock("../../../../src/modules/preferences/preference.service.js", () => ({
  preferenceService: mocks,
}));

import { preferenceController } from "../../../../src/modules/preferences/preference.controller.js";

const res = () => {
  const r: any = {};
  r.status = vi.fn().mockReturnValue(r);
  r.json = vi.fn().mockReturnValue(r);
  return r as Response;
};

describe("preferenceController", () => {
  let next: NextFunction;
  beforeEach(() => {
    vi.clearAllMocks();
    next = vi.fn() as unknown as NextFunction;
  });

  it("get handles 401, success, error", async () => {
    const r401 = res();
    await preferenceController.get({} as any, r401, next);
    expect(r401.status).toHaveBeenCalledWith(401);

    mocks.get.mockResolvedValueOnce({ theme: "dark" });
    const r = res();
    await preferenceController.get({ userId: "u1" } as any, r, next);
    expect(r.status).toHaveBeenCalledWith(200);

    mocks.get.mockRejectedValueOnce(new Error("boom"));
    await preferenceController.get({ userId: "u1" } as any, res(), next);
    expect(next).toHaveBeenCalledWith(expect.any(Error));
  });

  it("update handles 401 and success", async () => {
    const r401 = res();
    await preferenceController.update({ body: {} } as any, r401, next);
    expect(r401.status).toHaveBeenCalledWith(401);
    mocks.update.mockResolvedValueOnce({ ok: true });
    const r = res();
    await preferenceController.update({ userId: "u1", body: { a: 1 } } as any, r, next);
    expect(mocks.update).toHaveBeenCalledWith("u1", { a: 1 });
    expect(r.status).toHaveBeenCalledWith(200);
  });

  it("updateNotifications handles 401 and success", async () => {
    const r401 = res();
    await preferenceController.updateNotifications({ body: {} } as any, r401, next);
    expect(r401.status).toHaveBeenCalledWith(401);
    mocks.updateNotifications.mockResolvedValueOnce({ ok: true });
    const r = res();
    await preferenceController.updateNotifications({ userId: "u1", body: { email: true } } as any, r, next);
    expect(r.status).toHaveBeenCalledWith(200);
  });

  it("updateAppearance handles 401 and success", async () => {
    const r401 = res();
    await preferenceController.updateAppearance({ body: {} } as any, r401, next);
    expect(r401.status).toHaveBeenCalledWith(401);
    mocks.updateAppearance.mockResolvedValueOnce({ ok: true });
    const r = res();
    await preferenceController.updateAppearance({ userId: "u1", body: { theme: "dark" } } as any, r, next);
    expect(r.status).toHaveBeenCalledWith(200);
  });

  it("updateTimezone handles 401 and success", async () => {
    const r401 = res();
    await preferenceController.updateTimezone({ body: {} } as any, r401, next);
    expect(r401.status).toHaveBeenCalledWith(401);
    mocks.updateTimezone.mockResolvedValueOnce({ ok: true });
    const r = res();
    await preferenceController.updateTimezone({ userId: "u1", body: { timezone: "UTC" } } as any, r, next);
    expect(mocks.updateTimezone).toHaveBeenCalledWith("u1", "UTC");
    expect(r.status).toHaveBeenCalledWith(200);
  });
});
