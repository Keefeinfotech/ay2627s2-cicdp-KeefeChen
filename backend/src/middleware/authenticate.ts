import type { NextFunction, Request, Response } from "express";
import { AppError, unauthorized } from "../shared/utils/AppError.js";
import { logSecurityEvent } from "../shared/utils/securityLogger.js";
import { verifyAccessToken } from "../shared/utils/tokens.js";
import { authenticateSession } from "../modules/auth/auth.service.js";

const logAuthFailure = (req: Request, event: string, reason: string): void => {
  logSecurityEvent(event, {
    requestId: req.requestId,
    ip: req.ip,
    path: req.path,
    reason,
  });
};

export const authenticate = async (
  req: Request,
  _res: Response,
  next: NextFunction,
): Promise<void> => {
  try {
    const header = req.headers.authorization;
    if (!header?.startsWith("Bearer ")) {
      throw unauthorized();
    }

    const token = header.slice("Bearer ".length).trim();
    const payload = verifyAccessToken(token);
    if (!payload) {
      logAuthFailure(req, "auth_failed", "invalid_token");
      throw unauthorized("Invalid or expired session");
    }

    const user = await authenticateSession(payload.sub, payload.jti);

    req.userId = user.id;
    req.userEmail = user.email;
    req.userRole = user.role;
    req.sessionId = payload.jti;
    next();
  } catch (err) {
    if (err instanceof AppError && err.code === "SESSION_REPLACED") {
      logAuthFailure(req, "auth_failed", "session_replaced");
    }
    next(err);
  }
};
