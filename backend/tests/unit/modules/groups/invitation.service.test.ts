import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  groupRepository: {
    findById: vi.fn(),
  },
  memberRepository: {
    findActiveByGroupAndUser: vi.fn(),
    activate: vi.fn(),
  },
  invitationRepository: {
    findPendingByEmail: vi.fn(),
    create: vi.fn(),
    findById: vi.fn(),
    findByTokenHash: vi.fn(),
    accept: vi.fn(),
    revoke: vi.fn(),
  },
  userRepository: {
    findById: vi.fn(),
  },
  sendGroupInvitationEmail: vi.fn(),
  getAppBaseUrl: vi.fn(() => "https://auxilia.test"),
  logger: {
    warn: vi.fn(),
    info: vi.fn(),
    error: vi.fn(),
  },
}));

vi.mock("../../../../src/modules/groups/core/group.repository.js", () => ({
  GroupRepository: class {
    findById = mocks.groupRepository.findById;
  },
}));
vi.mock("../../../../src/modules/groups/member/member.repository.js", () => ({
  MemberRepository: class {
    findActiveByGroupAndUser = mocks.memberRepository.findActiveByGroupAndUser;
    activate = mocks.memberRepository.activate;
  },
}));
vi.mock("../../../../src/modules/groups/invitation/invitation.repository.js", () => ({
  InvitationRepository: class {
    findPendingByEmail = mocks.invitationRepository.findPendingByEmail;
    create = mocks.invitationRepository.create;
    findById = mocks.invitationRepository.findById;
    findByTokenHash = mocks.invitationRepository.findByTokenHash;
    accept = mocks.invitationRepository.accept;
    revoke = mocks.invitationRepository.revoke;
  },
}));
vi.mock("../../../../src/modules/users/user.repository.js", () => ({
  userRepository: mocks.userRepository,
}));
vi.mock("../../../../src/services/email.service.js", () => ({
  sendGroupInvitationEmail: mocks.sendGroupInvitationEmail,
}));
vi.mock("../../../../src/config/environment.js", () => ({
  getAppBaseUrl: mocks.getAppBaseUrl,
}));
vi.mock("../../../../src/config/logger.js", () => ({
  default: mocks.logger,
}));

import { InvitationService } from "../../../../src/modules/groups/invitation/invitation.service.js";
import { GroupRole } from "../../../../src/modules/groups/core/group.types.js";
import { InvitationStatus } from "../../../../src/modules/groups/invitation/invitation.types.js";

const invitationRecord = {
  invitationId: "invitation-1",
  groupId: "group-1",
  email: "student@example.edu",
  role: GroupRole.MEMBER,
  status: InvitationStatus.PENDING,
  invitedBy: "owner-1",
  expiresAt: new Date("2026-11-12T00:00:00Z"),
  createdAt: new Date("2026-11-05T00:00:00Z"),
};

const arrangeHappyPath = () => {
  mocks.groupRepository.findById.mockResolvedValue({
    groupId: "group-1",
    name: "Study Circle",
    status: "ACTIVE",
  });
  mocks.memberRepository.findActiveByGroupAndUser.mockResolvedValue({
    groupId: "group-1",
    userId: "owner-1",
    role: GroupRole.OWNER,
    status: "ACTIVE",
  });
  mocks.invitationRepository.findPendingByEmail.mockResolvedValue(null);
  mocks.invitationRepository.create.mockImplementation(async (input) => ({
    ...invitationRecord,
    ...input,
  }));
};

describe("invitation service", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.getAppBaseUrl.mockReturnValue("https://auxilia.test");
  });

  it("emails the invitation and omits the raw token when delivery succeeds", async () => {
    arrangeHappyPath();
    mocks.sendGroupInvitationEmail.mockResolvedValue(true);

    const result = await new InvitationService().create("owner-1", {
      groupId: "group-1",
      email: " Student@Example.edu ",
      role: GroupRole.MEMBER,
    });

    expect(result.delivery).toBe("email");
    expect(result).not.toHaveProperty("invitationToken");
    expect(mocks.sendGroupInvitationEmail).toHaveBeenCalledWith({
      recipient: "student@example.edu",
      acceptUrl: expect.stringMatching(
        /^https:\/\/auxilia\.test\/invitations\/accept\?token=/,
      ),
      groupName: "Study Circle",
      role: GroupRole.MEMBER,
    });
  });

  it("falls back to manual delivery when email is not configured", async () => {
    arrangeHappyPath();
    mocks.sendGroupInvitationEmail.mockResolvedValue(false);

    const result = await new InvitationService().create("owner-1", {
      groupId: "group-1",
      email: "student@example.edu",
      role: GroupRole.MEMBER,
    });

    expect(result.delivery).toBe("manual");
    expect(result.invitationToken).toMatch(/^[a-f0-9]{64}$/);
  });

  it("falls back to manual delivery when email sending fails", async () => {
    arrangeHappyPath();
    mocks.sendGroupInvitationEmail.mockRejectedValue(new Error("SMTP down"));

    const result = await new InvitationService().create("owner-1", {
      groupId: "group-1",
      email: "student@example.edu",
      role: GroupRole.MEMBER,
    });

    expect(result.delivery).toBe("manual");
    expect(result.invitationToken).toMatch(/^[a-f0-9]{64}$/);
    expect(mocks.logger.warn).toHaveBeenCalledWith(
      "group.invitation.email_failed",
      expect.objectContaining({ groupId: "group-1" }),
    );
  });

  it("rejects inviters without owner or admin role", async () => {
    mocks.groupRepository.findById.mockResolvedValue({
      groupId: "group-1",
      name: "Study Circle",
      status: "ACTIVE",
    });
    mocks.memberRepository.findActiveByGroupAndUser.mockResolvedValue({
      groupId: "group-1",
      userId: "member-1",
      role: GroupRole.MEMBER,
      status: "ACTIVE",
    });

    await expect(
      new InvitationService().create("member-1", {
        groupId: "group-1",
        email: "student@example.edu",
        role: GroupRole.MEMBER,
      }),
    ).rejects.toThrow("permission");

    expect(mocks.invitationRepository.create).not.toHaveBeenCalled();
  });

  it("rejects duplicate pending invitations", async () => {
    arrangeHappyPath();
    mocks.invitationRepository.findPendingByEmail.mockResolvedValue(
      invitationRecord,
    );

    await expect(
      new InvitationService().create("owner-1", {
        groupId: "group-1",
        email: "student@example.edu",
        role: GroupRole.MEMBER,
      }),
    ).rejects.toThrow("already exists");

    expect(mocks.invitationRepository.create).not.toHaveBeenCalled();
  });
});
