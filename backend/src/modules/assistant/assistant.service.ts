/**
 * File Name: assistant.service.ts
 * Description: Confirmation-gated AI assistant flow. The AI never creates a
 *              task without an explicit /confirm call; drafts expire after
 *              30 minutes and are scoped to their owner.
 */

import {
  AssistantDraft,
  type AssistantDraftRecord,
} from "./assistant-draft.model.js";
import { createTaskDraft, type ConversationTurn } from "../ai/ai.service.js";
import { taskService } from "../tasks/task.service.js";
import { AppError } from "../../shared/utils/AppError.js";

import type { DraftEdits } from "./assistant.validation.js";

const DRAFT_TTL_MS = 30 * 60 * 1000;

interface InterpretInput {
  message: string;
  context?: ConversationTurn[];
  currentDate?: string;
  utcOffsetMinutes?: number;
}

const normaliseDraftPriority = (
  value: unknown,
): "low" | "medium" | "high" | "urgent" | undefined => {
  if (
    value === "low" ||
    value === "medium" ||
    value === "high" ||
    value === "urgent"
  ) {
    return value;
  }
  return undefined;
};

const applyEdits = (
  draft: Record<string, unknown> | null,
  edits?: DraftEdits,
): Record<string, unknown> => {
  const base = { ...(draft ?? {}) };
  if (!edits) return base;

  for (const [key, value] of Object.entries(edits)) {
    if (value !== undefined) base[key] = value;
  }
  return base;
};

export const assistantService = {
  /** Interpret a natural-language request; returns a pending draft. */
  async interpret(userId: string, input: InterpretInput) {
    const result = await createTaskDraft(input.message, input.context, {
      currentDate: input.currentDate,
      utcOffsetMinutes: input.utcOffsetMinutes,
    });

    const doc = await AssistantDraft.create({
      userId,
      message: input.message,
      context: input.context ?? [],
      currentDate: input.currentDate,
      utcOffsetMinutes: input.utcOffsetMinutes,
      draft: result.draft ?? null,
      clarification: result.clarification ?? null,
      reply: result.reply ?? "",
      status: "pending",
      expiresAt: new Date(Date.now() + DRAFT_TTL_MS),
    });

    return this.toResponse(doc);
  },

  /** Re-run interpretation with an additional clarification answer. */
  async clarify(userId: string, input: { draftId: string; message: string }) {
    const draft = await this.requirePending(userId, input.draftId);

    const context: ConversationTurn[] = [
      ...((draft.context as ConversationTurn[]) ?? []),
      { role: "user", content: draft.message },
      { role: "assistant", content: draft.reply },
      { role: "user", content: input.message },
    ];

    const result = await createTaskDraft(input.message, context, {
      currentDate: draft.currentDate,
      utcOffsetMinutes: draft.utcOffsetMinutes ?? undefined,
    });

    draft.context = context;
    draft.draft = result.draft ?? null;
    draft.clarification = result.clarification ?? null;
    draft.reply = result.reply ?? "";
    await draft.save();

    return this.toResponse(draft);
  },

  /** Return the editable preview for a pending draft (optionally with edits). */
  async preview(
    userId: string,
    input: { draftId: string; edits?: DraftEdits },
  ) {
    const draft = await this.requirePending(userId, input.draftId);
    return {
      draftId: String(draft._id),
      preview: applyEdits(draft.draft, input.edits),
      clarification: draft.clarification,
      reply: draft.reply,
      status: draft.status,
    };
  },

  /** Create the task from the pending draft. The only path to persistence. */
  async confirm(
    userId: string,
    input: { draftId: string; edits?: DraftEdits },
  ) {
    const draft = await this.requirePending(userId, input.draftId);
    const merged = applyEdits(draft.draft, input.edits);

    const title = typeof merged.title === "string" ? merged.title.trim() : "";
    if (!title) {
      throw new AppError(
        422,
        "DRAFT_MISSING_TITLE",
        "The draft has no task title; ask for clarification or supply one.",
      );
    }

    const dueDateRaw = merged.dueDate;
    let dueDate: Date | null = null;
    if (dueDateRaw) {
      const parsed = new Date(dueDateRaw as string | Date);
      if (!Number.isNaN(parsed.getTime())) dueDate = parsed;
    }

    const task = await taskService.createTask(userId, {
      title,
      description:
        typeof merged.description === "string" ? merged.description : null,
      course: typeof merged.course === "string" ? merged.course : "",
      dueDate,
      priority: normaliseDraftPriority(merged.priority),
      tags: Array.isArray(merged.tags)
        ? (merged.tags as string[]).slice(0, 8)
        : undefined,
    });

    draft.status = "confirmed";
    draft.taskId = String(task._id);
    await draft.save();

    return { task, draftId: String(draft._id) };
  },

  /** Discard a pending draft without creating anything. */
  async cancel(userId: string, input: { draftId: string }) {
    const draft = await AssistantDraft.findOne({
      _id: input.draftId,
      userId,
      status: "pending",
    });
    if (!draft) {
      throw new AppError(404, "DRAFT_NOT_FOUND", "Draft not found.");
    }

    draft.status = "cancelled";
    await draft.save();

    return { draftId: String(draft._id), status: draft.status };
  },

  /** Deterministic prompt suggestions based on the user's open tasks. */
  async suggestions(userId: string) {
    const { items } = await taskService.listTasks(userId, {
      status: ["todo", "in_progress"],
      limit: 5,
      sortBy: "dueDate",
      sortOrder: "asc",
    });

    const suggestions: string[] = [];

    const overdue = items.filter(
      (t) => t.dueDate && new Date(t.dueDate) < new Date(),
    );
    if (overdue.length > 0) {
      suggestions.push(
        `Help me catch up on overdue work: ${overdue
          .slice(0, 3)
          .map((t) => t.title)
          .join(", ")}`,
      );
    }

    const dueSoon = items.filter(
      (t) =>
        t.dueDate &&
        new Date(t.dueDate) >= new Date() &&
        new Date(t.dueDate).getTime() - Date.now() < 48 * 3600 * 1000,
    );
    for (const t of dueSoon.slice(0, 2)) {
      suggestions.push(`Break "${t.title}" into smaller steps`);
    }

    suggestions.push("Plan my study schedule for the next week");
    suggestions.push("Which of my tasks should I do first today?");

    return { suggestions: suggestions.slice(0, 5) };
  },

  async requirePending(
    userId: string,
    draftId: string,
  ): Promise<AssistantDraftRecord & { save: () => Promise<unknown> }> {
    const draft = await AssistantDraft.findOne({
      _id: draftId,
      userId,
      status: "pending",
    });
    if (!draft) {
      throw new AppError(
        404,
        "DRAFT_NOT_FOUND",
        "Draft not found, already used or expired.",
      );
    }
    return draft as unknown as AssistantDraftRecord & {
      save: () => Promise<unknown>;
    };
  },

  async toResponse(
    doc: AssistantDraftRecord | (AssistantDraftRecord & { save?: unknown }),
  ) {
    return {
      draftId: String(doc._id),
      reply: doc.reply,
      draft: doc.draft,
      clarification: doc.clarification,
      status: doc.status,
    };
  },
};
