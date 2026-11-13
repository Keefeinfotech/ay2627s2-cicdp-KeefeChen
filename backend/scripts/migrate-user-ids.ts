/**
 * File Name: migrate-user-ids.ts
 * Description: Migrates the users collection `_id` values from ObjectId to
 *              String.Required because auth/auth.model.ts historically used
 *              a default ObjectId _id while every other collection (and the
 *              users model in user.model.ts) uses String UUIDs - a mismatch
 *              that broke full-document saves and logins for UUID-id users.
 *
 * Behaviour:
 *  - Only documents whose `_id` is an ObjectId are migrated.
 *  - Originals are first copied into `users_backup_pre_string_ids` (kept for
 *    audit/rollback; drop it manually after verification).
 *  - References elsewhere were ALWAYS written as String(user._id)
 *    (sessions.userId, tasks.userId, ...), so no other collections need
 *    changes.
 *  - In production this refuses to apply unless ALLOW_USER_ID_MIGRATION=true
 *    is set. It defaults to a dry run there.
 *
 * Usage:
 *   npm run migrate:user-ids            # report only (any environment)
 *   npm run migrate:user-ids -- --apply # migrate (production needs the ALLOW flag)
 */

import "dotenv/config";

import { connectDatabase, disconnectDatabase } from "../src/config/database.js";
import { isProduction } from "../src/config/environment.js";

const APPLY = process.argv.includes("--apply");

const log = (message: string): void => {
  console.log(`[migrate:user-ids] ${message}`);
};

const error = (message: string): void => {
  console.error(`[migrate:user-ids] ERROR: ${message}`);
};

const main = async (): Promise<void> => {
  const production = isProduction();
  const allowed = process.env.ALLOW_USER_ID_MIGRATION === "true";
  const dryRun = !APPLY || (production && !allowed);

  if (APPLY && production && !allowed) {
    error(
      "NODE_ENV=production requires ALLOW_USER_ID_MIGRATION=true to apply.",
    );
    process.exit(1);
  }

  await connectDatabase();

  try {
    const db = (await import("mongoose")).default.connection.db;
    if (!db) {
      throw new Error("Database connection is not initialised");
    }

    const users = db.collection("users");
    const backup = db.collection("users_backup_pre_string_ids");

    const candidates = await users
      .find({ _id: { $type: "objectId" } })
      .toArray();
    log(`found ${candidates.length} user document(s) with ObjectId _id.`);

    if (dryRun) {
      log(
        "dry run: no documents were modified. Re-run with --apply to migrate.",
      );
      return;
    }

    let migrated = 0;
    for (const doc of candidates) {
      const objectId = doc._id as {
        toHexString?: () => string;
        toString: () => string;
      };
      const stringId =
        typeof objectId.toHexString === "function"
          ? objectId.toHexString()
          : String(doc._id);

      await backup.updateOne(
        { _id: doc._id },
        { $setOnInsert: doc },
        { upsert: true },
      );

      // Insert-then-delete is impossible under the unique active-email
      // index: the copy carries the same email as the original. Swap order:
      // remove the original only after its backup is durable, then insert.
      await users.deleteOne({ _id: doc._id });
      try {
        await users.insertOne({ ...doc, _id: stringId });
      } catch (insertError) {
        // Restore the original so the migration is fail-safe.
        await users.insertOne(doc);
        throw insertError;
      }
      migrated += 1;
      log(
        `migrated ${stringId} (${(doc as { email?: string }).email ?? "no email"})`,
      );
    }

    log(`done: ${migrated} of ${candidates.length} document(s) migrated.`);
    log(
      "backups kept in users_backup_pre_string_ids — drop after verification.",
    );
  } catch (err) {
    error(err instanceof Error ? err.message : String(err));
    process.exitCode = 1;
  } finally {
    await disconnectDatabase();
  }
};

void main();
