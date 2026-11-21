/**
 * File Name: migrate-reminder-user-ids.ts
 * Description: Migrates `reminders.userId` from ObjectId to String so that it
 *              can reference users._id (a String UUID) and support populate().
 *
 *              The earlier users migration converted user ObjectId _id values
 *              into their hex-string form, so an ObjectId reminder.userId is
 *              mapped to the user whose _id equals that hex string. Reminders
 *              with no matching user are LEFT UNCHANGED and reported for
 *              manual review; they are never deleted or guessed.
 *
 * Behaviour:
 *  - Dry run by default (report only).
 *  - --apply performs the migration; production additionally requires
 *    ALLOW_REMINDER_ID_MIGRATION=true.
 *  - Originals are copied to `reminders_backup_pre_string_user_ids` before
 *    update, for audit and rollback.
 *  - Always runs a post-migration validation of ownership references.
 *
 * Usage:
 *   npm run migrate:reminder-user-ids
 *   npm run migrate:reminder-user-ids -- --apply
 */
import "dotenv/config";

import mongoose from "mongoose";

import { connectDatabase, disconnectDatabase } from "../src/config/database.js";
import { isProduction } from "../src/config/environment.js";

const APPLY = process.argv.includes("--apply");

const log = (message: string): void => {
  console.log(`[migrate:reminder-user-ids] ${message}`);
};

const error = (message: string): void => {
  console.error(`[migrate:reminder-user-ids] ERROR: ${message}`);
};

const main = async (): Promise<void> => {
  const production = isProduction();
  const allowed = process.env.ALLOW_REMINDER_ID_MIGRATION === "true";
  const dryRun = !APPLY || (production && !allowed);

  if (APPLY && production && !allowed) {
    error(
      "NODE_ENV=production requires ALLOW_REMINDER_ID_MIGRATION=true to apply.",
    );
    process.exit(1);
  }

  await connectDatabase();

  try {
    const db = mongoose.connection.db;
    if (!db) {
      throw new Error("Database connection is not initialised");
    }

    const reminders = db.collection("reminders");
    const users = db.collection("users");
    const backup = db.collection("reminders_backup_pre_string_user_ids");

    const candidates = await reminders
      .find({ userId: { $type: "objectId" } })
      .toArray();
    log(`found ${candidates.length} reminder(s) with ObjectId userId.`);

    const unresolved: string[] = [];
    let migrated = 0;

    if (dryRun) {
      log(
        "dry run: no documents were modified. Re-run with --apply to migrate.",
      );
    } else {
      for (const doc of candidates) {
        const objectId = doc.userId as {
          toHexString?: () => string;
          toString: () => string;
        };
        const stringId =
          typeof objectId.toHexString === "function"
            ? objectId.toHexString()
            : String(doc.userId);

        // Only migrate when the referenced user actually exists.
        const user = await users.findOne({ _id: stringId });
        if (!user) {
          unresolved.push(`${String(doc._id)} -> ${stringId}`);
          continue;
        }

        await backup.updateOne(
          { _id: doc._id },
          { $setOnInsert: doc },
          { upsert: true },
        );
        await reminders.updateOne(
          { _id: doc._id },
          { $set: { userId: stringId } },
        );
        migrated += 1;
      }
      log(`migrated ${migrated} of ${candidates.length} reminder(s).`);
      if (unresolved.length > 0) {
        log(
          `${unresolved.length} reminder(s) had no matching user and were left unchanged:`,
        );
        log(unresolved.slice(0, 20).join("\n"));
      }
      log(
        "backups kept in reminders_backup_pre_string_user_ids — drop after verification.",
      );
    }

    // Validation covers every reminder, including those already stored as
    // strings, so a failed or partial earlier run is detected too.
    const allReminders = await reminders
      .find({}, { projection: { _id: 1, userId: 1 } })
      .toArray();
    const userIds = new Set(
      (await users.find({}, { projection: { _id: 1 } }).toArray()).map((user) =>
        String(user._id),
      ),
    );
    const nonString = allReminders.filter(
      (doc) => typeof doc.userId !== "string",
    );
    const dangling = allReminders.filter(
      (doc) =>
        typeof doc.userId === "string" && !userIds.has(doc.userId as string),
    );

    log(
      `validation: ${allReminders.length} reminder(s); ${nonString.length} non-string userId; ${dangling.length} dangling userId.`,
    );
    if (dangling.length > 0) {
      log(
        `dangling examples: ${dangling
          .slice(0, 10)
          .map((doc) => String(doc._id))
          .join(", ")}`,
      );
    }
    if (!dryRun && (nonString.length > 0 || dangling.length > 0)) {
      error("post-migration validation failed; review the report above.");
      process.exitCode = 1;
    }
  } catch (err) {
    error(err instanceof Error ? err.message : String(err));
    process.exitCode = 1;
  } finally {
    await disconnectDatabase();
  }
};

void main();
