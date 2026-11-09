/**
 * File Name: seed.ts
 * Description: Seeds the Auxilia MongoDB database with realistic dummy data.
 * Author: Keefe Chen
 *
 * Usage:
 *   npm run seed          # Seed data (skips existing records)
 *   npm run seed:reset    # Clear all data then seed fresh
 *   npm run seed:dry-run  # Show current record counts without writing
 *
 * Data is loaded from seed-data.json.
 */

import { connectDatabase, disconnectDatabase } from "../src/config/database.js";
import { getBcryptRounds } from "../src/config/environment.js";
import { randomUUID } from "node:crypto";

import seedData from "./seed-data.json";

import { User } from "../src/modules/users/user.model.js";
import { Group } from "../src/modules/groups/core/group.model.js";
import { Member } from "../src/modules/groups/member/member.model.js";
import { Task } from "../src/modules/tasks/task.model.js";
import { Roadmap } from "../src/modules/roadmaps/roadmap.model.js";
import { Rubric } from "../src/modules/rubrics/rubric.model.js";
import { FeedbackModel } from "../src/modules/feedback/feedback.model.js";
import { CalendarEventModel } from "../src/modules/calendar/calendar.model.js";
import { StudySession } from "../src/modules/sessions/session.model.js";

import bcrypt from "bcryptjs";

const RESET = process.argv.includes("--reset") || process.argv.includes("-r");
const DRY_RUN = process.argv.includes("--dry-run");

const log = (message: string): void => {
  console.log(`[seed] ${message}`);
};

const error = (message: string): void => {
  console.error(`[seed] ERROR: ${message}`);
};

const success = (message: string): void => {
  console.log(`[seed] ✓ ${message}`);
};

const hashPassword = async (password: string): Promise<string> => {
  return bcrypt.hash(password, getBcryptRounds());
};

const now = () => new Date();

const oneTimeId = (): string => randomUUID();

/**
 * Add a number of days to the current date.
 */
const daysFromNow = (days: number): Date => {
  const d = new Date();
  d.setDate(d.getDate() + days);
  return d;
};

/**
 * Shared id maps populated by earlier seed steps and consumed by later ones.
 */
type SeedMaps = {
  users: Map<string, string>;
  groups: Map<string, string>;
};

/**
 * Callbacks that define entity-specific upsert behaviour. seedEntity owns the
 * shared find-or-create loop so each entity only declares what makes it unique.
 */
type SeedOptions = {
  /** Return an existing document, or null when none exists. */
  findExisting: (item: any, maps: SeedMaps) => Promise<any | null>;
  /** Store the document's id into the maps (for both existing & created). */
  storeId?: (item: any, doc: any, maps: SeedMaps) => void;
  /** Create and return a new document. */
  createOne: (item: any, maps: SeedMaps) => Promise<any>;
  /** Human-readable label used in log lines. */
  label: (item: any) => string;
};

/**
 * Generic entity seeder. Upserts each item once, skipping existing records.
 *
 * This single loop replaces the duplicated find/skip/create/success block that
 * previously lived in every per-entity seed function.
 */
const seedEntity = async (
  entityName: string,
  items: any[],
  options: SeedOptions,
  maps: SeedMaps,
): Promise<void> => {
  log(`Seeding ${entityName}...`);
  for (const item of items) {
    try {
      const existing = await options.findExisting(item, maps);
      if (existing) {
        options.storeId?.(item, existing, maps);
        log(`${entityName} already exists: ${options.label(item)} (skipping)`);
        continue;
      }
      const doc = await options.createOne(item, maps);
      options.storeId?.(item, doc, maps);
      success(`Created ${entityName}: ${options.label(item)}`);
    } catch (err) {
      error(
        `Failed to create ${entityName}: ${
          err instanceof Error ? err.message : String(err)
        }`,
      );
    }
  }
};

/**
 * Upsert users. Keyed on email to avoid duplicates.
 */
const seedUsers = async (maps: SeedMaps): Promise<Map<string, string>> => {
  const userIdMap = new Map<string, string>();
  maps.users = userIdMap;

  await seedEntity(
    "user",
    seedData.users,
    {
      findExisting: (item) => User.findOne({ email: item.email }).exec(),
      storeId: (item, doc) => userIdMap.set(item.email, doc._id.toString()),
      createOne: async (item) => {
        const passwordHash = await hashPassword(item.password);
        return User.create({
          _id: oneTimeId(),
          name: item.name,
          email: item.email,
          passwordHash,
          role: item.role,
          status: item.status,
          emailVerifiedAt: item.emailVerifiedAt
            ? new Date(item.emailVerifiedAt)
            : now(),
        });
      },
      label: (item) => item.email,
    },
    maps,
  );

  return userIdMap;
};

/**
 * Upsert groups. Keyed on name to avoid duplicates.
 */
const seedGroups = async (maps: SeedMaps): Promise<Map<string, string>> => {
  const groupIdMap = new Map<string, string>();
  maps.groups = groupIdMap;

  await seedEntity(
    "group",
    seedData.groups,
    {
      findExisting: (item) => Group.findOne({ name: item.name }).exec(),
      storeId: (item, doc) => groupIdMap.set(item.name, doc.groupId),
      createOne: (item) =>
        Group.create({
          groupId: oneTimeId(),
          name: item.name,
          description: item.description,
          visibility: item.visibility,
          status: item.status,
          ownerId: maps.users.get(seedData.users[item.ownerIndex].email)!,
        }),
      label: (item) => item.name,
    },
    maps,
  );

  return groupIdMap;
};

/**
 * Upsert memberships. Keyed on groupId + userId unique index.
 */
const seedMemberships = async (maps: SeedMaps): Promise<void> => {
  await seedEntity(
    "membership",
    seedData.memberships,
    {
      findExisting: (item) =>
        Member.findOne({
          groupId: maps.groups.get(seedData.groups[item.groupIndex].name)!,
          userId: maps.users.get(seedData.users[item.userIndex].email)!,
        }).exec(),
      createOne: (item) =>
        Member.create({
          groupId: maps.groups.get(seedData.groups[item.groupIndex].name)!,
          userId: maps.users.get(seedData.users[item.userIndex].email)!,
          role: item.role,
          status: item.status,
        }),
      label: (item) => `${item.userIndex} in ${item.groupIndex}`,
    },
    maps,
  );
};

/**
 * Upsert tasks. Keyed on title.
 */
const seedTasks = async (maps: SeedMaps): Promise<void> => {
  await seedEntity(
    "task",
    seedData.tasks,
    {
      findExisting: (item) => Task.findOne({ title: item[1] }).exec(),
      createOne: (item) => {
        const [
          userIdx,
          title,
          course,
          tags,
          groupIdx,
          assigneeIdx,
          assigneeName,
          status,
          priority,
          dueDays,
          completedDays,
        ] = item;

        return Task.create({
          _id: oneTimeId(),
          userId: maps.users.get(seedData.users[userIdx].email)!,
          title,
          description: null,
          course,
          tags,
          groupId:
            groupIdx !== null
              ? maps.groups.get(seedData.groups[groupIdx].name)!
              : null,
          assigneeId:
            assigneeIdx !== null
              ? maps.users.get(seedData.users[assigneeIdx].email)!
              : null,
          assigneeName,
          status,
          priority,
          dueDate: dueDays !== null ? daysFromNow(dueDays) : null,
          completedAt:
            completedDays !== null ? daysFromNow(completedDays) : null,
          reminderAt: null,
          deletedAt: null,
        });
      },
      label: (item) => item[1],
    },
    maps,
  );
};

/**
 * Upsert roadmaps. Keyed on title.
 */
const seedRoadmaps = async (maps: SeedMaps): Promise<void> => {
  await seedEntity(
    "roadmap",
    seedData.roadmaps,
    {
      findExisting: (item) => Roadmap.findOne({ title: item.title }).exec(),
      createOne: (item) =>
        Roadmap.create({
          _id: oneTimeId(),
          groupId: maps.groups.get(seedData.groups[item.groupIndex].name)!,
          title: item.title,
          description: item.description,
          source: item.source,
          status: item.status,
          createdBy: maps.users.get(seedData.users[item.createdByIndex].email)!,
          approvedAt:
            item.approvedDaysAgo !== null
              ? daysFromNow(item.approvedDaysAgo)
              : null,
          items: item.items.map((sub) => ({
            itemId: oneTimeId(),
            title: sub.title,
            description: sub.description,
            criterion: sub.criterion,
            weight: sub.weight,
            estimateHours: sub.estimateHours,
            status: sub.status,
            order: sub.order,
          })),
        }),
      label: (item) => item.title,
    },
    maps,
  );
};

/**
 * Upsert rubrics. Keyed on title.
 */
const seedRubrics = async (maps: SeedMaps): Promise<void> => {
  await seedEntity(
    "rubric",
    seedData.rubrics,
    {
      findExisting: (item) => Rubric.findOne({ title: item.title }).exec(),
      createOne: (item) =>
        Rubric.create({
          _id: oneTimeId(),
          groupId: maps.groups.get(seedData.groups[item.groupIndex].name)!,
          title: item.title,
          sourceText: item.sourceText,
          checksum: item.checksum,
          version: item.version,
          criteria: item.criteria,
          createdBy: maps.users.get(seedData.users[item.createdByIndex].email)!,
        }),
      label: (item) => item.title,
    },
    maps,
  );
};

/**
 * Upsert feedback. Keyed on userId + title.
 */
const seedFeedback = async (maps: SeedMaps): Promise<void> => {
  await seedEntity(
    "feedback",
    seedData.feedback,
    {
      findExisting: (item) =>
        FeedbackModel.findOne({
          userId: maps.users.get(seedData.users[item.userIndex].email)!,
          title: item.title,
        }).exec(),
      createOne: (item) =>
        FeedbackModel.create({
          userId: maps.users.get(seedData.users[item.userIndex].email)!,
          category: item.category,
          title: item.title,
          description: item.description,
          rating: item.rating,
          status: item.status,
        }),
      label: (item) => item.title,
    },
    maps,
  );
};

/**
 * Upsert calendar events. Keyed on userId + title + startTime.
 */
const seedCalendarEvents = async (maps: SeedMaps): Promise<void> => {
  await seedEntity(
    "calendarEvent",
    seedData.calendarEvents,
    {
      findExisting: (item) =>
        CalendarEventModel.findOne({
          userId: maps.users.get(seedData.users[item.userIndex].email)!,
          title: item.title,
          startTime: daysFromNow(item.startDays),
        }).exec(),
      createOne: (item) =>
        CalendarEventModel.create({
          userId: maps.users.get(seedData.users[item.userIndex].email)!,
          title: item.title,
          description: item.description,
          startTime: daysFromNow(item.startDays),
          endTime: daysFromNow(item.endDays),
          isAllDay: item.isAllDay,
          priority: item.priority,
          status: item.status,
          location: item.location,
          groupId:
            item.groupIndex !== null
              ? maps.groups.get(seedData.groups[item.groupIndex].name)!
              : null,
          taskId: null,
        }),
      label: (item) => item.title,
    },
    maps,
  );
};

/**
 * Upsert study sessions. Keyed on title.
 */
const seedStudySessions = async (maps: SeedMaps): Promise<void> => {
  await seedEntity(
    "studySession",
    seedData.studySessions,
    {
      findExisting: (item) =>
        StudySession.findOne({ title: item.title }).exec(),
      createOne: (item) =>
        StudySession.create({
          _id: oneTimeId(),
          groupId: maps.groups.get(seedData.groups[item.groupIndex].name)!,
          title: item.title,
          description: item.description,
          startsAt: daysFromNow(item.startDays),
          endsAt: daysFromNow(item.endDays),
          location: item.location,
          maxAttendees: item.maxAttendees,
          attendeeIds: item.attendeeIndices.map((i) =>
            maps.users.get(seedData.users[i].email)!,
          ),
          createdBy: maps.users.get(seedData.users[item.createdByIndex].email)!,
          status: item.status,
        }),
      label: (item) => item.title,
    },
    maps,
  );
};

/**
 * Print a summary of seeded data counts.
 */
const printSummary = async (): Promise<void> => {
  const counts = {
    users: await User.countDocuments({}),
    groups: await Group.countDocuments({}),
    memberships: await Member.countDocuments({}),
    tasks: await Task.countDocuments({}),
    roadmaps: await Roadmap.countDocuments({}),
    rubrics: await Rubric.countDocuments({}),
    feedback: await FeedbackModel.countDocuments({}),
    calendarEvents: await CalendarEventModel.countDocuments({}),
    studySessions: await StudySession.countDocuments({}),
  };

  log("\n=== Seed Summary ===");
  for (const [collection, count] of Object.entries(counts)) {
    log(`  ${collection}: ${count}`);
  }
  log("===================\n");
};

const main = async (): Promise<void> => {
  try {
    log("Connecting to database...");
    await connectDatabase();

    if (DRY_RUN) {
      log("Dry run mode: no data will be written.");
      await printSummary();
      return;
    }

    if (RESET) {
      await resetDatabase();
    }

    const maps: SeedMaps = { users: new Map(), groups: new Map() };
    await seedUsers(maps);
    await seedGroups(maps);
    await seedMemberships(maps);
    await seedTasks(maps);
    await seedRoadmaps(maps);
    await seedRubrics(maps);
    await seedFeedback(maps);
    await seedCalendarEvents(maps);
    await seedStudySessions(maps);

    await printSummary();
    success("Seeding complete.");
  } catch (err) {
    error(
      `Seeding failed: ${err instanceof Error ? err.message : String(err)}`,
    );
    process.exit(1);
  } finally {
    await disconnectDatabase();
  }
};

void main();

/**
 * Reset all collections. Order matters: delete referencing documents first.
 */
const resetDatabase = async (): Promise<void> => {
  log("Resetting all collections...");
  await Promise.all([
    Task.deleteMany({}),
    Group.deleteMany({}),
    Member.deleteMany({}),
    Roadmap.deleteMany({}),
    Rubric.deleteMany({}),
    FeedbackModel.deleteMany({}),
    CalendarEventModel.deleteMany({}),
    StudySession.deleteMany({}),
    User.deleteMany({}),
  ]);
  success("All collections cleared.");
};
