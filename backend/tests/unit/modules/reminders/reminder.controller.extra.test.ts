import { beforeEach, describe, expect, it, vi } from "vitest";
import type { NextFunction, Request, Response } from "express";

const mocks = vi.hoisted(() => ({
  findAll: vi.fn(),
  create: vi.fn(),
  complete: vi.fn(),
  delete: vi.fn(),
  findPending: vi.fn(),
}));
vi.mock("../../../../src/modules/reminders/reminder.service.js", () => ({
  reminderService: mocks,
}));
import { reminderController } from "../../../../src/modules/reminders/reminder.controller.js";

const res = () =>
  ({
    status: vi.fn().mockReturnThis(),
    json: vi.fn().mockReturnThis(),
  }) as unknown as Response;

describe("reminder controller extra", () => {
  let next: NextFunction;
  beforeEach(() => {
    vi.clearAllMocks();
    next = vi.fn() as unknown as NextFunction;
  });

  it("rejects unauthenticated index", async () => {
    const r = res();
    await reminderController.index({} as Request, r, next);
    expect(r.status).toHaveBeenCalledWith(401);
  });

  it("creates reminder", async () => {
    mocks.create.mockResolvedValue({ _id: "r1" });
    const r = res();
    await reminderController.create(
      {
        userId: "u1",
        body: { message: "M", dueAt: "2026-01-01" },
      } as unknown as Request,
      r,
      next,
    );
    expect(mocks.create).toHaveBeenCalled();
    const call = mocks.create.mock.calls[0];
    expect(call[0]).toBe("u1");
    const second = call[1];
    if (typeof second === "string") {
      expect(second).toBe("M");
    } else {
      expect(second).toEqual(expect.objectContaining({ message: "M" }));
    }
    expect(r.status).toHaveBeenCalledWith(201);
  });

  it("rejects create unauthenticated", async () => {
    const r = res();
    await reminderController.create({ body: {} } as Request, r, next);
    expect(r.status).toHaveBeenCalledWith(401);
  });

  it("completes reminder", async () => {
    mocks.complete.mockResolvedValue({ _id: "r1", completed: true });
    const r = res();
    await reminderController.complete(
      { userId: "u1", params: { id: "r1" } } as unknown as Request,
      r,
      next,
    );
    expect(r.status).toHaveBeenCalledWith(200);
  });

  it("rejects complete unauthenticated", async () => {
    const r = res();
    await reminderController.complete(
      { params: { id: "r1" } } as unknown as Request,
      r,
      next,
    );
    expect(r.status).toHaveBeenCalledWith(401);
  });

  it("returns 404 when deleting missing reminder", async () => {
    mocks.delete.mockResolvedValue(null);
    const r = res();
    await reminderController.remove(
      {
        userId: "u1",
        params: { id: "x", reminderId: "x" },
      } as unknown as Request,
      r,
      next,
    );
    const status404 = r.status.mock.calls.some((c: unknown[]) => c[0] === 404);
    const next404 = next.mock.calls.some(
      (c: unknown[]) => (c[0] as any)?.status === 404,
    );
    expect(status404 || next404).toBe(true);
  });

  it("rejects delete unauthenticated", async () => {
    const r = res();
    await reminderController.remove(
      { params: { id: "r1" } } as unknown as Request,
      r,
      next,
    );
    expect(r.status).toHaveBeenCalledWith(401);
  });

  it("rejects pending unauthenticated", async () => {
    const r = res();
    await reminderController.pending({} as Request, r, next);
    expect(r.status).toHaveBeenCalledWith(401);
  });

  it("forwards index errors", async () => {
    mocks.findAll.mockRejectedValue(new Error("boom"));
    await reminderController.index(
      { userId: "u1" } as unknown as Request,
      res(),
      next,
    );
    expect(next).toHaveBeenCalled();
  });

  it("forwards create errors", async () => {
    mocks.create.mockRejectedValue(new Error("boom"));
    await reminderController.create(
      {
        userId: "u1",
        body: { message: "M", dueAt: "2026-01-01" },
      } as unknown as Request,
      res(),
      next,
    );
    expect(next).toHaveBeenCalledWith(expect.any(Error));
  });

  it("forwards complete errors", async () => {
    mocks.complete.mockRejectedValue(new Error("boom"));
    await reminderController.complete(
      { userId: "u1", params: { id: "r1" } } as unknown as Request,
      res(),
      next,
    );
    expect(next).toHaveBeenCalledWith(expect.any(Error));
  });

  it("forwards remove errors", async () => {
    mocks.delete.mockRejectedValue(new Error("boom"));
    await reminderController.remove(
      { userId: "u1", params: { id: "r1" } } as unknown as Request,
      res(),
      next,
    );
    expect(next).toHaveBeenCalledWith(expect.any(Error));
  });

  it("forwards pending errors", async () => {
    mocks.findPending.mockRejectedValue(new Error("boom"));
    await reminderController.pending(
      { userId: "u1" } as unknown as Request,
      res(),
      next,
    );
    expect(next).toHaveBeenCalledWith(expect.any(Error));
  });
});
