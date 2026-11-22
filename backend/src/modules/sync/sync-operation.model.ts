/**
 * File Name: sync-operation.model.ts
 * Description: Idempotency ledger for offline sync operations pushed by
 *              clients. One document per (userId, opId); replays return the
 *              stored result instead of re-applying the operation.
 * Author: Keefe Chen
 */

import mongoose, { Schema, type Model } from "mongoose";

export const SYNC_OPERATION_TYPES = [
  "task.create",
  "task.update",
  "task.delete",
] as const;
export type SyncOperationType = (typeof SYNC_OPERATION_TYPES)[number];

export interface SyncOperationRecord {
  _id: string;
  userId: string;
  opId: string;
  type: SyncOperationType;
  status: "applied" | "failed" | "conflict";
  detail: unknown;
  createdAt: Date;
  updatedAt: Date;
}

const syncOperationSchema = new Schema<SyncOperationRecord>(
  {
    _id: { type: String, default: () => crypto.randomUUID() },
    userId: { type: String, required: true },
    opId: { type: String, required: true },
    type: { type: String, enum: SYNC_OPERATION_TYPES, required: true },
    status: {
      type: String,
      enum: ["applied", "failed", "conflict"],
      required: true,
    },
    // Result detail is a plain JSON payload; never store secrets here.
    detail: { type: Schema.Types.Mixed, default: null },
  },
  { timestamps: true, versionKey: false },
);

syncOperationSchema.index({ userId: 1, opId: 1 }, { unique: true });

export const SyncOperation: Model<SyncOperationRecord> =
  (mongoose.models.SyncOperation as Model<SyncOperationRecord>) ??
  mongoose.model<SyncOperationRecord>("SyncOperation", syncOperationSchema);
