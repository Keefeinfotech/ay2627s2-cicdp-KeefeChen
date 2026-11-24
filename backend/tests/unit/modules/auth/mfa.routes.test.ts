import { describe, expect, it, vi } from "vitest";

vi.mock("../../../../src/middleware/authenticate.js", () => ({
  authenticate: vi.fn((_req: any, _res: any, next: any) => next()),
}));
vi.mock("../../../../src/middleware/validateRequest.js", () => ({
  validateBody: vi.fn(() => (_req: any, _res: any, next: any) => next()),
}));
vi.mock("../../../../src/modules/auth/mfa/mfa.controller.js", () => ({
  mfaController: { status: vi.fn(), setup: vi.fn(), verify: vi.fn(), disable: vi.fn() },
}));

import router from "../../../../src/modules/auth/mfa/mfa.routes.js";

describe("mfa routes", () => {
  it("registers expected routes", () => {
    const routes = (router as any).stack
      .filter((l: any) => l.route)
      .map((l: any) => ({ path: l.route.path, methods: l.route.methods }));
    expect(routes).toEqual(expect.arrayContaining([
      expect.objectContaining({ path: "/status", methods: expect.objectContaining({ get: true }) }),
      expect.objectContaining({ path: "/setup", methods: expect.objectContaining({ post: true }) }),
      expect.objectContaining({ path: "/verify", methods: expect.objectContaining({ post: true }) }),
      expect.objectContaining({ path: "/disable", methods: expect.objectContaining({ post: true }) }),
    ]));
  });
});
