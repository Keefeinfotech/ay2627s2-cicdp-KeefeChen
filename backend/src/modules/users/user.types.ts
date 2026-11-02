/**
 * File Name: user.types.ts
 * Description: Defines user domain types and API data contracts.
 * Author: Keefe Chen
 */

export const USER_ROLES = ["user", "admin"] as const;

export type UserRole = (typeof USER_ROLES)[number];

export const USER_STATUSES = [
  "active",
  "disabled",
  "pending",
] as const;

export type UserStatus = (typeof USER_STATUSES)[number];

/**
 * Internal input used when creating a user.
 * The password must already be securely hashed.
 */
export interface CreateUserInput {
  name: string;
  email: string;
  passwordHash: string;
  role?: UserRole;
  status?: UserStatus;
}

/**
 * Fields that a user is allowed to update
 * through their own profile endpoint.
 */
export interface UpdateOwnProfileInput {
  name?: string;
}

/**
 * Safe user representation returned by the API.
 * Never includes passwordHash.
 */
export interface PublicUser {
  id: string;
  name: string;
  email: string;
  role: UserRole;
  status: UserStatus;
  emailVerifiedAt: Date | null;
  lastLoginAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

/**
 * Minimal user information for other modules.
 */
export interface PublicUserSummary {
  id: string;
  name: string;
  role: UserRole;
}