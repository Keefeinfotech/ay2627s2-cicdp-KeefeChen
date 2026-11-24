import { describe, expect, it } from "vitest";
import {
  getWelcomeMessage,
  requireSessionId,
  requireUserId,
} from "../../../src/shared/utils/request.js";

describe("request utils", () => {
  it("returns userId when present", () => {
    expect(requireUserId({ userId: "u1" } as never)).toBe("u1");
  });

  it("throws when userId missing", () => {
    expect(() => requireUserId({} as never)).toThrow();
  });

  it("returns sessionId when present", () => {
    expect(requireSessionId({ sessionId: "s1" } as never)).toBe("s1");
  });

  it("throws when sessionId missing", () => {
    expect(() => requireSessionId({} as never)).toThrow();
  });

  it("builds welcome message", () => {
    expect(getWelcomeMessage("Keefe")).toContain("Keefe");
  });
});
