import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("bcryptjs", () => ({
  default: { compare: vi.fn() },
}));

vi.mock("../../../../src/modules/users/user.repository.js", () => ({
  userRepository: {
    findById: vi.fn(),
    findByIdWithPassword: vi.fn(),
    updateOwnProfile: vi.fn(),
    deactivateAccount: vi.fn(),
  },
}));

import { userService } from "../../../../src/modules/users/user.service.js";
import { userRepository } from "../../../../src/modules/users/user.repository.js";

describe("user service", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("returns the authenticated user's profile", async () => {
    const user = {
      _id: "user-1",
      name: "Ada",
      email: "ada@example.com",
      role: "user",
      status: "active",
      emailVerifiedAt: null,
      lastLoginAt: null,
      createdAt: new Date(),
      updatedAt: new Date(),
    };
    vi.mocked(userRepository.findById).mockResolvedValue(user as any);

    const result = await userService.getOwnProfile("user-1");

    expect(result).toMatchObject({ id: "user-1", email: "ada@example.com" });
  });

  it("throws USER_NOT_FOUND when the user is missing", async () => {
    vi.mocked(userRepository.findById).mockResolvedValue(null);

    await expect(userService.getOwnProfile("user-1")).rejects.toMatchObject({
      status: 404,
      code: "USER_NOT_FOUND",
    });
  });

  it("throws ACCOUNT_UNAVAILABLE when the user is inactive", async () => {
    vi.mocked(userRepository.findById).mockResolvedValue({
      _id: "user-1",
      status: "disabled",
    } as any);

    await expect(userService.getOwnProfile("user-1")).rejects.toMatchObject({
      status: 403,
      code: "ACCOUNT_UNAVAILABLE",
    });
  });

  it("updates the user's profile", async () => {
    const user = {
      _id: "user-1",
      name: "Ada",
      email: "ada@example.com",
      role: "user",
      status: "active",
      emailVerifiedAt: null,
      lastLoginAt: null,
      createdAt: new Date(),
      updatedAt: new Date(),
    };
    vi.mocked(userRepository.updateOwnProfile).mockResolvedValue(user as any);

    const result = await userService.updateOwnProfile("user-1", {
      name: "Ada",
    });

    expect(userRepository.updateOwnProfile).toHaveBeenCalledWith("user-1", {
      name: "Ada",
    });
    expect(result).toMatchObject({ id: "user-1" });
  });

  it("throws USER_NOT_FOUND when update fails", async () => {
    vi.mocked(userRepository.updateOwnProfile).mockResolvedValue(null);

    await expect(
      userService.updateOwnProfile("user-1", { name: "Ada" }),
    ).rejects.toMatchObject({
      status: 404,
      code: "USER_NOT_FOUND",
    });
  });

  it("returns a public summary", async () => {
    const user = {
      _id: "user-1",
      name: "Ada",
      email: "ada@example.com",
      role: "user",
      status: "active",
      emailVerifiedAt: null,
      lastLoginAt: null,
      createdAt: new Date(),
      updatedAt: new Date(),
    };
    vi.mocked(userRepository.findById).mockResolvedValue(user as any);

    const result = await userService.getPublicSummary("user-1");

    expect(result).toMatchObject({ id: "user-1", name: "Ada" });
  });

  it("throws USER_NOT_FOUND when the summary user is missing or inactive", async () => {
    vi.mocked(userRepository.findById).mockResolvedValue(null);

    await expect(userService.getPublicSummary("user-1")).rejects.toMatchObject({
      status: 404,
      code: "USER_NOT_FOUND",
    });
  });

  it("deactivates an account with the correct password", async () => {
    const user = {
      _id: "user-1",
      status: "active",
      deletedAt: null,
      passwordHash:
        "$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy",
    };
    vi.mocked(userRepository.findByIdWithPassword).mockResolvedValue(
      user as any,
    );
    vi.mocked(userRepository.deactivateAccount).mockResolvedValue(true);
    vi.mocked((await import("bcryptjs")).default.compare).mockResolvedValue(
      true as any,
    );

    await expect(
      userService.deleteOwnAccount("user-1", "password123"),
    ).resolves.toBeUndefined();
    expect(userRepository.deactivateAccount).toHaveBeenCalledWith("user-1");
  });

  it("throws PASSWORD_VERIFICATION_UNAVAILABLE without a password hash", async () => {
    vi.mocked(userRepository.findByIdWithPassword).mockResolvedValue({
      _id: "user-1",
      status: "active",
      deletedAt: null,
      passwordHash: null,
    } as any);

    await expect(
      userService.deleteOwnAccount("user-1", "password123"),
    ).rejects.toMatchObject({
      status: 403,
      code: "PASSWORD_VERIFICATION_UNAVAILABLE",
    });
  });

  it("throws INVALID_PASSWORD when the password is wrong", async () => {
    const user = {
      _id: "user-1",
      status: "active",
      deletedAt: null,
      passwordHash:
        "$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy",
    };
    vi.mocked(userRepository.findByIdWithPassword).mockResolvedValue(
      user as any,
    );

    const bcrypt = await import("bcryptjs");
    vi.mocked(bcrypt.default.compare).mockResolvedValue(false as any);

    await expect(
      userService.deleteOwnAccount("user-1", "wrong"),
    ).rejects.toMatchObject({
      status: 401,
      code: "INVALID_PASSWORD",
    });
  });

  it("throws ACCOUNT_DEACTIVATION_CONFLICT when deactivation fails", async () => {
    const user = {
      _id: "user-1",
      status: "active",
      deletedAt: null,
      passwordHash:
        "$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy",
    };
    vi.mocked(userRepository.findByIdWithPassword).mockResolvedValue(
      user as any,
    );
    vi.mocked(userRepository.deactivateAccount).mockResolvedValue(false);

    const bcrypt = await import("bcryptjs");
    vi.mocked(bcrypt.default.compare).mockResolvedValue(true as any);

    await expect(
      userService.deleteOwnAccount("user-1", "password123"),
    ).rejects.toMatchObject({
      status: 409,
      code: "ACCOUNT_DEACTIVATION_CONFLICT",
    });
  });
});
