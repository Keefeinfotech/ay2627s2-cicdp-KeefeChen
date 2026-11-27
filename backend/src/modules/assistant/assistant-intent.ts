/**
 * File Name: assistant-intent.ts
 * Description: Deterministic, reliable action-routing for the AI assistant.
 *
 * The assistant must not rely exclusively on loosely structured AI-generated
 * text to execute database operations. This module parses a user's
 * natural-language message into a structured intent with validated-shaped
 * parameters using a fixed keyword grammar. Untrusted message text is only
 * ever *read*; it is never interpreted as a command, query or code, and any
 * extracted value is re-validated by the existing Zod schemas before it
 * reaches a service. When nothing matches, the intent is `conversation`.
 */

import { TASK_PRIORITIES, TASK_STATUSES } from "../tasks/task.types.js";
import type { TaskPriority, TaskStatus } from "../tasks/task.types.js";
import { REMINDER_RECURRENCES } from "../reminders/reminder.model.js";
import type { ReminderRecurrence } from "../reminders/reminder.model.js";

// ============================================================================
// INTENT TYPES
// ============================================================================

export const ASSISTANT_INTENTS = [
  "create_task",
  "update_task",
  "complete_task",
  "reopen_task",
  "delete_task",
  "list_tasks",
  "set_reminder",
  "cancel_reminder",
  "conversation",
] as const;

export type AssistantIntent = (typeof ASSISTANT_INTENTS)[number];

/** Task fields the assistant is allowed to extract for `update_task`. */
export interface UpdateTaskParams {
  title?: string;
  description?: string | null;
  dueDate?: string | null;
  priority?: TaskPriority;
  status?: TaskStatus;
  course?: string;
  tags?: string[];
  reminderAt?: string | null;
}

export interface CreateTaskParams {
  title: string;
  description?: string | null;
  dueDate?: string | null;
  priority?: TaskPriority;
  course?: string;
  tags?: string[];
  reminderAt?: string | null;
}

export interface ParsedIntent {
  intent: AssistantIntent;
  /** Natural-language fragment used to locate an existing task. */
  taskQuery?: string;
  /** Parameters for `create_task`. */
  create?: CreateTaskParams;
  /** Field changes for `update_task`. */
  updates?: UpdateTaskParams;
  /** Structured listing filters for `list_tasks`. */
  filters?: ListTaskFilters;
  /** Reminder parameters for `set_reminder`. */
  reminder?: ReminderParams;
  /** The raw user message, untrusted. */
  raw: string;
}

export interface ListTaskFilters {
  status?: TaskStatus[];
  priority?: TaskPriority[];
  dueBefore?: string;
  dueAfter?: string;
  search?: string;
  /** Human label for the applied timeframe, e.g. "due this week". */
  timeframe?: string;
}

export interface ReminderParams {
  /** Task title fragment the reminder attaches to, if any. */
  taskQuery?: string;
  /** Reminder message for a standalone reminder. */
  message?: string;
  /** ISO datetime for the reminder. */
  dueAt?: string;
  recurrence?: ReminderRecurrence;
}

export interface DateContext {
  currentDate?: string;
  utcOffsetMinutes?: number;
}

// ============================================================================
// TEXT NORMALISATION
// ============================================================================

const normalizeSpace = (value: string): string =>
  value.replace(/\s+/g, " ").trim();

const stripTrailingPunctuation = (value: string): string =>
  value.replace(/[.!?,;:\s]+$/g, "").trim();

/** Lower-case, collapsed-whitespace, punctuation-trimmed copy. */
export const normalizeTitle = (value: string): string =>
  normalizeSpace(value)
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s]/gu, " ")
    .replace(/\s+/g, " ")
    .trim();

// ============================================================================
// PRIORITY + STATUS VOCABULARY (fixed, not model-generated)
// ============================================================================

// The app surfaces low/medium/high; "urgent"/"critical"/"asap" map to "high"
// (matching the app's own quick-add parser) so no unsupported value is stored.
const PRIORITY_PATTERNS: Array<{ re: RegExp; priority: TaskPriority }> = [
  { re: /\b(urgent|critical|asap|highest\s+priority)\b/i, priority: "high" },
  { re: /\bhigh\s+priority\b|\bpriority\s+high\b|\bhigh-priority\b/i, priority: "high" },
  { re: /\bmedium\s+priority\b|\bpriority\s+medium\b|\bnormal\s+priority\b/i, priority: "medium" },
  { re: /\blow\s+priority\b|\bpriority\s+low\b|\blow-priority\b/i, priority: "low" },
];

/** Extracts a priority mention, e.g. "high priority" / "priority: low". */
export const extractPriority = (text: string): TaskPriority | undefined => {
  for (const { re, priority } of PRIORITY_PATTERNS) {
    if (re.test(text)) return priority;
  }
  // "set priority of X to high" / "priority high" / "priority: high"
  const m = text.match(
    /\bpriority\b\s*(?:to|is|=|:)?\s*(low|medium|high|urgent)\b/i,
  );
  if (m) {
    const value = m[1]!.toLowerCase();
    if (value === "urgent") return "high";
    if ((TASK_PRIORITIES as readonly string[]).includes(value)) {
      return value as TaskPriority;
    }
  }
  return undefined;
};

const normalizePriority = (value: string): TaskPriority => {
  const v = value.toLowerCase();
  if (v === "urgent") return "high"; // app supports low/medium/high
  if ((TASK_PRIORITIES as readonly string[]).includes(v)) return v as TaskPriority;
  return "medium";
};

/** Extracts a task status mention. */
export const extractStatus = (text: string): TaskStatus | undefined => {
  const m = text.match(
    /\bstatus\b\s*(?:to|is|=|:)?\s*(todo|to-do|in[\s_-]?progress|completed|done|archived|open)\b/i,
  );
  if (!m) return undefined;
  const value = m[1]!.toLowerCase().replace(/[\s-]+/g, "_");
  if (value === "done" || value === "to_do") return value === "done" ? "completed" : "todo";
  if (value === "open") return "todo";
  if (value === "in_progress") return "in_progress";
  if ((TASK_STATUSES as readonly string[]).includes(value)) {
    return value as TaskStatus;
  }
  return undefined;
};

// ============================================================================
// RELATIVE DATE PARSING (deterministic; anchored to the user's local date)
// ============================================================================

const WEEKDAYS = [
  "sunday",
  "monday",
  "tuesday",
  "wednesday",
  "thursday",
  "friday",
  "saturday",
];

const MONTHS =
  "jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?";

const MONTH_INDEX: Record<string, number> = {
  jan: 0, january: 0, feb: 1, february: 1, mar: 2, march: 2, apr: 3, april: 3,
  may: 4, jun: 5, june: 5, jul: 6, july: 6, aug: 7, august: 7, sep: 8,
  sept: 8, september: 8, oct: 9, october: 9, nov: 10, november: 10, dec: 11,
  december: 11,
};

const DATE_TOKEN_RE = new RegExp(
  [
    String.raw`\b\d{4}-\d{2}-\d{2}\b`, // ISO date
    String.raw`\b\d{1,2}\s+(?:${MONTHS})(?:\s+\d{4})?\b`, // 4 March / 4 March 2026
    String.raw`\b(?:${MONTHS})\s+\d{1,2}(?:,?\s+\d{4})?\b`, // March 4 / March 4, 2026
    String.raw`\b(?:today|tomorrow|tonight|yesterday)\b`,
    String.raw`\b(?:this|next|coming)\s+(?:week|month|weekend|${WEEKDAYS.join("|")})\b`,
    String.raw`\b(?:${WEEKDAYS.join("|")})\b`,
    String.raw`\bin\s+\d{1,3}\s+(?:day|days|week|weeks|month|months)\b`,
    String.raw`\bend\s+of\s+(?:the\s+)?(?:week|month)\b`,
    String.raw`\bnext\s+week\b`,
  ].join("|"),
  "i",
);

/** Returns a UTC `Date` at midnight for `currentDate` (YYYY-MM-DD). */
const referenceDay = (ctx: DateContext): Date => {
  const raw =
    ctx.currentDate && /^\d{4}-\d{2}-\d{2}$/.test(ctx.currentDate)
      ? ctx.currentDate
      : new Date().toISOString().slice(0, 10);
  return new Date(`${raw}T00:00:00.000Z`);
};

const isoDay = (d: Date): string => d.toISOString().slice(0, 10);

const addDays = (d: Date, days: number): Date => {
  const copy = new Date(d);
  copy.setUTCDate(copy.getUTCDate() + days);
  return copy;
};

/** Start of the user's local day expressed in UTC, given the offset. */
const localDayUtc = (ctx: DateContext, dayOffset = 0): Date => {
  const base = referenceDay(ctx);
  const offsetMin = ctx.utcOffsetMinutes ?? 0;
  // Local midnight = UTC midnight - offset. Keep arithmetic in whole days on
  // the UTC day grid; offsets only shift which UTC instant local midnight is.
  const shifted = addDays(base, dayOffset);
  return new Date(shifted.getTime() - offsetMin * 60_000);
};

/**
 * Resolves a single date token to an ISO string. Date-only expressions resolve
 * to start-of-local-day UTC. Returns null when the token cannot be resolved.
 */
export const resolveDateToken = (
  tokenRaw: string,
  ctx: DateContext,
): string | null => {
  const token = tokenRaw.trim().toLowerCase().replace(/,/g, " ");
  const base = referenceDay(ctx);

  // ISO date
  const iso = token.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (iso) {
    const d = new Date(`${token}T00:00:00.000Z`);
    if (Number.isNaN(d.getTime())) return null;
    // Reject impossible dates like 2026-02-30.
    if (isoDay(d) !== token) return null;
    return token;
  }

  if (token === "today" || token === "tonight") return isoDay(base);
  if (token === "tomorrow") return isoDay(addDays(base, 1));
  if (token === "yesterday") return isoDay(addDays(base, -1));

  // in N days / weeks / months
  const inN = token.match(/^in\s+(\d{1,3})\s+(day|days|week|weeks|month|months)$/);
  if (inN) {
    const n = Number(inN[1]);
    const unit = inN[2]!;
    if (unit.startsWith("day")) return isoDay(addDays(base, n));
    if (unit.startsWith("week")) return isoDay(addDays(base, n * 7));
    const d = new Date(base);
    d.setUTCMonth(d.getUTCMonth() + n);
    return isoDay(d);
  }

  // end of week / end of month
  if (/^end\s+of\s+(the\s+)?week$/.test(token)) {
    const delta = (7 - base.getUTCDay()) % 7; // upcoming Sunday
    return isoDay(addDays(base, delta === 0 ? 7 : delta));
  }
  if (/^end\s+of\s+(the\s+)?month$/.test(token)) {
    const d = new Date(Date.UTC(base.getUTCFullYear(), base.getUTCMonth() + 1, 0));
    return isoDay(d);
  }

  // this/next/coming X
  const rel = token.match(
    /^(this|next|coming)\s+(week|month|weekend|sunday|monday|tuesday|wednesday|thursday|friday|saturday)$/,
  );
  if (rel) {
    const which = rel[1]!;
    const what = rel[2]!;
    if (what === "week") {
      const startOfWeek = addDays(base, -((base.getUTCDay() + 6) % 7)); // Monday
      return isoDay(addDays(startOfWeek, which === "this" ? 6 : 13)); // Sunday end
    }
    if (what === "month") {
      const y = base.getUTCFullYear();
      const m = base.getUTCMonth() + (which === "this" ? 1 : 2);
      return isoDay(new Date(Date.UTC(y, m, 0)));
    }
    if (what === "weekend") {
      const delta = (6 - base.getUTCDay() + 7) % 7; // Saturday
      return isoDay(addDays(base, which === "this" ? (delta === 0 ? 0 : delta) : delta + 7));
    }
    const target = WEEKDAYS.indexOf(what);
    if (target >= 0) {
      const sameWeek = (target - base.getUTCDay() + 7) % 7;
      if (which === "this") {
        // "this monday" = the Monday of the current week
        return isoDay(addDays(base, -((base.getUTCDay() + 6) % 7) + ((target + 6) % 7)));
      }
      // "next/coming X" = strictly after this week's occurrence
      const delta = which === "next" ? sameWeek + 7 : sameWeek;
      return isoDay(addDays(base, delta === 0 ? 7 : delta));
    }
  }

  // bare weekday name → next occurrence (not today)
  if (WEEKDAYS.includes(token)) {
    const target = WEEKDAYS.indexOf(token);
    let delta = (target - base.getUTCDay() + 7) % 7;
    if (delta === 0) delta = 7;
    return isoDay(addDays(base, delta));
  }

  // "next week"
  if (token === "next week") return isoDay(addDays(base, 7));

  // Month-name dates: "4 March", "March 4", optional year.
  const monthDay = token.match(
    new RegExp(`^(?:(\\d{1,2})\\s+(${MONTHS})|(${MONTHS})\\s+(\\d{1,2}))(?:\\s+(\\d{4}))?$`, "i"),
  );
  if (monthDay) {
    const day = Number(monthDay[1] ?? monthDay[4]);
    const monthName = (monthDay[2] ?? monthDay[3])!.toLowerCase();
    const month = MONTH_INDEX[monthName] ?? MONTH_INDEX[monthName.slice(0, 3)];
    if (month === undefined || !Number.isInteger(day) || day < 1 || day > 31) {
      return null;
    }
    let year = monthDay[5] ? Number(monthDay[5]) : base.getUTCFullYear();
    let d = new Date(Date.UTC(year, month, day));
    // Reject impossible dates (e.g. 31 February).
    if (d.getUTCMonth() !== month || d.getUTCDate() !== day) return null;
    if (!monthDay[5] && isoDay(d) < isoDay(base)) {
      year += 1;
      d = new Date(Date.UTC(year, month, day));
    }
    return isoDay(d);
  }

  return null;
};

/**
 * Finds a date expression inside free text and resolves it. `anchor` is an
 * optional regex tested before the token (e.g. `to`, `by`, `due`, `on`).
 */
export const extractDate = (
  text: string,
  ctx: DateContext,
  anchor?: RegExp,
): string | null => {
  const haystack = anchor
    ? (() => {
        const m = text.match(anchor);
        return m ? text.slice((m.index ?? 0) + m[0].length) : text;
      })()
    : text;
  const match = haystack.match(DATE_TOKEN_RE);
  if (!match) return null;
  return resolveDateToken(match[0], ctx);
};

// ============================================================================
// TIME-OF-DAY PARSING for reminders ("at 9am", "at 14:30", "at noon")
// ============================================================================

const TIME_RE =
  /\bat\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)?\b|\bat\s+(noon|midday|midnight)\b|\b(\d{1,2}):(\d{2})\s*(am|pm)?\b/i;

/** Combines a resolved date (or today) with a time-of-day into ISO. */
export const extractDateTime = (
  text: string,
  ctx: DateContext,
): string | null => {
  const timeMatch = text.match(TIME_RE);
  let hour = 9;
  let minute = 0;
  let hasTime = false;
  if (timeMatch) {
    hasTime = true;
    if (timeMatch[4]) {
      // noon/midday/midnight
      const word = timeMatch[4].toLowerCase();
      hour = word === "midnight" ? 0 : 12;
      minute = 0;
    } else {
      hour = Number(timeMatch[1] ?? timeMatch[5] ?? 9);
      minute = Number(timeMatch[2] ?? timeMatch[6] ?? 0);
      const meridiem = (timeMatch[3] ?? timeMatch[7] ?? "").toLowerCase();
      if (meridiem.startsWith("p") && hour < 12) hour += 12;
      if (meridiem.startsWith("a") && hour === 12) hour = 0;
    }
    if (hour > 23 || minute > 59 || hour < 0) return null;
  }

  // Date part: search text with the time phrase removed.
  const withoutTime = timeMatch ? text.replace(timeMatch[0], " ") : text;
  let dayIso = extractDate(withoutTime, ctx);
  if (!dayIso) dayIso = isoDay(referenceDay(ctx));
  // A reminder time already past today with no explicit date → next day.
  let result = new Date(`${dayIso}T00:00:00.000Z`);
  result = new Date(
    result.getTime() +
      hour * 3_600_000 +
      minute * 60_000 +
      (ctx.utcOffsetMinutes ?? 0) * 60_000,
  );
  if (!hasTime && !extractDate(withoutTime, ctx)) return null;
  return result.toISOString();
};

// ============================================================================
// INTENT RECOGNITION
// ============================================================================

const CREATE_TRIGGER_RE = new RegExp(
  [
    String.raw`\bcreate\s+(?:a\s+|an\s+)?(?:new\s+)?task\b`,
    String.raw`\badd\s+(?:a\s+|an\s+)?(?:new\s+)?task\b`,
    String.raw`\bmake\s+(?:a\s+|an\s+)?(?:new\s+)?task\b`,
    String.raw`\bnew\s+task\b`,
    String.raw`\b(?:create|add|make)\s+task\b`,
    String.raw`\bremember\s+to\b`,
    String.raw`\bput\s+.+\s+on\s+my\s+(?:to-?do\s+)?list\b`,
    String.raw`\bschedule\b`,
    String.raw`\bset\s+up\s+a\s+task\b`,
  ].join("|"),
  "i",
);

const CREATE_TITLE_PREFIXES = [
  /^please\s+/i,
  /^(?:could|can)\s+you\s+/i,
  /^i\s+(?:want|need)\s+you\s+to\s+/i,
  /^(?:create|add|make)\s+(?:a\s+|an\s+)?(?:new\s+)?task\s*(?:to|for|called|named|titled|:)?\s*/i,
  /^(?:create|add|make)\s+task\s*(?:to|for|called|named|titled|:)?\s*/i,
  /^new\s+task\s*(?::|called|named|titled|to|for)?\s*/i,
  /^remember\s+to\s+/i,
  /^schedule\s+/i,
  /^set\s+up\s+a\s+task\s*(?:to|for|:)?\s*/i,
];

// Phrases that signal task retrieval rather than creation.
const RETRIEVAL_RE = new RegExp(
  [
    String.raw`\bwhat\s+(?:tasks?|to-?dos?|assignments?)\b`,
    String.raw`\b(?:list|show|display)\s+(?:me\s+)?(?:my\s+)?(?:all\s+)?(?:tasks?|to-?dos?)\b`,
    String.raw`\b(?:show|list)\s+(?:me\s+)?(?:my\s+)?(?:pending|completed|overdue|due)\b`,
    String.raw`\bdo\s+i\s+have\s+(?:any\s+)?(?:tasks?|to-?dos?|anything)\b`,
    String.raw`\bwhat\s+(?:do\s+i\s+have|am\s+i\s+(?:working\s+on|doing)|is\s+due)\b`,
    String.raw`\btasks?\s+due\b`,
    String.raw`\bwhat'?s\s+(?:due|on\s+my\s+(?:list|plate)|left)\b`,
    String.raw`\b(?:summari[sz]e|sum\s+up)\s+(?:my\s+)?(?:tasks?|to-?dos?|progress)\b`,
    String.raw`\bwhat\s+should\s+i\s+(?:work\s+on|do)\b`,
    String.raw`\bwhat\s+am\s+i\s+working\s+on\b`,
    String.raw`\bany\s+(?:tasks?|to-?dos?)\s+(?:due|today|this\s+week|overdue)\b`,
  ].join("|"),
  "i",
);

// Destructive verbs for task deletion.
const DELETE_RE = new RegExp(
  [
    String.raw`\bdelete\s+(?:my\s+|the\s+|a\s+)?(?:task\s+)?\b`,
    String.raw`\bremove\s+(?:my\s+|the\s+|a\s+)?(?:task\s+)?\b`,
    String.raw`\b(?:delete|remove)\s+task\b`,
    String.raw`\bdrop\s+task\b`,
    String.raw`\berase\s+(?:my\s+|the\s+)?(?:task\s+)?\b`,
    String.raw`\bcancel\s+(?:my\s+|the\s+)?task\b`,
    String.raw`\bget\s+rid\s+of\s+(?:my\s+|the\s+)?(?:task\s+)?\b`,
  ].join("|"),
  "i",
);

const COMPLETE_RE = new RegExp(
  [
    String.raw`\bmark\s+(?:my\s+|the\s+)?(?:task\s+)?.+?\s+(?:as\s+)?(?:completed|complete|done|finished)\b`,
    String.raw`\bmark\s+(?:my\s+|the\s+)?(?:task\s+)?(?:completed|complete|done|finished)\b`,
    String.raw`\b(?:complete|finish|close)\s+(?:my\s+|the\s+)?(?:task\s+)?\b`,
    String.raw`\bset\s+.+?\s+(?:as\s+)?(?:completed|complete|done)\b`,
    String.raw`\bset\s+status\s+(?:of\s+)?.+?\s+to\s+(?:completed|done)\b`,
    String.raw`\bmark\s+off\b`,
    String.raw`\bcheck\s+off\b`,
    String.raw`\bi\s+(?:finished|completed|did)\s+(?:my\s+|the\s+)?(?:task\s+)?\b`,
    String.raw`\bmy\s+.+?\s+is\s+(?:done|completed|finished)\b`,
  ].join("|"),
  "i",
);

const REOPEN_RE = new RegExp(
  [
    String.raw`\breopen\s+(?:my\s+|the\s+)?(?:task\s+)?\b`,
    String.raw`\bmark\s+(?:my\s+|the\s+)?(?:task\s+)?.+?\s+(?:as\s+)?(?:not\s+(?:completed|done)|incomplete|pending|todo|to-?do)\b`,
    String.raw`\buncomplete\b`,
    String.raw`\bset\s+.+?\s+(?:as\s+)?(?:not\s+(?:completed|done)|incomplete|pending|todo|to-?do)\b`,
  ].join("|"),
  "i",
);

const UPDATE_RE = new RegExp(
  [
    String.raw`\bupdate\s+(?:my\s+|the\s+)?(?:task\s+)?\b`,
    String.raw`\bedit\s+(?:my\s+|the\s+)?(?:task\s+)?\b`,
    String.raw`\bchange\s+(?:my\s+|the\s+)?(?:task\s+)?\b`,
    String.raw`\brename\s+(?:my\s+|the\s+)?(?:task\s+)?\b`,
    String.raw`\bmodify\s+(?:my\s+|the\s+)?(?:task\s+)?\b`,
    String.raw`\bset\s+(?:the\s+)?(?:due\s+date|deadline|priority|title|description|status|course|project|category|tags?)\b`,
    String.raw`\bset\s+priority\s+(?:of|for)\b`,
    String.raw`\b(?:change|move|reschedule|set)\s+.+?\s+(?:deadline|due\s+date|priority|title|description|course|project|category)\b`,
    String.raw`\breschedule\b`,
    String.raw`\bmove\s+.+?\s+to\b`,
    String.raw`\b(?:categori[sz]e|prioriti[sz]e|reorgani[sz]e|reorganise|reorganize)\b`,
    String.raw`\bset\s+(?:my\s+|the\s+)?(?:task\s+)?.+?\s+status\b`,
    String.raw`\b(?:clear|remove)\s+(?:the\s+)?(?:due\s+date|deadline|due)\b`,
    String.raw`\b(?:tag|label)\s+.+?\s+(?:with|as)\b`,
    String.raw`\badd\s+tag\b`,
  ].join("|"),
  "i",
);

const REMINDER_SET_RE = new RegExp(
  [
    String.raw`\bset\s+(?:a\s+|an\s+)?reminder\b`,
    String.raw`\bremind\s+me\s+(?:to\s+)?(?:about\s+)?\b`,
    String.raw`\bremind\s+me\s+(?:at|on|before|in)\b`,
    String.raw`\badd\s+(?:a\s+)?reminder\b`,
    String.raw`\bset\s+(?:a\s+)?reminder\s+(?:for|on|about)\b`,
    String.raw`\breminder\s+for\b`,
    String.raw`\bremind\s+me\s+about\b`,
  ].join("|"),
  "i",
);

const REMINDER_CANCEL_RE = new RegExp(
  [
    String.raw`\bcancel\s+(?:my\s+|the\s+)?reminder\b`,
    String.raw`\b(?:remove|delete|clear)\s+(?:my\s+|the\s+)?reminder\b`,
    String.raw`\bstop\s+reminding\s+me\b`,
    String.raw`\bturn\s+off\s+(?:my\s+|the\s+)?reminder\b`,
    String.raw`\bno\s+longer\s+remind\s+me\b`,
  ].join("|"),
  "i",
);

const REMINDER_RECURRENCE_RE = /\b(daily|every\s+day|weekly|every\s+week|monthly|every\s+month)\b/i;

// ============================================================================
// TASK-QUERY EXTRACTION (locate an existing task)
// ============================================================================

const QUERY_LEADING_NOISE = [
  /^please\s+/i,
  /^(?:could|can)\s+you\s+/i,
  // verbs
  /^(?:update|edit|change|rename|modify|complete|finish|close|reopen|delete|remove|drop|erase|cancel|uncomplete|reschedule|move|set|mark|categori[sz]e|prioriti[sz]e|reorgani[sz]e|reorganise|tag|label|get\s+rid\s+of)\s+/i,
  /^(?:off|my|the|a|an)\s+/i,
  /^(?:task|todo|to-do|assignment|reminder)\s+/i,
  /^(?:named|called|titled|title)\s+/i,
  /^["'“”]/,
  /["'“”]$/,
];

const stripLeadingNoise = (value: string): string => {
  let out = value;
  let prev: string;
  do {
    prev = out;
    for (const re of QUERY_LEADING_NOISE) out = out.replace(re, "");
    out = out.trim();
  } while (out !== prev);
  return out;
};

/**
 * Splits "X <modifier>" into task-query X and modifier text. `splitRe`
 * matches the boundary marking where field changes start.
 */
const splitQueryAndModifiers = (
  value: string,
  splitRe: RegExp,
): { query: string; modifiers: string } => {
  const m = value.match(splitRe);
  if (!m || m.index === undefined) return { query: value, modifiers: "" };
  return {
    query: value.slice(0, m.index),
    modifiers: value.slice(m.index + m[0].length),
  };
};

/** Extracts explicit tag lists: `tag X with a, b`, `#tag`. */
const extractTags = (text: string): string[] | undefined => {
  const tags = new Set<string>();
  const tagVerb = text.match(/\b(?:tag|label)\s+.+?\s+(?:with|as)\s+(.+)$/i);
  if (tagVerb) {
    for (const piece of tagVerb[1]!.split(/,|\band\b/i)) {
      const t = piece.trim().replace(/^#/, "");
      if (t) tags.add(t.slice(0, 24));
    }
  }
  for (const m of text.matchAll(/(?:^|\s)#([^\s#]{1,24})/g)) {
    tags.add(m[1]!);
  }
  return tags.size > 0 ? [...tags].slice(0, 8) : undefined;
};

// ============================================================================
// MAIN PARSER
// ============================================================================

/**
 * Parses a natural-language message into a structured intent. Pure and
 * deterministic; never executes anything. The caller must validate output
 * again before acting.
 */
export const parseAssistantIntent = (
  rawMessage: string,
  ctx: DateContext = {},
): ParsedIntent => {
  const raw = normalizeSpace(rawMessage ?? "");
  const text = stripTrailingPunctuation(raw);
  if (!text) return { intent: "conversation", raw };

  const hasCreateTrigger = CREATE_TRIGGER_RE.test(text);

  // ---- Reminder cancellation first (it can contain "cancel"). ----
  if (REMINDER_CANCEL_RE.test(text)) {
    return { intent: "cancel_reminder", taskQuery: extractReminderCancelQuery(text), raw };
  }

  // ---- Retrieval ----
  if (!hasCreateTrigger && RETRIEVAL_RE.test(text)) {
    return { intent: "list_tasks", filters: extractListFilters(text, ctx), raw };
  }

  // ---- Reminder creation ----
  if (!hasCreateTrigger && REMINDER_SET_RE.test(text)) {
    return { intent: "set_reminder", reminder: extractReminder(text, ctx), raw };
  }

  // ---- Creation ----
  if (hasCreateTrigger) {
    const create = extractCreateParams(text, ctx);
    if (create.title) {
      return { intent: "create_task", create, raw };
    }
    // Trigger present but no usable title: caller asks for clarification instead of guessing.
    return { intent: "create_task", create: { title: "" }, raw };
  }

  // ---- Deletion (destructive) ----
  if (DELETE_RE.test(text) && !REMINDER_CANCEL_RE.test(text)) {
    const query = extractDeleteQuery(text);
    return { intent: "delete_task", taskQuery: query, raw };
  }
  // ---- Completion / reopen ----
  if (REOPEN_RE.test(text)) {
    return { intent: "reopen_task", taskQuery: extractCompleteQuery(text), raw };
  }
  if (COMPLETE_RE.test(text)) {
    return { intent: "complete_task", taskQuery: extractCompleteQuery(text), raw };
  }

  // ---- Update ----
  const update = tryParseUpdate(text, ctx);
  if (update) return update;

  return { intent: "conversation", raw };
};

/** Extracts the task/reminder reference from a cancel-reminder command. */
const extractReminderCancelQuery = (text: string): string => {
  let out = text.replace(REMINDER_CANCEL_RE, " ");
  out = stripLeadingNoise(out);
  // Strip leading prepositions and the reminder word itself.
  out = out.replace(/^(?:on|for|about|at|in|before)\s+(?:my\s+|the\s+)?/i, "");
  out = out.replace(/^(?:my\s+|the\s+)?(?:reminder)\s*/i, "");
  // Strip trailing time expressions.
  const { query } = splitQueryAndModifiers(out, /\b(?:at|in|on|before|every)\b/i);
  return cleanQuery(stripLeadingNoise(query));
};

const cleanQuery = (value: string): string => {
  let out = stripTrailingPunctuation(value);
  out = out.replace(/\b(?:task|todo|to-do)\b\s*$/i, "").trim();
  out = out.replace(/^["'“”]|["'“”]$/g, "").trim();
  return out;
};

const extractDeleteQuery = (text: string): string => {
  let out = text.replace(DELETE_RE, " ");
  out = out.replace(/\b(?:cancel|remove|delete|drop|erase)\s+(?:my\s+|the\s+)?task\b/i, " ");
  out = out.replace(/\bget\s+rid\s+of\b/i, " ");
  const { query } = splitQueryAndModifiers(out, /\b(?:and|then)\b/i);
  return cleanQuery(stripLeadingNoise(query));
};

const extractCompleteQuery = (text: string): string => {
  let out = text;
  // Remove the completion marking, keep the task reference.
  out = out
    .replace(/\bmark\s+(?:my\s+|the\s+)?(?:task\s+)?/i, " ")
    .replace(/\b(?:as\s+)?(?:completed|complete|done|finished|not\s+(?:completed|done)|incomplete|pending|todo|to-?do)\b/gi, " ")
    .replace(/\b(?:complete|finish|close|reopen|uncomplete|set|status)\s+/gi, " ")
    .replace(/\b(?:set\s+status\s+(?:of\s+)?)/i, " ")
    .replace(/\b(?:to\s+)(?:completed|done|not\s+(?:completed|done)|incomplete|pending|todo|to-?do)\b/gi, " ")
    .replace(/\bmy\s+.+?\s+is\s+(?:done|completed|finished)\b/i, (m) =>
      m.replace(/\bis\s+(?:done|completed|finished)\b/i, " ").replace(/^my\s+/i, " "),
    )
    .replace(/\bi\s+(?:finished|completed|did)\s+(?:my\s+|the\s+)?(?:task\s+)?/i, " ")
    .replace(/\b(?:off|my|the|a|an)\b\s*/gi, " ");
  return cleanQuery(stripLeadingNoise(out));
};

// ============================================================================
// UPDATE PARSING
// ============================================================================

const tryParseUpdate = (text: string, ctx: DateContext): ParsedIntent | null => {
  if (!UPDATE_RE.test(text)) return null;

  // "mark X as completed" is handled by completion; avoid stealing it.
  if (COMPLETE_RE.test(text) || REOPEN_RE.test(text)) return null;

  const updates: UpdateTaskParams = {};
  let body = text;

  // --- rename to Y / change title to Y ---
  const rename = body.match(
    /\brename\s+(?:my\s+|the\s+)?(?:task\s+)?(.+?)\s+(?:to|as)\s+(.+)$/i,
  ) ?? body.match(
    /\b(?:change|set)\s+(?:the\s+)?(?:title|name)\s+(?:of\s+)?(.+?)\s+(?:to|as)\s+(.+)$/i,
  );
  if (rename) {
    updates.title = cleanQuery(rename[2]!).slice(0, 150);
    body = rename[1]!; // task reference is the pre-"to" part
    return finalizeUpdate(body, updates, ctx);
  }

  // Split "task-ref <field> <value>" style commands.
  // --- due date / deadline ---
  const dueRe =
    /\b(?:change|set|move|reschedule|update|edit)\s+(?:my\s+|the\s+)?(?:task\s+)?(.+?)\s*(?:'s\s+)?(?:deadline|due\s+date|due\s+on|due)\s+(?:to|for|on|by)?\s*(.+)$/i;
  const dueMatch = body.match(dueRe)
    ?? body.match(/\b(?:set|change|move|reschedule)\s+(?:the\s+)?(?:due\s+date|deadline)\s+(?:of\s+|for\s+)?(.+?)\s+(?:to|for|on|by)\s+(.+)$/i)
    ?? body.match(/\b(?:move|reschedule)\s+(?:my\s+|the\s+)?(?:task\s+)?(.+?)\s+(?:to|for)\s+(.+)$/i);
  if (dueMatch) {
    const target = dueMatch[1]!;
    const when = dueMatch[2]!;
    const date = extractDate(when, ctx) ?? extractDate(when, ctx, /\b(?:to|on|by|for)\b/i);
    if (date) {
      updates.dueDate = date;
      return finalizeUpdate(stripTrailingPunctuation(target), updates, ctx);
    }
  }

  // --- priority ---
  const prioMatch = body.match(
    /\b(?:set|change|update|make)\s+(?:my\s+|the\s+)?(?:task\s+)?(.+?)\s*(?:'s\s+)?priority\s+(?:to|as|=)?\s*(low|medium|high|urgent)\b/i,
  ) ?? body.match(
    /\b(?:set|change|update)\s+priority\s+(?:of\s+|for\s+)?(.+?)\s+(?:to|as|=)\s+(low|medium|high|urgent)\b/i,
  ) ?? body.match(
    /\bmake\s+(?:my\s+|the\s+)?(?:task\s+)?(.+?)\s+(low|medium|high|urgent)(?:\s+priority)?\b/i,
  ) ?? body.match(
    /\b(?:prioriti[sz]e)\s+(?:my\s+|the\s+)?(?:task\s+)?(.+?)(?:\s+(?:as|to)\s+(low|medium|high|urgent))?\s*$/i,
  );
  if (prioMatch) {
    updates.priority = normalizePriority(prioMatch[2] ?? "high");
    return finalizeUpdate(stripTrailingPunctuation(prioMatch[1]!), updates, ctx);
  }
  // "change task X to high priority"
  const toPrio = body.match(
    /\b(?:change|set|update)\s+(?:my\s+|the\s+)?(?:task\s+)?(.+?)\s+to\s+(low|medium|high|urgent)(?:\s+priority)?\s*$/i,
  );
  if (toPrio) {
    updates.priority = normalizePriority(toPrio[2]!);
    return finalizeUpdate(stripTrailingPunctuation(toPrio[1]!), updates, ctx);
  }

  // --- course / project / category ---
  const courseMatch = body.match(
    /\b(?:categori[sz]e|reorgani[sz]e|reorganise|reorganize|set\s+course\s+(?:of\s+)?|set\s+project\s+(?:of\s+)?|move)\s+(?:my\s+|the\s+)?(?:task\s+)?(.+?)\s+(?:as|to|under|in|into)\s+(.+)$/i,
  );
  if (courseMatch) {
    updates.course = cleanQuery(courseMatch[2]!).slice(0, 120);
    return finalizeUpdate(stripTrailingPunctuation(courseMatch[1]!), updates, ctx);
  }

  // --- tags ---
  const tagMatch = body.match(
    /\b(?:tag|label)\s+(?:my\s+|the\s+)?(?:task\s+)?(.+?)\s+(?:with|as)\s+(.+)$/i,
  ) ?? body.match(/\badd\s+tag\s+(.+?)\s+to\s+(?:my\s+|the\s+)?(?:task\s+)?(.+)$/i);
  if (tagMatch) {
    if (/\badd\s+tag\b/i.test(body)) {
      updates.tags = [cleanQuery(tagMatch[1]!).replace(/^#/, "").slice(0, 24)];
      return finalizeUpdate(stripTrailingPunctuation(tagMatch[2]!), updates, ctx);
    }
    const list = tagMatch[2]!.split(/,|\band\b/i).map((t) => t.trim().replace(/^#/, "")).filter(Boolean);
    updates.tags = list.slice(0, 8);
    return finalizeUpdate(stripTrailingPunctuation(tagMatch[1]!), updates, ctx);
  }

  // --- description ---
  const descMatch = body.match(
    /\b(?:change|set|update|edit)\s+(?:the\s+)?(?:description|notes?)\s+(?:of\s+|for\s+)?(.+?)\s+(?:to|as)\s+(.+)$/i,
  );
  if (descMatch) {
    updates.description = stripTrailingPunctuation(descMatch[2]!).slice(0, 5000);
    return finalizeUpdate(stripTrailingPunctuation(descMatch[1]!), updates, ctx);
  }

  // --- clear due date ---
  if (/\b(?:clear|remove)\s+(?:the\s+)?(?:due\s+date|deadline|due)\b/i.test(body)) {
    updates.dueDate = null;
    const query = stripLeadingNoise(
      body.replace(/\b(?:clear|remove)\s+(?:the\s+)?(?:due\s+date|deadline|due)\b/i, " ")
        .replace(/\b(?:on|from|for)\s+/i, " "),
    );
    return finalizeUpdate(query, updates, ctx);
  }

  // --- status ---
  const status = extractStatus(body);
  if (status && /\bstatus\b/i.test(body)) {
    updates.status = status;
    const { query } = splitQueryAndModifiers(
      stripLeadingNoise(body.replace(/\bstatus\b.*$/i, " ")),
      /\b(?:to|as|=)\b/i,
    );
    return finalizeUpdate(query, updates, ctx);
  }

  // --- priority standalone in update verb ---
  const prio = extractPriority(body);
  if (prio) {
    updates.priority = prio;
    const withoutPrio = body
      .replace(PRIORITY_PATTERNS.map((p) => p.re).find((re) => re.test(body)) ?? /$^/, " ")
      .replace(/\bpriority\b\s*(?:to|is|=|:)?\s*(low|medium|high|urgent)\b/i, " ");
    const query = stripLeadingNoise(withoutPrio);
    return finalizeUpdate(query, updates, ctx);
  }

  // --- generic "update task X to Y" is a title change when nothing else fits ---
  const generic = body.match(
    /\b(?:update|edit|change|rename|modify)\s+(?:my\s+|the\s+)?(?:task\s+)?(.+?)\s+(?:to|as)\s+(.+)$/i,
  );
  if (generic) {
    updates.title = cleanQuery(generic[2]!).slice(0, 150);
    return finalizeUpdate(stripTrailingPunctuation(generic[1]!), updates, ctx);
  }

  return null;
};

const finalizeUpdate = (
  taskQueryRaw: string,
  updates: UpdateTaskParams,
  _ctx: DateContext,
): ParsedIntent | null => {
  if (Object.keys(updates).length === 0) return null;
  let query = taskQueryRaw;
  // Strip trailing conjunctions introduced by splitting.
  query = query.replace(/\b(?:and|then|with)\s*$/i, "").trim();
  query = stripTrailingPunctuation(query);
  query = stripLeadingNoise(query);
  // Remove a leading verb remnant.
  query = query.replace(/^(?:my|the|a|an)\s+/i, "").trim();
  query = cleanQuery(query);
  if (!query) return null;
  return { intent: "update_task", taskQuery: query, updates, raw: taskQueryRaw };
};

// ============================================================================
// CREATE PARAMS
// ============================================================================

const extractCreateParams = (text: string, ctx: DateContext): CreateTaskParams => {
  let title = text;
  for (const re of CREATE_TITLE_PREFIXES) title = title.replace(re, "");
  title = title.replace(/^(?:please\s+)+/i, "");

  const priority = extractPriority(title);
  const dueDate = extractDate(title, ctx, /\b(?:due|by|on|for)\s+/i) ?? extractDate(title, ctx);
  // A reminder phrase inside a create request sets reminderAt, not dueDate.
  const reminderAt = /\bremind me\b/i.test(title)
    ? extractDateTime(title, ctx)
    : null;

  // Remove modifier phrases from the title.
  if (priority) {
    title = title
      .replace(/\b(urgent|critical|asap|highest\s+priority)\b/i, " ")
      .replace(/\bhigh\s+priority\b|\bpriority\s+high\b|\bhigh-priority\b/i, " ")
      .replace(/\bmedium\s+priority\b|\bpriority\s+medium\b|\bnormal\s+priority\b/i, " ")
      .replace(/\blow\s+priority\b|\bpriority\s+low\b|\blow-priority\b/i, " ")
      .replace(/\bpriority\s*(?:to|is|=|:)?\s*(low|medium|high|urgent)\b/i, " ");
  }

  // Remove the due-date expression from the title.
  const dueMatch = title.match(DATE_TOKEN_RE);
  if (dueMatch) title = title.replace(dueMatch[0], " ");
  title = title
    .replace(/\b(?:due|by|on|for)\s+(?:today|tomorrow|tonight)\b/gi, " ")
    .replace(/\b(?:due|by|on)\s*$/i, " ")
    .replace(/\bdue\b/gi, " ");

  // Course extraction: "for the course X" / "for COMP 2101".
  let course: string | undefined;
  const courseMatch = title.match(
    /\bfor\s+(?:the\s+)?(?:course|class|project)\s+(.+)$/i,
  );
  if (courseMatch) {
    course = cleanQuery(courseMatch[1]!).slice(0, 120);
    title = title.slice(0, courseMatch.index).trim();
  }

  // Tags.
  const tags = extractTags(title);
  if (tags) title = title.replace(/(?:^|\s)#([^\s#]{1,24})/g, " ");

  title = normalizeSpace(stripTrailingPunctuation(title.replace(/[,:;-]\s*$/g, "")));
  title = title.replace(/\b(?:to|for|by|on|due|and|with|at)\s*$/i, "").trim();

  const trimmedTitle = title.slice(0, 150);
  const params: CreateTaskParams = {
    title: trimmedTitle
      ? trimmedTitle.charAt(0).toUpperCase() + trimmedTitle.slice(1)
      : trimmedTitle,
  };
  if (dueDate) params.dueDate = dueDate;
  if (priority) params.priority = priority;
  if (course) params.course = course;
  if (tags) params.tags = tags;
  if (reminderAt) params.reminderAt = reminderAt;
  return params;
};

// ============================================================================
// LIST FILTER EXTRACTION
// ============================================================================

const startOfLocalDayIso = (ctx: DateContext, dayOffset: number): string =>
  localDayUtc(ctx, dayOffset).toISOString();

const extractListFilters = (text: string, ctx: DateContext): ListTaskFilters => {
  const lower = text.toLowerCase();
  const filters: ListTaskFilters = {};

  // status
  if (/\bcompleted\b|\bdone\b|\bfinished\b/.test(lower) && !/\bnot\s+completed\b/.test(lower)) {
    filters.status = ["completed"];
  } else if (/\bpending\b|\bto-?do\b|\bnot\s+(?:completed|done)\b|\bopen\b|\bleft\b/.test(lower)) {
    filters.status = ["todo", "in_progress"];
  } else if (/\bin[\s_-]progress\b|\bworking\s+on\b/.test(lower)) {
    filters.status = ["in_progress"];
  }

  // priority
  const prio = extractPriority(lower);
  if (prio) filters.priority = [prio];

  // timeframe
  const base = referenceDay(ctx);
  const day = 86_400_000;
  if (/\boverdue\b|\bpast\s+due\b|\blate\b/.test(lower)) {
    filters.dueBefore = startOfLocalDayIso(ctx, 0);
    filters.timeframe = "overdue";
    if (!filters.status) filters.status = ["todo", "in_progress"];
  } else if (/\bdue\s+today\b|\btoday\b/.test(lower) && /\bdue\b|\btoday\b/.test(lower)) {
    filters.dueAfter = startOfLocalDayIso(ctx, 0);
    filters.dueBefore = startOfLocalDayIso(ctx, 1);
    filters.timeframe = "due today";
  } else if (/\bdue\s+tomorrow\b|\btomorrow\b/.test(lower)) {
    filters.dueAfter = startOfLocalDayIso(ctx, 1);
    filters.dueBefore = startOfLocalDayIso(ctx, 2);
    filters.timeframe = "due tomorrow";
  } else if (/\bthis\s+week\b/.test(lower)) {
    // Monday 00:00 local → next Monday 00:00 local
    const dayOfWeek = base.getUTCDay();
    const mondayOffset = -((dayOfWeek + 6) % 7);
    filters.dueAfter = new Date(base.getTime() + mondayOffset * day + (ctx.utcOffsetMinutes ?? 0) * -60_000).toISOString();
    filters.dueBefore = new Date(base.getTime() + (mondayOffset + 7) * day + (ctx.utcOffsetMinutes ?? 0) * -60_000).toISOString();
    filters.timeframe = "due this week";
  } else if (/\bnext\s+week\b/.test(lower)) {
    const dayOfWeek = base.getUTCDay();
    const mondayOffset = -((dayOfWeek + 6) % 7);
    filters.dueAfter = new Date(base.getTime() + (mondayOffset + 7) * day + (ctx.utcOffsetMinutes ?? 0) * -60_000).toISOString();
    filters.dueBefore = new Date(base.getTime() + (mondayOffset + 14) * day + (ctx.utcOffsetMinutes ?? 0) * -60_000).toISOString();
    filters.timeframe = "due next week";
  } else if (/\bthis\s+month\b/.test(lower)) {
    const start = new Date(Date.UTC(base.getUTCFullYear(), base.getUTCMonth(), 1));
    const end = new Date(Date.UTC(base.getUTCFullYear(), base.getUTCMonth() + 1, 1));
    filters.dueAfter = start.toISOString();
    filters.dueBefore = end.toISOString();
    filters.timeframe = "due this month";
  } else if (/\bdue\s+(?:by|before|on)\b/.test(lower)) {
    const d = extractDate(lower, ctx, /\bdue\s+(?:by|before|on)\b/i);
    if (d) {
      filters.dueBefore = new Date(`${d}T23:59:59.999Z`).toISOString();
      filters.timeframe = `due by ${d}`;
    }
  }

  // "due this week" without "due" keyword handled above via this week.

  // free-text search fragment: quoted phrase or trailing words after filters
  const quoted = text.match(/["'“”]([^"'“”]{1,80})["'“”]/);
  if (quoted) filters.search = quoted[1];

  return filters;
};

// ============================================================================
// REMINDER PARAMS
// ============================================================================

const extractReminder = (text: string, ctx: DateContext): ReminderParams => {
  const reminder: ReminderParams = {};
  const recurrenceMatch = text.match(REMINDER_RECURRENCE_RE);
  if (recurrenceMatch) {
    const word = recurrenceMatch[1]!.toLowerCase();
    reminder.recurrence =
      word.startsWith("daily") || word === "every day"
        ? "daily"
        : word.startsWith("weekly") || word === "every week"
          ? "weekly"
          : "monthly";
  }
  if ((REMINDER_RECURRENCES as readonly string[]).includes("none")) {
    // noop: keep type linkage
  }

  // dueAt
  const dueAt = extractDateTime(text, ctx);
  if (dueAt) reminder.dueAt = dueAt;

  // task reference: "remind me about X", "reminder for my X task", "remind me to X"
  const about = text.match(/\bremind\s+me\s+(?:to\s+|about\s+|regarding\s+)?(.+?)(?:\s+(?:at|on|before|in|every|daily|weekly|monthly)\b.*)?$/i)
    ?? text.match(/\breminder\s+(?:for|on|about)\s+(?:my\s+|the\s+)?(?:task\s+)?(.+?)(?:\s+(?:at|on|before|in|every|daily|weekly|monthly)\b.*)?$/i)
    ?? text.match(/\bset\s+(?:a\s+)?reminder\s+(?:for|on|about)\s+(?:my\s+|the\s+)?(?:task\s+)?(.+?)(?:\s+(?:at|on|before|in|every|daily|weekly|monthly)\b.*)?$/i);
  if (about) {
    let fragment = about[1]!.trim();
    // strip trailing time expressions
    fragment = fragment.replace(/\b(?:at|on|in|before|every)\b.*$/i, "").trim();
    fragment = fragment.replace(/\b(?:today|tomorrow|tonight)\b/gi, "").trim();
    if (fragment) {
      // If it reads like an existing task reference ("my X task"), treat as task;
      // otherwise it is the reminder message.
      const looksLikeTask =
        /\bmy\s+.+\s+task\b/i.test(about[1]!) ||
        /\btask\s+/i.test(about[1]!);
      if (looksLikeTask) {
        reminder.taskQuery = cleanQuery(
          fragment.replace(/\bmy\s+/i, "").replace(/\btask\b/i, ""),
        );
      } else {
        reminder.message = stripTrailingPunctuation(fragment).slice(0, 500);
      }
    }
  }

  return reminder;
};
