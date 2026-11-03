import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("../../../../src/modules/tasks/task.model.js", () => ({
  Task: {
    create: vi.fn(),
    findOne: vi.fn(),
    find: vi.fn(),
    countDocuments: vi.fn(),
    findOneAndUpdate: vi.fn(),
    updateOne: vi.fn(),
  },
}));

import { taskRepository } from "../../../../src/modules/tasks/task.repository.js";

describe("task repository", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("creates a task", async () => {
    const task = {
      _id: "task-1",
      toObject: () => ({ _id: "task-1", title: "Ship it" }),
    };
    const { Task } = await import("../../../../src/modules/tasks/task.model.js");
    vi.mocked(Task.create).mockResolvedValue(task as any);

    const result = await taskRepository.create("user-1", { title: "Ship it" });

    expect(Task.create).toHaveBeenCalledWith({
      userId: "user-1",
      title: "Ship it",
      description: null,
      course: "",
      reminderAt: null,
      priority: "medium",
      dueDate: null,
    });
    expect(result).toEqual({ _id: "task-1", title: "Ship it" });
  });

  it("finds a task for the user", async () => {
    const task = { _id: "task-1" };
    const { Task } = await import("../../../../src/modules/tasks/task.model.js");
    vi.mocked(Task.findOne).mockReturnValue({
      lean: () => ({ exec: async () => task }),
    } as any);

    await expect(taskRepository.findByIdForUser("task-1", "user-1")).resolves.toBe(task);
  });

  it("lists tasks with pagination metadata", async () => {
    const { Task } = await import("../../../../src/modules/tasks/task.model.js");
    vi.mocked(Task.find).mockReturnValue({
      sort: () => ({
        skip: () => ({
          limit: () => ({ lean: () => ({ exec: async () => [{ _id: "task-1" }] }) }),
        }),
      }),
    } as any);
    vi.mocked(Task.countDocuments).mockReturnValue({ exec: async () => 1 });

    const result = await taskRepository.listForUser("user-1", { page: 2, limit: 20 });

    expect(result.type).toBe("offset");
    expect(result.items).toHaveLength(1);
    expect(result.pagination).toMatchObject({ page: 2, limit: 20, totalItems: 1 });
  });

  it("updates a task for the user", async () => {
    const task = { _id: "task-1" };
    const { Task } = await import("../../../../src/modules/tasks/task.model.js");
    vi.mocked(Task.findOneAndUpdate).mockReturnValue({
      lean: () => ({ exec: async () => task }),
    } as any);

    await expect(
      taskRepository.updateForUser("task-1", "user-1", { status: "COMPLETED" })
    ).resolves.toBe(task);
  });

  it("soft deletes a task", async () => {
    const { Task } = await import("../../../../src/modules/tasks/task.model.js");
    vi.mocked(Task.updateOne).mockReturnValue({
      exec: async () => ({ modifiedCount: 1 }),
    });

    await expect(taskRepository.softDeleteForUser("task-1", "user-1")).resolves.toBe(
      true
    );
  });
});
