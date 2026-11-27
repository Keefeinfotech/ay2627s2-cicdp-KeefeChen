/**
 * File Name: assistant-action.model.ts
 * Description: Persisted pending AI actions awaiting explicit user
 *              confirmation (e.g. destructive deletions). Pending actions are
 *              scoped to their owner, single-use, and expire quickly.
 */

import { randomUUID } from "node:crypto";
import mongoose, { Schema, type Model } from "mongoose";

export const ASSISTANT_ACTION_STATUSES = [
  "pending",
  "confirmed",
  "cancelled",
] as const;
export type AssistantActionStatus = (typeof ASSISTANT_ACTION_STATUSES)[number];

/** Pending actions require explicit confirmation before execution. */
export const ASSISTANT_ACTION_TYPES = ["delete_task"] as const;
export type AssistantActionType = (typeof ASSISTANT_ACTION_TYPES)[number];

export interface AssistantPendingActionRecord {
  _id: string;
  userId: string;
  type: AssistantActionType;
  /** Validated execution payload (e.g. { taskId }). Never client-supplied. */
  payload: Record<string, unknown>;
  /** Human-readable summary shown for review. */
  summary: string;
  status: AssistantActionStatus;
  createdAt: Date;
  updatedAt: Date;
  expiresAt: Date;
}

const assistantPendingActionSchema = new Schema<AssistantPendingActionRecord>(
  {
    _id: { type: String, default: () => randomUUID(), immutable: true },
    userId: { type: String, required: true, index: true },
    type: { type: String, enum: ASSISTANT_ACTION_TYPES, required: true },
    payload: { type: Schema.Types.Mixed, default: {} },
    summary: { type: String, required: true, maxlength: 500 },
    status: {
      type: String,
      enum: ASSISTANT_ACTION_STATUSES,
      default: "pending",
      index: true,
    },
    expiresAt: { type: Date, required: true },
  },
  { timestamps: true, versionKey: false },
);

// Pending confirmations are short-lived; expired actions vanish automatically.
assistantPendingActionSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });
assistantPendingActionSchema.index({ userId: 1, status: 1, createdAt: -1 });

export const AssistantPendingAction: Model<AssistantPendingActionRecord> =
  (mongoose.models.AssistantPendingAction as Model<AssistantPendingActionRecord>) ??
  mongoose.model<AssistantPendingActionRecord>(
    "AssistantPendingAction",
    assistantPendingActionSchema,
  );
