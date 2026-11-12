/**
 * File Name: admin.repository.ts
 * Description: Data access for the administrative module. Queries project only
 *              non-sensitive fields; aggregate pipelines exclude soft-deleted
 *              tasks where the model supports it.
 * Author: Keefe Chen
 */

import { Task } from "../tasks/task.model.js";
import { User } from "../users/user.model.js";
import type { AdminUserListQuery, AdminTrendPoint } from "./admin.types.js";

/** Safe fields — passwordHash/MFA secrets are never loaded for admin views. */
const SAFE_USER_FIELDS = "_id name email role status createdAt lastLoginAt";

export const countUsersByStatus = async () => {
  const grouped = await User.aggregate<{
    _id: string;
    count: number;
  }>([{ $group: { _id: "$status", count: { $sum: 1 } } }]);
  return Object.fromEntries(grouped.map((row) => [row._id, row.count]));
};

export const countNewUsersSince = async (since: Date): Promise<number> =>
  User.countDocuments({ createdAt: { $gte: since } });

export const countActiveAdmins = async (): Promise<number> =>
  User.countDocuments({ role: "admin", status: "active" });

export const findUsers = async (query: AdminUserListQuery) => {
  const filter: Record<string, unknown> = {};
  if (query.status) {
    filter.status = query.status;
  }
  if (query.search) {
    const escaped = query.search.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    filter.$or = [
      { name: { $regex: escaped, $options: "i" } },
      { email: { $regex: escaped, $options: "i" } },
    ];
  }

  const total = await User.countDocuments(filter);
  const skip = (query.page - 1) * query.limit;
  const docs = await User.find(filter)
    .select(SAFE_USER_FIELDS)
    .sort({ createdAt: -1 })
    .skip(skip)
    .limit(query.limit)
    .lean();

  return { total, docs };
};

export const findUserById = async (id: string) =>
  User.findById(id).select(SAFE_USER_FIELDS).lean();

export const updateUserStatus = async (
  id: string,
  status: "active" | "disabled",
) =>
  User.findByIdAndUpdate(id, { status }, { new: true })
    .select(SAFE_USER_FIELDS)
    .lean();

export const countTasks = async () => Task.countDocuments({ deletedAt: null });

export const countTasksByStatus = async () => {
  const grouped = await Task.aggregate<{
    _id: string;
    count: number;
  }>([
    { $match: { deletedAt: null } },
    { $group: { _id: "$status", count: { $sum: 1 } } },
  ]);
  return Object.fromEntries(grouped.map((row) => [row._id, row.count]));
};

export const countTasksCreatedSince = async (since: Date): Promise<number> =>
  Task.countDocuments({ deletedAt: null, createdAt: { $gte: since } });

export const countTasksCompletedSince = async (since: Date): Promise<number> =>
  Task.countDocuments({
    deletedAt: null,
    status: "completed",
    completedAt: { $gte: since },
  });

/** Daily counts for a date field over the trailing `days` window (UTC). */
export const tasksPerDay = async (
  field: "createdAt" | "completedAt",
  days: number,
): Promise<AdminTrendPoint[]> => {
  const since = new Date();
  since.setUTCDate(since.getUTCDate() - (days - 1));
  since.setUTCHours(0, 0, 0, 0);

  const match: Record<string, unknown> = {
    deletedAt: null,
    [field]: { $gte: since },
  };
  if (field === "completedAt") {
    match.status = "completed";
  }

  const rows = await Task.aggregate<{
    _id: string;
    count: number;
  }>([
    { $match: match },
    {
      $group: {
        _id: {
          $dateToString: {
            format: "%Y-%m-%d",
            date: `$${field}`,
            timezone: "UTC",
          },
        },
        count: { $sum: 1 },
      },
    },
  ]);

  const byDay = new Map(rows.map((row) => [row._id, row.count]));
  const points: AdminTrendPoint[] = [];
  for (let offset = days - 1; offset >= 0; offset -= 1) {
    const day = new Date();
    day.setUTCDate(day.getUTCDate() - offset);
    const key = day.toISOString().slice(0, 10);
    points.push({ date: key, count: byDay.get(key) ?? 0 });
  }
  return points;
};
