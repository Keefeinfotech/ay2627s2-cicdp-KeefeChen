
/**
 * File Name: AppError.ts
 * Description: Defines reusable application errors and HTTP status codes.
 * Author: Keefe Chen
 */

export class AppError extends Error {
  readonly status: number;
  readonly code: string;
  readonly details?: unknown;

  constructor(
    status: number,
    code: string,
    message: string,
    details?: unknown
  ) {
    super(message);

    this.name = "AppError";
    this.status = status;
    this.code = code;
    this.details = details;

    // Maintain the correct prototype chain.
    Object.setPrototypeOf(this, new.target.prototype);
  }
}

export const unauthorized = (message = "Authentication required"): AppError =>
  new AppError(401, "UNAUTHORIZED", message);

export const forbidden = (message = "Insufficient permissions"): AppError =>
  new AppError(403, "FORBIDDEN", message);

export const conflict = (message: string): AppError =>
  new AppError(409, "CONFLICT", message);

export const sessionReplaced = (): AppError =>
  new AppError(
    401,
    "SESSION_REPLACED",
    "Session ended. This account signed in on another device."
  );

export const badRequest = (message = "Invalid request"): AppError =>
  new AppError(400, "BAD_REQUEST", message);

export const notFound = (message = "Not found"): AppError =>
  new AppError(404, "NOT_FOUND", message);
