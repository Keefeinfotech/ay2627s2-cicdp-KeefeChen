import { describe, expect, it, vi } from "vitest";
import type { Request, Response } from "express";

import { healthCheck } from "../../src/modules/health/health.controller.js";

describe("health controller", () => {
  it("returns service status ok", () => {
    const json = vi.fn();
    const status = vi.fn().mockReturnValue({ json });
    const res = { status } as unknown as Response;

    healthCheck({} as Request, res);

    expect(status).toHaveBeenCalledWith(200);
    expect(json).toHaveBeenCalledWith({
      status: "ok",
      service: "personal-secretary-api",
    });
  });
});
