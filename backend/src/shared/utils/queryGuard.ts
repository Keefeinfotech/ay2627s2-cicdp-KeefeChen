/**
 * Small helpers for building MongoDB query objects from request data.
 *
 * MongoDB treats an object supplied as a field value as a query operator
 * (`{ $ne: ... }`, `{ $regex: ... }`, ...). Wrapping validated scalars in
 * `$eq` forces them to be interpreted as literal values. These helpers also
 * make the trust boundary explicit for static analysis (CodeQL NoSQL
 * injection checks) and for reviewers.
 */

import { AppError } from "./AppError.js";

/** Throws unless `value` is a non-empty string; returns a freshly typed string. */
export const requireString = (value: unknown, label: string): string => {
  if (typeof value !== "string" || value.length === 0) {
    throw new AppError(400, "INVALID_INPUT", `Invalid ${label}.`);
  }
  return value;
};

/** Literal equality wrapper for user-provided values in Mongo filters. */
export const literal = <T extends string | number | boolean | Date>(
  value: T,
): { $eq: T } => ({ $eq: value });
