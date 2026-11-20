import { describe, expect, it } from "vitest";
import {
  AppError,
  badRequest,
  conflict,
  forbidden,
  notFound,
  sessionReplaced,
  unauthorized,
} from "../../src/shared/utils/AppError";

describe("AppError", () => {
  it("is a real Error subclass with the expected prototype chain", () => {
    const err = new AppError(500, "INTERNAL", "boom");
    expect(err).toBeInstanceOf(AppError);
    expect(err).toBeInstanceOf(Error);
    expect(err.name).toBe("AppError");
  });

  it("carries status, code, message and optional details", () => {
    const err = new AppError(422, "UNPROCESSABLE", "bad input", {
      field: "age",
    });
    expect(err.status).toBe(422);
    expect(err.code).toBe("UNPROCESSABLE");
    expect(err.message).toBe("bad input");
    expect(err.details).toEqual({ field: "age" });
  });

  it("leaves details undefined when not provided", () => {
    const err = new AppError(500, "INTERNAL", "boom");
    expect(err.details).toBeUndefined();
  });

  it("unauthorized() builds a 401 UNAUTHORIZED with the default message", () => {
    const err = unauthorized();
    expect(err.status).toBe(401);
    expect(err.code).toBe("UNAUTHORIZED");
    expect(err.message).toBe("Authentication required");
  });

  it("unauthorized() accepts a custom message", () => {
    expect(unauthorized("Nope").message).toBe("Nope");
  });

  it("forbidden() builds a 403 FORBIDDEN with the default message", () => {
    const err = forbidden();
    expect(err.status).toBe(403);
    expect(err.code).toBe("FORBIDDEN");
    expect(err.message).toBe("Insufficient permissions");
  });

  it("conflict() builds a 409 CONFLICT with the given message", () => {
    const err = conflict("already exists");
    expect(err.status).toBe(409);
    expect(err.code).toBe("CONFLICT");
    expect(err.message).toBe("already exists");
  });

  it("sessionReplaced() builds the SESSION_REPLACED envelope", () => {
    const err = sessionReplaced();
    expect(err.status).toBe(401);
    expect(err.code).toBe("SESSION_REPLACED");
    expect(err.message).toContain("another device");
  });

  it("badRequest() builds a 400 BAD_REQUEST with the default message", () => {
    const err = badRequest();
    expect(err.status).toBe(400);
    expect(err.code).toBe("BAD_REQUEST");
    expect(err.message).toBe("Invalid request");
  });

  it("badRequest() accepts a custom message", () => {
    expect(badRequest("Pick a bigger field").message).toBe(
      "Pick a bigger field",
    );
  });

  it("notFound() builds a 404 NOT_FOUND with the default message", () => {
    const err = notFound();
    expect(err.status).toBe(404);
    expect(err.code).toBe("NOT_FOUND");
    expect(err.message).toBe("Not found");
  });
});
