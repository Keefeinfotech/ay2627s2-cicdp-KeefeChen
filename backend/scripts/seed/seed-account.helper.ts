/**
 * File Name: seed-account.helper.ts
 * Description: Shared account-creation helpers for the local seed scripts.
 *
 * Both the demo and the test-dummy seeds need the same idempotent
 * "create if missing" behaviour. Keeping it here avoids duplicating the bcrypt
 * hashing and Mongoose lookup logic in every script.
 */

import bcrypt from "bcryptjs";

import { User } from "../../src/modules/users/user.model.js";

export interface SeedContext {
  rounds: number;
  log: (message: string) => void;
  error: (message: string) => void;
}

export interface SeedAccount {
  name: string;
  email: string;
  password: string;
  role: "admin" | "user";
  status?: "active" | "disabled" | "pending";
  extraFields?: Record<string, unknown>;
}

export const createSeedLogger = (
  prefix: string,
): Pick<SeedContext, "log" | "error"> => ({
  log: (message: string) => console.log(`[${prefix}] ${message}`),
  error: (message: string) => console.error(`[${prefix}] ERROR: ${message}`),
});

/**
 * Creates an account only when its email is not already present, so seed
 * scripts can be re-run safely. Returns the account id for downstream seeding.
 */
export const ensureSeedAccount = async (
  account: SeedAccount,
  context: SeedContext,
  label: string,
): Promise<string> => {
  const existing = await User.findOne({ email: account.email })
    .select("_id")
    .lean();
  if (existing) {
    context.log(`skip ${account.email}: already exists`);
    return String((existing as { _id: unknown })._id);
  }

  const passwordHash = await bcrypt.hash(account.password, context.rounds);
  const created = await User.create({
    name: account.name,
    email: account.email,
    passwordHash,
    role: account.role,
    status: account.status ?? "active",
    ...account.extraFields,
  });
  context.log(`created ${label}: ${account.email}`);
  return String(created._id);
};
