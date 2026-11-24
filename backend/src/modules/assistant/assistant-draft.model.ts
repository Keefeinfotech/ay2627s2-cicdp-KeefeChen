/**
 * File Name: assistant-draft.model.ts
 * Description: Persisted AI task drafts awaiting explicit user confirmation.
 *              Drafts expire after 30 minutes (TTL index).
 * Author: Keefe Chen
 */

import { randomUUID } from "node:crypto";
import mongoose, { Schema, type Model } from "mongoose";

export const ASSISTANT_DRAFT_STATUSES = [
  "pending",
  "confirmed",
  "cancelled",
] as const;
export type AssistantDraftStatus = (typeof ASSISTANT_DRAFT_STATUSES)[number];

export interface AssistantDraftRecord {
  _id: string;
  userId: string;
  /** The user's natural-language request. */
  message: string;
  /** Conversation turns supplied by the client (JSON-serialisable). */
  context: unknown[];
  currentDate?: string;
  utcOffsetMinutes?: number;
  draft: Record<string, unknown> | null;
  clarification: string | null;
  reply: string;
  status: AssistantDraftStatus;
  taskId: string | null;
  createdAt: Date;
  updatedAt: Date;
  expiresAt: Date;
}

const assistantDraftSchema = new Schema<AssistantDraftRecord>(
  {
    _id: { type: String, default: () => randomUUID(), immutable: true },
    userId: { type: String, required: true, index: true },
    message: { type: String, required: true, maxlength: 4000 },
    context: { type: [Schema.Types.Mixed], default: [] },
    currentDate: { type: String, default: undefined },
    utcOffsetMinutes: { type: Number, default: undefined },
    draft: { type: Schema.Types.Mixed, default: null },
    clarification: { type: String, default: null },
    reply: { type: String, default: "" },
    status: {
      type: String,
      enum: ASSISTANT_DRAFT_STATUSES,
      default: "pending",
      index: true,
    },
    taskId: { type: String, default: null },
    expiresAt: { type: Date, required: true },
  },
  { timestamps: true, versionKey: false },
);

// Drafts are short-lived; expired drafts vanish automatically.
assistantDraftSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });
assistantDraftSchema.index({ userId: 1, status: 1, createdAt: -1 });

export const AssistantDraft: Model<AssistantDraftRecord> =
  (mongoose.models.AssistantDraft as Model<AssistantDraftRecord>) ??
  mongoose.model<AssistantDraftRecord>("AssistantDraft", assistantDraftSchema);
