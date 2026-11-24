import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("../../../../src/modules/progress/progress.service.js", () => ({
  progressService: {
    get: vi.fn(),
  },
}));

import { progressController } from "../../../../src/modules/progress/progress.controller.js";
import { progressService } from "../../../../src/modules/progress/progress.service.js";

describe("progress controller", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("returns progress for a valid group", async () => {
    const progress = { groupId: "group-1", members: { total: 3 } };
    vi.mocked(progressService.get).mockResolvedValue(progress as never);

    const res: any = { status: vi.fn().mockReturnThis(), json: vi.fn().mockReturnThis() };
    const next = vi.fn();

    await progressController.get(
      { userId: "user-1", params: { groupId: "group-1" } } as never,
      res,
      next,
    );

    expect(progressService.get).toHaveBeenCalledWith("group-1", "user-1");
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      message: "Progress retrieved successfully.",
      data: progress,
    });
  });

  it("returns 401 when unauthenticated", async () => {
    const res: any = { status: vi.fn().mockReturnThis(), json: vi.fn().mockReturnThis() };
    const next = vi.fn();

    await progressController.get({ params: { groupId: "group-1" } } as never, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(next).not.toHaveBeenCalled();
  });

  it("returns 400 when the group id is missing", async () => {
    const res: any = { status: vi.fn().mockReturnThis(), json: vi.fn().mockReturnThis() };
    const next = vi.fn();

    await progressController.get(
      { userId: "user-1", params: { groupId: "" } } as never,
      res,
      next,
    );

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({
      code: "INVALID_GROUP_ID",
      message: "A group ID is required.",
    });
    expect(progressService.get).not.toHaveBeenCalled();
  });

  it("propagates service errors", async () => {
    const error = new Error("boom");
    vi.mocked(progressService.get).mockRejectedValue(error);
    const next = vi.fn();

    await progressController.get(
      { userId: "user-1", params: { groupId: "group-1" } } as never,
      { status: vi.fn().mockReturnThis(), json: vi.fn().mockReturnThis() } as never,
      next,
    );

    expect(next).toHaveBeenCalledWith(error);
  });
});
