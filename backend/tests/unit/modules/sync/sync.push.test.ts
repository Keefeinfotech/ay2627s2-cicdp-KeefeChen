import { beforeEach, describe, expect, it, vi } from "vitest";

import type { ISyncRepository } from "../../../../src/modules/sync/sync.repository.js";

const mocks = vi.hoisted(() => ({
  findOne: vi.fn(),
  findOneAndUpdate: vi.fn(),
  create: vi.fn(),
  createTask: vi.fn(),
  updateTask: vi.fn(),
  deleteTask: vi.fn(),
  getTask: vi.fn(),
}));

vi.mock("../../../../src/modules/sync/sync-operation.model.js", () => ({
  SyncOperation: {
    findOne: mocks.findOne,
    findOneAndUpdate: mocks.findOneAndUpdate,
    create: mocks.create,
  },
}));

vi.mock("../../../../src/modules/tasks/task.service.js", () => ({
  taskService: {
    createTask: mocks.createTask,
    updateTask: mocks.updateTask,
    deleteTask: mocks.deleteTask,
    getTask: mocks.getTask,
  },
}));

import { SyncService } from "../../../../src/modules/sync/sync.service.js";
import { AppError } from "../../../../src/shared/utils/AppError.js";

const leanRow = (value: unknown) => ({
  lean: vi.fn().mockResolvedValue(value),
});

const createOperation = {
  opId: "op-1",
  type: "task.create" as const,
  payload: { title: "Revise calculus" },
};

describe("sync push idempotency and retry", () => {
  const service = new SyncService({} as ISyncRepository);

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("replays an applied operation without re-applying it", async () => {
    mocks.findOne.mockReturnValue(
      leanRow({
        userId: "user-1",
        opId: "op-1",
        status: "applied",
        detail: { taskId: "task-1" },
        updatedAt: new Date("2026-11-01T00:00:00Z"),
      }),
    );

    const result = await service.push("user-1", [createOperation]);

    expect(result.results[0]).toMatchObject({
      opId: "op-1",
      status: "applied",
      replayed: true,
    });
    expect(mocks.createTask).not.toHaveBeenCalled();
    expect(mocks.create).not.toHaveBeenCalled();
  });

  it("retries a failed operation with the same opId and updates its ledger result", async () => {
    const updatedAt = new Date("2026-11-01T00:00:00Z");
    mocks.findOne.mockReturnValue(
      leanRow({
        userId: "user-1",
        opId: "op-1",
        status: "failed",
        detail: { code: "TASK_NOT_FOUND" },
        updatedAt,
      }),
    );
    mocks.createTask.mockResolvedValue({
      _id: "task-2",
      updatedAt: new Date("2026-11-02T00:00:00Z"),
    });
    mocks.findOneAndUpdate.mockReturnValue(
      leanRow({ status: "applied", detail: { taskId: "task-2" } }),
    );

    const result = await service.push("user-1", [createOperation]);

    expect(mocks.createTask).toHaveBeenCalledOnce();
    expect(mocks.findOneAndUpdate).toHaveBeenCalledWith(
      {
        userId: { $eq: "user-1" },
        opId: { $eq: "op-1" },
        status: "failed",
        updatedAt,
      },
      { $set: { status: "applied", detail: { taskId: "task-2" } } },
      { new: true },
    );
    expect(result.results[0]).toMatchObject({
      status: "applied",
      replayed: false,
      retried: true,
    });
  });

  it("keeps a conflict terminal until the client resolves it", async () => {
    mocks.findOne.mockReturnValue(
      leanRow({
        userId: "user-1",
        opId: "op-1",
        status: "conflict",
        detail: { code: "TASK_CONFLICT" },
        updatedAt: new Date("2026-11-01T00:00:00Z"),
      }),
    );

    const result = await service.push("user-1", [createOperation]);

    expect(result.results[0]).toMatchObject({
      status: "conflict",
      replayed: true,
    });
    expect(mocks.updateTask).not.toHaveBeenCalled();
    expect(mocks.createTask).not.toHaveBeenCalled();
  });

  it("creates a ledger entry for a new operation", async () => {
    mocks.findOne.mockReturnValue(leanRow(null));
    mocks.createTask.mockResolvedValue({
      _id: "task-3",
      updatedAt: new Date("2026-11-02T00:00:00Z"),
    });

    const result = await service.push("user-1", [createOperation]);

    expect(mocks.create).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: "user-1",
        opId: "op-1",
        status: "applied",
      }),
    );
    expect(result.results[0]).toMatchObject({
      status: "applied",
      replayed: false,
    });
    expect(result.results[0].retried).toBeUndefined();
  });

  it("applies update and delete operations", async () => {
    mocks.findOne.mockReturnValue(leanRow(null));
    mocks.updateTask.mockResolvedValue({ _id: "task-1", updatedAt: new Date("2026-11-02T00:00:00Z") });
    mocks.deleteTask.mockResolvedValue(undefined);

    const result = await service.push("user-1", [
      { opId: "op-u", type: "task.update", payload: { taskId: "task-1", title: "New" } },
      { opId: "op-d", type: "task.delete", payload: { taskId: "task-1" } },
    ]);

    expect(result.results[0]).toMatchObject({ status: "applied", detail: { taskId: "task-1" } });
    expect(result.results[1]).toMatchObject({ status: "applied", detail: { taskId: "task-1" } });
  });

  it("maps TASK_CONFLICT to conflict and 404 AppError to failed", async () => {
    mocks.findOne.mockReturnValue(leanRow(null));
    mocks.updateTask.mockRejectedValueOnce(new AppError(409, "TASK_CONFLICT", "conflict"));
    mocks.deleteTask.mockRejectedValueOnce(new AppError(404, "TASK_NOT_FOUND", "missing"));

    const result = await service.push("user-1", [
      { opId: "op-c", type: "task.update", payload: { taskId: "t1", title: "x" } },
      { opId: "op-n", type: "task.delete", payload: { taskId: "t2" } },
    ]);

    expect(result.results[0]).toMatchObject({ status: "conflict", detail: { code: "TASK_CONFLICT" } });
    expect(result.results[1]).toMatchObject({ status: "failed", detail: { code: "TASK_NOT_FOUND" } });
  });

  it("rethrows unknown errors from applyOperation", async () => {
    mocks.findOne.mockReturnValue(leanRow(null));
    mocks.createTask.mockRejectedValueOnce(new Error("db down"));
    await expect(service.push("user-1", [createOperation])).rejects.toThrow("db down");
  });

  it("handles retry CAS miss by returning stored result or throwing when lost", async () => {
    const updatedAt = new Date("2026-11-01T00:00:00Z");
    mocks.findOne
      .mockReturnValueOnce(leanRow({ status: "failed", detail: {}, updatedAt }))
      .mockReturnValueOnce(leanRow({ status: "applied", detail: { taskId: "t1" } }));
    mocks.createTask.mockResolvedValue({ _id: "t1", updatedAt: new Date() });
    mocks.findOneAndUpdate.mockReturnValue(leanRow(null));

    const result = await service.push("user-1", [createOperation]);
    expect(result.results[0]).toMatchObject({ status: "applied", replayed: true });

    mocks.findOne
      .mockReturnValueOnce(leanRow({ status: "failed", detail: {}, updatedAt }))
      .mockReturnValueOnce(leanRow(null));
    mocks.createTask.mockResolvedValue({ _id: "t2", updatedAt: new Date() });
    mocks.findOneAndUpdate.mockReturnValue(leanRow(null));
    await expect(service.push("user-1", [{ ...createOperation, opId: "op-2" }])).rejects.toThrow(
      "SYNC_LEDGER_LOST",
    );
  });

  it("handles create 11000 race as replay or rethrows", async () => {
    mocks.findOne
      .mockReturnValueOnce(leanRow(null))
      .mockReturnValueOnce(leanRow({ status: "applied", detail: { taskId: "t1" } }));
    mocks.createTask.mockResolvedValue({ _id: "t1", updatedAt: new Date() });
    mocks.create.mockRejectedValueOnce({ code: 11000 });

    const result = await service.push("user-1", [createOperation]);
    expect(result.results[0]).toMatchObject({ status: "applied", replayed: true });

    mocks.findOne.mockReturnValueOnce(leanRow(null)).mockReturnValueOnce(leanRow(null));
    mocks.createTask.mockResolvedValue({ _id: "t2", updatedAt: new Date() });
    mocks.create.mockRejectedValueOnce({ code: 11000 });
    await expect(service.push("user-1", [{ ...createOperation, opId: "op-3" }])).rejects.toMatchObject({
      code: 11000,
    });

    mocks.findOne.mockReturnValueOnce(leanRow(null));
    mocks.createTask.mockResolvedValue({ _id: "t3", updatedAt: new Date() });
    mocks.create.mockRejectedValueOnce(new Error("other"));
    await expect(service.push("user-1", [{ ...createOperation, opId: "op-4" }])).rejects.toThrow("other");
  });
});

describe("sync service resolveConflict and status", () => {
  const service = new SyncService({} as ISyncRepository);

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("returns server state for server resolution", async () => {
    mocks.getTask.mockResolvedValue({ _id: "t1", title: "Server" });
    const result = await service.resolveConflict("user-1", {
      taskId: "t1",
      resolution: "server",
    });
    expect(mocks.getTask).toHaveBeenCalledWith("user-1", "t1");
    expect(result).toEqual({ _id: "t1", title: "Server" });
  });

  it("applies client state for client resolution", async () => {
    mocks.updateTask.mockResolvedValue({ _id: "t1", title: "Client" });
    const result = await service.resolveConflict("user-1", {
      taskId: "t1",
      resolution: "client",
      clientState: { title: "Client" },
    });
    expect(mocks.updateTask).toHaveBeenCalledWith("user-1", "t1", { title: "Client" });
    expect(result).toEqual({ _id: "t1", title: "Client" });
  });

  it("defaults clientState to empty object", async () => {
    mocks.updateTask.mockResolvedValue({ _id: "t1" });
    await service.resolveConflict("user-1", { taskId: "t1", resolution: "client" });
    expect(mocks.updateTask).toHaveBeenCalledWith("user-1", "t1", {});
  });

  it("returns sync status", async () => {
    const status = await service.getStatus("user-1");
    expect(status.protocol).toBe(1);
    expect(status.supportedOperations).toEqual([
      "task.create",
      "task.update",
      "task.delete",
    ]);
    expect(status.serverTime).toBeInstanceOf(Date);
  });
});
