/**
 * File Name: seed.ts
 * Description: Seeds the Auxilia MongoDB database with realistic dummy data.
 * Author: Keefe Chen
 *
 * Usage:
 *   npm run seed          # Seed data (skips existing records)
 *   npm run seed:reset    # Clear all data then seed fresh
 *
 * The script uses an upsert pattern keyed on email (users), groupId (groups),
 * and _id (all other entities) so it is safe to run repeatedly without
 * creating duplicate records.
 */

import { connectDatabase, disconnectDatabase } from "../src/config/database.js";
import { getBcryptRounds } from "../src/config/environment.js";

import {
  seedUsers,
  seedGroups,
  seedMemberships,
  seedTasks,
  seedRoadmaps,
  seedRubrics,
  seedFeedback,
  seedCalendarEvents,
  seedStudySessions,
} from "./seed-data.js";

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

/**
 * Upsert users. Keyed on email to avoid duplicates.
 */
const seedUsersData = async (): Promise<void> => {
  log("Seeding users...");

  for (const userData of seedUsers) {
    const existing = await User.findOne({ email: userData.email }).exec();
    if (existing) {
      log(`User already exists: ${userData.email} (skipping)`);
      continue;
    }

    const passwordHash = await hashPassword(userData.password);

    await User.create({
      _id: userData._id,
      name: userData.name,
      email: userData.email,
      passwordHash,
      role: userData.role,
      status: userData.status,
      emailVerifiedAt: userData.emailVerifiedAt,
    });
    success(`Created user: ${userData.name} (${userData.email})`);
  }
};

/**
 * Upsert groups. Keyed on groupId.
 */
const seedGroupsData = async (): Promise<void> => {
  log("Seeding groups...");
  for (const groupData of seedGroups) {
    const existing = await Group.findOne({ groupId: groupData.groupId }).exec();
    if (existing) {
      log(`Group already exists: ${groupData.name} (skipping)`);
      continue;
    }

    await Group.create(groupData);
    success(`Created group: ${groupData.name}`);
  }
};

/**
 * Upsert memberships. Keyed on groupId + userId unique index.
 */
const seedMembershipsData = async (): Promise<void> => {
  log("Seeding memberships...");
  for (const membership of seedMemberships) {
    const existing = await Member.findOne({
      groupId: membership.groupId,
      userId: membership.userId,
    }).exec();
    if (existing) {
      log(
        `Membership already exists: ${membership.userId} in ${membership.groupId} (skipping)`,
      );
      continue;
    }

    await Member.create(membership);
    success(
      `Created membership: ${membership.userId} in ${membership.groupId}`,
    );
  }
};

/**
 * Upsert tasks. Keyed on _id.
 */
const seedTasksData = async (): Promise<void> => {
  log("Seeding tasks...");
  for (const taskData of seedTasks) {
    const existing = await Task.findById(taskData._id).exec();
    if (existing) {
      log(`Task already exists: ${taskData.title} (skipping)`);
      continue;
    }

    // Remove completedAt for incomplete tasks; schema hook manages it on save
    const payload = { ...taskData };
    if (payload.status !== "completed") {
      payload.completedAt = null;
    }

    await Task.create(payload);
    success(`Created task: ${taskData.title}`);
  }
};

/**
 * Upsert roadmaps. Keyed on _id.
 */
const seedRoadmapsData = async (): Promise<void> => {
  log("Seeding roadmaps...");
  for (const roadmapData of seedRoadmaps) {
    const existing = await Roadmap.findById(roadmapData._id).exec();
    if (existing) {
      log(`Roadmap already exists: ${roadmapData.title} (skipping)`);
      continue;
    }

    await Roadmap.create(roadmapData);
    success(`Created roadmap: ${roadmapData.title}`);
  }
};

/**
 * Upsert rubrics. Keyed on _id.
 */
const seedRubricsData = async (): Promise<void> => {
  log("Seeding rubrics...");
  for (const rubricData of seedRubrics) {
    const existing = await Rubric.findById(rubricData._id).exec();
    if (existing) {
      log(`Rubric already exists: ${rubricData.title} (skipping)`);
      continue;
    }

    await Rubric.create(rubricData);
    success(`Created rubric: ${rubricData.title}`);
  }
};

/**
 * Upsert feedback. Keyed on userId + title (no unique constraint, so we
 * check before inserting to avoid duplicates).
 */
const seedFeedbackData = async (): Promise<void> => {
  log("Seeding feedback...");
  for (const feedbackData of seedFeedback) {
    const existing = await FeedbackModel.findOne({
      userId: feedbackData.userId,
      title: feedbackData.title,
    }).exec();
    if (existing) {
      log(`Feedback already exists: ${feedbackData.title} (skipping)`);
      continue;
    }

    await FeedbackModel.create(feedbackData);
    success(`Created feedback: ${feedbackData.title}`);
  }
};

/**
 * Upsert calendar events. Keyed on userId + title + startTime.
 */
const seedCalendarEventsData = async (): Promise<void> => {
  log("Seeding calendar events...");
  for (const eventData of seedCalendarEvents) {
    const existing = await CalendarEventModel.findOne({
      userId: eventData.userId,
      title: eventData.title,
      startTime: eventData.startTime,
    }).exec();
    if (existing) {
      log(`Calendar event already exists: ${eventData.title} (skipping)`);
      continue;
    }

    await CalendarEventModel.create(eventData);
    success(`Created calendar event: ${eventData.title}`);
  }
};

/**
 * Upsert study sessions. Keyed on _id.
 */
const seedStudySessionsData = async (): Promise<void> => {
  log("Seeding study sessions...");
  for (const sessionData of seedStudySessions) {
    const existing = await StudySession.findById(sessionData._id).exec();
    if (existing) {
      log(`Study session already exists: ${sessionData.title} (skipping)`);
      continue;
    }

    await StudySession.create(sessionData);
    success(`Created study session: ${sessionData.title}`);
  }
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

    await seedUsersData();
    await seedGroupsData();
    await seedMembershipsData();
    await seedTasksData();
    await seedRoadmapsData();
    await seedRubricsData();
    await seedFeedbackData();
    await seedCalendarEventsData();
    await seedStudySessionsData();

    await printSummary();
    success("Seeding complete.");
  } catch (err) {
    error(`Seeding failed: ${err instanceof Error ? err.message : String(err)}`);
    process.exit(1);
  } finally {
    await disconnectDatabase();
  }
};

void main();
