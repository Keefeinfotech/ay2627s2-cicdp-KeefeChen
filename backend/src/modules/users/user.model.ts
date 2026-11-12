/**
 * File Name: user.model.ts
 * Description: Defines the User entity and document configuration.
 *              The schema itself lives in ./user.schema.js — shared with
 *              the auth module — so both module registrations always agree.
 * Author: Keefe Chen
 */

import mongoose, { type HydratedDocument, type Model } from "mongoose";

import { userSchema, type UserRecord } from "./user.schema.js";

export type UserRecordType = UserRecord;
export type { UserRecord } from "./user.schema.js";

/**
 * Represents a hydrated Mongoose User document.
 */
export type UserDocument = HydratedDocument<UserRecord>;

/**
 * Reuses the existing User model during development to prevent Mongoose
 * model recompilation errors.
 */
export const User: Model<UserRecord> =
  (mongoose.models.User as Model<UserRecord> | undefined) ??
  mongoose.model<UserRecord>("User", userSchema);
