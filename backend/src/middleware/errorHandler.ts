import type { NextFunction, Request, Response } from "express";
import { AppError } from "../shared/utils/AppError.js";
import { logServerError } from "../shared/utils/securityLogger.js";

interface RequestError extends Error {
  type?: string;
  status?: number;
}

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null;

const isMongooseValidationError = (err: unknown): boolean =>
  isRecord(err) && err.name === "ValidationError";

const isDuplicateKeyError = (err: unknown): boolean =>
  isRecord(err) &&
  (err.code === 11000 || err.code === 11001) &&
  typeof err.name === "string" &&
  err.name.startsWith("Mongo");

export const errorHandler = (
  err: unknown,
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  if (res.headersSent) {
    next(err);
    return;
  }

  if (err instanceof AppError) {
    res.status(err.status).json({
      error: err.message,
      code: err.code,
      ...(err.details === undefined ? {} : { details: err.details }),
    });
    return;
  }

  const requestError: RequestError | null = isRecord(err)
    ? (err as unknown as RequestError)
    : null;

  if (requestError?.type === "entity.parse.failed") {
    res.status(400).json({
      error: "Request body must be valid JSON",
      code: "INVALID_JSON",
    });
    return;
  }

  if (
    requestError?.type === "entity.too.large" ||
    requestError?.status === 413
  ) {
    res.status(413).json({
      error: "Request body is too large",
      code: "PAYLOAD_TOO_LARGE",
    });
    return;
  }

  if (isDuplicateKeyError(err)) {
    res.status(409).json({
      error: "Resource already exists",
      code: "CONFLICT",
    });
    return;
  }

  if (isMongooseValidationError(err)) {
    res.status(400).json({
      error: "Validation failed",
      code: "VALIDATION_ERROR",
    });
    return;
  }

  logServerError({
    requestId: req.requestId,
    method: req.method,
    path: req.path,
    error: err instanceof Error ? err.message : "Unknown error",
  });

  res.status(500).json({
    error: "Internal server error",
    code: "INTERNAL_ERROR",
  });
};
