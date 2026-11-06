import type { NextFunction, Request, Response } from "express";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { SyncController } from "../../../../src/modules/sync/sync.controller.js";
import type { SyncService } from "../../../../src/modules/sync/sync.service.js";

const result = {
  serverTime: new Date("2026-11-06T00:00:00Z"),
  since: new Date(0),
  tasks: [],
};

const response = () => {
  const res = {
    status: vi.fn().mockReturnThis(),
    json: vi.fn().mockReturnThis(),
  } as unknown as Response;
  return res;
};

describe("sync controller", () => {
  const syncService = {
    getChangesSince: vi.fn(),
  } as unknown as SyncService;
  const controller = new SyncController(syncService);
  let next: NextFunction;

  beforeEach(() => {
    vi.clearAllMocks();
    next = vi.fn() as unknown as NextFunction;
  });

  it("rejects unauthenticated requests", async () => {
    const req = { query: {} } as unknown as Request;
    const res = response();

    await controller.getChanges(req, res, next);

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ status: 401, code: "UNAUTHENTICATED" }),
    );
  });

  it("rejects an invalid cursor", async () => {
    const req = {
      userId: "user-1",
      query: { since: "not-a-date" },
    } as unknown as Request;
    const res = response();

    await controller.getChanges(req, res, next);

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ status: 400, code: "INVALID_SINCE" }),
    );
  });

  it("returns the changes for the authenticated user", async () => {
    vi.mocked(syncService.getChangesSince).mockResolvedValue(result);
    const since = "2026-11-01T00:00:00.000Z";
    const req = {
      userId: "user-1",
      query: { since },
    } as unknown as Request;
    const res = response();

    await controller.getChanges(req, res, next);

    expect(syncService.getChangesSince).toHaveBeenCalledWith(
      "user-1",
      new Date(since),
    );
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      message: "Sync changes retrieved successfully.",
      data: result,
    });
  });
});
