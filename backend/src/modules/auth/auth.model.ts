/**
 * File Name: auth.model.ts
 * Description: Auth-side handle on the shared User model. The schema is the
 *              single source of truth in ../users/user.schema.js; this module
 *              keeps the auth-facing type aliases for compatibility.
 * Author: Keefe Chen
 */

import mongoose, { type HydratedDocument } from "mongoose";

import { userSchema, type UserRecord } from "../users/user.schema.js";

export type IUserRecord = UserRecord;

/** The hydrated Mongoose document type consumers receive. */
export type IUser = HydratedDocument<UserRecord>;

export const User = mongoose.model<UserRecord>("User", userSchema);
