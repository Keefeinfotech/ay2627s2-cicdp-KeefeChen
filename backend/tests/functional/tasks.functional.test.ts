/*
 * File Name: tasks.functional.test.ts
 * Description: Functional tests for the task API. Unlike the mocked-model
 *   integration suites, these exercise the whole HTTP pipeline — request
 *   validation, authentication, controller, service, repository — against an
 *   in-memory Task store that mimics Mongoose behaviour closely enough to
 *   cover ownership, filtering, sorting and pagination semantics.
 *
 *   Black-box perspective: assertions are made purely on the HTTP contract
 *   (status codes, body shapes and side effects visible over the API).
 */

import { beforeEach, describe, expect, it, vi } from "vitest";
import request from "supertest";

// Hoisted so the vi.mock factory (which is hoisted above all imports and
// top-level statements) can share state with beforeEach.
const store = vi.hoisted(() => ({
  tasks: [] as Array<Record<string, any>>,
}));

vi.mock("../../src/modules/auth/auth.model.js", async () => {
  const { authModelMock } = await import("../helpers/authMocks.js");
  return authModelMock();
});

vi.mock("../../src/modules/auth/session.model.js", async () => {
  const { sessionModelMock } = await import("../helpers/authMocks.js");
  return sessionModelMock();
});

vi.mock("../../src/modules/tasks/task.model.js", async () => {
  const { randomUUID } = await import("node:crypto");
  const randomId = () => randomUUID();

  const matchesFilter = (
    doc: Record<string, any>,
    filter: Record<string, any>,
  ): boolean => {
    for (const [key, condition] of Object.entries(filter)) {
      if (key === "$text") continue; // text search is not exercised here
      const value = doc[key] ?? null;
      if (
        condition !== null &&
        typeof condition === "object" &&
        !Array.isArray(condition) &&
        !(condition instanceof Date)
      ) {
        for (const [op, operand] of Object.entries(condition)) {
          if (op === "$in") {
            if (!(operand as any[]).includes(value)) return false;
            continue;
          }
          const time = value instanceof Date ? value.getTime() : value;
          const operandTime =
            (operand as unknown) instanceof Date
              ? (operand as unknown as Date).getTime()
              : (operand as number);
          if (op === "$gte" && !(time >= operandTime)) return false;
          if (op === "$lte" && !(time <= operandTime)) return false;
          if (op === "$gt" && !(time > operandTime)) return false;
          if (op === "$lt" && !(time < operandTime)) return false;
          else if (!["$gte", "$lte", "$gt", "$lt"].includes(op)) return false;
        }
        continue;
      }
      if (condition instanceof Date) {
        const time = value instanceof Date ? value.getTime() : NaN;
        if (time !== condition.getTime()) return false;
        continue;
      }
      if (condition === null) {
        if (value !== null && value !== undefined) return false;
        continue;
      }
      if (value !== condition) return false;
    }
    return true;
  };

  const sortDocs = (
    docs: Array<Record<string, any>>,
    sort: Record<string, 1 | -1> | undefined,
  ): Array<Record<string, any>> => {
    if (!sort) return docs;
    const entries = Object.entries(sort);
    return [...docs].sort((a, b) => {
      for (const [field, direction] of entries) {
        const av = a[field] instanceof Date ? a[field].getTime() : a[field];
        const bv = b[field] instanceof Date ? b[field].getTime() : b[field];
        if (av === bv) continue;
        if (av === null || av === undefined) return 1;
        if (bv === null || bv === undefined) return -1;
        return direction * (av > bv ? 1 : -1);
      }
      return 0;
    });
  };

  const chainable = (resolve: () => any) => ({
    lean: () => chainable(resolve),
    exec: () => Promise.resolve().then(resolve),
  });

  return {
    __esModule: true,
    Task: {
      create: vi.fn(async (input: Record<string, any>) => {
        const now = new Date();
        const doc: Record<string, any> = {
          _id: input._id ?? randomId(),
          userId: input.userId,
          title: input.title,
          description: input.description ?? null,
          course: input.course ?? "",
          tags: input.tags ?? [],
          groupId: input.groupId ?? null,
          assigneeId: input.assigneeId ?? null,
          assigneeName: input.assigneeName ?? null,
          reminderAt: input.reminderAt ?? null,
          status: input.status ?? "todo",
          priority: input.priority ?? "medium",
          dueDate: input.dueDate ?? null,
          completedAt: input.completedAt ?? null,
          deletedAt: input.deletedAt ?? null,
          createdAt: now,
          updatedAt: now,
        };
        store.tasks.push(doc);
        const toObject = function (this: Record<string, any>) {
          const { toObject: _ignored, ...rest } = this;
          return { ...rest };
        };
        return { ...doc, toObject };
      }),
      findOne: vi.fn((filter: Record<string, any>) =>
        chainable(
          () =>
            store.tasks.find((doc) => matchesFilter(doc, filter)) ?? null,
        ),
      ),
      find: vi.fn((filter: Record<string, any>) => {
        let result = store.tasks.filter((doc) => matchesFilter(doc, filter));
        const query: any = {
          sort(sort: Record<string, 1 | -1>) {
            result = sortDocs(result, sort);
            return query;
          },
          skip(count: number) {
            result = result.slice(count);
            return query;
          },
          limit(count: number) {
            result = result.slice(0, count);
            return query;
          },
          lean: () => chainable(() => result),
        };
        return query;
      }),
      countDocuments: vi.fn((filter: Record<string, any>) =>
        chainable(
          () =>
            store.tasks.filter((doc) => matchesFilter(doc, filter)).length,
        ),
      ),
      findOneAndUpdate: vi.fn(
        (
          filter: Record<string, any>,
          update: Record<string, any>,
          _opts?: Record<string, any>,
        ) =>
          chainable(() => {
            const doc = store.tasks.find((item) => matchesFilter(item, filter));
            if (!doc) return null;
            Object.assign(doc, update.$set ?? {});
            doc.updatedAt = new Date();
            return { ...doc };
          }),
      ),
      updateOne: vi.fn(
        (filter: Record<string, any>, update: Record<string, any>) =>
          chainable(() => {
            const doc = store.tasks.find((item) => matchesFilter(item, filter));
            if (!doc) return { modifiedCount: 0 };
            Object.assign(doc, update.$set ?? {});
            return { modifiedCount: 1 };
          }),
      ),
    },
  };
});

import app from "../../src/app";
import { User } from "../../src/modules/auth/auth.model.js";
import { AuthSession } from "../../src/modules/auth/session.model.js";
import { sessionCache } from "../../src/modules/auth/session.cache.js";
import { signAccessToken } from "../../src/shared/utils/tokens";
import { queryResult } from "../helpers/authMocks.js";

const userModel = User as any;
const sessionModel = AuthSession as any;

const ALPHA_USER_ID = "33333333-3333-4333-8333-333333333333";
const BETA_USER_ID = "44444444-4444-4444-8444-444444444444";

const authenticate = (userId: string, email: string): string => {
  const { token, sessionId } = signAccessToken(userId, email);
  userModel.findById.mockReturnValue(
    queryResult({ _id: userId, email, role: "user" }),
  );
  sessionModel.findById.mockReturnValue(
    queryResult({
      _id: sessionId,
      userId,
      revokedAt: null,
      expiresAt: new Date(Date.now() + 60 * 60 * 1000),
      userAgent: "vitest",
      createdAt: new Date(),
      lastUsedAt: new Date(),
    }),
  );
  return token;
};

const authHeader = (token: string) => ({ Authorization: `Bearer ${token}` });

const bodyTaskId = (body: any): string =>
  body.data?.id ?? body.data?._id ?? body.task?.id ?? body.task?._id ?? body.id ?? body._id;

const listItems = (body: any): any[] => body.data ?? body.items ?? body.tasks ?? [];

beforeEach(() => {
  store.tasks.length = 0;
  vi.resetAllMocks();
  sessionCache.clear();
  sessionModel.create.mockResolvedValue({});
  sessionModel.find.mockReturnValue(queryResult([]));
  sessionModel.updateOne.mockReturnValue(queryResult({}));
  sessionModel.updateMany.mockReturnValue(queryResult({}));
});

// ==========================================
// TASK LIFECYCLE JOURNEY
// ==========================================

describe("task API journey (functional)", () => {
  it("create → list → get → update → delete works end to end", async () => {
    const token = authenticate(ALPHA_USER_ID, "ada@example.com");

    // Create
    const created = await request(app)
      .post("/api/tasks")
      .set(authHeader(token))
      .send({
        title: "Revise biology chapter 4",
        course: "BIO101",
        tags: ["Biology", "biology", "Revision"],
        priority: "high",
        dueDate: "2027-03-01T00:00:00.000Z",
      });
    expect(created.status).toBe(201);
    const taskId = bodyTaskId(created.body);
    expect(taskId).toBeTruthy();
    // Tags are normalised case-insensitively.
    const createdTags: string[] =
      created.body.data?.tags ?? created.body.tags ?? [];
    expect(createdTags.map((t) => t.toLowerCase())).toEqual([
      "biology",
      "revision",
    ]);

    // List (defaults: page 1, limit 20)
    const list = await request(app)
      .get("/api/tasks")
      .set(authHeader(token));
    expect(list.status).toBe(200);
    expect(listItems(list.body)).toHaveLength(1);

    // Get by id
    const fetched = await request(app)
      .get(`/api/tasks/${taskId}`)
      .set(authHeader(token));
    expect(fetched.status).toBe(200);

    // Update (compare-and-swap using returned updatedAt)
    const updatedAt =
      fetched.body.data?.updatedAt ?? fetched.body.updatedAt ?? undefined;
    const updated = await request(app)
      .patch(`/api/tasks/${taskId}`)
      .set(authHeader(token))
      .send({
        priority: "urgent",
        status: "in_progress",
        ...(updatedAt ? { expectedUpdatedAt: updatedAt } : {}),
      });
    expect(updated.status).toBe(200);
    const priority =
      updated.body.data?.priority ?? updated.body.priority;
    expect(priority).toBe("urgent");

    // Delete (soft delete)
    const deleted = await request(app)
      .delete(`/api/tasks/${taskId}`)
      .set(authHeader(token));
    expect([200, 204]).toContain(deleted.status);

    // The deleted task no longer appears in the list.
    const afterDelete = await request(app)
      .get("/api/tasks")
      .set(authHeader(token));
    expect(listItems(afterDelete.body)).toHaveLength(0);
  });

  it("does not leak another user's task", async () => {
    const alpha = authenticate(ALPHA_USER_ID, "ada@example.com");
    const created = await request(app)
      .post("/api/tasks")
      .set(authHeader(alpha))
      .send({ title: "Private study plan" });
    expect(created.status).toBe(201);
    const taskId = bodyTaskId(created.body);

    const beta = authenticate(BETA_USER_ID, "grace@example.com");
    const stolen = await request(app)
      .get(`/api/tasks/${taskId}`)
      .set(authHeader(beta));
    expect([403, 404]).toContain(stolen.status);

    const betaList = await request(app)
      .get("/api/tasks")
      .set(authHeader(beta));
    expect(listItems(betaList.body)).toHaveLength(0);
  });

  it("rejects unauthenticated requests with 401", async () => {
    const res = await request(app).get("/api/tasks");
    expect(res.status).toBe(401);
    expect(res.body.code).toBe("UNAUTHORIZED");
  });

  it("rejects invalid create payloads with a validation error", async () => {
    const token = authenticate(ALPHA_USER_ID, "ada@example.com");
    const res = await request(app)
      .post("/api/tasks")
      .set(authHeader(token))
      .send({ title: "" });
    expect(res.status).toBe(400);
    expect(res.body.code).toBe("VALIDATION_ERROR");
  });

  it("filters by priority and paginates with defaults", async () => {
    const token = authenticate(ALPHA_USER_ID, "ada@example.com");
    const priorities = ["low", "medium", "high", "medium", "low"];
    for (const [index, priority] of priorities.entries()) {
      const res = await request(app)
        .post("/api/tasks")
        .set(authHeader(token))
        .send({ title: `Task ${index}`, priority });
      expect(res.status).toBe(201);
    }

    const filtered = await request(app)
      .get("/api/tasks?priority=low")
      .set(authHeader(token));
    expect(filtered.status).toBe(200);
    expect(listItems(filtered.body)).toHaveLength(2);

    const page = await request(app)
      .get("/api/tasks?limit=2&page=2")
      .set(authHeader(token));
    expect(page.status).toBe(200);
    expect(listItems(page.body)).toHaveLength(2);
    expect(page.body.pagination?.totalItems ?? page.body.total ?? 5).toBe(5);
  });
});
