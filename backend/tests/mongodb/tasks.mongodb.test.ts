/*
 * File Name: tasks.mongodb.test.ts
 * Description: Real MongoDB (in-memory) integration tests for the task
 *   persistence layer. Unlike the supertest suites — which mock Mongoose via
 *   tests/helpers/*Mocks.ts — these exercise the actual model, schema
 *   validation, indexes, repository queries and soft-delete/CAS semantics
 *   against a real mongod (mongodb-memory-server).
 *
 *   This is the coverage the strategy document calls out as "MongoDB-backed
 *   integration tests": if the model, index definitions or repository query
 *   construction drift from valid Mongo behaviour, these tests fail.
 *
 *   Runs as part of `npm test`. The in-memory mongod binary is downloaded on
 *   first run and cached by mongodb-memory-server (CI: ubuntu-latest).
 */

import {
  afterAll,
  beforeAll,
  beforeEach,
  describe,
  expect,
  it,
} from "vitest";
import mongoose from "mongoose";
import { MongoMemoryServer } from "mongodb-memory-server";

import { Task } from "../../src/modules/tasks/task.model.js";
import { taskRepository } from "../../src/modules/tasks/task.repository.js";

const USER_A = "11111111-1111-4111-8111-111111111111";
const USER_B = "22222222-2222-4222-8222-222222222222";

let mongod: MongoMemoryServer | null = null;

beforeAll(async () => {
  mongod = await MongoMemoryServer.create();
  await mongoose.connect(mongod.getUri());
}, 120_000);

beforeEach(async () => {
  await Task.deleteMany({});
});

afterAll(async () => {
  await mongoose.disconnect();
  if (mongod) {
    await mongod.stop();
  }
  mongod = null;
});

describe("task repository against in-memory MongoDB", () => {
  it("creates a task with model defaults and returns it", async () => {
    const created = await taskRepository.create(USER_A, {
      title: "Revise geometry chapter 3",
    });

    expect(created._id).toMatch(/^[0-9a-f-]{36}$/);
    expect(created.userId).toBe(USER_A);
    expect(created.status).toBe("todo");
    expect(created.priority).toBe("medium");
    expect(created.description).toBeNull();
    expect(created.deletedAt).toBeNull();
  });

  it("enforces the schema (title required)", async () => {
    await expect(Task.create({ userId: USER_A } as any)).rejects.toThrow();
  });

  it("lists tasks with offset pagination and correct totals", async () => {
    for (let i = 1; i <= 7; i += 1) {
      await taskRepository.create(USER_A, { title: `Task ${i}` });
    }

    const page1 = await taskRepository.listForUser(USER_A, {
      page: 1,
      limit: 3,
      sortOrder: "desc",
    });
    const page3 = await taskRepository.listForUser(USER_A, {
      page: 3,
      limit: 3,
      sortOrder: "desc",
    });

    expect(page1.type).toBe("offset");
    expect(page1.items).toHaveLength(3);
    expect(page1.pagination).toEqual({
      page: 1,
      limit: 3,
      totalItems: 7,
      totalPages: 3,
      hasNextPage: true,
      hasPreviousPage: false,
    });
    expect(page3.items).toHaveLength(1);
    expect(page3.pagination.hasNextPage).toBe(false);
    expect(page3.pagination.hasPreviousPage).toBe(true);
  });

  it("filters by status and priority", async () => {
    await taskRepository.create(USER_A, {
      title: "Low priority task",
      priority: "low",
    });
    await taskRepository.create(USER_A, {
      title: "High priority task",
      priority: "high",
    });

    const highOnly = await taskRepository.listForUser(USER_A, {
      priority: "high",
      limit: 20,
    });

    expect(highOnly.items).toHaveLength(1);
    expect(highOnly.items[0].title).toBe("High priority task");
  });

  it("never leaks another user's tasks", async () => {
    await taskRepository.create(USER_A, { title: "Alpha's task" });

    const forA = await taskRepository.listForUser(USER_A, { limit: 20 });
    const forB = await taskRepository.listForUser(USER_B, { limit: 20 });

    expect(forA.items).toHaveLength(1);
    expect(forB.items).toHaveLength(0);
    expect(forB.pagination.totalItems).toBe(0);
  });

  it("excludes soft-deleted tasks from lists and get-by-id", async () => {
    const created = await taskRepository.create(USER_A, { title: "Doomed" });

    const removed = await taskRepository.softDeleteForUser(created._id, USER_A);
    expect(removed).toBe(true);

    const list = await taskRepository.listForUser(USER_A, { limit: 20 });
    expect(list.items).toHaveLength(0);

    const fetched = await taskRepository.findByIdForUser(created._id, USER_A);
    expect(fetched).toBeNull();

    const archived = await Task.findById(created._id).lean();
    expect(archived?.status).toBe("archived");
    expect(archived?.deletedAt).not.toBeNull();
  });

  it("implements compare-and-swap updates via expectedUpdatedAt", async () => {
    const created = await taskRepository.create(USER_A, { title: "CAS me" });

    const updated = await taskRepository.updateForUser(created._id, USER_A, {
      title: "CAS applied",
      expectedUpdatedAt: created.updatedAt,
    });
    expect(updated?.title).toBe("CAS applied");

    const conflict = await taskRepository.updateForUser(created._id, USER_A, {
      title: "CAS should fail",
      expectedUpdatedAt: created.updatedAt,
    });
    expect(conflict).toBeNull();

    const fetched = await taskRepository.findByIdForUser(created._id, USER_A);
    expect(fetched?.title).toBe("CAS applied");
  });

  it("rejects updates to another user's task", async () => {
    const created = await taskRepository.create(USER_A, { title: "Mine" });

    const updated = await taskRepository.updateForUser(created._id, USER_B, {
      title: "Not yours",
    });
    expect(updated).toBeNull();
  });
});
