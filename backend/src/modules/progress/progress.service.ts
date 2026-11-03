/**
 * File Name: progress.service.ts
 * Description: Aggregates group progress from membership, roadmap and
 *              session data.
 * Author: Keefe Chen
 */

import { requireGroupMembership } from "../groups/shared/membership.js";
import { Member } from "../groups/member/member.model.js";
import { Roadmap } from "../roadmaps/roadmap.model.js";
import { StudySession } from "../sessions/session.model.js";

import type { GroupProgressResponse } from "./progress.types.js";

export const progressService = {
  /**
   * Builds a progress overview for the group.
   */
  async get(
    groupId: string,
    userId: string,
  ): Promise<GroupProgressResponse> {
    await requireGroupMembership(groupId, userId);

    const [members, roadmaps, sessions] = await Promise.all([
      Member.find({ groupId, status: "ACTIVE" })
        .select("role -_id")
        .lean(),
      Roadmap.find({ groupId })
        .select("status items.status")
        .lean(),
      StudySession.find({ groupId })
        .select("status startsAt")
        .lean(),
    ]);

    const memberCounts = {
      total: members.length,
      owners: members.filter((m) => m.role === "OWNER").length,
      admins: members.filter((m) => m.role === "ADMIN").length,
      members: members.filter((m) => m.role === "MEMBER").length,
    };

    const itemTotals = {
      total: 0,
      done: 0,
      inProgress: 0,
      pending: 0,
    };

    for (const roadmap of roadmaps) {
      const items = (roadmap.items ?? []) as { status?: string }[];

      for (const item of items) {
        itemTotals.total += 1;

        const status = item.status ?? "pending";

        if (status === "done") itemTotals.done += 1;
        else if (status === "in_progress") itemTotals.inProgress += 1;
        else itemTotals.pending += 1;
      }
    }

    const completionPercent =
      itemTotals.total === 0
        ? 0
        : Math.round((itemTotals.done / itemTotals.total) * 100);

    const now = new Date();

    const sessionCounts = {
      total: sessions.length,
      upcoming: sessions.filter(
        (s) =>
          s.status === "scheduled" &&
          new Date(s.startsAt).getTime() >= now.getTime(),
      ).length,
      completed: sessions.filter((s) => s.status === "completed").length,
      cancelled: sessions.filter((s) => s.status === "cancelled").length,
    };

    return {
      groupId,
      generatedAt: now,
      members: memberCounts,
      roadmaps: {
        total: roadmaps.length,
        approved: roadmaps.filter((r) => r.status === "approved").length,
        items: itemTotals,
        completionPercent,
      },
      sessions: sessionCounts,
    };
  },
};

