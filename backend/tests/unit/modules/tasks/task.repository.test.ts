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
    const { Task } =
      await import("../../../../src/modules/tasks/task.model.js");
    vi.mocked(Task.create).mockResolvedValue(task as any);

    const result = await taskRepository.create("user-1", { title: "Ship it" });

    expect(Task.create).toHaveBeenCalledWith({
      userId: "user-1",
      title: "Ship it",
      description: null,
      course: "",
      tags: [],
      groupId: null,
      assigneeId: null,
      assigneeName: null,
      reminderAt: null,
      priority: "medium",
      dueDate: null,
    });
    expect(result).toEqual({ _id: "task-1", title: "Ship it" });
  });

  it("finds a task for the user", async () => {
    const task = { _id: "task-1" };
    const { Task } =
      await import("../../../../src/modules/tasks/task.model.js");
    vi.mocked(Task.findOne).mockReturnValue({
      lean: () => ({ exec: async () => task }),
    } as any);

    await expect(
      taskRepository.findByIdForUser("task-1", "user-1"),
    ).resolves.toBe(task);
  });

  it("lists tasks with pagination metadata", async () => {
    const { Task } =
      await import("../../../../src/modules/tasks/task.model.js");
    vi.mocked(Task.find).mockReturnValue({
      sort: () => ({
        skip: () => ({
          limit: () => ({
            lean: () => ({ exec: async () => [{ _id: "task-1" }] }),
          }),
        }),
      }),
    } as any);
    vi.mocked(Task.countDocuments).mockReturnValue({
      exec: async () => 1,
      _mongooseOptions: undefined,
    } as any);

    const result = await taskRepository.listForUser("user-1", {
      page: 2,
      limit: 20,
    });

    expect(result.type).toBe("offset");
    expect(result.items).toHaveLength(1);
    expect(result.pagination).toMatchObject({
      page: 2,
      limit: 20,
      totalItems: 1,
    });
  });

  it("updates a task for the user", async () => {
    const task = { _id: "task-1" };
    const { Task } =
      await import("../../../../src/modules/tasks/task.model.js");
    vi.mocked(Task.findOneAndUpdate).mockReturnValue({
      lean: () => ({ exec: async () => task }),
    } as any);

    await expect(
      taskRepository.updateForUser("task-1", "user-1", { status: "COMPLETED" }),
    ).resolves.toBe(task);
  });

  it("soft deletes a task", async () => {
    const { Task } =
      await import("../../../../src/modules/tasks/task.model.js");
    vi.mocked(Task.updateOne).mockReturnValue({
      exec: async () => ({ modifiedCount: 1 }),
    });

    await expect(
      taskRepository.softDeleteForUser("task-1", "user-1"),
    ).resolves.toBe(true);
  });

  it("creates a task with all optional fields", async () => {
    const { Task } = await import("../../../../src/modules/tasks/task.model.js");
    vi.mocked(Task.create).mockResolvedValue({
      toObject: () => ({ _id: "task-1" }),
    } as any);

    await taskRepository.create("user-1", {
      id: "task-1",
      title: "Ship it",
      description: "desc",
      course: "CS101",
      tags: ["a"],
      groupId: "g1",
      assigneeId: "u2",
      assigneeName: "Asha",
      reminderAt: new Date("2026-01-01T00:00:00Z"),
      priority: "high",
      dueDate: new Date("2026-01-02T00:00:00Z"),
    } as any);

    expect(Task.create).toHaveBeenCalledWith(
      expect.objectContaining({
        _id: "task-1",
        description: "desc",
        course: "CS101",
        tags: ["a"],
        groupId: "g1",
        assigneeId: "u2",
        assigneeName: "Asha",
        priority: "high",
      }),
    );
  });

  it("lists tasks with filters, search, date ranges, and sort", async () => {
    const { Task } = await import("../../../../src/modules/tasks/task.model.js");
    const findMock = vi.fn().mockReturnValue({
      sort: vi.fn().mockReturnThis(),
      skip: vi.fn().mockReturnThis(),
      limit: vi.fn().mockReturnThis(),
      lean: vi.fn().mockReturnThis(),
      exec: vi.fn().mockResolvedValue([]),
    });
    vi.mocked(Task.find).mockImplementation(findMock as any);
    vi.mocked(Task.countDocuments).mockReturnValue({ exec: vi.fn().mockResolvedValue(0) } as any);

    await taskRepository.listForUser("user-1", {
      includeDeleted: true,
      search: "  calc  ",
      status: ["todo", "in_progress"] as any,
      priority: ["high"] as any,
      dueAfter: new Date("2026-01-01T00:00:00Z"),
      dueBefore: new Date("2026-02-01T00:00:00Z"),
      completedAfter: new Date("2026-01-03T00:00:00Z"),
      completedBefore: new Date("2026-01-04T00:00:00Z"),
      sortBy: "dueDate" as any,
      sortOrder: "asc",
      page: 1,
      limit: 10,
    } as any);

    expect(findMock).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: "user-1",
        $text: { $search: "calc" },
        status: { $in: ["todo", "in_progress"] },
        priority: { $in: ["high"] },
        dueDate: { $gte: expect.any(Date), $lte: expect.any(Date) },
        completedAt: { $gte: expect.any(Date), $lte: expect.any(Date) },
      }),
    );
  });

  it("applies single-value status/priority filters", async () => {
    const { Task } = await import("../../../../src/modules/tasks/task.model.js");
    const findMock = vi.fn().mockReturnValue({
      sort: vi.fn().mockReturnThis(),
      skip: vi.fn().mockReturnThis(),
      limit: vi.fn().mockReturnThis(),
      lean: vi.fn().mockReturnThis(),
      exec: vi.fn().mockResolvedValue([]),
    });
    vi.mocked(Task.find).mockImplementation(findMock as any);
    vi.mocked(Task.countDocuments).mockReturnValue({ exec: vi.fn().mockResolvedValue(0) } as any);

    await taskRepository.listForUser("user-1", {
      status: "todo" as any,
      priority: "high" as any,
    } as any);

    expect(findMock).toHaveBeenCalledWith(
      expect.objectContaining({ status: "todo", priority: "high" }),
    );
  });

  it("includes expectedUpdatedAt in update filter for compare-and-swap", async () => {
    const { Task } = await import("../../../../src/modules/tasks/task.model.js");
    vi.mocked(Task.findOneAndUpdate).mockReturnValue({
      lean: () => ({ exec: async () => ({ _id: "task-1" }) }),
    } as any);

    const expected = new Date("2026-03-01T00:00:00.000Z");
    await taskRepository.updateForUser("task-1", "user-1", {
      title: "Changed",
      expectedUpdatedAt: expected,
    } as any);

    expect(Task.findOneAndUpdate).toHaveBeenCalledWith(
      expect.objectContaining({ updatedAt: expected }),
      { $set: { title: "Changed" } },
      { new: true, runValidators: true },
    );
  });
});
