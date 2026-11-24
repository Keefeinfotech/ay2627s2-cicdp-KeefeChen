import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  cacheDelByPattern: vi.fn(async () => 2),
  sendNotification: vi.fn(async () => true),
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

vi.mock("../../../src/config/logger.js", () => ({
  default: { info: mocks.info, warn: mocks.warn, error: mocks.error },
}));

describe("jobs queue", () => {
  beforeEach(() => {
    vi.resetModules();
    vi.clearAllMocks();
  });

  it("registers built-in jobs and enqueues notification", async () => {
    const jobs = await import("../../../src/shared/jobs/index.js");
    const ok = jobs.enqueue("notification.send", { to: "a@b.com", message: "hi" });
    expect(ok).toBe(true);
    await new Promise((r) => setImmediate(r));
    await new Promise((r) => setImmediate(r));
    expect(mocks.sendNotification).toHaveBeenCalled();
    expect(jobs.getJobStats().enqueued).toBeGreaterThanOrEqual(1);
  });

  it("enqueues analytics invalidation and handles unknown jobs", async () => {
    const jobs = await import("../../../src/shared/jobs/index.js");
    expect(jobs.enqueue("missing.job", {})).toBe(false);
    expect(jobs.enqueue("analytics.invalidate", { userId: "u1" })).toBe(true);
    await new Promise((r) => setImmediate(r));
    await new Promise((r) => setImmediate(r));
    expect(mocks.cacheDelByPattern).toHaveBeenCalledWith("analytics:v1:weekly:u1:*");
  });
});
