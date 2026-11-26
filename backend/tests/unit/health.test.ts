import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  readyState: 1 as number,
  getRedisClient: vi.fn(),
  getRedisUrl: vi.fn(),
  ping: vi.fn(),
}));

vi.mock("mongoose", () => ({
  default: {
    connection: {
      get readyState() {
        return mocks.readyState;
      },
    },
  },
}));

vi.mock("../../src/config/redis.js", () => ({
  getRedisClient: mocks.getRedisClient,
}));

vi.mock("../../src/config/environment.js", () => ({
  getRedisUrl: mocks.getRedisUrl,
}));

import {
  healthCheck,
  livenessCheck,
  readinessCheck,
} from "../../src/modules/health/health.controller.js";

const createRes = () => {
  const res: any = {};
  res.status = vi.fn().mockReturnValue(res);
  res.json = vi.fn().mockReturnValue(res);
  return res;
};

describe("health controller", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.readyState = 1;
    mocks.getRedisUrl.mockReturnValue(undefined);
    mocks.getRedisClient.mockReturnValue(null);
    mocks.ping.mockResolvedValue("PONG");
  });

  it("healthCheck returns ok", () => {
    const res = createRes();
    healthCheck({} as any, res);
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      status: "ok",
      service: "personal-secretary-api",
    });
  });

  it("livenessCheck returns ok", () => {
    const res = createRes();
    livenessCheck({} as any, res);
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({ status: "ok" });
  });

  it("readinessCheck returns ready when mongo connected and redis not configured", async () => {
    const res = createRes();
    await readinessCheck({} as any, res);
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      status: "ready",
      checks: { mongodb: "ok", redis: "not_configured" },
    });
  });

  it("readinessCheck returns 503 when mongo disconnected", async () => {
    mocks.readyState = 0;
    const res = createRes();
    await readinessCheck({} as any, res);
    expect(res.status).toHaveBeenCalledWith(503);
    expect(res.json).toHaveBeenCalledWith({
      status: "not_ready",
      checks: { mongodb: "unavailable", redis: "not_configured" },
    });
  });

  it("readinessCheck reports redis ok when ping succeeds", async () => {
    mocks.getRedisUrl.mockReturnValue("redis://localhost:6379");
    mocks.getRedisClient.mockReturnValue({ ping: mocks.ping });
    const res = createRes();
    await readinessCheck({} as any, res);
    expect(mocks.ping).toHaveBeenCalled();
    expect(res.json).toHaveBeenCalledWith({
      status: "ready",
      checks: { mongodb: "ok", redis: "ok" },
    });
  });

  it("readinessCheck reports redis unavailable when ping throws", async () => {
    mocks.getRedisUrl.mockReturnValue("redis://localhost:6379");
    mocks.getRedisClient.mockReturnValue({
      ping: mocks.ping.mockRejectedValue(new Error("down")),
    });
    const res = createRes();
    await readinessCheck({} as any, res);
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      status: "ready",
      checks: { mongodb: "ok", redis: "unavailable" },
    });
  });

  it("readinessCheck reports redis unavailable when configured but client missing", async () => {
    mocks.getRedisUrl.mockReturnValue("redis://localhost:6379");
    mocks.getRedisClient.mockReturnValue(null);
    const res = createRes();
    await readinessCheck({} as any, res);
    expect(res.json).toHaveBeenCalledWith({
      status: "ready",
      checks: { mongodb: "ok", redis: "unavailable" },
    });
  });
});
