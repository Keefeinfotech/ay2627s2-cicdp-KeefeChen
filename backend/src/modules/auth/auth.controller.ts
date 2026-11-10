import type { NextFunction, Request, Response } from "express";
import { AppError } from "../../shared/utils/AppError.js";
import { requireUserId } from "../../shared/utils/request.js";
import { logSecurityEvent } from "../../shared/utils/securityLogger.js";
import * as authService from "./auth.service.js";

const logAuthFailure = (req: Request, event: string): void => {
  logSecurityEvent(event, {
    requestId: req.requestId,
    ip: req.ip,
    path: req.path,
  });
};

export const signup = async (
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> => {
  try {
    const { name, email, password } = req.body as {
      name?: string;
      email: string;
      password: string;
    };
    const result = await authService.signup({ name, email, password });
    res.status(201).json(result);
  } catch (err) {
    if (err instanceof AppError && err.code === "CONFLICT") {
      logAuthFailure(req, "signup_conflict");
    }
    next(err);
  }
};

export const login = async (
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> => {
  try {
    const { email, password } = req.body as {
      email: string;
      password: string;
    };
    const result = await authService.login({ email, password });
    res.status(200).json(result);
  } catch (err) {
    if (err instanceof AppError && err.code === "UNAUTHORIZED") {
      logAuthFailure(req, "login_failed");
    }
    next(err);
  }
};

export const logout = async (
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> => {
  try {
    await authService.logout(requireUserId(req));
    res.status(204).send();
  } catch (err) {
    next(err);
  }
};

export const forgotPassword = async (
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> => {
  try {
    const { email } = req.body as { email: string };
    const result = await authService.requestPasswordReset({ email });
    logSecurityEvent("password_reset_requested", {
      requestId: req.requestId,
      ip: req.ip,
      path: req.path,
    });
    res.status(200).json(result);
  } catch (err) {
    next(err);
  }
};

export const resetPassword = async (
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> => {
  try {
    const { token, password } = req.body as {
      token: string;
      password: string;
    };
    const result = await authService.resetPassword({ token, password });
    logSecurityEvent("password_reset_completed", {
      requestId: req.requestId,
      ip: req.ip,
      path: req.path,
    });
    res.status(200).json(result);
  } catch (err) {
    next(err);
  }
};

export const me = async (
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> => {
  try {
    const user = await authService.getCurrentUser(requireUserId(req));
    res.status(200).json({ user });
  } catch (err) {
    next(err);
  }
};
