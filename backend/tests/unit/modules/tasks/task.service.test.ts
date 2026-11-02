import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("../../../../src/modules/tasks/task.repository.js", () => ({
  taskRepository: {
    create: vi.fn(),
    findByIdForUser: vi.fn(),
    listForUser: vi.fn(),
    updateForUser: vi.fn(),
    softDeleteForUser: vi.fn(),
  },
}));

import { taskRepository } from "../../../../src/modules/tasks/task.repository.js";
import { taskService } from "../../../../src/modules/tasks/task.service.js";
import { AppError } from "../../../../src/shared/utils/AppError";

describe("task service", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("creates a task for the authenticated user", async () => {
    const task = { _id: "task-1", title: "Ship it" };
    vi.mocked(taskRepository.create).mockResolvedValue(task as any);

    const result = await taskService.createTask("user-1", {
      title: "Ship it",
    });

    expect(taskRepository.create).toHaveBeenCalledWith("user-1", {
      title: "Ship it",
    });
    expect(result).toBe(task);
  });

  it("rejects task creation without an authenticated user", async () => {
    await expect(
      taskService.createTask("", { title: "Ship it" })
    ).rejects.toBeInstanceOf(AppError);

    expect(taskRepository.create).not.toHaveBeenCalled();
  });

  it("returns the task for the authenticated user", async () => {
    const task = { _id: "task-1", title: "Ship it" };
    vi.mocked(taskRepository.findByIdForUser).mockResolvedValue(task as any);

    await expect(taskService.getTask("user-1", "task-1")).resolves.toBe(task);
  });

  it("throws TASK_NOT_FOUND when the task is missing", async () => {
    vi.mocked(taskRepository.findByIdForUser).mockResolvedValue(null);

    await expect(taskService.getTask("user-1", "task-1")).rejects.toMatchObject(
      {
        status: 404,
        code: "TASK_NOT_FOUND",
      }
    );
  });

  it("lists tasks with pagination", async () => {
    const result = {
      type: "offset",
      items: [],
      pagination: {
        page: 1,
        limit: 20,
        totalItems: 0,
        totalPages: 0,
        hasNextPage: false,
        hasPreviousPage: false,
      },
    };
    vi.mocked(taskRepository.listForUser).mockResolvedValue(result);

    const output = await taskService.listTasks("user-1", {
      page: 1,
      limit: 20,
    });

    expect(taskRepository.listForUser).toHaveBeenCalledWith("user-1", {
      page: 1,
      limit: 20,
    });
    expect(output).toBe(result);
  });

  it("rejects an inverted date range", async () => {
    await expect(
      taskService.listTasks("user-1", {
        dueAfter: new Date("2026-02-01"),
        dueBefore: new Date("2026-01-01"),
      })
    ).rejects.toMatchObject({ status: 400, code: "INVALID_DATE_RANGE" });
  });

  it("updates a task", async () => {
    const task = { _id: "task-1", status: "COMPLETED" };
    vi.mocked(taskRepository.updateForUser).mockResolvedValue(task as any);

    await expect(
      taskService.updateTask("user-1", "task-1", { status: "COMPLETED" })
    ).resolves.toBe(task);
  });

  it("soft deletes a task", async () => {
    vi.mocked(taskRepository.softDeleteForUser).mockResolvedValue(true);

    await expect(taskService.deleteTask("user-1", "task-1")).resolves.toBe(
      undefined
    );
    expect(taskRepository.softDeleteForUser).toHaveBeenCalledWith(
      "task-1",
      "user-1"
    );
  });
});
