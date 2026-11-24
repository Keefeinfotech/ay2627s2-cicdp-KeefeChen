import { afterEach, describe, expect, it, vi } from "vitest";

const ORIGINAL_ENV = { ...process.env };

const loadSecurity = async () => {
  vi.resetModules();
  return import("../../../src/config/security.js");
};

afterEach(() => {
  process.env = { ...ORIGINAL_ENV };
  vi.resetModules();
});

describe("security config", () => {
  it("builds helmet middleware for dev and prod", async () => {
    process.env.NODE_ENV = "test";
    const dev = await loadSecurity();
    expect(dev.helmetMiddleware).toBeTypeOf("function");
    expect(dev.jsonBodyOptions).toMatchObject({ strict: true });
    expect(dev.urlEncodedBodyOptions).toMatchObject({ extended: true });

    process.env.NODE_ENV = "production";
    const prod = await loadSecurity();
    expect(prod.helmetMiddleware).toBeTypeOf("function");
  });

  it("cors allows missing origin, allowlisted origin, and local dev origin", async () => {
    process.env.NODE_ENV = "test";
    process.env.CORS_ORIGIN = "https://app.example.com";
    const { corsOptions } = await loadSecurity();
    const origin = corsOptions.origin as any;

    const noOrigin = await new Promise((resolve) =>
      origin(undefined, (...args: any[]) => resolve(args)),
    );
    expect(noOrigin).toEqual([null, true]);

    const allowed = await new Promise((resolve) =>
      origin("https://app.example.com", (...args: any[]) => resolve(args)),
    );
    expect(allowed).toEqual([null, true]);

    const local = await new Promise((resolve) =>
      origin("http://localhost:63488", (...args: any[]) => resolve(args)),
    );
    expect(local).toEqual([null, true]);
  });

  it("cors rejects disallowed origin in dev and loopback in production", async () => {
    process.env.NODE_ENV = "test";
    process.env.CORS_ORIGIN = "https://app.example.com";
    const dev = await loadSecurity();
    const devOrigin = dev.corsOptions.origin as any;
    const rejected = await new Promise((resolve) =>
      devOrigin("https://evil.com", (...args: any[]) => resolve(args)),
    );
    expect((rejected as any[])[0]).toMatchObject({ status: 403, code: "CORS_FORBIDDEN" });

    process.env.NODE_ENV = "production";
    process.env.CORS_ORIGIN = "https://app.example.com";
    const prod = await loadSecurity();
    const prodOrigin = prod.corsOptions.origin as any;
    const loopbackRejected = await new Promise((resolve) =>
      prodOrigin("http://localhost:3000", (...args: any[]) => resolve(args)),
    );
    expect((loopbackRejected as any[])[0]).toMatchObject({ status: 403 });
  });
});
