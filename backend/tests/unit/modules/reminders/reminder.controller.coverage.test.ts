import type { NextFunction, Request, Response } from "express";
import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  findAll: vi.fn(),
  findById: vi.fn(),
  findByTask: vi.fn(),
  create: vi.fn(),
  update: vi.fn(),
  upcoming: vi.fn(),
  complete: vi.fn(),
  delete: vi.fn(),
  findPending: vi.fn(),
  setEnabled: vi.fn(),
  getTask: vi.fn(),
}));

vi.mock("../../../../src/modules/reminders/reminder.service.js", () => ({
  reminderService: mocks,
}));

vi.mock("../../../../src/modules/tasks/task.service.js", () => ({
  taskService: { getTask: mocks.getTask },
}));

import { reminderController } from "../../../../src/modules/reminders/reminder.controller.js";

const res = () => {
  const r: any = {};
  r.status = vi.fn().mockReturnValue(r);
  r.json = vi.fn().mockReturnValue(r);
  r.send = vi.fn().mockReturnValue(r);
  return r as Response;
};

describe("reminder controller coverage", () => {
  let next: NextFunction;
  beforeEach(() => {
    vi.clearAllMocks();
    next = vi.fn() as unknown as NextFunction;
    mocks.getTask.mockResolvedValue({ _id: "task-1" });
  });

  it("show returns reminder or 404", async () => {
    mocks.findById.mockResolvedValueOnce({ _id: "r1" });
    const r = res();
    await reminderController.show({ userId: "u1", params: { reminderId: "r1" } } as any, r, next);
    expect(r.status).toHaveBeenCalledWith(200);

    mocks.findById.mockResolvedValueOnce(null);
    await reminderController.show({ userId: "u1", params: { reminderId: "missing" } } as any, res(), next);
    expect(next).toHaveBeenCalledWith(expect.objectContaining({ code: "REMINDER_NOT_FOUND" }));
  });

  it("show rejects unauthenticated", async () => {
    const r = res();
    await reminderController.show({ params: { reminderId: "r1" } } as any, r, next);
    expect(r.status).toHaveBeenCalledWith(401);
  });

  it("update checks task ownership, updates, and handles 404", async () => {
    mocks.update.mockResolvedValueOnce({ _id: "r1" });
    const r = res();
    await reminderController.update(
      { userId: "u1", params: { reminderId: "r1" }, body: { taskId: "t1", message: "m" } } as any,
      r,
      next,
    );
    expect(mocks.getTask).toHaveBeenCalledWith("u1", "t1");
    expect(r.status).toHaveBeenCalledWith(200);

    mocks.update.mockResolvedValueOnce(null);
    await reminderController.update(
      { userId: "u1", params: { reminderId: "r1" }, body: {} } as any,
      res(),
      next,
    );
    expect(next).toHaveBeenCalledWith(expect.objectContaining({ code: "REMINDER_NOT_FOUND" }));
  });

  it("update rejects unauthenticated", async () => {
    const r = res();
    await reminderController.update({ params: { reminderId: "r1" }, body: {} } as any, r, next);
    expect(r.status).toHaveBeenCalledWith(401);
  });

  it("status handles completed true/false, enabled, missing fields, and 404", async () => {
    mocks.complete.mockResolvedValue({ _id: "r1", completed: true });
    let r = res();
    await reminderController.status(
      { userId: "u1", params: { reminderId: "r1" }, body: { completed: true } } as any,
      r,
      next,
    );
    expect(mocks.complete).toHaveBeenCalled();

    mocks.update.mockResolvedValue({ _id: "r1", completed: false });
    r = res();
    await reminderController.status(
      { userId: "u1", params: { reminderId: "r1" }, body: { completed: false } } as any,
      r,
      next,
    );
    expect(mocks.update).toHaveBeenCalledWith("r1", "u1", { completed: false });

    mocks.setEnabled.mockResolvedValue({ _id: "r1", enabled: false });
    r = res();
    await reminderController.status(
      { userId: "u1", params: { reminderId: "r1" }, body: { enabled: false } } as any,
      r,
      next,
    );
    expect(mocks.setEnabled).toHaveBeenCalledWith("r1", "u1", false);

    r = res();
    await reminderController.status(
      { userId: "u1", params: { reminderId: "r1" }, body: {} } as any,
      r,
      next,
    );
    expect(r.status).toHaveBeenCalledWith(400);

    mocks.complete.mockResolvedValueOnce(null);
    await reminderController.status(
      { userId: "u1", params: { reminderId: "r1" }, body: { completed: true } } as any,
      res(),
      next,
    );
    expect(next).toHaveBeenCalledWith(expect.objectContaining({ code: "REMINDER_NOT_FOUND" }));
  });

  it("status rejects unauthenticated", async () => {
    const r = res();
    await reminderController.status({ params: { reminderId: "r1" }, body: {} } as any, r, next);
    expect(r.status).toHaveBeenCalledWith(401);
  });

  it("complete uses id fallback and handles unauthenticated", async () => {
    mocks.complete.mockResolvedValue({ _id: "r1" });
    const r = res();
    await reminderController.complete({ userId: "u1", params: { id: "r1" } } as any, r, next);
    expect(mocks.complete).toHaveBeenCalledWith("r1", "u1");

    const r401 = res();
    await reminderController.complete({ params: { id: "r1" } } as any, r401, next);
    expect(r401.status).toHaveBeenCalledWith(401);
  });

  it("remove uses id fallback and handles unauthenticated", async () => {
    mocks.delete.mockResolvedValue({ _id: "r1" });
    const r = res();
    await reminderController.remove({ userId: "u1", params: { id: "r1" } } as any, r, next);
    expect(r.status).toHaveBeenCalledWith(204);

    const r401 = res();
    await reminderController.remove({ params: { id: "r1" } } as any, r401, next);
    expect(r401.status).toHaveBeenCalledWith(401);
  });

  it("listForTask and createForTask check ownership and validate", async () => {
    mocks.findByTask.mockResolvedValue([{ _id: "r1" }]);
    let r = res();
    await reminderController.listForTask({ userId: "u1", params: { taskId: "t1" } } as any, r, next);
    expect(mocks.getTask).toHaveBeenCalledWith("u1", "t1");
    expect(r.status).toHaveBeenCalledWith(200);

    r = res();
    await reminderController.createForTask(
      { userId: "u1", params: { taskId: "t1" }, body: { message: "M", dueAt: "2026-01-01" } } as any,
      r,
      next,
    );
    expect(r.status).toHaveBeenCalledWith(201);

    r = res();
    await reminderController.createForTask(
      { userId: "u1", params: { taskId: "t1" }, body: {} } as any,
      r,
      next,
    );
    expect(r.status).toHaveBeenCalledWith(400);
  });

  it("listForTask/createForTask reject unauthenticated", async () => {
    let r = res();
    await reminderController.listForTask({ params: { taskId: "t1" } } as any, r, next);
    expect(r.status).toHaveBeenCalledWith(401);
    r = res();
    await reminderController.createForTask({ params: { taskId: "t1" }, body: {} } as any, r, next);
    expect(r.status).toHaveBeenCalledWith(401);
  });

  it("create creates with taskId ownership check", async () => {
    mocks.create.mockResolvedValue({ _id: "r1" });
    const r = res();
    await reminderController.create(
      { userId: "u1", body: { message: "M", dueAt: "2026-01-01", taskId: "t1" } } as any,
      r,
      next,
    );
    expect(mocks.getTask).toHaveBeenCalledWith("u1", "t1");
    expect(r.status).toHaveBeenCalledWith(201);
  });
});
