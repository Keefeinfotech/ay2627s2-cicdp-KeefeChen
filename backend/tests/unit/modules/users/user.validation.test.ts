/**
 * File Name: user.validation.test.ts
 * Description: Tests user request validation using equivalence partitioning.
 * Author: Keefe Chen
 */

import { describe, expect, it } from "vitest";

import {
  updateOwnProfileSchema,
  userIdParamSchema,
} from "../../../../src/modules/users/user.validation.js";

describe("User Validation", () => {
  describe("updateOwnProfileSchema", () => {
    // Valid equivalence partitions
    it("EP-N01: accepts a valid name", () => {
      const result = updateOwnProfileSchema.safeParse({
        body: { name: "Keefe" },
      });

      expect(result.success).toBe(true);
    });

    it("EP-N02: accepts a name with the minimum length", () => {
      const result = updateOwnProfileSchema.safeParse({
        body: { name: "Jo" },
      });

      expect(result.success).toBe(true);
    });

    it("EP-N03: accepts a name with the maximum length", () => {
      const result = updateOwnProfileSchema.safeParse({
        body: { name: "A".repeat(80) },
      });

      expect(result.success).toBe(true);
    });

    // Invalid equivalence partitions
    it("EP-N04: rejects a name shorter than 2 characters", () => {
      const result = updateOwnProfileSchema.safeParse({
        body: { name: "A" },
      });

      expect(result.success).toBe(false);
    });

    it("EP-N05: rejects a name longer than 80 characters", () => {
      const result = updateOwnProfileSchema.safeParse({
        body: { name: "A".repeat(81) },
      });

      expect(result.success).toBe(false);
    });

    it("EP-N06: rejects an empty name", () => {
      const result = updateOwnProfileSchema.safeParse({
        body: { name: "" },
      });

      expect(result.success).toBe(false);
    });

    it("EP-N07: rejects whitespace-only names", () => {
      const result = updateOwnProfileSchema.safeParse({
        body: { name: "   " },
      });

      expect(result.success).toBe(false);
    });

    it("EP-B01: rejects an empty request body", () => {
      const result = updateOwnProfileSchema.safeParse({
        body: {},
      });

      expect(result.success).toBe(false);
    });

    it("EP-B02: rejects unexpected protected fields", () => {
      const result = updateOwnProfileSchema.safeParse({
        body: {
          name: "Keefe",
          role: "admin",
        },
      });

      expect(result.success).toBe(false);
    });

    it("EP-B03: rejects an incorrect name data type", () => {
      const result = updateOwnProfileSchema.safeParse({
        body: { name: 123 },
      });

      expect(result.success).toBe(false);
    });

    it("EP-B04: rejects a null name", () => {
      const result = updateOwnProfileSchema.safeParse({
        body: { name: null },
      });

      expect(result.success).toBe(false);
    });
  });

  describe("userIdParamSchema", () => {
    it("EP-U01: accepts a valid UUID", () => {
      const result = userIdParamSchema.safeParse({
        params: {
          userId: "550e8400-e29b-41d4-a716-446655440000",
        },
      });

      expect(result.success).toBe(true);
    });

    it("EP-U02: rejects an invalid UUID format", () => {
      const result = userIdParamSchema.safeParse({
        params: { userId: "12345" },
      });

      expect(result.success).toBe(false);
    });

    it("EP-U03: rejects an empty UUID", () => {
      const result = userIdParamSchema.safeParse({
        params: { userId: "" },
      });

      expect(result.success).toBe(false);
    });

    it("EP-U04: rejects a missing UUID", () => {
      const result = userIdParamSchema.safeParse({
        params: {},
      });

      expect(result.success).toBe(false);
    });
  });
});