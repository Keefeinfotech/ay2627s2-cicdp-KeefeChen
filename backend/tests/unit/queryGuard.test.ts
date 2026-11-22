import { describe, expect, it } from "vitest";

import { literal, requireString } from "../../src/shared/utils/queryGuard.js";

describe("queryGuard", () => {
  it("accepts a non-empty string", () => {
    expect(requireString("abc", "id")).toBe("abc");
  });

  it("rejects a non-string value (query operators included)", () => {
    expect(() => requireString({ $ne: null }, "id")).toThrow("Invalid id.");
  });

  it("rejects an empty string", () => {
    expect(() => requireString("", "id")).toThrow("Invalid id.");
  });

  it("wraps a scalar in an $eq literal", () => {
    expect(literal("value")).toEqual({ $eq: "value" });
  });
});
