import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  get: vi.fn(),
  set: vi.fn(),
  del: vi.fn(),
  scan: vi.fn(),
  quit: vi.fn(),
  getRedisClient: vi.fn(),
  warn: vi.fn(),
}));

vi.mock("../../../src/config/redis.js", () => ({
  getRedisClient: mocks.getRedisClient,
}));

vi.mock("../../../src/config/logger.js", () => ({
  default: { warn: mocks.warn, info: vi.fn(), error: vi.fn() },
}));

import { cacheGetJson, cacheSetJson, cacheDel, cacheDelByPattern } from "../../../src/shared/utils/cache.js";

describe("cache utils", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("cacheGetJson returns null when redis unavailable", async () => {
    mocks.getRedisClient.mockReturnValue(null);
    await expect(cacheGetJson("k")).resolves.toBeNull();
  });

  it("cacheGetJson returns parsed value", async () => {
    mocks.getRedisClient.mockReturnValue({ get: mocks.get });
    mocks.get.mockResolvedValue(JSON.stringify({ a: 1 }));
    await expect(cacheGetJson("k")).resolves.toEqual({ a: 1 });
  });

  it("cacheGetJson returns null on miss", async () => {
    mocks.getRedisClient.mockReturnValue({ get: mocks.get });
    mocks.get.mockResolvedValue(null);
    await expect(cacheGetJson("k")).resolves.toBeNull();
  });

  it("cacheGetJson fails open on error", async () => {
    mocks.getRedisClient.mockReturnValue({ get: mocks.get });
    mocks.get.mockRejectedValue(new Error("redis down"));
    await expect(cacheGetJson("k")).resolves.toBeNull();
    expect(mocks.warn).toHaveBeenCalled();
  });

  it("cacheSetJson noops when redis unavailable", async () => {
    mocks.getRedisClient.mockReturnValue(null);
    await expect(cacheSetJson("k", { a: 1 }, 60)).resolves.toBeUndefined();
  });

  it("cacheSetJson writes json with ttl", async () => {
    mocks.getRedisClient.mockReturnValue({ set: mocks.set });
    mocks.set.mockResolvedValue("OK");
    await cacheSetJson("k", { a: 1 }, 60);
    expect(mocks.set).toHaveBeenCalledWith("k", JSON.stringify({ a: 1 }), "EX", 60);
  });

  it("cacheSetJson fails open on error", async () => {
    mocks.getRedisClient.mockReturnValue({ set: mocks.set });
    mocks.set.mockRejectedValue(new Error("boom"));
    await expect(cacheSetJson("k", 1, 60)).resolves.toBeUndefined();
    expect(mocks.warn).toHaveBeenCalled();
  });

  it("cacheDel noops when redis unavailable", async () => {
    mocks.getRedisClient.mockReturnValue(null);
    await expect(cacheDel("k")).resolves.toBeUndefined();
  });

  it("cacheDel deletes key", async () => {
    mocks.getRedisClient.mockReturnValue({ del: mocks.del });
    mocks.del.mockResolvedValue(1);
    await cacheDel("k");
    expect(mocks.del).toHaveBeenCalledWith("k");
  });

  it("cacheDel fails open on error", async () => {
    mocks.getRedisClient.mockReturnValue({ del: mocks.del });
    mocks.del.mockRejectedValue(new Error("boom"));
    await expect(cacheDel("k")).resolves.toBeUndefined();
  });

  it("cacheDelByPattern noops when redis unavailable", async () => {
    mocks.getRedisClient.mockReturnValue(null);
    await expect(cacheDelByPattern("p:*")).resolves.toBe(0);
  });

  it("cacheDelByPattern scans and deletes matches", async () => {
    mocks.scan.mockResolvedValueOnce(["2", ["a", "b"]]).mockResolvedValueOnce(["0", ["c"]]);
    mocks.del.mockResolvedValue(1);
    mocks.getRedisClient.mockReturnValue({ scan: mocks.scan, del: mocks.del });
    await cacheDelByPattern("p:*");
    expect(mocks.scan).toHaveBeenCalled();
    expect(mocks.del).toHaveBeenCalledWith("a", "b");
    expect(mocks.del).toHaveBeenCalledWith("c");
  });

  it("cacheDelByPattern fails open on error", async () => {
    mocks.getRedisClient.mockReturnValue({ scan: mocks.scan, del: mocks.del });
    mocks.scan.mockRejectedValue(new Error("boom"));
    await expect(cacheDelByPattern("p:*")).resolves.toBe(0);
    expect(mocks.warn).toHaveBeenCalled();
  });
});
