import { beforeEach, describe, expect, it, vi } from "vitest";

const { registerMock, counterMock, histogramMock, gaugeMock } = vi.hoisted(
  () => {
    const counter = { inc: vi.fn() };
    const timer = vi.fn();
    const histogram = { startTimer: vi.fn(() => timer) };
    const gauge = { set: vi.fn() };
    const register = {
      contentType: "text/plain",
      metrics: vi.fn().mockResolvedValue("metrics"),
    };
    return {
      registerMock: register,
      counterMock: counter,
      histogramMock: histogram,
      gaugeMock: gauge,
    };
  },
);

vi.mock("prom-client", () => ({
  default: {
    collectDefaultMetrics: vi.fn(),
    Counter: vi.fn().mockImplementation(function () {
      return counterMock;
    }),
    Histogram: vi.fn().mockImplementation(function () {
      return histogramMock;
    }),
    Gauge: vi.fn().mockImplementation(function () {
      return gaugeMock;
    }),
    register: registerMock,
  },
}));

vi.mock("mongoose", () => ({
  default: { connection: { readyState: 1 } },
}));

vi.mock("../../../../src/middleware/authenticate.js", () => ({
  authenticate: vi.fn((_req: any, _res: any, next: any) => next()),
}));

vi.mock("../../../../src/middleware/authorize.js", () => ({
  authorize: vi.fn(() => (_req: any, _res: any, next: any) => next()),
}));

import {
  metricsMiddleware,
  metricsGuard,
  metricsHandler,
} from "../../../../src/modules/metrics/metrics.js";

const mkRes = () => {
  const handlers: Record<string, Function> = {};
  return {
    statusCode: 200,
    on: vi.fn((event: string, cb: Function) => {
      handlers[event] = cb;
    }),
    set: vi.fn(),
    send: vi.fn(),
    emit: (event: string) => handlers[event]?.(),
  } as any;
};

describe("metrics", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    delete process.env.METRICS_TOKEN;
  });

  it("records http metrics on finish", () => {
    const req: any = {
      method: "GET",
      originalUrl: "/api/tasks/123e4567-e89b-12d3-a456-426614174000?x=1",
    };
    const res = mkRes();
    const next = vi.fn();

    metricsMiddleware(req, res, next);
    expect(next).toHaveBeenCalled();
    res.emit("finish");

    expect(counterMock.inc).toHaveBeenCalledWith(
      expect.objectContaining({ method: "GET", status_code: "200" }),
    );
    const timer = histogramMock.startTimer.mock.results[0].value;
    expect(timer).toHaveBeenCalled();
  });

  it("allows metrics with valid bearer token", () => {
    process.env.METRICS_TOKEN = "secret";
    const req: any = { headers: { authorization: "Bearer secret" } };
    const next = vi.fn();
    metricsGuard(req, mkRes(), next);
    expect(next).toHaveBeenCalledWith();
  });

  it("rejects metrics with invalid bearer token", () => {
    process.env.METRICS_TOKEN = "secret";
    const req: any = { headers: { authorization: "Bearer wrong" } };
    const next = vi.fn();
    metricsGuard(req, mkRes(), next);
    expect(next).toHaveBeenCalledWith(expect.objectContaining({ status: 401 }));
  });

  it("falls back to admin auth when no token configured", async () => {
    const req: any = { headers: {} };
    const next = vi.fn();
    metricsGuard(req, mkRes(), next);
    // authenticate is mocked to call next immediately; authorize mock also calls next
    await vi.waitFor(() => expect(next).toHaveBeenCalled());
  });

  it("renders metrics", async () => {
    const res = mkRes();
    const next = vi.fn();
    await metricsHandler({} as never, res, next);
    expect(gaugeMock.set).toHaveBeenCalledWith(1);
    expect(res.set).toHaveBeenCalledWith("Content-Type", "text/plain");
    expect(res.send).toHaveBeenCalledWith("metrics");
    expect(next).not.toHaveBeenCalled();
  });
});
