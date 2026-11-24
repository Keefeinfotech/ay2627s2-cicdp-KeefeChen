import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => {
  const listeners: Record<string, Function[]> = {};
  const client = {
    connect: vi.fn(async () => undefined),
    quit: vi.fn(async () => "OK"),
    disconnect: vi.fn(),
    on: vi.fn((event: string, fn: Function) => {
      listeners[event] = listeners[event] || [];
      listeners[event].push(fn);
      return client;
    }),
    __listeners: listeners,
  };
  const RedisCtor = vi.fn(function Redis(this: any) {
    return client;
  });
  return {
    client,
    RedisCtor,
    getRedisUrl: vi.fn(),
    warn: vi.fn(),
  };
});

vi.mock("ioredis", () => ({ default: mocks.RedisCtor }));
vi.mock("../../../src/config/environment.js", () => ({
  getRedisUrl: mocks.getRedisUrl,
}));
vi.mock("../../../src/config/logger.js", () => ({
  default: { warn: mocks.warn },
}));

const loadRedis = async () => {
  vi.resetModules();
  // reapply mocks after resetModules by re-mocking? vi.mock is hoisted, so it persists.
  return import("../../../src/config/redis.js");
};

describe("redis config", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.client.__listeners.error = [];
    mocks.getRedisUrl.mockReturnValue(null);
    mocks.client.connect.mockResolvedValue(undefined);
    mocks.client.quit.mockResolvedValue("OK");
  });

  it("returns null when REDIS_URL is not configured", async () => {
    const redis = await loadRedis();
    expect(redis.getRedisClient()).toBeNull();
    await redis.connectRedis();
    expect(mocks.RedisCtor).not.toHaveBeenCalled();
  });

  it("creates and caches a client", async () => {
    mocks.getRedisUrl.mockReturnValue("redis://localhost:6379");
    const redis = await loadRedis();
    const c1 = redis.getRedisClient();
    const c2 = redis.getRedisClient();
    expect(c1).toBe(mocks.client);
    expect(c2).toBe(c1);
    expect(mocks.RedisCtor).toHaveBeenCalledTimes(1);
  });

  it("connectRedis connects and logs failures", async () => {
    mocks.getRedisUrl.mockReturnValue("redis://localhost:6379");
    const redis = await loadRedis();
    await redis.connectRedis();
    expect(mocks.client.connect).toHaveBeenCalled();

    vi.resetModules();
    mocks.getRedisUrl.mockReturnValue("redis://localhost:6379");
    mocks.client.connect.mockRejectedValueOnce(new Error("nope"));
    const redis2 = await loadRedis();
    await redis2.connectRedis();
    expect(mocks.warn).toHaveBeenCalledWith(
      "redis.connect_failed",
      expect.objectContaining({ error: "nope" }),
    );
  });

  it("connectRedis logs stringified non-Error", async () => {
    mocks.getRedisUrl.mockReturnValue("redis://localhost:6379");
    mocks.client.connect.mockRejectedValueOnce("bad");
    const redis = await loadRedis();
    await redis.connectRedis();
    expect(mocks.warn).toHaveBeenCalledWith(
      "redis.connect_failed",
      expect.objectContaining({ error: "bad" }),
    );
  });

  it("closeRedisClient noops when no client, quits, and disconnects on quit failure", async () => {
    const redis = await loadRedis();
    await redis.closeRedisClient();
    expect(mocks.client.quit).not.toHaveBeenCalled();

    mocks.getRedisUrl.mockReturnValue("redis://localhost:6379");
    const redis2 = await loadRedis();
    redis2.getRedisClient();
    await redis2.closeRedisClient();
    expect(mocks.client.quit).toHaveBeenCalled();

    vi.resetModules();
    mocks.getRedisUrl.mockReturnValue("redis://localhost:6379");
    mocks.client.quit.mockRejectedValueOnce(new Error("quit fail"));
    const redis3 = await loadRedis();
    redis3.getRedisClient();
    await redis3.closeRedisClient();
    expect(mocks.client.disconnect).toHaveBeenCalled();
  });

  it("throttles connection error logging", async () => {
    mocks.getRedisUrl.mockReturnValue("redis://localhost:6379");
    const nowSpy = vi.spyOn(Date, "now");
    nowSpy.mockReturnValue(1_000_000);
    const redis = await loadRedis();
    redis.getRedisClient();
    const handler = mocks.client.on.mock.calls.find((c: any[]) => c[0] === "error")?.[1];
    expect(handler).toBeTypeOf("function");
    handler(new Error("e1"));
    handler(new Error("e2"));
    expect(mocks.warn).toHaveBeenCalledTimes(1);
    nowSpy.mockReturnValue(1_000_000 + 31_000);
    handler(new Error("e3"));
    expect(mocks.warn).toHaveBeenCalledTimes(2);
    nowSpy.mockRestore();
  });
});
