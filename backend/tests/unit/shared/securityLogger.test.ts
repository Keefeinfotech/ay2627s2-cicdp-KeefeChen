import { describe, expect, it, vi, beforeEach, afterEach } from "vitest";
import {
  logAccessDenied,
  logAuthFailure,
  logRateLimitExceeded,
  logSecurityEvent,
  logServerError,
  logSuspiciousActivity,
} from "../../../src/shared/utils/securityLogger.js";

describe("securityLogger", () => {
  let warnSpy: ReturnType<typeof vi.spyOn>;
  let errorSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    warnSpy = vi.spyOn(console, "warn").mockImplementation(() => {});
    errorSpy = vi.spyOn(console, "error").mockImplementation(() => {});
  });

  afterEach(() => {
    warnSpy.mockRestore();
    errorSpy.mockRestore();
  });

  it("logs security events as warn json", () => {
    logSecurityEvent("evt", { ip: "1.2.3.4" });
    expect(warnSpy).toHaveBeenCalled();
    const line = String(warnSpy.mock.calls[0][0]);
    expect(line).toContain('"event":"evt"');
  });

  it("logs server errors as error json", () => {
    logServerError({ requestId: "r1" });
    expect(errorSpy).toHaveBeenCalled();
    expect(String(errorSpy.mock.calls[0][0])).toContain("server_error");
  });

  it("logs auth failures", () => {
    logAuthFailure("auth.fail", "1.1.1.1", "u1", "r1", "/p");
    expect(warnSpy).toHaveBeenCalled();
  });

  it("logs access denied", () => {
    logAccessDenied("denied", "1.1.1.1", "u1", "r1", "/p", "res");
    expect(warnSpy).toHaveBeenCalled();
  });

  it("logs rate limit exceeded", () => {
    logRateLimitExceeded("rl", "1.1.1.1", "u1", "r1", "/p");
    expect(warnSpy).toHaveBeenCalled();
  });

  it("logs suspicious activity", () => {
    logSuspiciousActivity("sus", "1.1.1.1", "u1", "r1", "/p", "desc");
    expect(warnSpy).toHaveBeenCalled();
  });
});
