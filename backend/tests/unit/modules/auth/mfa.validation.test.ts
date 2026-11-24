import { describe, expect, it } from "vitest";
import {
  verifyMfaSchema,
  disableMfaSchema,
} from "../../../../src/modules/auth/mfa/mfa.validation.js";

describe("mfa validation", () => {
  it("accepts valid verify payload", () => {
    expect(verifyMfaSchema.shape.body.parse({ code: "123456" })).toEqual({
      code: "123456",
    });
  });

  it("rejects invalid verify code", () => {
    expect(() => verifyMfaSchema.shape.body.parse({ code: "12" })).toThrow();
  });

  it("accepts valid disable payload", () => {
    expect(disableMfaSchema.shape.body.parse({ code: "123456" })).toEqual({
      code: "123456",
    });
  });

  it("rejects too-short disable code", () => {
    expect(() => disableMfaSchema.shape.body.parse({ code: "1" })).toThrow();
  });
});
