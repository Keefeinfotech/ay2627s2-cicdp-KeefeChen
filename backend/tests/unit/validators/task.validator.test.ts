import { describe, expect, it, vi } from "vitest";
import {
  createTaskSchema,
  getTasksQuerySchema,
  taskIdParamSchema,
  updateTaskSchema,
  validateCreateTask,
  validateGetTasks,
  validateTaskId,
  validateUpdateTask,
} from "../../../src/validators/task.validator";

describe("task validator schemas", () => {
  it("accepts a valid object id", () => {
    const result = taskIdParamSchema.safeParse({ taskId: "507f1f77bcf86cd799439011" });
    expect(result.success).toBe(true);
  });

  it("rejects an invalid object id", () => {
    const result = taskIdParamSchema.safeParse({ taskId: "not-an-id" });
    expect(result.success).toBe(false);
  });

  it("validates a create task payload", () => {
    const result = createTaskSchema.safeParse({
      title: "Ship it",
      priority: "HIGH",
      dueDate: "2026-01-01",
    });
    expect(result.success).toBe(true);
  });

  it("rejects an empty update payload", () => {
    const result = updateTaskSchema.safeParse({});
    expect(result.success).toBe(false);
  });

  it("validates an update task payload", () => {
    const result = updateTaskSchema.safeParse({ title: "Updated", status: "COMPLETED" });
    expect(result.success).toBe(true);
  });

  it("validates task query parameters with defaults", () => {
    const result = getTasksQuerySchema.safeParse({});
    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.page).toBe(1);
      expect(result.data.limit).toBe(20);
    }
  });

  it("rejects an invalid limit", () => {
    const result = getTasksQuerySchema.safeParse({ limit: 101 });
    expect(result.success).toBe(false);
  });

  it("rejects an invalid status", () => {
    const result = getTasksQuerySchema.safeParse({ status: "NOPE" });
    expect(result.success).toBe(false);
  });

  it("rejects unknown fields", () => {
    const result = createTaskSchema.safeParse({ title: "x", extra: true });
    expect(result.success).toBe(false);
  });
});

describe("task validator middleware", () => {
  function mockRes() {
    const res: any = { status: vi.fn().mockReturnThis(), json: vi.fn().mockReturnThis(), locals: {} };
    return res;
  }

  it("validateTaskId calls next on success", () => {
    const req: any = { params: { taskId: "507f1f77bcf86cd799439011" } };
    const res = mockRes();
    const next = vi.fn();
    validateTaskId(req, res, next);
    expect(next).toHaveBeenCalled();
  });

  it("validateTaskId returns 400 on failure", () => {
    const req: any = { params: { taskId: "bad" } };
    const res = mockRes();
    const next = vi.fn();
    validateTaskId(req, res, next);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: false, message: "Invalid task ID." })
    );
    expect(next).not.toHaveBeenCalled();
  });

  it("validateCreateTask calls next and sets body on success", () => {
    const req: any = { body: { title: "Ship it" } };
    const res = mockRes();
    const next = vi.fn();
    validateCreateTask(req, res, next);
    expect(next).toHaveBeenCalled();
    expect(req.body).toMatchObject({ title: "Ship it" });
  });

  it("validateCreateTask returns 400 on failure", () => {
    const req: any = { body: {} };
    const res = mockRes();
    const next = vi.fn();
    validateCreateTask(req, res, next);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(next).not.toHaveBeenCalled();
  });

  it("validateUpdateTask returns 400 on empty body", () => {
    const req: any = { body: {} };
    const res = mockRes();
    const next = vi.fn();
    validateUpdateTask(req, res, next);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(next).not.toHaveBeenCalled();
  });

  it("validateUpdateTask calls next on success", () => {
    const req: any = { body: { title: "Updated" } };
    const res = mockRes();
    const next = vi.fn();
    validateUpdateTask(req, res, next);
    expect(next).toHaveBeenCalled();
  });

  it("validateGetTasks stores filters in res.locals on success", () => {
    const req: any = { query: { page: "2" } };
    const res = mockRes();
    const next = vi.fn();
    validateGetTasks(req, res, next);
    expect(next).toHaveBeenCalled();
    expect(res.locals.taskFilters).toMatchObject({ page: 2 });
  });

  it("validateGetTasks returns 400 on failure", () => {
    const req: any = { query: { limit: "0" } };
    const res = mockRes();
    const next = vi.fn();
    validateGetTasks(req, res, next);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(next).not.toHaveBeenCalled();
  });
});
