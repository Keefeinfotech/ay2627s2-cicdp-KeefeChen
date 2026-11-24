import { describe, expect, it, vi } from "vitest";

vi.mock("../../../src/shared/utils/securityLogger.js", () => ({
  logServerError: vi.fn(),
}));

import { AppError } from "../../../src/shared/utils/AppError.js";
import { errorHandler } from "../../../src/middleware/errorHandler.js";
import { logServerError } from "../../../src/shared/utils/securityLogger.js";

const mkRes = () => {
  const res: any = {
    headersSent: false,
    status: vi.fn().mockReturnThis(),
    json: vi.fn().mockReturnThis(),
  };
  return res;
};

describe("errorHandler", () => {
  it("passes through when headers already sent", () => {
    const err = new Error("boom");
    const res = mkRes();
    res.headersSent = true;
    const next = vi.fn();

    errorHandler(err, { requestId: "r1", method: "GET", path: "/x" } as never, res, next);

    expect(next).toHaveBeenCalledWith(err);
    expect(res.status).not.toHaveBeenCalled();
  });

  it("handles AppError with details", () => {
    const err = new AppError(422, "BAD", "Nope", { field: "x" });
    const res = mkRes();
    errorHandler(err, {} as never, res, vi.fn());
    expect(res.status).toHaveBeenCalledWith(422);
    expect(res.json).toHaveBeenCalledWith({ error: "Nope", code: "BAD", details: { field: "x" } });
  });

  it("handles AppError without details", () => {
    const err = new AppError(400, "BAD", "Nope");
    const res = mkRes();
    errorHandler(err, {} as never, res, vi.fn());
    expect(res.json).toHaveBeenCalledWith({ error: "Nope", code: "BAD" });
  });

  it("handles invalid JSON body parse errors", () => {
    const res = mkRes();
    errorHandler({ type: "entity.parse.failed" }, {} as never, res, vi.fn());
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({ error: "Request body must be valid JSON", code: "INVALID_JSON" });
  });

  it("handles entity too large errors", () => {
    const res = mkRes();
    errorHandler({ type: "entity.too.large" }, {} as never, res, vi.fn());
    expect(res.status).toHaveBeenCalledWith(413);
  });

  it("handles 413 status errors", () => {
    const res = mkRes();
    errorHandler({ status: 413 }, {} as never, res, vi.fn());
    expect(res.status).toHaveBeenCalledWith(413);
  });

  it("handles errors with statusCode", () => {
    const res = mkRes();
    errorHandler({ statusCode: 418, message: "Teapot", code: "TEAPOT" }, {} as never, res, vi.fn());
    expect(res.status).toHaveBeenCalledWith(418);
    expect(res.json).toHaveBeenCalledWith({ error: "Teapot", code: "TEAPOT" });
  });

  it("handles duplicate key errors", () => {
    const res = mkRes();
    errorHandler({ code: 11000, name: "MongoServerError" }, {} as never, res, vi.fn());
    expect(res.status).toHaveBeenCalledWith(409);
    expect(res.json).toHaveBeenCalledWith({ error: "Resource already exists", code: "CONFLICT" });
  });

  it("handles mongoose validation errors", () => {
    const res = mkRes();
    errorHandler({ name: "ValidationError" }, {} as never, res, vi.fn());
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({ error: "Validation failed", code: "VALIDATION_ERROR" });
  });

  it("logs and returns 500 for unknown errors", () => {
    const res = mkRes();
    errorHandler(new Error("secret"), { requestId: "r1", method: "GET", path: "/x" } as never, res, vi.fn());
    expect(logServerError).toHaveBeenCalledWith(expect.objectContaining({ requestId: "r1", error: "secret" }));
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({ error: "Internal server error", code: "INTERNAL_ERROR" });
  });

  it("handles unknown non-error throws", () => {
    const res = mkRes();
    errorHandler("boom", { requestId: "r1", method: "GET", path: "/x" } as never, res, vi.fn());
    expect(res.status).toHaveBeenCalledWith(500);
  });
});
