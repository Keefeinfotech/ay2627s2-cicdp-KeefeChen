/**
 * File Name: authorize.middleware.ts
 * Description: Middleware for role-based access control.
 * Author: Keefe Chen
 *
 * Role comparison is case-insensitive because the domain stores roles in
 * lower case ("admin", "user") while several call sites use conventional
 * upper case ("ADMIN"). The check is always performed server-side on the
 * role read from the database session — never from client input.
 */

import { NextFunction, Request, Response } from "express";
import { forbidden, unauthorized } from "../shared/utils/AppError.js";

/**
 * Application roles. The canonical list lives in `constants/security.ts`
 * (USER_ROLES); the legacy upper-case variants are accepted so existing
 * call sites keep working.
 */
export type UserRole =
  "admin" | "user" | "ADMIN" | "GROUP_OWNER" | "GROUP_MEMBER";

/**
 * Authorisation middleware.
 *
 * Checks whether the authenticated user has at least one of the required
 * roles. Comparison is performed with both sides lower-cased.
 *
 * @param allowedRoles - Roles permitted to access the resource.
 */
export const authorize = (...allowedRoles: string[]) => {
  const allowed = allowedRoles.map((role) => role.toLowerCase());
  return (req: Request, res: Response, next: NextFunction): void => {
    try {
      // Ensure the user is authenticated.
      if (!req.userId) {
        throw unauthorized();
      }

      // Ensure the user's role is available.
      const userRole = req.userRole;

      if (!userRole || typeof userRole !== "string") {
        throw forbidden("User role not found.");
      }

      // Check whether the user's role is permitted (case-insensitive).
      if (!allowed.includes(userRole.toLowerCase())) {
        throw forbidden("You do not have permission to perform this action.");
      }

      return next();
    } catch (error) {
      return next(error);
    }
  };
};
