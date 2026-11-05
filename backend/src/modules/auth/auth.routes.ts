import type { NextFunction, Request, Response } from "express";
import { AppError, unauthorized, forbidden, conflict } from "../../shared/utils/AppError.js";
import { logSecurityEvent } from "../../shared/utils/securityLogger.js";
import * as authService from "./auth.service.js";

const logAuthFailure = (
  req: Request,
  event: string,
  reason: string
): void => {
  logSecurityEvent(event, {
    requestId: req.requestId,
    ip: req.ip,
    path: req.path,
    reason,
  });
};

const router = require("express").Router();

// POST /api/auth/signup
router.post("/signup", async (req: Request, res: Response, next: NextFunction) => {
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
      logAuthFailure(req, "signup_conflict", String(req.body.email));
    } else {
      const message = err instanceof Error ? err.message : "Unknown error";
      logAuthFailure(req, "signup_error", message);
    }
    next(err);
  }
});

// POST /api/auth/login
router.post("/login", async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { email, password } = req.body as {
      email: string;
      password: string;
    };
    const result = await authService.login({ email, password });
    res.status(200).json(result);
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unknown error";
    if (err instanceof AppError && err.code === "UNAUTHORIZED") {
      logAuthFailure(req, "login_failed", String(req.body.email));
    }
    next(err);
  }
});

// POST /api/auth/logout
router.post("/logout", async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = (req as any).userId;
    if (userId) {
      await authService.logout(userId);
    }
    res.status(204).send();
  } catch (err) {
    next(err);
  }
});

// GET /api/auth/me
router.get("/me", async (req: Request, res: Response, next: NextFunction) => {
  try {
    const user = await authService.getCurrentUser((req as any).userId);
    res.status(200).json({ user });
  } catch (err) {
    next(err);
  }
});

export default router;