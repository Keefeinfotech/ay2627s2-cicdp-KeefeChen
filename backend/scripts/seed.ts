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
const seedUsersData = async (): Promise<Map<string, string>> => {
  log("Seeding users...");
  const userIdMap = new Map<string, string>();

  for (const userData of seedData.users as SeedUser[]) {
    const existing = await User.findOne({ email: userData.email }).exec();
    if (existing) {
      log(`User already exists: ${userData.email} (skipping)`);
      userIdMap.set(userData.email, existing._id.toString());
      continue;
    }

    const passwordHash = await hashPassword(userData.password);

    const user = await User.create({
      _id: oneTimeId(),
      name: userData.name,
      email: userData.email,
      passwordHash,
      role: userData.role,
      status: userData.status,
      emailVerifiedAt: userData.emailVerifiedAt
        ? new Date(userData.emailVerifiedAt)
        : now(),
    });
    userIdMap.set(userData.email, user._id.toString());
    success(`Created user: ${userData.name} (${userData.email})`);
  }

  return userIdMap;
};

/**
 * Upsert groups. Keyed on groupId to avoid duplicates.
 */
const seedGroupsData = async (): Promise<Map<string, string>> => {
  log("Seeding groups...");
  const groupIdMap = new Map<string, string>();

  for (let i = 0; i < seedData.groups.length; i++) {
    const groupData = seedData.groups[i];
    const existing = await Group.findOne({ name: groupData.name }).exec();
    if (existing) {
      log(`Group already exists: ${groupData.name} (skipping)`);
      groupIdMap.set(groupData.name, existing.groupId);
      continue;
    }

    await Group.create({
      groupId: oneTimeId(),
      name: groupData.name,
      description: groupData.description,
      visibility: groupData.visibility,
      status: groupData.status,
      ownerId: userIdMap.get(seedData.users[groupData.ownerIndex].email)!,
    });
    success(`Created group: ${groupData.name}`);
    groupIdMap.set(groupData.name, groupIdMap.get(groupData.name)!);
  }

  return groupIdMap;
};

/**
 * Upsert tasks. Keyed on _id.
 */
const seedTasksData = async (
  userIdMap: Map<string, string>,
  groupIdMap: Map<string, string>,
): Promise<void> => {
  log("Seeding tasks...");
  const taskData = seedData.tasks as any[][];

  for (const task of taskData) {
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
    ] = task as unknown as [
      number,
      string,
      string,
      string[],
      number | null,
      number | null,
      string | null,
      string,
      string,
      number | null,
      number | null,
    ];

    const existing = await Task.findOne({ title }).exec();
    if (existing) {
      log(`Task already exists: ${title} (skipping)`);
      continue;
    }

    await Task.create({
      _id: oneTimeId(),
      userId: userIdMap.get(seedData.users[userIdx].email)!,
      title,
      description: null,
      course,
      tags,
      groupId:
        groupIdx !== null
          ? groupIdMap.get(seedData.groups[groupIdx].name)!
          : null,
      assigneeId:
        assigneeIdx !== null
          ? userIdMap.get(seedData.users[assigneeIdx].email)!
          : null,
      assigneeName,
      status,
      priority,
      dueDate: dueDays !== null ? daysFromNow(dueDays) : null,
      completedAt: completedDays !== null ? daysFromNow(completedDays) : null,
      reminderAt: null,
      deletedAt: null,
    });
    success(`Created task: ${title}`);
  }
};

/**
 * Upsert roadmaps. Keyed on _id.
 */
const seedRoadmapsData = async (
  userIdMap: Map<string, string>,
  groupIdMap: Map<string, string>,
): Promise<void> => {
  log("Seeding roadmaps...");
  for (const roadmapData of seedData.roadmaps) {
    const existing = await Roadmap.findOne({ title: roadmapData.title }).exec();
    if (existing) {
      log(`Roadmap already exists: ${roadmapData.title} (skipping)`);
      continue;
    }

    await Roadmap.create({
      _id: oneTimeId(),
      groupId: groupIdMap.get(seedData.groups[roadmapData.groupIndex].name)!,
      title: roadmapData.title,
      description: roadmapData.description,
      source: roadmapData.source,
      status: roadmapData.status,
      createdBy: userIdMap.get(
        seedData.users[roadmapData.createdByIndex].email,
      )!,
      approvedAt:
        roadmapData.approvedDaysAgo !== null
          ? daysFromNow(roadmapData.approvedDaysAgo)
          : null,
      items: roadmapData.items.map((item) => ({
        itemId: oneTimeId(),
        title: item.title,
        description: item.description,
        criterion: item.criterion,
        weight: item.weight,
        estimateHours: item.estimateHours,
        status: item.status,
        order: item.order,
      })),
    });
    success(`Created roadmap: ${roadmapData.title}`);
  }
};

const seedRubricsData = async (
  userIdMap: Map<string, string>,
): Promise<void> => {
  log("Seeding rubrics...");
  for (const rubricData of seedData.rubrics) {
    const existing = await Rubric.findOne({ title: rubricData.title }).exec();
    if (existing) {
      log(`Rubric already exists: ${rubricData.title} (skipping)`);
      continue;
    }

    await Rubric.create({
      _id: oneTimeId(),
      groupId: groupIdMap.get(seedData.groups[rubricData.groupIndex].name)!,
      title: rubricData.title,
      sourceText: rubricData.sourceText,
      checksum: rubricData.checksum,
      version: rubricData.version,
      criteria: rubricData.criteria,
      createdBy: userIdMap.get(
        seedData.users[rubricData.createdByIndex].email,
      )!,
    });
    success(`Created rubric: ${rubricData.title}`);
  }
};

const seedFeedbackData = async (
  userIdMap: Map<string, string>,
): Promise<void> => {
  log("Seeding feedback...");
  for (const feedbackData of seedData.feedback) {
    const existing = await FeedbackModel.findOne({
      userId: userIdMap.get(seedData.users[feedbackData.userIndex].email)!,
      title: feedbackData.title,
    }).exec();
    if (existing) {
      log(`Feedback already exists: ${feedbackData.title} (skipping)`);
      continue;
    }

    await FeedbackModel.create({
      userId: userIdMap.get(seedData.users[feedbackData.userIndex].email)!,
      category: feedbackData.category,
      title: feedbackData.title,
      description: feedbackData.description,
      rating: feedbackData.rating,
      status: feedbackData.status,
    });
    success(`Created feedback: ${feedbackData.title}`);
  }
};

const seedCalendarEventsData = async (
  userIdMap: Map<string, string>,
  groupIdMap: Map<string, string>,
): Promise<void> => {
  log("Seeding calendar events...");
  for (const eventData of seedData.calendarEvents) {
    const existing = await CalendarEventModel.findOne({
      userId: userIdMap.get(seedData.users[eventData.userIndex].email)!,
      title: eventData.title,
      startTime: daysFromNow(eventData.startDays),
    }).exec();
    if (existing) {
      log(`Calendar event already exists: ${eventData.title} (skipping)`);
      continue;
    }

    await CalendarEventModel.create({
      userId: userIdMap.get(seedData.users[eventData.userIndex].email)!,
      title: eventData.title,
      description: eventData.description,
      startTime: daysFromNow(eventData.startDays),
      endTime: daysFromNow(eventData.endDays),
      isAllDay: eventData.isAllDay,
      priority: eventData.priority,
      status: eventData.status,
      location: eventData.location,
      groupId:
        eventData.groupIndex !== null
          ? groupIdMap.get(seedData.groups[eventData.groupIndex].name)!
          : null,
      taskId: null,
    });
    success(`Created calendar event: ${eventData.title}`);
  }
};

const seedStudySessionsData = async (
  userIdMap: Map<string, string>,
  groupIdMap: Map<string, string>,
): Promise<void> => {
  log("Seeding study sessions...");
  for (const sessionData of seedData.studySessions) {
    const existing = await StudySession.findOne({
      title: sessionData.title,
    }).exec();
    if (existing) {
      log(`Study session already exists: ${sessionData.title} (skipping)`);
      continue;
    }

    await StudySession.create({
      _id: oneTimeId(),
      groupId: groupIdMap.get(seedData.groups[sessionData.groupIndex].name)!,
      title: sessionData.title,
      description: sessionData.description,
      startsAt: daysFromNow(sessionData.startDays),
      endsAt: daysFromNow(sessionData.endDays),
      location: sessionData.location,
      maxAttendees: sessionData.maxAttendees,
      attendeeIds: sessionData.attendeeIndices.map((i) =>
        userIdMap.get(seedData.users[i].email)!,
      ),
      createdBy: userIdMap.get(
        seedData.users[sessionData.createdByIndex].email,
      )!,
      status: sessionData.status,
    });
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

    const userIdMap = await seedUsersData();
    const groupIdMap = await seedGroupsData();
    await seedMembershipsData(userIdMap, groupIdMap);
    await seedTasksData(userIdMap, groupIdMap);
    await seedRoadmapsData(userIdMap, groupIdMap);
    await seedRubricsData(userIdMap);
    await seedFeedbackData(userIdMap);
    await seedCalendarEventsData(userIdMap, groupIdMap);
    await seedStudySessionsData(userIdMap, groupIdMap);

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
