import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("../../../../src/modules/users/user.model.js", () => ({
  User: {
    create: vi.fn(),
    findOne: vi.fn(),
    exists: vi.fn(),
    findOneAndUpdate: vi.fn(),
    updateOne: vi.fn(),
  },
}));

import { userRepository } from "../../../../src/modules/users/user.repository.js";

describe("user repository", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("creates a user", async () => {
    const created = { _id: "user-1", toObject: () => ({ _id: "user-1" }) };
    const { User } = await import("../../../../src/modules/users/user.model.js");
    vi.mocked(User.create).mockResolvedValue(created as any);

    const result = await userRepository.create({
      name: "Ada",
      email: "ADA@EXAMPLE.COM",
      passwordHash: "hash",
    });

    expect(User.create).toHaveBeenCalledWith({
      name: "Ada",
      email: "ada@example.com",
      passwordHash: "hash",
      role: "user",
      status: "pending",
    });
    expect(result).toEqual({ _id: "user-1" });
  });

  it("finds a user by id", async () => {
    const user = { _id: "user-1" };
    const { User } = await import("../../../../src/modules/users/user.model.js");
    vi.mocked(User.findOne).mockReturnValue({
      lean: () => ({ exec: async () => user }),
    } as any);

    await expect(userRepository.findById("user-1")).resolves.toBe(user);
  });

  it("finds a user with password", async () => {
    const user = { _id: "user-1", passwordHash: "hash" };
    const { User } = await import("../../../../src/modules/users/user.model.js");
    vi.mocked(User.findOne).mockReturnValue({
      select: () => ({ lean: () => ({ exec: async () => user }) }),
    } as any);

    await expect(userRepository.findByIdWithPassword("user-1")).resolves.toBe(user);
  });

  it("finds a user by email", async () => {
    const user = { _id: "user-1" };
    const { User } = await import("../../../../src/modules/users/user.model.js");
    vi.mocked(User.findOne).mockReturnValue({
      select: () => ({ lean: () => ({ exec: async () => user }) }),
    } as any);

    await expect(userRepository.findByEmail("ADA@EXAMPLE.COM")).resolves.toBe(user);
  });

  it("checks whether an email exists", async () => {
    const { User } = await import("../../../../src/modules/users/user.model.js");
    vi.mocked(User.exists).mockResolvedValue({ _id: "user-1" } as any);

    await expect(userRepository.existsByEmail("ada@example.com")).resolves.toBe(true);
  });

  it("updates a user's profile", async () => {
    const user = { _id: "user-1", name: "Ada" };
    const { User } = await import("../../../../src/modules/users/user.model.js");
    vi.mocked(User.findOneAndUpdate).mockReturnValue({
      select: () => ({ lean: () => ({ exec: async () => user }) }),
    } as any);

    await expect(
      userRepository.updateOwnProfile("user-1", { name: "Ada" })
    ).resolves.toBe(user);
  });

  it("updates the last login timestamp", async () => {
    const { User } = await import("../../../../src/modules/users/user.model.js");
    vi.mocked(User.updateOne).mockReturnValue({ exec: async () => ({}) });

    await expect(userRepository.updateLastLogin("user-1")).resolves.toBeUndefined();
  });

  it("deactivates an account", async () => {
    const { User } = await import("../../../../src/modules/users/user.model.js");
    vi.mocked(User.updateOne).mockReturnValue({
      exec: async () => ({ modifiedCount: 1 }),
    });

    await expect(userRepository.deactivateAccount("user-1")).resolves.toBe(true);
  });
});
