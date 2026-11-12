import type { NextFunction, Request, Response } from "express";
import { afterEach, describe, expect, it, vi } from "vitest";
import { authorize } from "../../src/middleware/authorize";
import { AppError } from "../../src/shared/utils/AppError";
import { requireUserId } from "../../src/shared/utils/request";

const mockRequest = (overrides: Partial<Request> = {}): Request =>
  ({ requestId: "req-1", ...overrides }) as Request;

afterEach(() => {
  vi.restoreAllMocks();
});

describe("authorize", () => {
  it("rejects an unauthenticated request", () => {
    const next = vi.fn();
    authorize("admin")(mockRequest(), {} as Response, next as NextFunction);
    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ status: 401, code: "UNAUTHORIZED" }),
    );
  });

  it("rejects a role that is not allowed", () => {
    const next = vi.fn();
    expect(() =>
      authorize("admin")(
        mockRequest({ userId: "user-1", userRole: "user" }),
        {} as Response,
        next as NextFunction,
      ),
    ).not.toThrow();
    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ status: 403, code: "FORBIDDEN" }),
    );
    expect(next).toHaveBeenCalledTimes(1);
  });

  it("matches roles case-insensitively (upper-case call sites, lower-case storage)", () => {
    const next = vi.fn();
    authorize("ADMIN")(
      mockRequest({ userId: "user-1", userRole: "admin" }),
      {} as Response,
      next as NextFunction,
    );
    expect(next).toHaveBeenCalledTimes(1);
    expect(next).toHaveBeenCalledWith();
  });

  it("matches roles case-insensitively in the reverse direction", () => {
    const next = vi.fn();
    authorize("admin")(
      mockRequest({ userId: "user-1", userRole: "ADMIN" }),
      {} as Response,
      next as NextFunction,
    );
    expect(next).toHaveBeenCalledTimes(1);
  });

  it("allows an explicitly permitted role", () => {
    const next = vi.fn();
    authorize("admin")(
      mockRequest({ userId: "user-1", userRole: "admin" }),
      {} as Response,
      next as NextFunction,
    );
    expect(next).toHaveBeenCalledTimes(1);
  });

  it("allows any authenticated role when no roles are listed", () => {
    const next = vi.fn();
    authorize()(
      mockRequest({ userId: "user-1", userRole: "user" }),
      {} as Response,
      next as NextFunction,
    );
    expect(next).toHaveBeenCalledTimes(1);
  });
});

describe("requireUserId", () => {
  it("returns the authenticated user id", () => {
    expect(requireUserId(mockRequest({ userId: "user-1" }))).toBe("user-1");
  });

  it("throws when authentication middleware did not run", () => {
    expect(() => requireUserId(mockRequest())).toThrow(AppError);
  });
});
