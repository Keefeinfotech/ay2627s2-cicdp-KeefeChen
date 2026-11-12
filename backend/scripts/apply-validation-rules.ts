/**
 * File Name: apply-validation-rules.ts
 * Description: Applies MongoDB $jsonSchema validators to every application
 *              collection. Mirrors the Mongoose schemas so the database
 *              enforces type, range, enum and required-field rules on writes.
 *
 * Usage:
 *   npm run validate:collections          # apply validators (requires MONGODB_URI)
 *   npm run validate:collections -- --dry-run   # print planned rules, no DB access
 *
 * Notes:
 *  - Uses validationLevel "moderate" so historical documents that pre-date the
 *    rules are not re-validated on read; validationAction "error" rejects
 *    invalid writes.
 *  - Validators use additionalProperties: true so documents written by a newer
 *    schema version remain valid until the next migration.
 */

import mongoose from "mongoose";

import { connectDatabase, disconnectDatabase } from "../src/config/database.js";

const DRY_RUN =
  process.argv.includes("--dry-run") || process.argv.includes("-d");

const log = (message: string): void => {
  console.log(`[validate] ${message}`);
};

const error = (message: string): void => {
  console.error(`[validate] ERROR: ${message}`);
};

const stringMax = (max: number) => ({ bsonType: "string", maxLength: max });
const stringWithNull = (max: number) => ({
  bsonType: ["string", "null"],
  maxLength: max,
});
const dateOrNull = { bsonType: ["date", "null"] };
const numberOrNull = { bsonType: ["int", "long", "double", "null"] };
const intNonNegative = { bsonType: ["int", "long", "double"], minimum: 0 };
const stringArray = {
  bsonType: "array",
  items: { bsonType: "string" },
};

/**
 * Collection validators keyed by the collection's Mongoose-pluralized name.
 */
const validators: Record<string, Record<string, unknown>> = {
  // ------------------------------------------------------------- users
  users: {
    bsonType: "object",
    required: ["_id", "email", "passwordHash", "role"],
    additionalProperties: true,
    properties: {
      _id: { bsonType: "string" },
      name: {
        bsonType: "string",
        minLength: 2,
        maxLength: 80,
      },
      email: { bsonType: "string", maxLength: 254 },
      passwordHash: { bsonType: "string", maxLength: 255 },
      // users/user.model.js registers "user" (this wins in seed flows) while
      // auth/auth.model.ts registers it too with a narrower shape; accept the
      // union so either registration works.
      role: { enum: ["user", "admin"] },
      status: { enum: ["active", "disabled", "pending"] },
      emailVerifiedAt: dateOrNull,
      emailVerificationTokenHash: stringWithNull(255),
      emailVerificationExpiresAt: dateOrNull,
      passwordResetTokenHash: stringWithNull(255),
      passwordResetExpiresAt: dateOrNull,
      activeSessionId: { bsonType: ["string", "null"] },
      activeSessionExpiresAt: dateOrNull,
      mfaEnabled: { bsonType: "bool" },
      mfaSecretEncrypted: stringWithNull(400),
      mfaPendingSecretEncrypted: stringWithNull(400),
      mfaPendingExpiresAt: dateOrNull,
      mfaRecoveryCodeHashes: stringArray,
      mfaLastUsedStep: { bsonType: ["int", "long", "double", "null"] },
      mfaEnabledAt: dateOrNull,
      lastLoginAt: dateOrNull,
      deletedAt: dateOrNull,
      createdAt: { bsonType: "date" },
      updatedAt: { bsonType: "date" },
    },
  },

  // ------------------------------------------------------------- tasks
  tasks: {
    bsonType: "object",
    required: ["_id", "userId", "title"],
    additionalProperties: true,
    properties: {
      _id: { bsonType: "string" },
      userId: { bsonType: "string" },
      title: {
        bsonType: "string",
        minLength: 1,
        maxLength: 150,
      },
      description: { bsonType: ["string", "null"], maxLength: 5000 },
      course: { ...stringMax(120) },
      tags: { bsonType: "array", items: { bsonType: "string" }, maxItems: 8 },
      groupId: { bsonType: ["string", "null"] },
      assigneeId: { bsonType: ["string", "null"] },
      assigneeName: { bsonType: ["string", "null"], maxLength: 120 },
      status: { enum: ["todo", "in_progress", "completed", "archived"] },
      priority: { enum: ["low", "medium", "high", "urgent"] },
      dueDate: dateOrNull,
      reminderAt: dateOrNull,
      completedAt: dateOrNull,
      deletedAt: dateOrNull,
      createdAt: { bsonType: "date" },
      updatedAt: { bsonType: "date" },
    },
  },

  // ------------------------------------------------------------- groups
  groups: {
    bsonType: "object",
    required: ["groupId", "name", "ownerId"],
    additionalProperties: true,
    properties: {
      groupId: { bsonType: "string" },
      name: {
        bsonType: "string",
        minLength: 2,
        maxLength: 80,
      },
      description: { bsonType: ["string", "null"], maxLength: 500 },
      visibility: { enum: ["PUBLIC", "PRIVATE"] },
      status: { enum: ["ACTIVE", "ARCHIVED"] },
      ownerId: { bsonType: "string" },
      createdAt: { bsonType: "date" },
      updatedAt: { bsonType: "date" },
    },
  },

  // ---------------------------------------------------------- groupmembers
  groupmembers: {
    bsonType: "object",
    required: ["groupId", "userId"],
    additionalProperties: true,
    properties: {
      groupId: { bsonType: "string" },
      userId: { bsonType: "string" },
      createdAt: { bsonType: "date" },
      updatedAt: { bsonType: "date" },
    },
  },

  // ------------------------------------------------------------- members
  members: {
    bsonType: "object",
    required: ["groupId", "userId", "role", "status"],
    additionalProperties: true,
    properties: {
      groupId: { bsonType: "string" },
      userId: { bsonType: "string" },
      role: { enum: ["OWNER", "ADMIN", "MEMBER"] },
      status: { enum: ["ACTIVE", "PENDING", "REJECTED", "LEFT", "REMOVED"] },
      createdAt: { bsonType: "date" },
      updatedAt: { bsonType: "date" },
    },
  },

  // --------------------------------------------------------- invitations
  invitations: {
    bsonType: "object",
    required: [
      "invitationId",
      "groupId",
      "email",
      "role",
      "status",
      "invitedBy",
      "tokenHash",
      "expiresAt",
    ],
    additionalProperties: true,
    properties: {
      invitationId: { bsonType: "string" },
      groupId: { bsonType: "string" },
      email: { bsonType: "string", maxLength: 254 },
      role: { enum: ["ADMIN", "MEMBER"] },
      status: {
        enum: ["PENDING", "ACCEPTED", "DECLINED", "REVOKED", "EXPIRED"],
      },
      invitedBy: { bsonType: "string" },
      tokenHash: { bsonType: "string" },
      expiresAt: { bsonType: "date" },
      acceptedAt: dateOrNull,
      createdAt: { bsonType: "date" },
      updatedAt: { bsonType: "date" },
    },
  },

  // ------------------------------------------------------------- roadmaps
  roadmaps: {
    bsonType: "object",
    required: ["_id", "groupId", "title", "source", "status", "createdBy"],
    additionalProperties: true,
    properties: {
      _id: { bsonType: "string" },
      groupId: { bsonType: "string" },
      title: {
        bsonType: "string",
        minLength: 1,
        maxLength: 200,
      },
      description: { bsonType: ["string", "null"], maxLength: 2000 },
      source: { enum: ["manual", "rubric"] },
      status: { enum: ["draft", "approved", "archived"] },
      createdBy: { bsonType: "string" },
      approvedAt: dateOrNull,
      items: {
        bsonType: "array",
        items: {
          bsonType: "object",
          required: ["title"],
          additionalProperties: true,
          properties: {
            itemId: { bsonType: "string" },
            title: { bsonType: "string", minLength: 1, maxLength: 150 },
            description: { bsonType: ["string", "null"], maxLength: 2000 },
            criterion: { bsonType: ["string", "null"], maxLength: 200 },
            weight: {
              bsonType: ["int", "long", "double", "null"],
              minimum: 0,
              maximum: 100,
            },
            estimateHours: {
              bsonType: ["int", "long", "double", "null"],
              minimum: 0,
              maximum: 1000,
            },
            status: { enum: ["pending", "in_progress", "done", "skipped"] },
            order: { bsonType: ["int", "long", "double"], minimum: 0 },
          },
        },
      },
      createdAt: { bsonType: "date" },
      updatedAt: { bsonType: "date" },
    },
  },

  // ------------------------------------------------------------- rubrics
  rubrics: {
    bsonType: "object",
    required: [
      "_id",
      "groupId",
      "title",
      "sourceText",
      "checksum",
      "version",
      "criteria",
      "createdBy",
    ],
    additionalProperties: true,
    properties: {
      _id: { bsonType: "string" },
      groupId: { bsonType: "string" },
      title: {
        bsonType: "string",
        minLength: 1,
        maxLength: 200,
      },
      sourceText: { bsonType: "string", maxLength: 30000 },
      checksum: { bsonType: "string" },
      version: { bsonType: ["int", "long", "double"], minimum: 1 },
      criteria: {
        bsonType: "array",
        items: {
          bsonType: "object",
          required: ["name", "weight"],
          additionalProperties: true,
          properties: {
            name: { bsonType: "string", minLength: 1, maxLength: 200 },
            description: { bsonType: ["string", "null"], maxLength: 1000 },
            weight: {
              bsonType: ["int", "long", "double"],
              minimum: 0,
              maximum: 100,
            },
          },
        },
      },
      createdBy: { bsonType: "string" },
      createdAt: { bsonType: "date" },
      updatedAt: { bsonType: "date" },
    },
  },

  // ------------------------------------------------------------ reminders
  reminders: {
    bsonType: "object",
    required: ["userId", "message", "dueAt"],
    additionalProperties: true,
    properties: {
      userId: { bsonType: "objectId" },
      message: { bsonType: "string", minLength: 1 },
      dueAt: { bsonType: "date" },
      completed: { bsonType: "bool" },
      completedAt: dateOrNull,
      createdAt: { bsonType: "date" },
      updatedAt: { bsonType: "date" },
    },
  },

  // -------------------------------------------------------- calendarevents
  calendarevents: {
    bsonType: "object",
    required: ["userId", "title", "startTime", "endTime"],
    additionalProperties: true,
    properties: {
      userId: { bsonType: "objectId" },
      title: { bsonType: "string", minLength: 1 },
      description: { bsonType: "string" },
      startTime: { bsonType: "date" },
      endTime: { bsonType: "date" },
      isAllDay: { bsonType: "bool" },
      priority: { enum: ["LOW", "MEDIUM", "HIGH", "URGENT"] },
      status: { enum: ["SCHEDULED", "COMPLETED", "CANCELLED"] },
      location: { bsonType: "string" },
      groupId: { bsonType: ["objectId", "null"] },
      taskId: { bsonType: ["objectId", "null"] },
      recurrence: {
        bsonType: "object",
        additionalProperties: true,
        properties: {
          frequency: { enum: ["DAILY", "WEEKLY", "MONTHLY", "YEARLY"] },
          interval: { bsonType: ["int", "long", "double"], minimum: 1 },
          until: { bsonType: "date" },
        },
      },
      createdAt: { bsonType: "date" },
      updatedAt: { bsonType: "date" },
    },
  },

  // ------------------------------------------------------------ feedbacks
  feedbacks: {
    bsonType: "object",
    required: ["userId", "category", "title", "description"],
    additionalProperties: true,
    properties: {
      userId: { bsonType: "objectId" },
      category: { enum: ["BUG", "FEATURE_REQUEST", "GENERAL", "UI_UX"] },
      title: { bsonType: "string", minLength: 1, maxLength: 150 },
      description: { bsonType: "string", minLength: 1 },
      rating: { bsonType: ["int", "long", "double"], minimum: 1, maximum: 5 },
      status: { enum: ["PENDING", "IN_REVIEW", "RESOLVED", "DISMISSED"] },
      adminResponse: {
        bsonType: ["object", "null"],
        additionalProperties: true,
        properties: {
          respondedBy: { bsonType: "objectId" },
          message: { bsonType: "string" },
          respondedAt: { bsonType: "date" },
        },
      },
      createdAt: { bsonType: "date" },
      updatedAt: { bsonType: "date" },
    },
  },

  // ------------------------------------------------------------- batchjobs
  batchjobs: {
    bsonType: "object",
    required: [
      "jobId",
      "groupId",
      "operationType",
      "status",
      "requestedBy",
      "totalCount",
      "successCount",
      "failureCount",
    ],
    additionalProperties: true,
    properties: {
      jobId: { bsonType: "string" },
      groupId: { bsonType: "string" },
      operationType: { enum: ["ADD_MEMBERS"] },
      status: { enum: ["COMPLETED", "PARTIALLY_FAILED", "FAILED"] },
      requestedBy: { bsonType: "string" },
      totalCount: intNonNegative,
      successCount: intNonNegative,
      failureCount: intNonNegative,
      errors: {
        bsonType: "array",
        items: {
          bsonType: "object",
          required: ["index", "code", "message"],
          additionalProperties: true,
          properties: {
            index: { bsonType: ["int", "long", "double"], minimum: 0 },
            memberId: { bsonType: "string" },
            code: { bsonType: "string" },
            message: { bsonType: "string" },
          },
        },
      },
      createdAt: { bsonType: "date" },
      updatedAt: { bsonType: "date" },
    },
  },

  // ---------------------------------------------------------- auditevents
  auditevents: {
    bsonType: "object",
    required: ["eventId", "groupId", "actorId", "action"],
    additionalProperties: true,
    properties: {
      eventId: { bsonType: "string" },
      groupId: { bsonType: "string" },
      actorId: { bsonType: "string" },
      action: { bsonType: "string", minLength: 1, maxLength: 80 },
      targetType: { bsonType: ["string", "null"], maxLength: 80 },
      targetId: { bsonType: ["string", "null"], maxLength: 120 },
      metadata: {
        bsonType: ["object", "null"],
      },
      createdAt: { bsonType: "date" },
      updatedAt: { bsonType: "date" },
    },
  },

  // --------------------------------------------------------- studysessions
  studysessions: {
    bsonType: "object",
    required: ["_id", "groupId", "title", "startsAt", "endsAt", "createdBy"],
    additionalProperties: true,
    properties: {
      _id: { bsonType: "string" },
      groupId: { bsonType: "string" },
      title: {
        bsonType: "string",
        minLength: 1,
        maxLength: 150,
      },
      description: { bsonType: ["string", "null"], maxLength: 2000 },
      startsAt: { bsonType: "date" },
      endsAt: { bsonType: "date" },
      location: { bsonType: ["string", "null"], maxLength: 200 },
      maxAttendees: {
        bsonType: ["int", "long", "double", "null"],
        minimum: 1,
        maximum: 200,
      },
      attendeeIds: stringArray,
      createdBy: { bsonType: "string" },
      status: { enum: ["scheduled", "completed", "cancelled"] },
      createdAt: { bsonType: "date" },
      updatedAt: { bsonType: "date" },
    },
  },
};

const applyValidator = async (
  collection: string,
  validator: Record<string, unknown>,
): Promise<{ applied: boolean; reason?: string }> => {
  const db = mongoose.connection.db;
  if (!db) {
    throw new Error("Database connection not initialized");
  }

  const existing = await db
    .listCollections({ name: collection }, { nameOnly: true })
    .toArray();

  if (existing.length === 0) {
    log(
      `skip ${collection}: collection does not exist yet (create it by writing once, then re-run)`,
    );
    return { applied: false, reason: "missing collection" };
  }

  await db.command({
    collMod: collection,
    validator: { $jsonSchema: validator },
    validationLevel: "moderate",
    validationAction: "error",
  });

  log(`✓ ${collection}: validation rules applied (moderate/error)`);
  return { applied: true };
};

const main = async (): Promise<void> => {
  const collections = Object.entries(validators);

  if (DRY_RUN) {
    log(
      `Dry run: ${collections.length} collections would receive validators.\n`,
    );
    for (const [collection, validator] of collections) {
      const roundTripped = JSON.parse(JSON.stringify(validator)) as unknown;
      if (JSON.stringify(roundTripped) !== JSON.stringify(validator)) {
        throw new Error(`${collection} validator is not JSON-serializable`);
      }
      log(
        `  ${collection} (required: ${
          (validator.required as string[] | undefined)?.join(", ") ?? "none"
        })`,
      );
    }
    log(
      "\nAll validators are JSON-serializable. Run without --dry-run to apply.",
    );
    return;
  }

  try {
    log("Connecting to database...");
    await connectDatabase();

    const results = { applied: 0, skipped: 0 };
    for (const [collection, validator] of collections) {
      const result = await applyValidator(collection, validator);
      if (result.applied) {
        results.applied += 1;
      } else {
        results.skipped += 1;
      }
    }

    log(
      `\nDone. ${results.applied} applied, ${results.skipped} skipped.` +
        ` Re-run after any collection is first created.`,
    );
  } catch (err) {
    error(err instanceof Error ? err.message : String(err));
    process.exit(1);
  } finally {
    await disconnectDatabase();
  }
};

void main();
