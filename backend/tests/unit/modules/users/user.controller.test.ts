import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("../../../../src/modules/users/user.service.js", () => ({
  userService: {
    getOwnProfile: vi.fn(),
    updateOwnProfile: vi.fn(),
    deleteOwnAccount: vi.fn(),
  },
}));

import { userController } from "../../../../src/modules/users/user.controller.js";
import { userService } from "../../../../src/modules/users/user.service.js";

describe("user controller", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("returns the authenticated user's profile", async () => {
    const user = { id: "user-1" };
    vi.mocked(userService.getOwnProfile).mockResolvedValue(user as any);

    const res: any = {
      status: vi.fn().mockReturnThis(),
      json: vi.fn().mockReturnThis(),
    };

    await userController.getOwnProfile({ userId: "user-1" } as any, res, vi.fn());

    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      message: "User profile retrieved successfully.",
      data: user,
    });
  });

  it("returns 401 without an authenticated user", async () => {
    const res: any = {
      status: vi.fn().mockReturnThis(),
      json: vi.fn().mockReturnThis(),
    };

    await userController.getOwnProfile({} as any, res, vi.fn());

    expect(res.status).toHaveBeenCalledWith(401);
  });

  it("updates the authenticated user's profile", async () => {
    const user = { id: "user-1" };
    vi.mocked(userService.updateOwnProfile).mockResolvedValue(user as any);

    const res: any = {
      status: vi.fn().mockReturnThis(),
      json: vi.fn().mockReturnThis(),
    };

    await userController.updateOwnProfile(
      { userId: "user-1", body: { name: "Ada" } } as any,
      res,
      vi.fn()
    );

    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      message: "User profile updated successfully.",
      data: user,
    });
  });

  it("deactivates the authenticated user's account", async () => {
    vi.mocked(userService.deleteOwnAccount).mockResolvedValue(undefined as any);

    const res: any = {
      status: vi.fn().mockReturnThis(),
      json: vi.fn().mockReturnThis(),
    };

    await userController.deleteOwnAccount(
      { userId: "user-1", body: { currentPassword: "password123" } } as any,
      res,
      vi.fn()
    );

    expect(userService.deleteOwnAccount).toHaveBeenCalledWith(
      "user-1",
      "password123"
    );
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("returns 401 when deleting without an authenticated user", async () => {
    const res: any = {
      status: vi.fn().mockReturnThis(),
      json: vi.fn().mockReturnThis(),
    };

    await userController.deleteOwnAccount(
      { body: { currentPassword: "password123" } } as any,
      res,
      vi.fn()
    );

    expect(res.status).toHaveBeenCalledWith(401);
  });

  it("propagates errors", async () => {
    const error = new Error("boom");
    vi.mocked(userService.getOwnProfile).mockRejectedValue(error);

    const next = vi.fn();
    const res: any = {
      status: vi.fn().mockReturnThis(),
      json: vi.fn().mockReturnThis(),
    };

    await userController.getOwnProfile({ userId: "user-1" } as any, res, next);

    expect(next).toHaveBeenCalledWith(error);
  });
});
