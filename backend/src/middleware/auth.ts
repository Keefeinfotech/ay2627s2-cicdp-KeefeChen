
/**
 * File Name: auth.ts
 * Description: Handles authentication and session verification middleware.
 * Author: Keefe Chen
 */

import {
  NextFunction,
  Request,
  Response,
} from "express";

import { User } from "../modules/auth/auth.model.js";
import { allowConcurrentSessions } from "../config/environment.js";
import { unauthorized } from "../shared/utils/AppError.js";
import { isSessionActive } from "../shared/utils/session.js";
import { verifyAccessToken } from "../shared/utils/tokens.js";

/**
 * Authenticate a user using a Bearer access token.
 *
 * Checks:
 * 1. Authorization header exists.
 * 2. Bearer token is provided.
 * 3. Access token is valid and not expired.
 * 4. User account exists.
 * 5. Active session is valid unless concurrent sessions are allowed.
 */
export const requireAuth = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const header = req.headers.authorization;

    // Check whether the Authorization header exists.
    if (!header?.startsWith("Bearer ")) {
      res.status(401).json({
        error: "Authentication required",
        code: "UNAUTHORIZED",
      });
      return;
    }

    // Extract the access token from the Bearer header.
    const token = header.slice("Bearer ".length).trim();

    // Verify the JWT access token.
    const payload = verifyAccessToken(token);

    if (!payload) {
      res.status(401).json({
        error: "Invalid or expired session",
        code: "UNAUTHORIZED",
      });
      return;
    }

    // Retrieve the user associated with the token.
    const user = await User.findById(payload.sub).lean();

    if (!user) {
      res.status(401).json({
        error: "Invalid or expired session",
        code: "UNAUTHORIZED",
      });
      return;
    }

    // Enforce single-session authentication by default.
    // A newer login invalidates previously issued tokens.
    if (
      !allowConcurrentSessions() &&
      !isSessionActive(user, payload.jti)
    ) {
      res.status(401).json({
        error: "Session ended. This account signed in on another device.",
        code: "SESSION_REPLACED",
      });
      return;
    }

    // Attach authenticated user information to the request.
    req.userId = String(user._id);
    req.userEmail = user.email;

    // Continue to the next middleware or controller.
    next();
  } catch (error) {
    next(error);
  }
};

/**
 * Retrieve the authenticated user's ID.
 *
 * Throws an unauthorized error if authentication
 * information is missing from the request.
 */
export const requireUserId = (req: Request): string => {
  if (!req.userId) {
    throw unauthorized();
  }

  return req.userId;
};
