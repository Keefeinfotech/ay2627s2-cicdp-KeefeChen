/**
 * File Name: assistant-actions.http.test.ts
 * Description: HTTP surface for POST /api/assistant/act|confirm-action|
 *   cancel-action. Verifies authentication, request validation, that the
 *   authenticated userId (not a client-supplied one) reaches the service,
 *   and that API/validation failures never report executed=true.
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

// Mock the task service so we can inspect exactly what userId is passed.
const taskMocks = vi.hoisted(() => ({
  createTask: vi.fn(),
  updateTask: vi.fn(),
  deleteTask: vi.fn(),
  getTask: vi.fn(),
  listTasks: vi.fn(),
}));
vi.mock("../../src/modules/tasks/task.service.js", () => ({
  taskService: taskMocks,
}));

import app from "../../src/app";
import { User } from "../../src/modules/auth/auth.model.js";
import { AuthSession } from "../../src/modules/auth/session.model.js";
import { sessionCache } from "../../src/modules/auth/session.cache.js";
import { signAccessToken } from "../../src/shared/utils/tokens";
import { queryResult } from "../helpers/authMocks.js";

const userModel = User as never as { findById: ReturnType<typeof vi.fn> };
const sessionModel = AuthSession as never as { findById: ReturnType<typeof vi.fn> };

const USER_ID = "user-1";

const authenticate = (): string => {
  const { token, sessionId } = signAccessToken(USER_ID, "ada@example.com");
  userModel.findById.mockReturnValue(
    queryResult({ _id: USER_ID, email: "ada@example.com", role: "user" }),
  );
  sessionModel.findById.mockReturnValue(
    queryResult({
      _id: sessionId,
      userId: USER_ID,
      revokedAt: null,
      expiresAt: new Date(Date.now() + 3_600_000),
      lastUsedAt: new Date(),
    }),
  );
  return token;
};

const persistedTask = {
  _id: "44444444-4444-4444-8444-444444444444",
  userId: USER_ID,
  title: "CI/CD report",
  description: null,
  course: "",
  tags: [],
  status: "todo",
  priority: "high",
  dueDate: new Date("2026-11-28"),
  reminderAt: null,
  completedAt: null,
  createdAt: new Date(),
  updatedAt: new Date(),
};

beforeEach(() => {
  vi.clearAllMocks();
  sessionCache.clear();
  taskMocks.listTasks.mockResolvedValue({ items: [], type: "offset", pagination: {} });
  taskMocks.getTask.mockResolvedValue(persistedTask);
  taskMocks.createTask.mockResolvedValue(persistedTask);
  taskMocks.updateTask.mockResolvedValue(persistedTask);
  taskMocks.deleteTask.mockResolvedValue(undefined);
});

describe("POST /api/assistant/act", () => {
  it("requires authentication", async () => {
    const res = await request(app).post("/api/assistant/act").send({ message: "Create a task to buy milk" });
    expect(res.status).toBe(401);
    expect(taskMocks.createTask).not.toHaveBeenCalled();
  });

  it("rejects invalid bodies", async () => {
    const token = authenticate();
    const res = await request(app)
      .post("/api/assistant/act")
      .set("Authorization", `Bearer ${token}`)
      .send({ message: "", unexpected: true });
    expect(res.status).toBe(400);
    expect(taskMocks.createTask).not.toHaveBeenCalled();
  });

  it("executes a create through taskService with the AUTHENTICATED userId", async () => {
    const token = authenticate();
    const res = await request(app)
      .post("/api/assistant/act")
      .set("Authorization", `Bearer ${token}`)
      .send({ message: "Create a task to finish my CI/CD report by tomorrow, high priority." });

    expect(res.status).toBe(200);
    expect(res.body.executed).toBe(true);
    expect(res.body.kind).toBe("action");
    expect(res.body.intent).toBe("create_task");
    expect(taskMocks.createTask).toHaveBeenCalledTimes(1);
    const [userIdArg] = taskMocks.createTask.mock.calls[0]!;
    expect(userIdArg).toBe(USER_ID);
  });

  it("a client-supplied userId in the body cannot override ownership", async () => {
    const token = authenticate();
    const res = await request(app)
      .post("/api/assistant/act")
      .set("Authorization", `Bearer ${token}`)
      .send({ message: "Create a task to buy milk", userId: "someone-else" });
    // strict schema rejects unknown key OR it is ignored; either way service
    // receives the authenticated user id.
    if (res.status === 200) {
      const [userIdArg] = taskMocks.createTask.mock.calls[0]!;
      expect(userIdArg).toBe(USER_ID);
    } else {
      expect(res.status).toBe(400);
      expect(taskMocks.createTask).not.toHaveBeenCalled();
    }
  });

  it("task update is scoped to the authenticated user", async () => {
    const token = authenticate();
    taskMocks.listTasks.mockResolvedValue({ items: [persistedTask], type: "offset", pagination: {} });
    const res = await request(app)
      .post("/api/assistant/act")
      .set("Authorization", `Bearer ${token}`)
      .send({ message: "Change my CI/CD report task deadline to Friday." });

    expect(res.status).toBe(200);
    expect(res.body.executed).toBe(true);
    expect(taskMocks.updateTask).toHaveBeenCalledWith(USER_ID, persistedTask._id, expect.any(Object));
  });

  it("surfaces failure honestly when the service throws", async () => {
    const token = authenticate();
    taskMocks.createTask.mockRejectedValue(new Error("db down"));
    const res = await request(app)
      .post("/api/assistant/act")
      .set("Authorization", `Bearer ${token}`)
      .send({ message: "Create a task to buy milk" });

    expect(res.status).toBe(200);
    expect(res.body.executed).toBe(false);
    expect(res.body.status).toBe("failed");
    expect(res.body.reply.toLowerCase()).not.toContain("created");
  });
});

describe("POST /api/assistant/confirm-action", () => {
  it("requires authentication", async () => {
    const res = await request(app).post("/api/assistant/confirm-action").send({ pendingActionId: "x" });
    expect(res.status).toBe(401);
  });

  it("rejects a missing pendingActionId", async () => {
    const token = authenticate();
    const res = await request(app)
      .post("/api/assistant/confirm-action")
      .set("Authorization", `Bearer ${token}`)
      .send({});
    expect(res.status).toBe(400);
  });
});

describe("POST /api/assistant/cancel-action", () => {
  it("requires authentication", async () => {
    const res = await request(app).post("/api/assistant/cancel-action").send({ pendingActionId: "x" });
    expect(res.status).toBe(401);
  });
});
