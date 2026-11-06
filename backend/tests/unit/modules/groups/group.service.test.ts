import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  groupRepository: {
    create: vi.fn(),
    findById: vi.fn(),
    findOwned: vi.fn(),
    update: vi.fn(),
    archive: vi.fn(),
    list: vi.fn(),
  },
  memberRepository: {
    create: vi.fn(),
    findActiveGroupIdsByUser: vi.fn(),
    findActiveByUserAndGroupIds: vi.fn(),
    findActiveByGroupAndUser: vi.fn(),
  },
}));

vi.mock("../../../../src/modules/groups/core/group.repository.js", () => ({
  GroupRepository: class {
    create = mocks.groupRepository.create;
    findById = mocks.groupRepository.findById;
    findOwned = mocks.groupRepository.findOwned;
    update = mocks.groupRepository.update;
    archive = mocks.groupRepository.archive;
    list = mocks.groupRepository.list;
  },
}));
vi.mock("../../../../src/modules/groups/member/member.repository.js", () => ({
  MemberRepository: class {
    create = mocks.memberRepository.create;
    findActiveGroupIdsByUser =
      mocks.memberRepository.findActiveGroupIdsByUser;
    findActiveByUserAndGroupIds =
      mocks.memberRepository.findActiveByUserAndGroupIds;
    findActiveByGroupAndUser =
      mocks.memberRepository.findActiveByGroupAndUser;
  },
}));
vi.mock("mongoose", async (importOriginal) => {
  const actual = await importOriginal<typeof import("mongoose")>();
  const session = {
    withTransaction: async (callback: () => Promise<void>) => callback(),
    endSession: vi.fn(),
  };
  return {
    ...actual,
    default: {
      ...actual.default,
      startSession: vi.fn().mockResolvedValue(session),
    },
  };
});

import { GroupService } from "../../../../src/modules/groups/core/group.services.js";
import { GroupVisibility } from "../../../../src/modules/groups/core/group.types.js";

const service = new GroupService();

describe("group service", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("creates a group and an owner membership", async () => {
    const created = {
      groupId: "group-1",
      name: "Study Circle",
      visibility: GroupVisibility.PRIVATE,
    };
    mocks.groupRepository.create.mockResolvedValue(created);
    mocks.memberRepository.create.mockResolvedValue({});

    const result = await service.create("owner-1", {
      name: "  Study Circle  ",
      description: "  Weekly revision  ",
    } as any);

    expect(result).toBe(created);
    expect(mocks.groupRepository.create).toHaveBeenCalledWith(
      expect.objectContaining({
        name: "Study Circle",
        description: "Weekly revision",
        visibility: GroupVisibility.PRIVATE,
        ownerId: "owner-1",
      }),
      expect.anything(),
    );
    expect(mocks.memberRepository.create).toHaveBeenCalledWith(
      expect.objectContaining({
        groupId: "group-1",
        userId: "owner-1",
        role: "OWNER",
        status: "ACTIVE",
      }),
      expect.anything(),
    );
  });

  it("returns an empty page when the user has no memberships", async () => {
    mocks.memberRepository.findActiveGroupIdsByUser.mockResolvedValue([]);

    const result = await service.list("user-1", {
      page: 1,
      limit: 20,
    } as any);

    expect(result).toEqual({
      items: [],
      pagination: { page: 1, limit: 20, total: 0, totalPages: 0 },
    });
  });

  it("attaches the caller's role to listed groups", async () => {
    mocks.memberRepository.findActiveGroupIdsByUser.mockResolvedValue([
      "group-1",
    ]);
    mocks.groupRepository.list.mockResolvedValue({
      items: [{ groupId: "group-1", name: "Study Circle" }],
      pagination: { page: 1, limit: 20, total: 1, totalPages: 1 },
    });
    mocks.memberRepository.findActiveByUserAndGroupIds.mockResolvedValue([
      { groupId: "group-1", role: "ADMIN" },
    ]);

    const result = await service.list("user-1", {
      page: 1,
      limit: 20,
    } as any);

    expect(result.items[0]).toMatchObject({ groupId: "group-1", role: "ADMIN" });
  });

  it("denies members-only access to private groups", async () => {
    mocks.groupRepository.findById.mockResolvedValue({
      groupId: "group-1",
      visibility: GroupVisibility.PRIVATE,
    });
    mocks.memberRepository.findActiveByGroupAndUser.mockResolvedValue(null);

    await expect(service.get("group-1", "user-1")).rejects.toMatchObject({
      statusCode: 403,
      code: "GROUP_ACCESS_DENIED",
    });
  });

  it("allows public groups to be viewed without membership", async () => {
    const group = {
      groupId: "group-1",
      visibility: GroupVisibility.PUBLIC,
    };
    mocks.groupRepository.findById.mockResolvedValue(group);
    mocks.memberRepository.findActiveByGroupAndUser.mockResolvedValue(null);

    await expect(service.get("group-1", "user-1")).resolves.toBe(group);
  });

  it("rejects updates from non-owners", async () => {
    mocks.groupRepository.findOwned.mockResolvedValue(null);

    await expect(
      service.update("group-1", "user-1", { name: "New name" }),
    ).rejects.toMatchObject({ statusCode: 404, code: "GROUP_NOT_FOUND" });
  });

  it("archives an owned group", async () => {
    const archived = { groupId: "group-1", status: "ARCHIVED" };
    mocks.groupRepository.archive.mockResolvedValue(archived);

    await expect(service.archive("group-1", "owner-1")).resolves.toBe(
      archived,
    );
    expect(mocks.groupRepository.archive).toHaveBeenCalledWith(
      "group-1",
      "owner-1",
    );
  });
});
