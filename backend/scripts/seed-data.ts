/**
 * File Name: seed-data.ts
 * Description: Defines realistic dummy data for seeding the Auxilia database.
 * Author: Keefe Chen
 *
 * This module contains pure data definitions (no database logic) so the
 * same fixtures can be reused by the seed script and any future test
 * helpers. All timestamps are deterministic so seeding is repeatable.
 */

import { randomUUID } from "node:crypto";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const now = () => new Date();

const daysFromNow = (days: number): Date => {
  const d = new Date();
  d.setDate(d.getDate() + days);
  d.setHours(0, 0, 0, 0);
  return d;
};

const oneTimeId = (): string => randomUUID();

// ---------------------------------------------------------------------------
// Users
// ---------------------------------------------------------------------------

export const seedUsers = [
  {
    _id: oneTimeId(),
    name: "Admin User",
    email: "admin@auxilia.test",
    password: "Admin$ecure2026", // nosec - dummy seed password for development only
    role: "admin" as const,
    status: "active" as const,
    emailVerifiedAt: now(),
  },
  {
    _id: oneTimeId(),
    name: "Alice Chen",
    email: "alice@example.com",
    password: "Alice$ecure2026", // nosec - dummy seed password for development only
    role: "user" as const,
    status: "active" as const,
    emailVerifiedAt: now(),
  },
  {
    _id: oneTimeId(),
    name: "Bob Smith",
    email: "bob@example.com",
    password: "Bob$ecure2026", // nosec - dummy seed password for development only
    role: "user" as const,
    status: "active" as const,
    emailVerifiedAt: now(),
  },
  {
    _id: oneTimeId(),
    name: "Carol Davis",
    email: "carol@example.com",
    password: "Carol$ecure2026", // nosec - dummy seed password for development only
    role: "user" as const,
    status: "active" as const,
    emailVerifiedAt: now(),
  },
  {
    _id: oneTimeId(),
    name: "David Wilson",
    email: "david@example.com",
    password: "David$ecure2026", // nosec - dummy seed password for development only
    role: "user" as const,
    status: "pending" as const,
    emailVerifiedAt: null,
  },
];

export const seedGroups = [
  {
    groupId: oneTimeId(),
    name: "CS101 Study Group",
    description: "Weekly study sessions for Introduction to Computer Science.",
    visibility: "PRIVATE" as const,
    status: "ACTIVE" as const,
    ownerId: seedUsers[1]._id, // Alice
  },
  {
    groupId: oneTimeId(),
    name: "Project Alpha",
    description: "Capstone project collaboration for the software engineering course.",
    visibility: "PRIVATE" as const,
    status: "ACTIVE" as const,
    ownerId: seedUsers[2]._id, // Bob
  },
  {
    groupId: oneTimeId(),
    name: "Weekend Planning",
    description: "Personal task coordination for weekend activities and errands.",
    visibility: "PUBLIC" as const,
    status: "ACTIVE" as const,
    ownerId: seedUsers[3]._id, // Carol
  },
];

export const seedMemberships = [
  // CS101 Study Group
  { groupId: seedGroups[0].groupId, userId: seedUsers[1]._id, role: "OWNER" as const, status: "ACTIVE" as const }, // Alice
  { groupId: seedGroups[0].groupId, userId: seedUsers[2]._id, role: "MEMBER" as const, status: "ACTIVE" as const }, // Bob
  { groupId: seedGroups[0].groupId, userId: seedUsers[3]._id, role: "MEMBER" as const, status: "ACTIVE" as const }, // Carol
  // Project Alpha
  { groupId: seedGroups[1].groupId, userId: seedUsers[2]._id, role: "OWNER" as const, status: "ACTIVE" as const }, // Bob
  { groupId: seedGroups[1].groupId, userId: seedUsers[1]._id, role: "ADMIN" as const, status: "ACTIVE" as const }, // Alice
  { groupId: seedGroups[1].groupId, userId: seedUsers[4]._id, role: "MEMBER" as const, status: "ACTIVE" as const }, // David
  // Weekend Planning
  { groupId: seedGroups[2].groupId, userId: seedUsers[3]._id, role: "OWNER" as const, status: "ACTIVE" as const }, // Carol
  { groupId: seedGroups[2].groupId, userId: seedUsers[2]._id, role: "MEMBER" as const, status: "ACTIVE" as const }, // Bob
];

// ---------------------------------------------------------------------------
// Tasks (covers all required test scenarios)
// ---------------------------------------------------------------------------

export const seedTasks = [
  // --- Alice (alice@example.com) ---
  {
    _id: oneTimeId(),
    userId: seedUsers[1]._id,
    title: "Finish research summary",
    description: "Compile findings from the literature review into a 5-page summary.",
    course: "CS101",
    tags: ["research", "writing"],
    groupId: seedGroups[0].groupId,
    assigneeId: seedUsers[1]._id,
    assigneeName: "Alice Chen",
    status: "todo" as const,
    priority: "high" as const,
    dueDate: daysFromNow(0), // due today
    reminderAt: daysFromNow(0),
  },
  {
    _id: oneTimeId(),
    userId: seedUsers[1]._id,
    title: "Read chapter 4",
    description: "Read and annotate chapter 4 of the textbook.",
    course: "CS101",
    tags: ["reading"],
    status: "in_progress" as const,
    priority: "medium" as const,
    dueDate: daysFromNow(2), // due within 7 days
    reminderAt: daysFromNow(1),
  },
  {
    _id: oneTimeId(),
    userId: seedUsers[1]._id,
    title: "Submit lab report",
    description: "Finalize and upload the Week 3 lab report.",
    course: "CS101",
    tags: ["lab", "submission"],
    groupId: seedGroups[0].groupId,
    assigneeId: seedUsers[1]._id,
    assigneeName: "Alice Chen",
    status: "completed" as const,
    priority: "high" as const,
    dueDate: daysFromNow(-3), // completed, was due 3 days ago
    completedAt: daysFromNow(-1),
  },
  {
    _id: oneTimeId(),
    userId: seedUsers[1]._id,
    title: "Midterm exam preparation",
    description: "Review lecture notes and practice problems for the midterm.",
    course: "CS101",
    tags: ["exam", "study"],
    status: "todo" as const,
    priority: "urgent" as const,
    dueDate: daysFromNow(-1), // overdue
  },
  {
    _id: oneTimeId(),
    userId: seedUsers[1]._id,
    title: "Buy groceries",
    description: "Milk, eggs, bread, and vegetables for the week.",
    course: "",
    tags: ["personal", "errands"],
    groupId: seedGroups[2].groupId,
    assigneeId: seedUsers[3]._id,
    assigneeName: "Carol Davis",
    status: "todo" as const,
    priority: "low" as const,
    dueDate: null, // no deadline
  },
  {
    _id: oneTimeId(),
    userId: seedUsers[1]._id,
    title: "Group project milestone 1",
    description: "Complete the requirements specification document.",
    course: "SE301",
    tags: ["group", "documentation"],
    groupId: seedGroups[1].groupId,
    assigneeId: seedUsers[2]._id,
    assigneeName: "Bob Smith",
    status: "in_progress" as const,
    priority: "high" as const,
    dueDate: daysFromNow(5), // due within 7 days
  },
  {
    _id: oneTimeId(),
    userId: seedUsers[1]._id,
    title: "Update CV",
    description: "Add recent internship experience and projects.",
    course: "",
    tags: ["career", "personal"],
    status: "todo" as const,
    priority: "medium" as const,
    dueDate: null, // no deadline
  },
  {
    _id: oneTimeId(),
    userId: seedUsers[1]._id,
    title: "Attend office hours",
    description: "Clarify assignment questions with the professor.",
    course: "CS101",
    tags: ["academic"],
    status: "completed" as const,
    priority: "low" as const,
    dueDate: daysFromNow(-5),
    completedAt: daysFromNow(-5),
  },

  // --- Bob (bob@example.com) ---
  {
    _id: oneTimeId(),
    userId: seedUsers[2]._id,
    title: "Capstone prototype demo",
    description: "Prepare the working prototype for the capstone review.",
    course: "SE401",
    tags: ["capstone", "demo"],
    groupId: seedGroups[1].groupId,
    assigneeId: seedUsers[2]._id,
    assigneeName: "Bob Smith",
    status: "in_progress" as const,
    priority: "urgent" as const,
    dueDate: daysFromNow(1), // due tomorrow
  },
  {
    _id: oneTimeId(),
    userId: seedUsers[2]._id,
    title: "Database schema review",
    description: "Review the ER diagram with the team.",
    course: "SE301",
    tags: ["database", "design"],
    status: "todo" as const,
    priority: "medium" as const,
    dueDate: daysFromNow(3), // due within 7 days
  },
  {
    _id: oneTimeId(),
    userId: seedUsers[2]._id,
    title: "Weekly timesheet",
    description: "Submit hours for the part-time research assistantship.",
    course: "",
    tags: ["admin", "recurring"],
    status: "completed" as const,
    priority: "low" as const,
    dueDate: daysFromNow(-2),
    completedAt: daysFromNow(-2),
  },
  {
    _id: oneTimeId(),
    userId: seedUsers[2]._id,
    title: "Fix login bug",
    description: "Investigate and resolve the OAuth redirect issue.",
    course: "",
    tags: ["bug", "frontend"],
    groupId: seedGroups[1].groupId,
    assigneeId: seedUsers[2]._id,
    assigneeName: "Bob Smith",
    status: "todo" as const,
    priority: "high" as const,
    dueDate: daysFromNow(-2), // overdue
  },
  {
    _id: oneTimeId(),
    userId: seedUsers[2]._id,
    title: "Buy textbooks",
    description: "Order SE301 and CS101 textbooks from the bookstore.",
    course: "",
    tags: ["personal", "errands"],
    status: "todo" as const,
    priority: "low" as const,
    dueDate: null, // no deadline
  },
  {
    _id: oneTimeId(),
    userId: seedUsers[2]._id,
    title: "Team standup",
    description: "Weekly sync with Project Alpha team.",
    course: "SE401",
    tags: ["meeting"],
    groupId: seedGroups[1].groupId,
    assigneeId: seedUsers[2]._id,
    assigneeName: "Bob Smith",
    status: "completed" as const,
    priority: "medium" as const,
    dueDate: daysFromNow(-1),
    completedAt: daysFromNow(-1),
  },

  // --- Carol (carol@example.com) ---
  {
    _id: oneTimeId(),
    userId: seedUsers[3]._id,
    title: "Essay draft",
    description: "Write the first draft of the English literature essay.",
    course: "ENG202",
    tags: ["writing", "essay"],
    status: "todo" as const,
    priority: "medium" as const,
    dueDate: daysFromNow(4), // due within 7 days
  },
  {
    _id: oneTimeId(),
    userId: seedUsers[3]._id,
    title: "Art history quiz",
    description: "Prepare for the Renaissance art quiz on Friday.",
    course: "ART101",
    tags: ["quiz", "study"],
    status: "in_progress" as const,
    priority: "high" as const,
    dueDate: daysFromNow(1), // due tomorrow
  },
  {
    _id: oneTimeId(),
    userId: seedUsers[3]._id,
    title: "Submit portfolio",
    description: "Upload the design portfolio to the course portal.",
    course: "DES101",
    tags: ["submission", "design"],
    groupId: seedGroups[2].groupId,
    assigneeId: seedUsers[3]._id,
    assigneeName: "Carol Davis",
    status: "completed" as const,
    priority: "high" as const,
    dueDate: daysFromNow(-4),
    completedAt: daysFromNow(-4),
  },
  {
    _id: oneTimeId(),
    userId: seedUsers[3]._id,
    title: "Plan weekend trip",
    description: "Research destinations and book accommodation.",
    course: "",
    tags: ["personal", "travel"],
    groupId: seedGroups[2].groupId,
    assigneeId: seedUsers[3]._id,
    assigneeName: "Carol Davis",
    status: "todo" as const,
    priority: "low" as const,
    dueDate: null, // no deadline
  },
  {
    _id: oneTimeId(),
    userId: seedUsers[3]._id,
    title: "Language practice",
    description: "Complete the weekly Spanish conversation exercise.",
    course: "SPAN101",
    tags: ["language"],
    status: "todo" as const,
    priority: "medium" as const,
    dueDate: daysFromNow(6), // due within 7 days
  },

  // --- David (david@example.com) ---
  {
    _id: oneTimeId(),
    userId: seedUsers[4]._id,
    title: "Orientation session",
    description: "Attend the new student orientation.",
    course: "ORI100",
    tags: ["orientation"],
    groupId: seedGroups[1].groupId,
    assigneeId: seedUsers[4]._id,
    assigneeName: "David Wilson",
    status: "completed" as const,
    priority: "medium" as const,
    dueDate: daysFromNow(-7),
    completedAt: daysFromNow(-7),
  },
  {
    _id: oneTimeId(),
    userId: seedUsers[4]._id,
    title: "Set up development environment",
    description: "Install Node.js, MongoDB, and configure IDE.",
    course: "",
    tags: ["setup", "technical"],
    status: "in_progress" as const,
    priority: "high" as const,
    dueDate: daysFromNow(2), // due within 7 days
  },
  {
    _id: oneTimeId(),
    userId: seedUsers[4]._id,
    title: "Read student handbook",
    description: "Review policies and procedures.",
    course: "",
    tags: ["reading"],
    status: "todo" as const,
    priority: "low" as const,
    dueDate: null, // no deadline
  },
];

// ---------------------------------------------------------------------------
// Roadmaps
// ---------------------------------------------------------------------------

export const seedRoadmaps = [
  {
    _id: oneTimeId(),
    groupId: seedGroups[0].groupId,
    title: "CS101 Course Roadmap",
    description: "Week-by-week plan for mastering Introduction to Computer Science.",
    source: "manual" as const,
    status: "approved" as const,
    createdBy: seedUsers[1]._id, // Alice
    approvedAt: daysFromNow(-10),
    items: [
      {
        itemId: oneTimeId(),
        title: "Variables and data types",
        description: "Understand primitives, objects, and references.",
        criterion: "Fundamentals",
        weight: 15,
        estimateHours: 4,
        status: "done" as const,
        order: 1,
      },
      {
        itemId: oneTimeId(),
        title: "Control structures",
        description: "Loops, conditionals, and flow control.",
        criterion: "Fundamentals",
        weight: 20,
        estimateHours: 6,
        status: "done" as const,
        order: 2,
      },
      {
        itemId: oneTimeId(),
        title: "Functions and modules",
        description: "Write reusable code with functions and ES modules.",
        criterion: "Modularity",
        weight: 25,
        estimateHours: 8,
        status: "in_progress" as const,
        order: 3,
      },
      {
        itemId: oneTimeId(),
        title: "Object-oriented programming",
        description: "Classes, inheritance, and polymorphism.",
        criterion: "OOP",
        weight: 25,
        estimateHours: 10,
        status: "pending" as const,
        order: 4,
      },
      {
        itemId: oneTimeId(),
        title: "Final project",
        description: "Build a capstone application integrating all topics.",
        criterion: "Capstone",
        weight: 15,
        estimateHours: 20,
        status: "pending" as const,
        order: 5,
      },
    ],
  },
  {
    _id: oneTimeId(),
    groupId: seedGroups[1].groupId,
    title: "Project Alpha Milestones",
    description: "Key deliverables for the capstone software engineering project.",
    source: "manual" as const,
    status: "draft" as const,
    createdBy: seedUsers[2]._id, // Bob
    approvedAt: null,
    items: [
      {
        itemId: oneTimeId(),
        title: "Requirements specification",
        description: "Document functional and non-functional requirements.",
        criterion: null,
        weight: null,
        estimateHours: 12,
        status: "done" as const,
        order: 1,
      },
      {
        itemId: oneTimeId(),
        title: "System architecture",
        description: "Design the high-level architecture and tech stack.",
        criterion: null,
        weight: null,
        estimateHours: 16,
        status: "in_progress" as const,
        order: 2,
      },
      {
        itemId: oneTimeId(),
        title: "Prototype",
        description: "Build a working prototype of core features.",
        criterion: null,
        weight: null,
        estimateHours: 24,
        status: "pending" as const,
        order: 3,
      },
      {
        itemId: oneTimeId(),
        title: "User testing",
        description: "Conduct usability testing with target users.",
        criterion: null,
        weight: null,
        estimateHours: 8,
        status: "pending" as const,
        order: 4,
      },
      {
        itemId: oneTimeId(),
        title: "Final release",
        description: "Deploy the production-ready application.",
        criterion: null,
        weight: null,
        estimateHours: 10,
        status: "pending" as const,
        order: 5,
      },
    ],
  },
];

// ---------------------------------------------------------------------------
// Rubrics
// ---------------------------------------------------------------------------

export const seedRubrics = [
  {
    _id: oneTimeId(),
    groupId: seedGroups[0].groupId,
    title: "Essay Grading Rubric",
    sourceText:
      "Criteria: Thesis (25%), Evidence (35%), Organization (20%), Mechanics (20%).",
    checksum: "placeholder-checksum-00000000000000000000000000000001",
    version: 1,
    criteria: [
      {
        name: "Thesis Statement",
        description: "Clear, arguable central claim.",
        weight: 25,
      },
      {
        name: "Evidence",
        description: "Relevant and well-integrated supporting evidence.",
        weight: 35,
      },
      {
        name: "Organization",
        description: "Logical structure and transitions.",
        weight: 20,
      },
      {
        name: "Mechanics",
        description: "Grammar, spelling, and citation format.",
        weight: 20,
      },
    ],
    createdBy: seedUsers[1]._id, // Alice
  },
];

// ---------------------------------------------------------------------------
// Feedback
// ---------------------------------------------------------------------------

export const seedFeedback = [
  {
    userId: seedUsers[1]._id,
    category: "FEATURE_REQUEST" as const,
    title: "Add dark mode toggle",
    description: "It would be great to have a dark mode for late-night studying.",
    rating: 4,
    status: "PENDING" as const,
  },
  {
    userId: seedUsers[2]._id,
    category: "BUG" as const,
    title: "Task due date not saving",
    description: "When I set a due date on a task, it reverts to null after refresh.",
    rating: 2,
    status: "IN_REVIEW" as const,
  },
  {
    userId: seedUsers[3]._id,
    category: "GENERAL" as const,
    title: "Great app so far",
    description: "Really enjoying the group collaboration features.",
    rating: 5,
    status: "RESOLVED" as const,
  },
  {
    userId: seedUsers[4]._id,
    category: "UI_UX" as const,
    title: "Navigation is confusing",
    description: "The sidebar could use clearer labels and icons.",
    rating: 3,
    status: "PENDING" as const,
  },
];

// ---------------------------------------------------------------------------
// Calendar Events
// ---------------------------------------------------------------------------

export const seedCalendarEvents = [
  {
    userId: seedUsers[1]._id,
    title: "CS101 Lecture",
    description: "Introduction to Computer Science lecture.",
    startTime: daysFromNow(0),
    endTime: daysFromNow(0),
    isAllDay: false,
    priority: "MEDIUM" as const,
    status: "SCHEDULED" as const,
    location: "Building A, Room 101",
    groupId: seedGroups[0].groupId,
  },
  {
    userId: seedUsers[1]._id,
    title: "Study Group Meeting",
    description: "Weekly CS101 study group session.",
    startTime: daysFromNow(2),
    endTime: daysFromNow(2),
    isAllDay: false,
    priority: "HIGH" as const,
    status: "SCHEDULED" as const,
    location: "Library, Room 2B",
    groupId: seedGroups[0].groupId,
  },
  {
    userId: seedUsers[2]._id,
    title: "Capstone Review",
    description: "Mid-point review with project advisor.",
    startTime: daysFromNow(1),
    endTime: daysFromNow(1),
    isAllDay: false,
    priority: "URGENT" as const,
    status: "SCHEDULED" as const,
    location: "Engineering Building, Room 305",
    groupId: seedGroups[1].groupId,
  },
  {
    userId: seedUsers[2]._id,
    title: "Past Project Meeting",
    description: "Initial kickoff meeting (already held).",
    startTime: daysFromNow(-14),
    endTime: daysFromNow(-14),
    isAllDay: false,
    priority: "LOW" as const,
    status: "COMPLETED" as const,
    location: "Online",
    groupId: seedGroups[1].groupId,
  },
  {
    userId: seedUsers[3]._id,
    title: "Weekend Trip Planning",
    description: "Plan the weekend getaway with friends.",
    startTime: daysFromNow(5),
    endTime: daysFromNow(5),
    isAllDay: true,
    priority: "LOW" as const,
    status: "SCHEDULED" as const,
    location: null,
    groupId: seedGroups[2].groupId,
  },
  {
    userId: seedUsers[3]._id,
    title: "Cancelled Event",
    description: "This event was cancelled.",
    startTime: daysFromNow(-3),
    endTime: daysFromNow(-3),
    isAllDay: false,
    priority: "LOW" as const,
    status: "CANCELLED" as const,
    location: null,
  },
];

// ---------------------------------------------------------------------------
// Study Sessions
// ---------------------------------------------------------------------------

export const seedStudySessions = [
  {
    _id: oneTimeId(),
    groupId: seedGroups[0].groupId,
    title: "CS101 Midterm Review",
    description: "Group review session for the upcoming midterm exam.",
    startsAt: daysFromNow(3),
    endsAt: daysFromNow(3),
    location: "Library, Study Room 4",
    maxAttendees: 10,
    attendeeIds: [seedUsers[1]._id, seedUsers[2]._id, seedUsers[3]._id],
    createdBy: seedUsers[1]._id, // Alice
    status: "scheduled" as const,
  },
  {
    _id: oneTimeId(),
    groupId: seedGroups[1].groupId,
    title: "Capstone Architecture Workshop",
    description: "Workshop to finalise the system architecture.",
    startsAt: daysFromNow(7),
    endsAt: daysFromNow(7),
    location: "Engineering Lab",
    maxAttendees: 8,
    attendeeIds: [seedUsers[2]._id, seedUsers[1]._id, seedUsers[4]._id],
    createdBy: seedUsers[2]._id, // Bob
    status: "scheduled" as const,
  },
];
