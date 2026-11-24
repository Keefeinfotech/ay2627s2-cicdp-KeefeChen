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
    expect(mocks.create).toHaveBeenCalledWith("u1", "M", expect.any(Date));
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
      { userId: "u1", params: { id: "x" } } as unknown as Request,
      r,
      next,
    );
    expect(r.status).toHaveBeenCalledWith(404);
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
});
