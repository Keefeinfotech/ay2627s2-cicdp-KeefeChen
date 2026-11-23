/**
 * File Name: seed-test-dummies.ts
 * Description: Seeds lightweight test accounts — one administrator and three
 *              participants — so the app can be exercised with data in the
 *              dashboard, groups and sign-in flows.
 *
 * Safety model (mirrors seed-admin-demo.ts):
 *  - Skips any account whose email already exists (idempotent re-runs).
 *  - Refuses to run with NODE_ENV=production unless ALLOW_DEMO_SEED=true is
 *    set explicitly in the environment.
 *  - Never stores plaintext passwords; hashes with the same bcrypt
 *    configuration the application uses at sign-up.
 *
 * Usage:
 *   npm run seed:test-dummies          # seed the test dummy accounts
 *
 * Credentials created (public test values, delete after use):
 *   test-admin@auxilia.test         / TestAdmin$2026         (admin, active)
 *   test-participant-1@auxilia.test / TestParticipant$2026   (user, active)
 *   test-participant-2@auxilia.test / TestParticipant$2026   (user, active)
 *   test-participant-3@auxilia.test / TestParticipant$2026   (user, active)
 *
 * Participants have no tasks or groups yet — create some in the UI to explore.
 */

import "dotenv/config";

import bcrypt from "bcryptjs";

import {
  connectDatabase,
  disconnectDatabase,
} from "../../src/config/database.js";
import { getBcryptRounds, isProduction } from "../../src/config/environment.js";
import { User } from "../../src/modules/users/user.model.js";

// NOSONAR — public test credentials for local exploration only; see header.
const ADMIN_EMAIL = "test-admin@auxilia.test";
const ADMIN_PASSWORD = "TestAdmin$2026"; // NOSONAR
const USER_PASSWORD = "TestParticipant$2026"; // NOSONAR

const PARTICIPANTS = [
  { name: "Test Participant One", email: "test-participant-1@auxilia.test" },
  { name: "Test Participant Two", email: "test-participant-2@auxilia.test" },
  { name: "Test Participant Three", email: "test-participant-3@auxilia.test" },
] as const;

const log = (message: string): void => {
  console.log(`[seed:test-dummies] ${message}`);
};

const error = (message: string): void => {
  console.error(`[seed:test-dummies] ERROR: ${message}`);
};

const main = async (): Promise<void> => {
  if (isProduction() && process.env.ALLOW_DEMO_SEED !== "true") {
    error(
      "Refusing to seed test accounts in production. Set ALLOW_DEMO_SEED=true " +
        "only if you fully understand the risk.",
    );
    process.exit(1);
  }

  const rounds = getBcryptRounds();
  await connectDatabase();

  try {
    // ---------------------------------------------------------- administrator
    const adminHash = await bcrypt.hash(ADMIN_PASSWORD, rounds);
    const admin = await User.findOne({ email: ADMIN_EMAIL }).lean();
    if (admin) {
      log(`skip ${ADMIN_EMAIL}: already exists`);
    } else {
      await User.create({
        name: "Test Admin",
        email: ADMIN_EMAIL,
        passwordHash: adminHash,
        role: "admin",
        status: "active",
        emailVerifiedAt: new Date(),
      });
      log(`created administrator: ${ADMIN_EMAIL}`);
    }

    // --------------------------------------------------------- participants
    const userHash = await bcrypt.hash(USER_PASSWORD, rounds);
    for (const participant of PARTICIPANTS) {
      const existing = await User.findOne({
        email: participant.email,
      }).lean();
      if (existing) {
        log(`skip ${participant.email}: already exists`);
        continue;
      }
      await User.create({
        name: participant.name,
        email: participant.email,
        passwordHash: userHash,
        role: "user",
        status: "active",
        emailVerifiedAt: new Date(),
      });
      log(`created participant: ${participant.email}`);
    }

    const count = await User.countDocuments({ email: { $regex: "^test-" } });
    log(`done: ${count} test accounts ready.`);
  } catch (err) {
    error(err instanceof Error ? err.message : String(err));
    process.exitCode = 1;
  } finally {
    await disconnectDatabase();
  }
};

void main();
