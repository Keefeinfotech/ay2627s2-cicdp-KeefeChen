import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("../../../../src/modules/tasks/task.service.js", () => ({
  taskService: {
    createTask: vi.fn(),
    getTask: vi.fn(),
    listTasks: vi.fn(),
    updateTask: vi.fn(),
    deleteTask: vi.fn(),
  },
}));

import { taskController } from "../../../../src/modules/tasks/task.controller.js";
import { taskService } from "../../../../src/modules/tasks/task.service.js";

describe("task controller", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("creates a task and returns 201", async () => {
    const task = { _id: "550e8400-e29b-41d4-a716-446655440000", title: "Ship it" };
    vi.mocked(taskService.createTask).mockResolvedValue(task as any);

    const res: any = {
      status: vi.fn().mockReturnThis(),
      json: vi.fn().mockReturnThis(),
    };

    await taskController.create(
      { userId: "user-1", body: { title: "Ship it" } } as any,
      res,
      vi.fn()
    );

    expect(taskService.createTask).toHaveBeenCalledWith("user-1", {
      title: "Ship it",
    });
    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.json).toHaveBeenCalledWith({
      message: "Task created successfully.",
      data: task,
    });
  });

  it("rejects task creation without an authenticated user", async () => {
    const res: any = {
      status: vi.fn().mockReturnThis(),
      json: vi.fn().mockReturnThis(),
    };

    await taskController.create({ body: { title: "Ship it" } } as any, res, vi.fn());

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith({
      code: "UNAUTHENTICATED",
      message: "Authentication is required.",
    });
  });

  it("lists tasks and returns pagination", async () => {
    const result = {
      type: "offset",
      items: [{ _id: "550e8400-e29b-41d4-a716-446655440000" }],
      pagination: {
        page: 1,
        limit: 20,
        totalItems: 1,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false,
      },
    };
    vi.mocked(taskService.listTasks).mockResolvedValue(result);

    const res: any = {
      status: vi.fn().mockReturnThis(),
      json: vi.fn().mockReturnThis(),
    };

    await taskController.list(
      { userId: "user-1", query: { page: 1, limit: 20 } } as any,
      res,
      vi.fn()
    );

    expect(taskService.listTasks).toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      message: "Tasks retrieved successfully.",
      data: result.items,
      pagination: result.pagination,
    });
  });

  it("returns 401 when listing without an authenticated user", async () => {
    const res: any = {
      status: vi.fn().mockReturnThis(),
      json: vi.fn().mockReturnThis(),
    };

    await taskController.list({ query: {} } as any, res, vi.fn());

    expect(res.status).toHaveBeenCalledWith(401);
  });

  it("gets a task by id", async () => {
    const task = { _id: "550e8400-e29b-41d4-a716-446655440000", title: "Ship it" };
    vi.mocked(taskService.getTask).mockResolvedValue(task as any);

    const res: any = {
      status: vi.fn().mockReturnThis(),
      json: vi.fn().mockReturnThis(),
    };

    await taskController.getById(
      { userId: "user-1", params: { taskId: "550e8400-e29b-41d4-a716-446655440000" } } as any,
      res,
      vi.fn()
    );

    expect(taskService.getTask).toHaveBeenCalledWith("user-1", "550e8400-e29b-41d4-a716-446655440000");
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      message: "Task retrieved successfully.",
      data: task,
    });
  });

  it("propagates errors when getting a task fails", async () => {
    const error = new Error("boom");
    vi.mocked(taskService.getTask).mockRejectedValue(error);

    const next = vi.fn();
    const res: any = {
      status: vi.fn().mockReturnThis(),
      json: vi.fn().mockReturnThis(),
    };

    await taskController.getById(
      { userId: "user-1", params: { taskId: "550e8400-e29b-41d4-a716-446655440000" } } as any,
      res,
      next
    );

    expect(next).toHaveBeenCalledWith(error);
  });

  it("updates a task", async () => {
    const task = { _id: "550e8400-e29b-41d4-a716-446655440000", status: "COMPLETED" };
    vi.mocked(taskService.updateTask).mockResolvedValue(task as any);

    const res: any = {
      status: vi.fn().mockReturnThis(),
      json: vi.fn().mockReturnThis(),
    };

    await taskController.update(
      { userId: "user-1", params: { taskId: "550e8400-e29b-41d4-a716-446655440000" }, body: { status: "completed" } } as any,
      res,
      vi.fn()
    );

    expect(taskService.updateTask).toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      message: "Task updated successfully.",
      data: task,
    });
  });

  it("deletes a task and returns 204", async () => {
    vi.mocked(taskService.deleteTask).mockResolvedValue(undefined as any);

    const res: any = {
      status: vi.fn().mockReturnThis(),
      send: vi.fn().mockReturnThis(),
    };

    await taskController.remove(
      { userId: "user-1", params: { taskId: "550e8400-e29b-41d4-a716-446655440000" } } as any,
      res,
      vi.fn()
    );

    expect(taskService.deleteTask).toHaveBeenCalledWith("user-1", "550e8400-e29b-41d4-a716-446655440000");
    expect(res.status).toHaveBeenCalledWith(204);
    expect(res.send).toHaveBeenCalled();
  });

  it("returns 401 when deleting without an authenticated user", async () => {
    const res: any = {
      status: vi.fn().mockReturnThis(),
      json: vi.fn().mockReturnThis(),
    };

    await taskController.remove({ params: { taskId: "550e8400-e29b-41d4-a716-446655440000" } } as any, res, vi.fn());

    expect(res.status).toHaveBeenCalledWith(401);
  });
});
