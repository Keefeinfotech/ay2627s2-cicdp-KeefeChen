/**
 * File Name: seed-admin-demo.ts
 * Description: Seeds demonstration accounts and realistic sample data for the
 *              admin console and presentations.
 *
 * Safety model:
 *  - Skips any account whose email already exists (idempotent re-runs).
 *  - Skips task creation for users who already own tasks.
 *  - Refuses to run with NODE_ENV=production unless ALLOW_DEMO_SEED=true is
 *    set explicitly in the environment.
 *  - Never stores plaintext passwords; hashes with the same bcrypt
 *    configuration the application uses at sign-up.
 *
 * Usage:
 *   npm run seed:demo            # seed users, tasks and stats spread
 *   ALLOW_DEMO_SEED=true NODE_ENV=production npm run seed:demo   (discouraged)
 *
 * Credentials created (documented in README.md and docs/admin/ADMINISTRATION.md):
 *   admin@auxilia.demo  / AdminDemo!2026   (administrator)
 *   grace@auxilia.demo  / DemoUser!2026    (standard user)
 *   liam@auxilia.demo   / DemoUser!2026
 *   priya@auxilia.demo  / DemoUser!2026
 *   wei@auxilia.demo    / DemoUser!2026
 *   fatimah@auxilia.demo / DemoUser!2026
 *   daniel@auxilia.demo / DemoUser!2026
 */

import bcrypt from "bcryptjs";

import { connectDatabase, disconnectDatabase } from "../src/config/database.js";
import { getBcryptRounds, isProduction } from "../src/config/environment.js";
import { User } from "../src/modules/users/user.model.js";
import { Task } from "../src/modules/tasks/task.model.js";

// NOSONAR — public demonstration credentials, not secrets. They exist only
// to run the local demo seed (see docs/admin/ADMINISTRATION.md §6); the seed
// refuses to run with NODE_ENV=production without ALLOW_DEMO_SEED=true, and
// the passwords are documented as public in the README and the admin doc.
const ADMIN_EMAIL = "admin@auxilia.demo";
const ADMIN_PASSWORD = "AdminDemo!2026"; // NOSONAR
const USER_PASSWORD = "DemoUser!2026"; // NOSONAR

const DEMO_USERS: ReadonlyArray<{
  name: string;
  email: string;
  daysAgoRegistered: number;
  daysAgoLastLogin: number | null;
  status: "active" | "disabled" | "pending";
}> = [
  {
    name: "Grace Tan",
    email: "grace@auxilia.demo",
    daysAgoRegistered: 41,
    daysAgoLastLogin: 0,
    status: "active",
  },
  {
    name: "Liam Chen",
    email: "liam@auxilia.demo",
    daysAgoRegistered: 33,
    daysAgoLastLogin: 1,
    status: "active",
  },
  {
    name: "Priya Patel",
    email: "priya@auxilia.demo",
    daysAgoRegistered: 27,
    daysAgoLastLogin: 2,
    status: "active",
  },
  {
    name: "Wei Lin",
    email: "wei@auxilia.demo",
    daysAgoRegistered: 19,
    daysAgoLastLogin: 5,
    status: "active",
  },
  {
    name: "Fatimah Rahman",
    email: "fatimah@auxilia.demo",
    daysAgoRegistered: 11,
    daysAgoLastLogin: 9,
    status: "active",
  },
  {
    name: "Daniel Ong",
    email: "daniel@auxilia.demo",
    daysAgoRegistered: 6,
    daysAgoLastLogin: null,
    status: "disabled",
  },
  {
    name: "Meera Krishnan",
    email: "meera@auxilia.demo",
    daysAgoRegistered: 2,
    daysAgoLastLogin: null,
    status: "pending",
  },
];

const TASK_TEMPLATES: ReadonlyArray<{
  title: string;
  status: "todo" | "in_progress" | "completed";
  priority: "low" | "medium" | "high" | "urgent";
  daysAgoCreated: number;
}> = [
  {
    title: "Revise operating systems chapter 4",
    status: "completed",
    priority: "high",
    daysAgoCreated: 13,
  },
  {
    title: "Submit database assignment 3",
    status: "completed",
    priority: "urgent",
    daysAgoCreated: 12,
  },
  {
    title: "Prepare for chemistry quiz",
    status: "completed",
    priority: "medium",
    daysAgoCreated: 10,
  },
  {
    title: "Draft reflection journal entry",
    status: "completed",
    priority: "low",
    daysAgoCreated: 9,
  },
  {
    title: "Group project: literature review",
    status: "in_progress",
    priority: "high",
    daysAgoCreated: 8,
  },
  {
    title: "Weekly lab report — data structures",
    status: "in_progress",
    priority: "medium",
    daysAgoCreated: 7,
  },
  {
    title: "Book campus washing machine slot",
    status: "todo",
    priority: "low",
    daysAgoCreated: 6,
  },
  {
    title: "Review calculus problem set",
    status: "todo",
    priority: "high",
    daysAgoCreated: 5,
  },
  {
    title: "Plan study session for networking",
    status: "todo",
    priority: "medium",
    daysAgoCreated: 3,
  },
  {
    title: "Finish AI assistant API integration",
    status: "todo",
    priority: "high",
    daysAgoCreated: 1,
  },
];

const DAY_MS = 24 * 60 * 60 * 1000;
const daysAgo = (days: number): Date => new Date(Date.now() - days * DAY_MS);

const log = (message: string): void => {
  console.log(`[seed:demo] ${message}`);
};

const error = (message: string): void => {
  console.error(`[seed:demo] ERROR: ${message}`);
};

const main = async (): Promise<void> => {
  if (isProduction() && process.env.ALLOW_DEMO_SEED !== "true") {
    error(
      "Refusing to seed demo accounts in production. Set ALLOW_DEMO_SEED=true " +
        "only if you fully understand the risk.",
    );
    process.exit(1);
  }

  const rounds = getBcryptRounds();
  await connectDatabase();

  try {
    // ---------------------------------------------------------- admin account
    const adminHash = await bcrypt.hash(ADMIN_PASSWORD, rounds);
    const admin = await User.findOne({ email: ADMIN_EMAIL }).lean();
    if (admin) {
      log(`skip ${ADMIN_EMAIL}: already exists`);
    } else {
      await User.create({
        name: "Auxilia Demo Admin",
        email: ADMIN_EMAIL,
        passwordHash: adminHash,
        role: "admin",
        status: "active",
        lastLoginAt: daysAgo(0),
      });
      log(`created administrator: ${ADMIN_EMAIL}`);
    }

    // ------------------------------------------------------- standard accounts
    const userHash = await bcrypt.hash(USER_PASSWORD, rounds);
    const createdIds: string[] = [];
    for (const demo of DEMO_USERS) {
      const existing = await User.findOne({ email: demo.email })
        .select("_id")
        .lean();
      if (existing) {
        log(`skip ${demo.email}: already exists`);
        createdIds.push(String((existing as { _id: string })._id));
        continue;
      }

      const user = await User.create({
        name: demo.name,
        email: demo.email,
        passwordHash: userHash,
        role: "user",
        status: demo.status,
        createdAt: daysAgo(demo.daysAgoRegistered),
        lastLoginAt:
          demo.daysAgoLastLogin === null
            ? null
            : daysAgo(demo.daysAgoLastLogin),
      });
      createdIds.push(String(user._id));
      log(`created standard user: ${demo.email} (${demo.status})`);
    }

    // ------------------------------------------------------------------- tasks
    // Spread creation dates and priorities across users so the analytics charts
    // have meaningful data. Completion timestamps trail creation dates.
    let tasksCreated = 0;
    for (const userId of createdIds) {
      const existingTasks = await Task.countDocuments({ userId });
      if (existingTasks > 0) {
        log(`skip tasks for ${userId}: ${existingTasks} already exist`);
        continue;
      }

      const docs = TASK_TEMPLATES.map((template, index) => {
        const createdAt = daysAgo(template.daysAgoCreated);
        const completed = template.status === "completed";
        return {
          userId,
          title: template.title,
          priority: template.priority,
          status: template.status,
          createdAt,
          completedAt: completed
            ? new Date(createdAt.getTime() + DAY_MS / 2)
            : null,
          // Rotate a small amount of due-date variety into the seed.
          dueDate:
            template.status === "todo" && index % 2 === 0
              ? new Date(Date.now() + (index + 1) * DAY_MS)
              : null,
        };
      });

      await Task.insertMany(docs);
      tasksCreated += docs.length;
      log(`seeded ${docs.length} tasks for user ${userId}`);
    }

    log(
      `done: ${tasksCreated} tasks seeded across ${createdIds.length} users.`,
    );
    log(
      "sign in as admin@auxilia.demo / AdminDemo!2026 (demo only — not for production).",
    );
  } catch (err) {
    error(err instanceof Error ? err.message : String(err));
    process.exitCode = 1;
  } finally {
    await disconnectDatabase();
  }
};

void main();
