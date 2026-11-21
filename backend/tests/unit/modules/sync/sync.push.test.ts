import { beforeEach, describe, expect, it, vi } from "vitest";

import type { ISyncRepository } from "../../../../src/modules/sync/sync.repository.js";

const mocks = vi.hoisted(() => ({
  findOne: vi.fn(),
  findOneAndUpdate: vi.fn(),
  create: vi.fn(),
  createTask: vi.fn(),
  updateTask: vi.fn(),
  deleteTask: vi.fn(),
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
  },
}));

import { SyncService } from "../../../../src/modules/sync/sync.service.js";

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
      { userId: "user-1", opId: "op-1", status: "failed", updatedAt },
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
});
