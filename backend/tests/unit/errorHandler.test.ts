import express from "express";
import request from "supertest";
import { afterEach, describe, expect, it, vi } from "vitest";
import { errorHandler } from "../../src/middleware/errorHandler";
import { requestId } from "../../src/middleware/requestId";
import { AppError } from "../../src/shared/utils/AppError";

const buildApp = (handler: express.RequestHandler) => {
  const app = express();
  app.use(requestId);
  app.get("/boom", handler);
  app.use(errorHandler);
  return app;
};

afterEach(() => {
  vi.restoreAllMocks();
});

describe("central error handler", () => {
  it("returns AppError details", async () => {
    const app = buildApp(() => {
      throw new AppError(403, "FORBIDDEN", "No access", [{ field: "role" }]);
    });
    const res = await request(app).get("/boom");

    expect(res.status).toBe(403);
    expect(res.body).toEqual({
      error: "No access",
      code: "FORBIDDEN",
      details: [{ field: "role" }],
    });
  });

  it("maps duplicate keys to a conflict without leaking the key", async () => {
    const app = buildApp(() => {
      throw Object.assign(new Error("E11000 duplicate"), {
        name: "MongoServerError",
        code: 11000,
        keyValue: { email: "ada@example.com" },
      });
    });
    const res = await request(app).get("/boom");

    expect(res.status).toBe(409);
    expect(res.body.code).toBe("CONFLICT");
    expect(JSON.stringify(res.body)).not.toContain("ada@example.com");
  });

  it("maps Mongoose validation failures to a 400", async () => {
    const app = buildApp(() => {
      throw Object.assign(new Error("bad document"), {
        name: "ValidationError",
      });
    });
    const res = await request(app).get("/boom");

    expect(res.status).toBe(400);
    expect(res.body.code).toBe("VALIDATION_ERROR");
  });

  it("hides unexpected error details", async () => {
    const warn = vi.spyOn(console, "error").mockImplementation(() => undefined);
    const app = buildApp(() => {
      throw new Error("database password leaked");
    });
    const res = await request(app).get("/boom");

    expect(res.status).toBe(500);
    expect(res.body).toEqual({
      error: "Internal server error",
      code: "INTERNAL_ERROR",
    });
    expect(JSON.stringify(res.body)).not.toContain("password");
    expect(warn).toHaveBeenCalledTimes(1);
  });
});
