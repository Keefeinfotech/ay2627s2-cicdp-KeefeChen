import { describe, expect, it, vi } from "vitest";
import {
  getTasksQuerySchema,
  validateGetTasks,
} from "../../../src/validators/task.validator";

/**
 * Design-technique tests for task query validation.
 * Techniques: Equivalence Partitioning (EP), Boundary Value Analysis (BVA),
 * and Use Case Testing (UC).
 */
describe("task query validation - design techniques", () => {
  describe("EP/BVA: pagination 'page' (positive integer, default 1)", () => {
    it("EP-valid: typical page number is accepted", () => {
      const result = getTasksQuerySchema.safeParse({ page: "3" });
      expect(result.success).toBe(true);
      if (result.success) expect(result.data.page).toBe(3);
    });

    it("BVA-lower boundary: page=1 (minimum valid) is accepted", () => {
      const result = getTasksQuerySchema.safeParse({ page: "1" });
      expect(result.success).toBe(true);
      if (result.success) expect(result.data.page).toBe(1);
    });

    it("BVA-just below minimum: page=0 is rejected", () => {
      const result = getTasksQuerySchema.safeParse({ page: "0" });
      expect(result.success).toBe(false);
    });

    it("EP-invalid: negative page is rejected", () => {
      const result = getTasksQuerySchema.safeParse({ page: "-1" });
      expect(result.success).toBe(false);
    });

    it("EP-default: omitted page defaults to 1", () => {
      const result = getTasksQuerySchema.safeParse({});
      expect(result.success).toBe(true);
      if (result.success) expect(result.data.page).toBe(1);
    });
  });

  describe("EP/BVA: pagination 'limit' (1..100, default 20)", () => {
    it("BVA-lower boundary: limit=1 (minimum valid) is accepted", () => {
      const result = getTasksQuerySchema.safeParse({ limit: "1" });
      expect(result.success).toBe(true);
      if (result.success) expect(result.data.limit).toBe(1);
    });

    it("BVA-just below minimum: limit=0 is rejected", () => {
      const result = getTasksQuerySchema.safeParse({ limit: "0" });
      expect(result.success).toBe(false);
    });

    it("BVA-upper boundary: limit=100 (maximum valid) is accepted", () => {
      const result = getTasksQuerySchema.safeParse({ limit: "100" });
      expect(result.success).toBe(true);
      if (result.success) expect(result.data.limit).toBe(100);
    });

    it("BVA-just above maximum: limit=101 is rejected", () => {
      const result = getTasksQuerySchema.safeParse({ limit: "101" });
      expect(result.success).toBe(false);
    });

    it("EP-invalid: non-integer limit is rejected", () => {
      const result = getTasksQuerySchema.safeParse({ limit: "10.5" });
      expect(result.success).toBe(false);
    });
  });

  describe("EP: status and priority enumerations", () => {
    it.each(["TODO", "IN_PROGRESS", "COMPLETED"])(
      "EP-valid status '%s' is accepted",
      (status) => {
        const result = getTasksQuerySchema.safeParse({ status });
        expect(result.success).toBe(true);
      },
    );

    it("EP-invalid status value is rejected", () => {
      const result = getTasksQuerySchema.safeParse({ status: "ARCHIVED" });
      expect(result.success).toBe(false);
    });

    it.each(["LOW", "MEDIUM", "HIGH"])(
      "EP-valid priority '%s' is accepted",
      (priority) => {
        const result = getTasksQuerySchema.safeParse({ priority });
        expect(result.success).toBe(true);
      },
    );

    it("EP-invalid priority value is rejected", () => {
      const result = getTasksQuerySchema.safeParse({ priority: "URGENT" });
      expect(result.success).toBe(false);
    });
  });

  describe("UC: retrieve filtered task list (query middleware use case)", () => {
    function mockRes() {
      return {
        status: vi.fn().mockReturnThis(),
        json: vi.fn().mockReturnThis(),
        locals: {} as Record<string, unknown>,
      } as any;
    }

    it("UC-main success: valid filters parsed, stored in res.locals, next() called", () => {
      const req: any = {
        query: { status: "TODO", priority: "HIGH", page: "2", limit: "10" },
      };
      const res = mockRes();
      const next = vi.fn();

      validateGetTasks(req, res, next);

      expect(next).toHaveBeenCalledTimes(1);
      expect(res.status).not.toHaveBeenCalled();
      expect(res.locals.taskFilters).toEqual({
        status: "TODO",
        priority: "HIGH",
        page: 2,
        limit: 10,
      });
    });

    it("UC-alternate/exception: invalid query returns 400 and blocks request", () => {
      const req: any = { query: { status: "TODO", limit: "101" } };
      const res = mockRes();
      const next = vi.fn();

      validateGetTasks(req, res, next);

      expect(next).not.toHaveBeenCalled();
      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: false,
          message: "Invalid query parameters.",
        }),
      );
      expect(res.locals.taskFilters).toBeUndefined();
    });
  });
});
