/**
 * File Name: admin.types.ts
 * Description: Contracts for the administrative module. Responses expose only
 *              non-sensitive fields; password hashes, tokens and MFA secrets
 *              never leave the repository.
 * Author: Keefe Chen
 */

import type { UserRole, UserStatus } from "../users/user.types.js";

/** Query parameters accepted by `GET /api/admin/users`. */
export interface AdminUserListQuery {
  page: number;
  limit: number;
  search?: string;
  status?: UserStatus;
}

/** Safe projection of a user account for administrative listing. */
export interface AdminUserView {
  id: string;
  name: string;
  email: string;
  role: UserRole;
  status: UserStatus;
  createdAt: Date | null;
  lastLoginAt: Date | null;
}

/** One bucket of a daily trend series (oldest first). */
export interface AdminTrendPoint {
  date: string; // YYYY-MM-DD
  count: number;
}

export interface AdminUserStats {
  total: number;
  active: number;
  disabled: number;
  pending: number;
  newLast7Days: number;
}

export interface AdminTaskStats {
  total: number;
  todo: number;
  inProgress: number;
  completed: number;
  archived: number;
  completionRate: number; // completed / (total - archived); 0 when empty
  createdLast7Days: number;
  completedLast7Days: number;
}

export interface AdminStats {
  users: AdminUserStats;
  tasks: AdminTaskStats;
  /** Tasks created per day for the last 14 days (UTC). */
  taskCreationTrend: AdminTrendPoint[];
  /** Tasks completed per day for the last 14 days (UTC). */
  taskCompletionTrend: AdminTrendPoint[];
}

export interface AdminListResponse<T> {
  items: T[];
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}
