/**
 * File Name: admin.service.ts
 * Description: Business logic for the administrative module. Aggregates
 *              platform statistics from real Mongoose data and enforces the
 *              account-management guard rails (no self-deactivation, never
 *              deactivate the last active administrator).
 * Author: Keefe Chen
 */

import { AppError, notFound } from "../../shared/utils/AppError.js";
import type {
  AdminListResponse,
  AdminStats,
  AdminUserListQuery,
  AdminUserView,
} from "./admin.types.js";
import * as repository from "./admin.repository.js";

const TREND_DAYS = 14;
const MS_PER_DAY = 24 * 60 * 60 * 1000;

interface UserLean {
  _id: string;
  name: string;
  email: string;
  role: string;
  status: string;
  createdAt?: Date | null;
  lastLoginAt?: Date | null;
}

const toAdminUserView = (doc: UserLean): AdminUserView => ({
  id: doc._id,
  name: doc.name,
  email: doc.email,
  role: doc.role as AdminUserView["role"],
  status: doc.status as AdminUserView["status"],
  createdAt: doc.createdAt ?? null,
  lastLoginAt: doc.lastLoginAt ?? null,
});

export const listUsers = async (
  query: AdminUserListQuery,
): Promise<AdminListResponse<AdminUserView>> => {
  const { total, docs } = await repository.findUsers(query);
  const totalPages = total === 0 ? 0 : Math.ceil(total / query.limit);
  return {
    items: docs.map((doc) => toAdminUserView(doc as unknown as UserLean)),
    total,
    page: query.page,
    limit: query.limit,
    totalPages,
  };
};

/**
 * Sets an account's status. Guard rails:
 *  - an administrator cannot deactivate their own account;
 *  - the last active administrator cannot be deactivated;
 *  - unknown user ids surface as 404.
 */
export const setUserStatus = async (
  actorId: string,
  targetUserId: string,
  status: "active" | "disabled",
): Promise<AdminUserView> => {
  if (actorId === targetUserId && status === "disabled") {
    throw new AppError(
      400,
      "SELF_DEACTIVATION",
      "You cannot deactivate your own account.",
    );
  }

  const target = await repository.findUserById(targetUserId);
  if (!target) {
    throw notFound("User not found.");
  }

  if (status === "disabled" && (target as { role?: string }).role === "admin") {
    const activeAdmins = await repository.countActiveAdmins();
    if (activeAdmins <= 1) {
      throw new AppError(
        409,
        "LAST_ADMIN",
        "The last active administrator cannot be deactivated.",
      );
    }
  }

  const updated = await repository.updateUserStatus(targetUserId, status);
  if (!updated) {
    throw notFound("User not found.");
  }
  return toAdminUserView(updated as unknown as UserLean);
};

export const getStats = async (): Promise<AdminStats> => {
  const since7d = new Date(Date.now() - 7 * MS_PER_DAY);

  const [
    usersByStatus,
    newUsers7d,
    tasksByStatus,
    created7d,
    completed7d,
    creationTrend,
    completionTrend,
  ] = await Promise.all([
    repository.countUsersByStatus(),
    repository.countNewUsersSince(since7d),
    repository.countTasksByStatus(),
    repository.countTasksCreatedSince(since7d),
    repository.countTasksCompletedSince(since7d),
    repository.tasksPerDay("createdAt", TREND_DAYS),
    repository.tasksPerDay("completedAt", TREND_DAYS),
  ]);

  const active = usersByStatus["active"] ?? 0;
  const disabled = usersByStatus["disabled"] ?? 0;
  const pending = usersByStatus["pending"] ?? 0;
  const totalUsers = active + disabled + pending;

  const todo = tasksByStatus["todo"] ?? 0;
  const inProgress = tasksByStatus["in_progress"] ?? 0;
  const completed = tasksByStatus["completed"] ?? 0;
  const archived = tasksByStatus["archived"] ?? 0;
  const totalTasks = todo + inProgress + completed + archived;
  const activeTasks = totalTasks - archived;
  const completionRate =
    activeTasks > 0 ? Number((completed / activeTasks).toFixed(4)) : 0;

  return {
    users: {
      total: totalUsers,
      active,
      disabled,
      pending,
      newLast7Days: newUsers7d,
    },
    tasks: {
      total: totalTasks,
      todo,
      inProgress,
      completed,
      archived,
      completionRate,
      createdLast7Days: created7d,
      completedLast7Days: completed7d,
    },
    taskCreationTrend: creationTrend,
    taskCompletionTrend: completionTrend,
  };
};
