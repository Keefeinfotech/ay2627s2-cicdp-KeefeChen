
/**
 * File Name: user.service.ts
 * Description: Implements business logic for user account operations.
 * Author: Keefe Chen
 */

import bcrypt from "bcryptjs";

import { AppError } from "../../shared/utils/AppError.js";

import { userRepository } from "./user.repository.js";

import type { UserRecord } from "./user.model.js";

import type {
  PublicUser,
  PublicUserSummary,
  UpdateOwnProfileInput,
} from "./user.types.js";

/**
 * Converts a database record into a safe public response.
 *
 * Sensitive authentication information is not exposed.
 */
function toPublicUser(user: UserRecord): PublicUser {
  return {
    id: user._id,
    name: user.name,
    email: user.email,
    role: user.role,
    status: user.status,
    emailVerifiedAt: user.emailVerifiedAt,
    lastLoginAt: user.lastLoginAt,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt,
  };
}

/**
 * Converts a database record into a limited user summary.
 */
function toPublicSummary(
  user: UserRecord
): PublicUserSummary {
  return {
    id: user._id,
    name: user.name,
    role: user.role,
  };
}

export const userService = {
  /**
   * Retrieves the authenticated user's profile.
   */
  async getOwnProfile(
    userId: string
  ): Promise<PublicUser> {
    const user = await userRepository.findById(userId);

    if (!user) {
      throw new AppError(
        404,
        "USER_NOT_FOUND",
        "User account was not found."
      );
    }

    if (user.status !== "active") {
      throw new AppError(
        403,
        "ACCOUNT_UNAVAILABLE",
        "This account is unavailable."
      );
    }

    return toPublicUser(user);
  },

  /**
   * Updates the authenticated user's permitted profile fields.
   */
  async updateOwnProfile(
    userId: string,
    input: UpdateOwnProfileInput
  ): Promise<PublicUser> {
    const user = await userRepository.updateOwnProfile(
      userId,
      input
    );

    if (!user) {
      throw new AppError(
        404,
        "USER_NOT_FOUND",
        "User account was not found or is unavailable."
      );
    }

    return toPublicUser(user);
  },

  /**
   * Retrieves limited user information for other modules.
   *
   * This avoids exposing unnecessary account information
   * when another feature only needs a user's identity.
   */
  async getPublicSummary(
    userId: string
  ): Promise<PublicUserSummary> {
    const user = await userRepository.findById(userId);

    if (!user || user.status !== "active") {
      throw new AppError(
        404,
        "USER_NOT_FOUND",
        "User account was not found."
      );
    }

    return toPublicSummary(user);
  },

  /**
   * Deactivates the authenticated user's account.
   *
   * Requires the current password as an additional
   * security verification step.
   *
   * The account is deactivated rather than permanently
   * deleted to preserve related records and audit history.
   */
  async deleteOwnAccount(
    userId: string,
    currentPassword: string
  ): Promise<void> {
    // Retrieve the account and explicitly include its password hash.
    const user = await userRepository.findByIdWithPassword(
      userId
    );

    if (
      !user ||
      user.status !== "active" ||
      user.deletedAt
    ) {
      throw new AppError(
        404,
        "USER_NOT_FOUND",
        "User account was not found or is unavailable."
      );
    }

    // Ensure a password hash is available for verification.
    if (!user.passwordHash) {
      throw new AppError(
        403,
        "PASSWORD_VERIFICATION_UNAVAILABLE",
        "Account password verification is unavailable."
      );
    }

    // Verify the supplied password against the stored hash.
    const passwordMatches = await bcrypt.compare(
      currentPassword,
      user.passwordHash
    );

    if (!passwordMatches) {
      throw new AppError(
        401,
        "INVALID_PASSWORD",
        "The current password is incorrect."
      );
    }

    // Deactivate the account using a conditional database update.
    // This prevents two concurrent requests from deactivating
    // the same account successfully.
    const deactivated = await userRepository.deactivateAccount(
      userId
    );

    if (!deactivated) {
      throw new AppError(
        409,
        "ACCOUNT_DEACTIVATION_CONFLICT",
        "The account could not be deactivated. It may already be unavailable."
      );
    }
  },
};
