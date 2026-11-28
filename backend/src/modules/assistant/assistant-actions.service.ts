/**
 * File Name: assistant-actions.service.ts
 * Description: Genuine AI action-execution pipeline for the assistant.
 *
 *   natural language
 *     -> deterministic intent routing (assistant-intent.ts)
 *     -> parameter extraction + ownership-scoped task/reminder resolution
 *     -> validation through the SAME Zod schemas as the public REST API
 *     -> execution through the existing taskService / reminderService
 *     -> persistence in MongoDB
 *     -> structured result the frontend uses for UI updates
 *     -> truthful confirmation ONLY after the write has succeeded
 *
 * Nothing here lets the model emit arbitrary queries, code or shell; only a
 * fixed allow-list of operations with schema-validated scalar parameters runs,
 * always scoped to the authenticated user. Destructive actions are
 * confirmation-gated through a persisted, single-use pending action.
 */

import { AppError } from "../../shared/utils/AppError.js";
import { literal, requireString } from "../../shared/utils/queryGuard.js";
import logger from "../../config/logger.js";

import { createChatReply, type ConversationTurn } from "../ai/ai.service.js";
import { taskService } from "../tasks/task.service.js";
import {
  createTaskSchema,
  updateTaskSchema,
} from "../tasks/task.validation.js";
import type {
  CreateTaskInput,
  TaskPriority,
  TaskRecord,
  TaskStatus,
  UpdateTaskInput,
} from "../tasks/task.types.js";
import { reminderService } from "../reminders/reminder.service.js";
import { createReminderSchema } from "../reminders/reminder.validation.js";
import type { ReminderRecurrence } from "../reminders/reminder.model.js";

import {
  AssistantPendingAction,
  type AssistantPendingActionRecord,
} from "./assistant-action.model.js";
import {
  normalizeTitle,
  parseAssistantIntent,
  type CreateTaskParams,
  type ListTaskFilters,
  type UpdateTaskParams,
} from "./assistant-intent.js";

// ============================================================================
// RESULT CONTRACT
// ============================================================================

export type AssistantActStatus =
  | "executed"
  | "confirmation_required"
  | "clarification_required"
  | "not_found"
  | "failed"
  | "conversation";

export interface AssistantConfirmation {
  pendingActionId: string;
  type: string;
  summary: string;
  /** Task snapshot shown for review. */
  task: TaskSnapshot | null;
  expiresAt: Date;
}

export interface TaskSnapshot {
  id: string;
  title: string;
  status: TaskStatus;
  priority: TaskPriority;
  dueDate: Date | null;
  reminderAt: Date | null;
  course: string;
  description: string | null;
  tags: string[];
}

export interface AssistantActionResult {
  /** Truthful, human-readable outcome. */
  reply: string;
  /** Distinguishes an executed application action from ordinary conversation. */
  kind: "action" | "conversation";
  intent: string;
  status: AssistantActStatus;
  /** True ONLY when a backend operation persisted successfully. */
  executed: boolean;
  /** True when the database was actually modified. */
  changed: boolean;
  task: TaskSnapshot | null;
  tasks: TaskSnapshot[];
  reminder: unknown | null;
  confirmation: AssistantConfirmation | null;
  clarification: string | null;
  /** Frontend should reload tasks/reminders. */
  refresh: { tasks: boolean; reminders: boolean };
  /** Echo of applied changes for display. */
  appliedChanges: Record<string, unknown> | null;
  /** For conversational replies, which provider answered. */
  provider?: string;
  model?: string;
}

export interface AssistantActInput {
  message?: string;
  context?: ConversationTurn[];
  currentDate?: string;
  utcOffsetMinutes?: number;
  /** Client-generated idempotency key (UUID) to prevent duplicate creation. */
  clientRequestId?: string;
  /** Pre-parsed action (e.g. a user-confirmed proposal from the UI). */
  action?: { type: string; params?: Record<string, unknown> };
}

const CONVERSATION_NOTE =
  "Routing note: no application action was executed for this message. " +
  "Never claim any task was created, updated, completed, or deleted, never " +
  "claim to have checked or changed the user's data, and do not fabricate " +
  "tasks. If the user asked for an app action, tell them you need clearer " +
  "details rather than saying it was done.";

// ============================================================================
// SNAPSHOTS
// ============================================================================

const snapshot = (task: TaskRecord): TaskSnapshot => ({
  id: String(task._id),
  title: task.title,
  status: task.status,
  priority: task.priority,
  dueDate: task.dueDate ?? null,
  reminderAt: task.reminderAt ?? null,
  course: task.course ?? "",
  description: task.description ?? null,
  tags: task.tags ?? [],
});

// ============================================================================
// OWNERSHIP-SCOPED TASK RESOLUTION
// ============================================================================

type TaskMatch =
  | { kind: "one"; task: TaskRecord }
  | { kind: "none" }
  | { kind: "ambiguous"; candidates: TaskRecord[] };

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/** Finds tasks owned by `userId` matching a natural-language title fragment. */
async function matchTask(userId: string, queryRaw: string): Promise<TaskMatch> {
  const query = queryRaw.trim();
  if (!query) return { kind: "none" };

  // Direct id reference.
  if (UUID_RE.test(query)) {
    const task = await taskService.getTask(userId, query).catch(() => null);
    return task ? { kind: "one", task } : { kind: "none" };
  }

  const { items } = await taskService.listTasks(userId, {
    limit: 1000,
    sortBy: "updatedAt",
    sortOrder: "desc",
  });

  const needle = normalizeTitle(query);
  if (!needle) return { kind: "none" };

  // Exact title match wins.
  const exact = items.filter((t) => normalizeTitle(t.title) === needle);
  if (exact.length === 1) return { kind: "one", task: exact[0]! };
  if (exact.length > 1) return { kind: "ambiguous", candidates: exact };

  // Substring match (task title contains query, or query contains title).
  const partial = items.filter((t) => {
    const title = normalizeTitle(t.title);
    if (!title) return false;
    return title.includes(needle) || needle.includes(title);
  });
  if (partial.length === 1) return { kind: "one", task: partial[0]! };
  if (partial.length > 1) return { kind: "ambiguous", candidates: partial };

  // Token-overlap fallback for reordered words.
  const tokens = needle.split(" ").filter((w) => w.length > 2);
  const overlap = items.filter((t) => {
    const title = normalizeTitle(t.title);
    return tokens.length > 0 && tokens.every((w) => title.includes(w));
  });
  if (overlap.length === 1) return { kind: "one", task: overlap[0]! };
  if (overlap.length > 1) return { kind: "ambiguous", candidates: overlap };

  return { kind: "none" };
}

// ============================================================================
// RESULT HELPERS
// ============================================================================

const base = {
  kind: "action" as const,
  executed: false,
  changed: false,
  task: null,
  tasks: [] as TaskSnapshot[],
  reminder: null,
  confirmation: null,
  clarification: null,
  refresh: { tasks: false, reminders: false },
  appliedChanges: null,
};

const clarification = (
  intent: string,
  message: string,
): AssistantActionResult => ({
  ...base,
  intent,
  status: "clarification_required",
  reply: message,
  clarification: message,
});

const notFound = (intent: string, message: string): AssistantActionResult => ({
  ...base,
  intent,
  status: "not_found",
  reply: message,
});

const failed = (intent: string, message: string): AssistantActionResult => ({
  ...base,
  intent,
  status: "failed",
  reply: message,
});

const ambiguousResult = (
  intent: string,
  candidates: TaskRecord[],
  verb: string,
): AssistantActionResult => {
  const list = candidates
    .slice(0, 5)
    .map((t) => `"${t.title}"`)
    .join(", ");
  const message =
    `I found several matching tasks: ${list}. ` +
    `Please tell me exactly which one to ${verb}; nothing has been changed.`;
  return {
    ...base,
    intent,
    status: "clarification_required",
    reply: message,
    clarification: message,
  };
};

const noMatch = (
  intent: string,
  query: string,
  verb: string,
): AssistantActionResult =>
  notFound(
    intent,
    `I couldn't find a task matching "${query}". ` +
      `Nothing has been changed. Check the title, or tell me the exact task name to ${verb}.`,
  );

// ============================================================================
// MAIN ENTRY
// ============================================================================

export const assistantActionsService = {
  /**
   * Runs the full pipeline for one natural-language message.
   * `userId` MUST come from authenticated request context.
   */
  async act(
    userId: string,
    input: AssistantActInput,
  ): Promise<AssistantActionResult> {
    if (!userId)
      throw new AppError(401, "UNAUTHENTICATED", "Authentication is required.");

    // Structured pre-parsed action from the UI (still validated + ownership-checked).
    if (input.action?.type) {
      return this.executeStructured(userId, input);
    }

    const message = (input.message ?? "").trim();
    if (!message) {
      return clarification(
        "conversation",
        "Please tell me what you'd like me to do.",
      );
    }

    const ctx = {
      currentDate: input.currentDate,
      utcOffsetMinutes: input.utcOffsetMinutes,
    };
    const parsed = parseAssistantIntent(message, ctx);

    try {
      switch (parsed.intent) {
        case "create_task":
          return await this.executeCreate(
            userId,
            parsed.create ?? { title: "" },
            input,
            message,
          );
        case "update_task":
          return await this.executeUpdate(
            userId,
            parsed.taskQuery ?? "",
            parsed.updates ?? {},
            message,
          );
        case "complete_task":
          return await this.executeComplete(
            userId,
            parsed.taskQuery ?? "",
            true,
            message,
          );
        case "reopen_task":
          return await this.executeComplete(
            userId,
            parsed.taskQuery ?? "",
            false,
            message,
          );
        case "delete_task":
          return await this.proposeDelete(
            userId,
            parsed.taskQuery ?? "",
            message,
          );
        case "list_tasks":
          return await this.executeList(userId, parsed.filters ?? {}, message);
        case "set_reminder":
          return await this.executeSetReminder(
            userId,
            parsed.reminder ?? {},
            ctx,
            message,
          );
        case "cancel_reminder":
          return await this.executeCancelReminder(
            userId,
            parsed.taskQuery ?? "",
            message,
          );
        case "conversation":
        default:
          return await this.executeConversation(
            userId,
            message,
            input.context ?? [],
          );
      }
    } catch (error) {
      logger.error("assistant.act.failed", {
        userId,
        intent: parsed.intent,
        message: error instanceof Error ? error.message : String(error),
      });
      return failed(
        parsed.intent,
        `I couldn't complete that action${friendlyReason(error)}. ` +
          "Nothing has been confirmed as changed; please check your task list and try again.",
      );
    }
  },

  /** Execute a structured action proposal after re-validation. */
  async executeStructured(
    userId: string,
    input: AssistantActInput,
  ): Promise<AssistantActionResult> {
    const type = input.action!.type;
    const params = input.action!.params ?? {};
    const message = input.message ?? "";
    try {
      switch (type) {
        case "create_task":
          return await this.executeCreate(
            userId,
            params as unknown as CreateTaskParams,
            input,
            message,
          );
        case "update_task": {
          const taskId = requireString(
            (params as { taskId?: unknown }).taskId,
            "task ID",
          );
          return await this.executeUpdateOnId(
            userId,
            taskId,
            (params as { updates?: UpdateTaskParams }).updates ?? {},
            message,
          );
        }
        case "complete_task": {
          const taskId = requireString(
            (params as { taskId?: unknown }).taskId,
            "task ID",
          );
          return await this.executeCompleteOnId(userId, taskId, true, message);
        }
        case "set_reminder": {
          return await this.executeSetReminder(
            userId,
            params as never,
            {
              currentDate: input.currentDate,
              utcOffsetMinutes: input.utcOffsetMinutes,
            },
            message,
          );
        }
        default:
          return failed(
            type,
            `Unsupported action type "${type}". Nothing has been changed.`,
          );
      }
    } catch (error) {
      logger.error("assistant.structured.failed", {
        userId,
        type,
        message: error instanceof Error ? error.message : String(error),
      });
      return failed(
        type,
        `I couldn't complete that action${friendlyReason(error)}. Nothing has been confirmed as changed.`,
      );
    }
  },

  // --------------------------------------------------------------------------
  // CREATE
  // --------------------------------------------------------------------------

  async executeCreate(
    userId: string,
    params: CreateTaskParams,
    input: AssistantActInput,
    _message: string,
  ): Promise<AssistantActionResult> {
    const title = (params.title ?? "").trim();
    if (!title) {
      return clarification(
        "create_task",
        "What should the task be called? Nothing has been created. " +
          "You can include a deadline, priority or project too.",
      );
    }

    // Validate through the exact schema used by POST /api/tasks.
    const candidate: Record<string, unknown> = { title };
    if (params.description !== undefined && params.description !== null) {
      candidate.description = params.description;
    }
    if (params.course) candidate.course = params.course;
    if (params.tags && params.tags.length > 0) candidate.tags = params.tags;
    if (params.priority) candidate.priority = params.priority;
    if (params.dueDate) candidate.dueDate = params.dueDate;
    if (params.reminderAt) candidate.reminderAt = params.reminderAt;
    // Idempotency key: a repeated submission with the same key cannot create
    // a duplicate task (the task id is unique and createTask is retry-safe).
    if (input.clientRequestId) candidate.id = input.clientRequestId;

    let parsed;
    try {
      parsed = createTaskSchema.shape.body.parse(candidate);
    } catch (error) {
      return clarification(
        "create_task",
        `I couldn't create the task: ${zodMessage(error)}. Nothing has been created.`,
      );
    }

    const createInput: CreateTaskInput = {
      title: parsed.title,
      description: parsed.description ?? null,
      course: parsed.course ?? "",
      tags: parsed.tags,
      priority: parsed.priority,
      dueDate: parsed.dueDate ?? null,
      reminderAt: parsed.reminderAt ?? null,
      id: parsed.id,
    };

    // Persist through the existing task service (ownership + group rules).
    const created = await taskService.createTask(userId, createInput);

    // Confirm ONLY after the write returned a persisted record.
    if (!created || !created._id) {
      return failed(
        "create_task",
        "The task could not be saved. Nothing was created.",
      );
    }

    const snap = snapshot(created);
    return {
      ...base,
      kind: "action",
      intent: "create_task",
      status: "executed",
      executed: true,
      changed: true,
      task: snap,
      reply: `Created task "${snap.title}"${describeDue(snap)}.`,
      appliedChanges: { created: snap },
      refresh: { tasks: true, reminders: Boolean(snap.reminderAt) },
    };
  },

  // --------------------------------------------------------------------------
  // UPDATE
  // --------------------------------------------------------------------------

  async executeUpdate(
    userId: string,
    taskQuery: string,
    updatesRaw: UpdateTaskParams,
    message: string,
  ): Promise<AssistantActionResult> {
    if (!taskQuery.trim()) {
      return clarification(
        "update_task",
        "Which task should I update? Nothing has been changed.",
      );
    }
    const match = await matchTask(userId, taskQuery);
    if (match.kind === "none")
      return noMatch("update_task", taskQuery, "update");
    if (match.kind === "ambiguous")
      return ambiguousResult("update_task", match.candidates, "update");
    return this.applyUpdate(userId, match.task, updatesRaw, message);
  },

  async executeUpdateOnId(
    userId: string,
    taskId: string,
    updatesRaw: UpdateTaskParams,
    message: string,
  ): Promise<AssistantActionResult> {
    // Ownership-scoped lookup; a task owned by another user reads as not found.
    const task = await taskService.getTask(userId, taskId).catch(() => null);
    if (!task) return noMatch("update_task", taskId, "update");
    return this.applyUpdate(userId, task, updatesRaw, message);
  },

  async applyUpdate(
    userId: string,
    task: TaskRecord,
    updatesRaw: UpdateTaskParams,
    _message: string,
  ): Promise<AssistantActionResult> {
    // Build a candidate containing ONLY allow-listed, known fields.
    const candidate: Record<string, unknown> = {};
    if (updatesRaw.title !== undefined) candidate.title = updatesRaw.title;
    if (updatesRaw.description !== undefined)
      candidate.description = updatesRaw.description;
    if (updatesRaw.dueDate !== undefined)
      candidate.dueDate = updatesRaw.dueDate;
    if (updatesRaw.priority !== undefined)
      candidate.priority = updatesRaw.priority;
    if (updatesRaw.status !== undefined) candidate.status = updatesRaw.status;
    if (updatesRaw.course !== undefined) candidate.course = updatesRaw.course;
    if (updatesRaw.tags !== undefined) candidate.tags = updatesRaw.tags;
    if (updatesRaw.reminderAt !== undefined)
      candidate.reminderAt = updatesRaw.reminderAt;

    if (Object.keys(candidate).length === 0) {
      return clarification(
        "update_task",
        `I couldn't tell what to change on "${task.title}". ` +
          "Say e.g. a new title, deadline, priority, status or project. Nothing has been changed.",
      );
    }

    let parsed;
    try {
      parsed = updateTaskSchema.shape.body.parse(candidate);
    } catch (error) {
      return clarification(
        "update_task",
        `I couldn't apply that change: ${zodMessage(error)}. Nothing has been changed.`,
      );
    }

    const update: UpdateTaskInput = { ...parsed };
    const before = snapshot(task);
    const updated = await taskService.updateTask(
      userId,
      String(task._id),
      update,
    );
    const after = snapshot(updated);

    const changes = diffSnapshots(before, after);
    const changedFields = Object.keys(changes);
    if (changedFields.length === 0) {
      // The service returned successfully but nothing actually differs.
      return {
        ...base,
        kind: "action",
        intent: "update_task",
        status: "executed",
        executed: true,
        changed: false,
        task: after,
        reply: `"${after.title}" already had those values; nothing needed to change.`,
      };
    }

    return {
      ...base,
      kind: "action",
      intent: "update_task",
      status: "executed",
      executed: true,
      changed: true,
      task: after,
      reply: `Updated "${after.title}": ${describeChanges(changes)}.`,
      appliedChanges: changes,
      refresh: { tasks: true, reminders: "reminderAt" in changes },
    };
  },

  // --------------------------------------------------------------------------
  // COMPLETE / REOPEN
  // --------------------------------------------------------------------------

  async executeComplete(
    userId: string,
    taskQuery: string,
    completed: boolean,
    message: string,
  ): Promise<AssistantActionResult> {
    if (!taskQuery.trim()) {
      return clarification(
        completed ? "complete_task" : "reopen_task",
        `Which task should I mark as ${completed ? "completed" : "not completed"}? Nothing has been changed.`,
      );
    }
    const match = await matchTask(userId, taskQuery);
    const intent = completed ? "complete_task" : "reopen_task";
    if (match.kind === "none")
      return noMatch(intent, taskQuery, completed ? "complete" : "reopen");
    if (match.kind === "ambiguous")
      return ambiguousResult(
        intent,
        match.candidates,
        completed ? "complete" : "reopen",
      );
    return this.executeCompleteOnId(
      userId,
      String(match.task._id),
      completed,
      message,
    );
  },

  async executeCompleteOnId(
    userId: string,
    taskId: string,
    completed: boolean,
    _message: string,
  ): Promise<AssistantActionResult> {
    const intent = completed ? "complete_task" : "reopen_task";
    const existing = await taskService
      .getTask(userId, taskId)
      .catch(() => null);
    if (!existing)
      return noMatch(intent, taskId, completed ? "complete" : "reopen");

    const targetStatus: TaskStatus = completed ? "completed" : "todo";
    if (existing.status === targetStatus) {
      return {
        ...base,
        kind: "action",
        intent,
        status: "executed",
        executed: true,
        changed: false,
        task: snapshot(existing),
        reply: `"${existing.title}" is already ${completed ? "completed" : "not completed"}.`,
      };
    }

    const updated = await taskService.updateTask(userId, taskId, {
      status: targetStatus,
    });
    const snap = snapshot(updated);
    return {
      ...base,
      kind: "action",
      intent,
      status: "executed",
      executed: true,
      changed: true,
      task: snap,
      reply: completed
        ? `Marked "${snap.title}" as completed.`
        : `Reopened "${snap.title}"; it is no longer completed.`,
      appliedChanges: {
        status: { before: existing.status, after: snap.status },
      },
      refresh: { tasks: true, reminders: false },
    };
  },

  // --------------------------------------------------------------------------
  // DELETE (confirmation-gated, single-use)
  // --------------------------------------------------------------------------

  async proposeDelete(
    userId: string,
    taskQuery: string,
    _message: string,
  ): Promise<AssistantActionResult> {
    if (!taskQuery.trim()) {
      return clarification(
        "delete_task",
        "Which task should I delete? Nothing has been changed.",
      );
    }
    const match = await matchTask(userId, taskQuery);
    if (match.kind === "none")
      return noMatch("delete_task", taskQuery, "delete");
    if (match.kind === "ambiguous")
      return ambiguousResult("delete_task", match.candidates, "delete");

    const task = match.task;
    const summary = `Delete task "${task.title}"`;

    // Persist a pending action; NOTHING is deleted yet.
    const pending = await AssistantPendingAction.create({
      userId,
      type: "delete_task",
      payload: { taskId: String(task._id), taskTitle: task.title },
      summary,
      status: "pending",
      expiresAt: new Date(Date.now() + 10 * 60 * 1000),
    });

    const confirmation: AssistantConfirmation = {
      pendingActionId: String(pending._id),
      type: "delete_task",
      summary,
      task: snapshot(task),
      expiresAt: pending.expiresAt,
    };

    return {
      ...base,
      kind: "action",
      intent: "delete_task",
      status: "confirmation_required",
      executed: false,
      changed: false,
      task: snapshot(task),
      reply:
        `I found "${task.title}". Deleting it cannot be undone from this ` +
        `conversation. Confirm to delete it, or cancel. Nothing has been changed yet.`,
      confirmation,
    };
  },

  /** Confirm a pending action: atomically claim it, then execute. */
  async confirmAction(
    userId: string,
    pendingActionId: string,
  ): Promise<AssistantActionResult> {
    if (!userId)
      throw new AppError(401, "UNAUTHENTICATED", "Authentication is required.");
    const id = requireString(pendingActionId, "pending action ID");

    // Single-use + owner-scoped + not expired: atomic compare-and-set.
    const claimed = await AssistantPendingAction.findOneAndUpdate(
      {
        _id: literal(id),
        userId: literal(userId),
        status: "pending",
        expiresAt: { $gt: new Date() },
      },
      { $set: { status: "confirmed" } },
      { new: true },
    );

    if (!claimed) {
      // Distinguish replay/expiry from never-existing, without leaking others' data.
      const existing = await AssistantPendingAction.findOne({
        _id: literal(id),
        userId: literal(userId),
      }).lean<AssistantPendingActionRecord>();
      if (existing && existing.status !== "pending") {
        return failed(
          existing.type,
          `This action was already ${existing.status}. Nothing new was changed.`,
        );
      }
      return notFound(
        "delete_task",
        "That confirmation is no longer valid or has expired. Nothing has been changed.",
      );
    }

    try {
      return await this.executePending(userId, claimed);
    } catch (error) {
      logger.error("assistant.confirm.failed", {
        userId,
        pendingActionId: id,
        message: error instanceof Error ? error.message : String(error),
      });
      // The pending action is consumed; report honestly that nothing changed.
      return failed(
        claimed.type,
        `I couldn't complete the confirmed action${friendlyReason(error)}. Please check your task list.`,
      );
    }
  },

  async executePending(
    userId: string,
    pending: AssistantPendingActionRecord,
  ): Promise<AssistantActionResult> {
    switch (pending.type) {
      case "delete_task": {
        const taskId = requireString(
          (pending.payload as { taskId?: unknown }).taskId,
          "task ID",
        );
        // Ownership re-checked by taskService; a task removed meanwhile reads as not found.
        const existing = await taskService
          .getTask(userId, taskId)
          .catch(() => null);
        if (!existing) {
          return notFound(
            "delete_task",
            "That task no longer exists; nothing was deleted.",
          );
        }
        await taskService.deleteTask(userId, taskId);
        return {
          ...base,
          kind: "action",
          intent: "delete_task",
          status: "executed",
          executed: true,
          changed: true,
          task: snapshot(existing),
          reply: `Deleted task "${existing.title}".`,
          appliedChanges: { deleted: snapshot(existing) },
          refresh: { tasks: true, reminders: Boolean(existing.reminderAt) },
        };
      }
      default:
        return failed(
          pending.type,
          "Unsupported pending action. Nothing has been changed.",
        );
    }
  },

  /** Cancel a pending action; nothing executes. */
  async cancelAction(
    userId: string,
    pendingActionId: string,
  ): Promise<AssistantActionResult> {
    if (!userId)
      throw new AppError(401, "UNAUTHENTICATED", "Authentication is required.");
    const id = requireString(pendingActionId, "pending action ID");
    const cancelled = await AssistantPendingAction.findOneAndUpdate(
      { _id: literal(id), userId: literal(userId), status: "pending" },
      { $set: { status: "cancelled" } },
      { new: true },
    );
    if (!cancelled) {
      return notFound(
        "delete_task",
        "No pending action to cancel. Nothing has been changed.",
      );
    }
    return {
      ...base,
      kind: "action",
      intent: cancelled.type,
      status: "executed",
      executed: false,
      changed: false,
      reply: "Cancelled. Nothing was changed.",
    };
  },

  // --------------------------------------------------------------------------
  // LIST / RETRIEVE
  // --------------------------------------------------------------------------

  async executeList(
    userId: string,
    filters: ListTaskFilters,
    _message: string,
  ): Promise<AssistantActionResult> {
    const { items } = await taskService.listTasks(userId, {
      status: filters.status,
      priority: filters.priority,
      dueBefore: filters.dueBefore ? new Date(filters.dueBefore) : undefined,
      dueAfter: filters.dueAfter ? new Date(filters.dueAfter) : undefined,
      search: filters.search?.trim() || undefined,
      limit: 100,
      sortBy: "dueDate",
      sortOrder: "asc",
    });

    const tasks = items.map(snapshot);
    const label = filters.timeframe ? ` (${filters.timeframe})` : "";
    const filterBits: string[] = [];
    if (filters.status?.length) filterBits.push(filters.status.join(", "));
    if (filters.priority?.length)
      filterBits.push(`${filters.priority.join(", ")} priority`);

    let reply: string;
    if (tasks.length === 0) {
      reply = `You have no tasks${label}${filterBits.length ? ` matching ${filterBits.join(", ")}` : ""}.`;
    } else {
      const lines = tasks
        .slice(0, 10)
        .map((t) => `- ${t.title}${describeDue(t)} [${t.status}]`);
      reply =
        `You have ${tasks.length} task${tasks.length === 1 ? "" : "s"}${label}` +
        `${filterBits.length ? ` matching ${filterBits.join(", ")}` : ""}:\n${lines.join("\n")}` +
        (tasks.length > 10 ? `\n...and ${tasks.length - 10} more.` : "");
    }

    return {
      ...base,
      kind: "action",
      intent: "list_tasks",
      status: "executed",
      executed: true,
      changed: false,
      tasks,
      reply,
      refresh: { tasks: false, reminders: false },
    };
  },

  // --------------------------------------------------------------------------
  // REMINDERS
  // --------------------------------------------------------------------------

  async executeSetReminder(
    userId: string,
    reminder: {
      taskQuery?: string;
      message?: string;
      dueAt?: string;
      recurrence?: ReminderRecurrence;
    },
    _ctx: { currentDate?: string; utcOffsetMinutes?: number },
    _message: string,
  ): Promise<AssistantActionResult> {
    const dueAt = reminder.dueAt ? new Date(reminder.dueAt) : null;
    if (!dueAt || Number.isNaN(dueAt.getTime())) {
      return clarification(
        "set_reminder",
        'When should I remind you? Give a date/time, e.g. "tomorrow at 9am". Nothing has been changed.',
      );
    }

    // Try to attach to an existing owned task.
    let task: TaskRecord | null = null;
    if (reminder.taskQuery?.trim()) {
      const match = await matchTask(userId, reminder.taskQuery);
      if (match.kind === "ambiguous")
        return ambiguousResult(
          "set_reminder",
          match.candidates,
          "set a reminder on",
        );
      if (match.kind === "one") task = match.task;
    }

    // Standalone recurring reminder OR no matching task -> reminderService.
    if (!task || reminder.recurrence) {
      const message =
        reminder.message?.trim() ||
        (task
          ? `Reminder: ${task.title}`
          : reminder.taskQuery?.trim() || "Reminder");
      // Validate with the same schema as POST /api/reminders.
      const parsed = createReminderSchema.shape.body.parse({
        message: message.slice(0, 500),
        dueAt: dueAt.toISOString(),
        taskId: task ? String(task._id) : null,
        recurrence: reminder.recurrence ?? "none",
      });
      // If linked to a task, verify ownership again through taskService.
      if (parsed.taskId) await taskService.getTask(userId, parsed.taskId);
      const created = await reminderService.create(userId, parsed);
      return {
        ...base,
        kind: "action",
        intent: "set_reminder",
        status: "executed",
        executed: true,
        changed: true,
        task: task ? snapshot(task) : null,
        reminder: created,
        reply:
          `Reminder set for ${formatWhen(dueAt)}: "${created.message}"` +
          (created.recurrence !== "none"
            ? ` (repeats ${created.recurrence})`
            : "") +
          ".",
        appliedChanges: { reminderAt: dueAt.toISOString() },
        refresh: { tasks: Boolean(task), reminders: true },
      };
    }

    // Attach to the task's reminderAt through taskService.
    const updated = await taskService.updateTask(userId, String(task!._id), {
      reminderAt: dueAt,
    });
    const snap = snapshot(updated);
    return {
      ...base,
      kind: "action",
      intent: "set_reminder",
      status: "executed",
      executed: true,
      changed: true,
      task: snap,
      reply: `Reminder set on "${snap.title}" for ${formatWhen(dueAt)}.`,
      appliedChanges: { reminderAt: dueAt.toISOString() },
      refresh: { tasks: true, reminders: true },
    };
  },

  async executeCancelReminder(
    userId: string,
    taskQuery: string,
    _message: string,
  ): Promise<AssistantActionResult> {
    if (!taskQuery.trim()) {
      return clarification(
        "cancel_reminder",
        "Which task's reminder should I cancel? Nothing has been changed.",
      );
    }
    const match = await matchTask(userId, taskQuery);

    if (match.kind === "one") {
      const updated = await taskService.updateTask(
        userId,
        String(match.task._id),
        { reminderAt: null },
      );
      const snap = snapshot(updated);
      return {
        ...base,
        kind: "action",
        intent: "cancel_reminder",
        status: "executed",
        executed: true,
        changed: Boolean(match.task.reminderAt),
        task: snap,
        reply: `Cleared the reminder on "${snap.title}".`,
        appliedChanges: { reminderAt: null },
        refresh: { tasks: true, reminders: true },
      };
    }
    if (match.kind === "ambiguous")
      return ambiguousResult(
        "cancel_reminder",
        match.candidates,
        "clear a reminder on",
      );

    // Fall back to standalone reminders matching the reference.
    const needle = normalizeTitle(taskQuery);
    const reminders = await reminderService.findAll(userId);
    const reminderMatch = reminders.filter(
      (r) =>
        normalizeTitle(r.message).includes(needle) ||
        needle.includes(normalizeTitle(r.message)),
    );
    if (reminderMatch.length === 1) {
      const updatedReminder = await reminderService.update(
        String(reminderMatch[0]!._id),
        userId,
        { enabled: false },
      );
      return {
        ...base,
        kind: "action",
        intent: "cancel_reminder",
        status: "executed",
        executed: true,
        changed: true,
        reminder: updatedReminder,
        reply: `Cancelled the reminder "${reminderMatch[0]!.message}".`,
        refresh: { tasks: false, reminders: true },
      };
    }

    return noMatch("cancel_reminder", taskQuery, "clear a reminder on");
  },

  // --------------------------------------------------------------------------
  // CONVERSATION FALLBACK (no action recognized; never claims execution)
  // --------------------------------------------------------------------------

  async executeConversation(
    _userId: string,
    message: string,
    context: ConversationTurn[],
  ): Promise<AssistantActionResult> {
    const chat = await createChatReply(message, context, CONVERSATION_NOTE);
    return {
      ...base,
      kind: "conversation",
      intent: "conversation",
      status: "conversation",
      executed: false,
      changed: false,
      reply: chat.reply,
      provider: chat.provider,
      model: chat.model,
    };
  },
};

// ============================================================================
// FORMATTING + ERROR HELPERS
// ============================================================================

const formatWhen = (d: Date): string =>
  d.toISOString().replace("T", " ").slice(0, 16) + " UTC";

const describeDue = (t: TaskSnapshot): string => {
  const bits: string[] = [];
  if (t.dueDate)
    bits.push(`due ${formatWhen(new Date(t.dueDate)).slice(0, 10)}`);
  if (t.priority) bits.push(`${t.priority} priority`);
  return bits.length ? ` (${bits.join(", ")})` : "";
};

const describeChanges = (
  changes: Record<string, { before: unknown; after: unknown }>,
): string =>
  Object.entries(changes)
    .map(
      ([field, { before, after }]) =>
        `${field} ${formatValue(before)} -> ${formatValue(after)}`,
    )
    .join(", ");

const formatValue = (v: unknown): string => {
  if (v === null || v === undefined) return "none";
  if (v instanceof Date) return v.toISOString().slice(0, 10);
  if (Array.isArray(v)) return v.join(", ") || "none";
  return String(v);
};

const diffSnapshots = (
  before: TaskSnapshot,
  after: TaskSnapshot,
): Record<string, { before: unknown; after: unknown }> => {
  const changes: Record<string, { before: unknown; after: unknown }> = {};
  const fields: Array<keyof TaskSnapshot> = [
    "title",
    "status",
    "priority",
    "dueDate",
    "reminderAt",
    "course",
    "description",
    "tags",
  ];
  for (const field of fields) {
    const a = normalizeForCompare(before[field]);
    const b = normalizeForCompare(after[field]);
    if (a !== b)
      changes[field] = { before: before[field], after: after[field] };
  }
  return changes;
};

const normalizeForCompare = (v: unknown): string => {
  if (v === null || v === undefined) return "";
  if (v instanceof Date) return v.toISOString();
  if (Array.isArray(v)) return [...v].sort().join("");
  return String(v);
};

const friendlyReason = (error: unknown): string => {
  if (error instanceof AppError) return `: ${error.message}`;
  return "";
};

const zodMessage = (error: unknown): string => {
  if (error && typeof error === "object" && "issues" in error) {
    const issues = (
      error as { issues: Array<{ message: string; path: unknown[] }> }
    ).issues;
    if (issues.length > 0) {
      const first = issues[0]!;
      const path = Array.isArray(first.path) ? first.path.join(".") : "";
      return `${path ? path + ": " : ""}${first.message}`;
    }
  }
  return "invalid parameters";
};
