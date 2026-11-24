import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  cacheDelByPattern: vi.fn(async () => 2),
  sendNotification: vi.fn(async () => true),
  createInApp: vi.fn(async () => ({ _id: "n1" })),
  info: vi.fn(),
  warn: vi.fn(),
  error: vi.fn(),
}));

vi.mock("../../../src/shared/utils/cache.js", () => ({
  cacheDelByPattern: mocks.cacheDelByPattern,
}));

vi.mock("../../../src/services/notification.service.js", () => ({
  sendNotification: mocks.sendNotification,
}));

vi.mock("../../../src/modules/notifications/notification.service.js", () => ({
  notificationService: { create: mocks.createInApp },
}));

vi.mock("../../../src/config/logger.js", () => ({
  default: { info: mocks.info, warn: mocks.warn, error: mocks.error },
}));

const flush = async () => {
  await new Promise((r) => setImmediate(r));
  await new Promise((r) => setImmediate(r));
  await new Promise((r) => setImmediate(r));
};

describe("jobs queue", () => {
  beforeEach(() => {
    vi.resetModules();
    vi.clearAllMocks();
    mocks.cacheDelByPattern.mockResolvedValue(2);
    mocks.sendNotification.mockResolvedValue(true);
    mocks.createInApp.mockResolvedValue({ _id: "n1" });
  });

  it("registers built-in jobs and enqueues notification", async () => {
    const jobs = await import("../../../src/shared/jobs/index.js");
    const ok = jobs.enqueue("notification.send", {
      to: "a@b.com",
      message: "hi",
    });
    expect(ok).toBe(true);
    await flush();
    expect(mocks.sendNotification).toHaveBeenCalled();
    expect(jobs.getJobStats().enqueued).toBeGreaterThanOrEqual(1);
  });

  it("persists in-app notification when userId is present", async () => {
    const jobs = await import("../../../src/shared/jobs/index.js");
    jobs.enqueue("notification.send", {
      userId: "u1",
      to: "a@b.com",
      subject: "Hello",
      message: "body",
      type: "task",
      entityId: "e1",
    });
    await flush();
    expect(mocks.createInApp).toHaveBeenCalledWith("u1", {
      type: "task",
      title: "Hello",
      body: "body",
      entityId: "e1",
    });
    expect(mocks.sendNotification).toHaveBeenCalled();
  });

  it("uses defaults for in-app notification optional fields", async () => {
    const jobs = await import("../../../src/shared/jobs/index.js");
    jobs.enqueue("notification.send", {
      userId: "u1",
      to: "a@b.com",
      message: "body",
    });
    await flush();
    expect(mocks.createInApp).toHaveBeenCalledWith("u1", {
      type: "system",
      title: "Notification",
      body: "body",
      entityId: null,
    });
  });

  it("logs warning when in-app persistence fails but still delivers", async () => {
    mocks.createInApp.mockRejectedValueOnce(new Error("db down"));
    const jobs = await import("../../../src/shared/jobs/index.js");
    jobs.enqueue("notification.send", {
      userId: "u1",
      to: "a@b.com",
      message: "body",
    });
    await flush();
    expect(mocks.warn).toHaveBeenCalledWith(
      "notification.in_app_persist_failed",
      expect.objectContaining({ userId: "u1", error: "db down" }),
    );
    expect(mocks.sendNotification).toHaveBeenCalled();
  });

  it("logs stringified non-Error persistence failures", async () => {
    mocks.createInApp.mockRejectedValueOnce("boom");
    const jobs = await import("../../../src/shared/jobs/index.js");
    jobs.enqueue("notification.send", { userId: "u1", to: "a@b.com", message: "x" });
    await flush();
    expect(mocks.warn).toHaveBeenCalledWith(
      "notification.in_app_persist_failed",
      expect.objectContaining({ error: "boom" }),
    );
  });

  it("enqueues analytics invalidation and handles unknown jobs", async () => {
    const jobs = await import("../../../src/shared/jobs/index.js");
    expect(jobs.enqueue("missing.job", {})).toBe(false);
    expect(mocks.warn).toHaveBeenCalledWith("job.unknown", { name: "missing.job" });
    expect(jobs.enqueue("analytics.invalidate", { userId: "u1" })).toBe(true);
    await flush();
    expect(mocks.cacheDelByPattern).toHaveBeenCalledWith(
      "analytics:v1:weekly:u1:*",
    );
  });

  it("records failed jobs when handler throws", async () => {
    mocks.sendNotification.mockRejectedValueOnce(new Error("smtp down"));
    const jobs = await import("../../../src/shared/jobs/index.js");
    jobs.enqueue("notification.send", { to: "a@b.com", message: "hi" });
    await flush();
    expect(jobs.getJobStats().failed).toBeGreaterThanOrEqual(1);
    expect(mocks.error).toHaveBeenCalledWith(
      "job.failed",
      expect.objectContaining({ name: "notification.send", error: "smtp down" }),
    );
  });

  it("records failed jobs with stringified non-Error", async () => {
    mocks.sendNotification.mockRejectedValueOnce("fail");
    const jobs = await import("../../../src/shared/jobs/index.js");
    jobs.enqueue("notification.send", { to: "a@b.com", message: "hi" });
    await flush();
    expect(mocks.error).toHaveBeenCalledWith(
      "job.failed",
      expect.objectContaining({ error: "fail" }),
    );
  });
});
