/**
 * File Name: ai-action-endpoints.test.ts
 * Description: The pre-existing AI task-action endpoints must actually
 *   execute. Regression: ai.controller read `req.user.id` while
 *   `authenticate` populates `req.userId`, so every authenticated call
 *   returned 401 "Unauthenticated". Verifies auth + execution + validation +
 *   ownership scoping for /api/ai/create|complete|delete|tasks|today.
 */

import { beforeEach, describe, expect, it, vi } from "vitest";
import request from "supertest";

vi.mock("../../src/modules/auth/auth.model.js", async () => {
  const { authModelMock } = await import("../helpers/authMocks.js");
  return authModelMock();
});
vi.mock("../../src/modules/auth/session.model.js", async () => {
  const { sessionModelMock } = await import("../helpers/authMocks.js");
  return sessionModelMock();
});

const taskMocks = vi.hoisted(() => ({
  createTask: vi.fn(),
  updateTask: vi.fn(),
  deleteTask: vi.fn(),
  getTask: vi.fn(),
  listTasks: vi.fn(),
}));
vi.mock("../../src/modules/tasks/task.service.js", () => ({ taskService: taskMocks }));

import app from "../../src/app";
import { User } from "../../src/modules/auth/auth.model.js";
import { AuthSession } from "../../src/modules/auth/session.model.js";
import { sessionCache } from "../../src/modules/auth/session.cache.js";
import { signAccessToken } from "../../src/shared/utils/tokens";
import { queryResult } from "../helpers/authMocks.js";

const userModel = User as never as { findById: ReturnType<typeof vi.fn> };
const sessionModel = AuthSession as never as { findById: ReturnType<typeof vi.fn> };
const USER_ID = "user-1";
const TASK_ID = "44444444-4444-4444-8444-444444444444";

const authenticate = (): string => {
  const { token, sessionId } = signAccessToken(USER_ID, "ada@example.com");
  userModel.findById.mockReturnValue(queryResult({ _id: USER_ID, email: "ada@example.com", role: "user" }));
  sessionModel.findById.mockReturnValue(
    queryResult({ _id: sessionId, userId: USER_ID, revokedAt: null, expiresAt: new Date(Date.now() + 3_600_000), lastUsedAt: new Date() }),
  );
  return token;
};

const task = {
  _id: TASK_ID,
  userId: USER_ID,
  title: "Revise biology",
  description: null,
  course: "",
  tags: [],
  status: "todo",
  priority: "medium",
  dueDate: null,
  reminderAt: null,
  completedAt: null,
  createdAt: new Date(),
  updatedAt: new Date(),
};

beforeEach(() => {
  vi.clearAllMocks();
  sessionCache.clear();
  taskMocks.listTasks.mockResolvedValue({ items: [task], type: "offset", pagination: {} });
  taskMocks.createTask.mockResolvedValue(task);
  taskMocks.updateTask.mockResolvedValue({ ...task, status: "completed" });
  taskMocks.deleteTask.mockResolvedValue(undefined);
});

describe("POST /api/ai/create", () => {
  it("requires authentication", async () => {
    const res = await request(app).post("/api/ai/create").send({ title: "x" });
    expect(res.status).toBe(401);
    expect(taskMocks.createTask).not.toHaveBeenCalled();
  });

  it("creates a task for the authenticated user (not 401)", async () => {
    const token = authenticate();
    const res = await request(app).post("/api/ai/create").set("Authorization", `Bearer ${token}`).send({ title: "Revise biology" });
    expect(res.status).toBe(201);
    expect(res.body.message).toBe("Task created");
    expect(taskMocks.createTask).toHaveBeenCalledWith(USER_ID, expect.objectContaining({ title: "Revise biology" }));
  });

  it("rejects invalid input via schema validation", async () => {
    const token = authenticate();
    const res = await request(app).post("/api/ai/create").set("Authorization", `Bearer ${token}`).send({ title: "", priority: "banana" });
    expect(res.status).toBe(400);
    expect(taskMocks.createTask).not.toHaveBeenCalled();
  });
});

describe("POST /api/ai/complete", () => {
  it("marks an owned task completed for the authenticated user", async () => {
    const token = authenticate();
    const res = await request(app).post("/api/ai/complete").set("Authorization", `Bearer ${token}`).send({ taskId: TASK_ID });
    expect(res.status).toBe(200);
    expect(taskMocks.updateTask).toHaveBeenCalledWith(USER_ID, TASK_ID, { status: "completed" });
  });

  it("rejects a missing taskId", async () => {
    const token = authenticate();
    const res = await request(app).post("/api/ai/complete").set("Authorization", `Bearer ${token}`).send({});
    expect(res.status).toBe(400);
    expect(taskMocks.updateTask).not.toHaveBeenCalled();
  });
});

describe("POST /api/ai/delete", () => {
  it("deletes an owned task for the authenticated user", async () => {
    const token = authenticate();
    const res = await request(app).post("/api/ai/delete").set("Authorization", `Bearer ${token}`).send({ taskId: TASK_ID });
    expect(res.status).toBe(200);
    expect(taskMocks.deleteTask).toHaveBeenCalledWith(USER_ID, TASK_ID);
  });
});

describe("GET /api/ai/tasks", () => {
  it("lists only the authenticated user's tasks", async () => {
    const token = authenticate();
    const res = await request(app).get("/api/ai/tasks").set("Authorization", `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(taskMocks.listTasks).toHaveBeenCalledWith(USER_ID, expect.any(Object));
    expect(res.body.count).toBe(1);
  });
});

describe("GET /api/ai/today", () => {
  it("summarises the authenticated user's open tasks", async () => {
    const token = authenticate();
    const res = await request(app).get("/api/ai/today").set("Authorization", `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.summary).toContain("Revise biology");
  });
});
