/*
 * File Name: admin.test.ts
 * Description: Integration tests for the administrative API surface: RBAC,
 *              user management, aggregated statistics and error handling.
 *              Models are mocked in memory; the Express pipeline is real.
 * Author: Keefe Chen
 */

import request from "supertest";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("../../src/modules/auth/auth.model.js", async () => {
  const { authModelMock } = await import("../helpers/authMocks.js");
  return authModelMock();
});

vi.mock("../../src/modules/auth/session.model.js", async () => {
  const { sessionModelMock } = await import("../helpers/authMocks.js");
  return sessionModelMock();
});

vi.mock("../../src/modules/users/user.model.js", () => ({
  User: {
    countDocuments: vi.fn(),
    find: vi.fn(),
    findById: vi.fn(),
    findByIdAndUpdate: vi.fn(),
    aggregate: vi.fn(),
  },
}));

vi.mock("../../src/modules/tasks/task.model.js", () => ({
  Task: {
    countDocuments: vi.fn(),
    aggregate: vi.fn(),
  },
}));

import app from "../../src/app";
import { User } from "../../src/modules/users/user.model.js";
import { Task } from "../../src/modules/tasks/task.model.js";
import { User as AuthUser } from "../../src/modules/auth/auth.model.js";
import { AuthSession } from "../../src/modules/auth/session.model.js";
import { sessionCache } from "../../src/modules/auth/session.cache.js";
import { signAccessToken } from "../../src/shared/utils/tokens.js";
import { queryResult } from "../helpers/authMocks.js";

const authUser = AuthUser as never as {
  findById: ReturnType<typeof vi.fn>;
};
const authSession = AuthSession as never as {
  findById: ReturnType<typeof vi.fn>;
};
const userModel = User as never as {
  countDocuments: ReturnType<typeof vi.fn>;
  find: ReturnType<typeof vi.fn>;
  findById: ReturnType<typeof vi.fn>;
  findByIdAndUpdate: ReturnType<typeof vi.fn>;
  aggregate: ReturnType<typeof vi.fn>;
};
const taskModel = Task as never as {
  countDocuments: ReturnType<typeof vi.fn>;
  aggregate: ReturnType<typeof vi.fn>;
};

const ADMIN = {
  _id: "admin-1",
  email: "admin@auxilia.demo",
  name: "Demo Admin",
  role: "admin",
  status: "active",
};
const STANDARD = {
  _id: "user-1",
  email: "user@auxilia.demo",
  name: "Demo User",
  role: "user",
  status: "active",
};

const futureExpiry = () => new Date(Date.now() + 3_600_000);

const adminToken = () =>
  signAccessToken("admin-1", ADMIN.email, "session-1").token;
const userToken = () =>
  signAccessToken("user-1", STANDARD.email, "session-u").token;

const leanChain = (value: unknown) => ({
  select: vi.fn().mockReturnThis(),
  sort: vi.fn().mockReturnThis(),
  skip: vi.fn().mockReturnThis(),
  limit: vi.fn().mockReturnThis(),
  lean: vi.fn().mockResolvedValue(value),
});

const giveSessionFor = (
  user: typeof ADMIN | typeof STANDARD,
  sessionId: string,
) => {
  authUser.findById.mockReturnValue(queryResult({ ...user }));
  authSession.findById.mockReturnValue(
    queryResult({
      _id: sessionId,
      userId: user._id,
      revokedAt: null,
      expiresAt: futureExpiry(),
      refreshTokenHash: null,
    }),
  );
};

beforeEach(() => {
  vi.resetAllMocks();
  sessionCache.clear();
  giveSessionFor(ADMIN, "session-1");
});

describe("RBAC", () => {
  it("rejects anonymous requests with 401", async () => {
    const res = await request(app).get("/api/admin/users");
    expect(res.status).toBe(401);
  });

  it("rejects authenticated non-admin roles with 403", async () => {
    giveSessionFor(STANDARD, "session-u");
    const res = await request(app)
      .get("/api/admin/users")
      .set("Authorization", `Bearer ${userToken()}`);
    expect(res.status).toBe(403);
  });

  it("rejects non-admin access to statistics with 403", async () => {
    giveSessionFor(STANDARD, "session-u");
    const res = await request(app)
      .get("/api/admin/stats")
      .set("Authorization", `Bearer ${userToken()}`);
    expect(res.status).toBe(403);
  });
});

describe("GET /api/admin/users", () => {
  it("returns a paginated list without sensitive fields", async () => {
    userModel.countDocuments.mockResolvedValue(2);
    userModel.find.mockReturnValue(
      leanChain([
        {
          _id: "u1",
          name: "Keefe",
          email: "keefe@auxilia.demo",
          role: "admin",
          status: "active",
          createdAt: new Date("2026-10-01T00:00:00Z"),
          lastLoginAt: null,
          passwordHash: "must-never-appear",
        },
        {
          _id: "u2",
          name: "Wei",
          email: "wei@auxilia.demo",
          role: "user",
          status: "disabled",
          createdAt: null,
          lastLoginAt: null,
          passwordHash: "must-never-appear",
        },
      ]),
    );

    const res = await request(app)
      .get("/api/admin/users?page=1&limit=10")
      .set("Authorization", `Bearer ${adminToken()}`);

    expect(res.status).toBe(200);
    expect(res.body.data.items).toHaveLength(2);
    expect(res.body.data.total).toBe(2);
    expect(res.body.data.totalPages).toBe(1);
    expect(JSON.stringify(res.body)).not.toContain("passwordHash");
    expect(JSON.stringify(res.body)).not.toContain("must-never-appear");
  });

  it("forwards search and status filters to the query", async () => {
    userModel.countDocuments.mockResolvedValue(0);
    userModel.find.mockReturnValue(leanChain([]));

    const res = await request(app)
      .get("/api/admin/users?search=keefe&status=active&page=2&limit=5")
      .set("Authorization", `Bearer ${adminToken()}`);

    expect(res.status).toBe(200);
    expect(userModel.countDocuments).toHaveBeenCalledWith(
      expect.objectContaining({ status: "active", $or: expect.any(Array) }),
    );
  });

  it("rejects an invalid status filter with 400", async () => {
    const res = await request(app)
      .get("/api/admin/users?status=bogus")
      .set("Authorization", `Bearer ${adminToken()}`);
    expect(res.status).toBe(400);
    expect(res.body.code).toBe("INVALID_QUERY");
  });

  it("rejects an out-of-range page limit with 400", async () => {
    const res = await request(app)
      .get("/api/admin/users?limit=5000")
      .set("Authorization", `Bearer ${adminToken()}`);
    expect(res.status).toBe(400);
  });
});

describe("PATCH /api/admin/users/:id/status", () => {
  it("rejects an invalid status value with 400", async () => {
    const res = await request(app)
      .patch("/api/admin/users/user-1/status")
      .set("Authorization", `Bearer ${adminToken()}`)
      .send({ status: "banned" });
    expect(res.status).toBe(400);
    expect(res.body.code).toBe("INVALID_BODY");
  });

  it("refuses to deactivate your own account", async () => {
    const res = await request(app)
      .patch("/api/admin/users/admin-1/status")
      .set("Authorization", `Bearer ${adminToken()}`)
      .send({ status: "disabled" });
    expect(res.status).toBe(400);
    expect(res.body.code).toBe("SELF_DEACTIVATION");
  });

  it("returns 404 for an unknown user", async () => {
    userModel.findById.mockReturnValue(leanChain(null));
    const res = await request(app)
      .patch("/api/admin/users/unknown/status")
      .set("Authorization", `Bearer ${adminToken()}`)
      .send({ status: "disabled" });
    expect(res.status).toBe(404);
  });

  it("refuses to deactivate the last active administrator", async () => {
    userModel.findById.mockReturnValue(
      leanChain({ _id: "admin-2", role: "admin", status: "active" }),
    );
    userModel.countDocuments.mockResolvedValue(1); // one active admin

    const res = await request(app)
      .patch("/api/admin/users/admin-2/status")
      .set("Authorization", `Bearer ${adminToken()}`)
      .send({ status: "disabled" });
    expect(res.status).toBe(409);
    expect(res.body.code).toBe("LAST_ADMIN");
  });

  it("activates a disabled standard account", async () => {
    userModel.findById.mockReturnValue(
      leanChain({ _id: "user-2", role: "user", status: "disabled" }),
    );
    userModel.findByIdAndUpdate.mockReturnValue(
      leanChain({
        _id: "user-2",
        name: "Wei",
        email: "wei@auxilia.demo",
        role: "user",
        status: "active",
        createdAt: new Date("2026-10-01T00:00:00Z"),
        lastLoginAt: null,
      }),
    );

    const res = await request(app)
      .patch("/api/admin/users/user-2/status")
      .set("Authorization", `Bearer ${adminToken()}`)
      .send({ status: "active" });

    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe("active");
  });
});

describe("GET /api/admin/stats", () => {
  it("aggregates real database data into platform statistics", async () => {
    const recent = new Date();
    recent.setUTCDate(recent.getUTCDate() - 3);
    const recentKey = recent.toISOString().slice(0, 10);

    userModel.aggregate.mockResolvedValueOnce([
      { _id: "active", count: 3 },
      { _id: "disabled", count: 1 },
    ]);
    userModel.countDocuments.mockResolvedValue(2); // new in last 7 days
    taskModel.aggregate
      .mockResolvedValueOnce([
        { _id: "todo", count: 7 },
        { _id: "completed", count: 10 },
        { _id: "in_progress", count: 3 },
      ])
      .mockResolvedValueOnce([{ _id: recentKey, count: 3 }])
      .mockResolvedValueOnce([{ _id: recentKey, count: 2 }]);
    taskModel.countDocuments
      .mockResolvedValueOnce(5) // created in last 7 days
      .mockResolvedValueOnce(4); // completed in last 7 days

    const res = await request(app)
      .get("/api/admin/stats")
      .set("Authorization", `Bearer ${adminToken()}`);

    expect(res.status).toBe(200);
    expect(res.body.data.users).toEqual({
      total: 4,
      active: 3,
      disabled: 1,
      pending: 0,
      newLast7Days: 2,
    });
    expect(res.body.data.tasks.total).toBe(20);
    expect(res.body.data.tasks.completionRate).toBeCloseTo(10 / 20, 4);
    expect(res.body.data.taskCreationTrend).toHaveLength(14);
    expect(res.body.data.taskCompletionTrend).toHaveLength(14);
    expect(
      res.body.data.taskCreationTrend.find(
        (p: { date: string }) => p.date === recentKey,
      )?.count,
    ).toBe(3);
  });
});

describe("GET /metrics", () => {
  const originalToken = process.env.METRICS_TOKEN;

  afterEach(() => {
    process.env.METRICS_TOKEN = originalToken;
  });

  it("requires a bearer token when METRICS_TOKEN is configured", async () => {
    process.env.METRICS_TOKEN = "test-metrics-token";
    const res = await request(app).get("/metrics");
    expect(res.status).toBe(401);
  });

  it("serves Prometheus metrics to the configured scraper", async () => {
    process.env.METRICS_TOKEN = "test-metrics-token";
    const res = await request(app)
      .get("/metrics")
      .set("Authorization", "Bearer test-metrics-token");
    expect(res.status).toBe(200);
    expect(res.text).toContain("auxilia_http_requests_total");
    expect(res.text).toContain("auxilia_db_connected");
  });
});
