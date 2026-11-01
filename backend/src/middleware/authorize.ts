/**
 * File Name: authorize.middleware.ts
 * Description: Middleware for role-based access control.
 * Author: Keefe Chen
 */

import { NextFunction, Request, Response } from "express";
import { forbidden, unauthorized } from "../shared/utils/AppError.js";

/**
 * Application roles.
 */
export type UserRole =
  | "ADMIN"
  | "GROUP_OWNER"
  | "GROUP_MEMBER";

/**
 * Authorisation middleware.
 *
 * Checks whether the authenticated user has at least one
 * of the required roles.
 *
 * @param allowedRoles - Roles permitted to access the resource.
 */
export const authorize = (...allowedRoles: UserRole[]) => {
  return (
    req: Request,
    res: Response,
    next: NextFunction
  ): void => {
    try {
      // Ensure the user is authenticated.
      if (!req.userId) {
        throw unauthorized();
      }

      // Ensure the user's role is available.
      const userRole = req.userRole as UserRole | undefined;

      if (!userRole) {
        throw forbidden("User role not found.");
      }

      // Check whether the user's role is permitted.
      if (!allowedRoles.includes(userRole)) {
        throw forbidden(
          "You do not have permission to perform this action."
        );
      }

      return next();
    } catch (error) {
      return next(error);
    }
  };
};
