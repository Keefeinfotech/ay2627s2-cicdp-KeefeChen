import type { NextFunction, Request, Response } from "express";
import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  interpret: vi.fn(),
  clarify: vi.fn(),
  preview: vi.fn(),
  confirm: vi.fn(),
  cancel: vi.fn(),
  suggestions: vi.fn(),
}));

vi.mock("../../../../src/modules/assistant/assistant.service.js", () => ({
  assistantService: mocks,
}));

import { assistantController } from "../../../../src/modules/assistant/assistant.controller.js";

const res = () => {
  const r: any = {};
  r.status = vi.fn().mockReturnValue(r);
  r.json = vi.fn().mockReturnValue(r);
  return r as Response;
};

describe("assistantController", () => {
  let next: NextFunction;
  beforeEach(() => {
    vi.clearAllMocks();
    next = vi.fn() as unknown as NextFunction;
  });

  const cases: Array<[keyof typeof assistantController, string, number]> = [
    ["interpret", "interpret", 200],
    ["clarify", "clarify", 200],
    ["preview", "preview", 200],
    ["confirm", "confirm", 201],
    ["cancel", "cancel", 200],
  ];

  for (const [method, serviceMethod, status] of cases) {
    it(`${String(method)} handles 401, success, and error`, async () => {
      const r401 = res();
      await (assistantController[method] as any)({ body: {} } as any, r401, next);
      expect(r401.status).toHaveBeenCalledWith(401);

      (mocks as any)[serviceMethod].mockResolvedValueOnce({ ok: true });
      const r = res();
      await (assistantController[method] as any)({ userId: "u1", body: { a: 1 } } as any, r, next);
      expect((mocks as any)[serviceMethod]).toHaveBeenCalledWith("u1", { a: 1 });
      expect(r.status).toHaveBeenCalledWith(status);

      (mocks as any)[serviceMethod].mockRejectedValueOnce(new Error("boom"));
      await (assistantController[method] as any)({ userId: "u1", body: {} } as any, res(), next);
      expect(next).toHaveBeenCalledWith(expect.any(Error));
    });
  }

  it("suggestions handles 401, success, and error", async () => {
    const r401 = res();
    await assistantController.suggestions({} as any, r401, next);
    expect(r401.status).toHaveBeenCalledWith(401);

    mocks.suggestions.mockResolvedValueOnce([{ id: "s1" }]);
    const r = res();
    await assistantController.suggestions({ userId: "u1" } as any, r, next);
    expect(mocks.suggestions).toHaveBeenCalledWith("u1");
    expect(r.status).toHaveBeenCalledWith(200);

    mocks.suggestions.mockRejectedValueOnce(new Error("boom"));
    await assistantController.suggestions({ userId: "u1" } as any, res(), next);
    expect(next).toHaveBeenCalledWith(expect.any(Error));
  });
});
