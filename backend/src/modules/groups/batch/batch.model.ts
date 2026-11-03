/**
 * File Name: batch.model.ts
 * Description: Defines the MongoDB schema for bulk group member operations.
 * Author: Keefe Chen
 */

import { randomUUID } from "node:crypto";
import mongoose, { Schema, type InferSchemaType } from "mongoose";

export enum BatchJobStatus {
  COMPLETED = "COMPLETED",
  PARTIALLY_FAILED = "PARTIALLY_FAILED",
  FAILED = "FAILED",
}

export enum BatchOperationType {
  ADD_MEMBERS = "ADD_MEMBERS",
}

export interface BatchItemError {
  index: number;
  memberId?: string;
  code: string;
  message: string;
}

const batchJobSchema = new Schema(
  {
    jobId: {
      type: String,
      default: () => randomUUID(),
      immutable: true,
      unique: true,
      index: true,
    },

    groupId: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },

    operationType: {
      type: String,
      enum: Object.values(BatchOperationType),
      required: true,
    },

    status: {
      type: String,
      enum: Object.values(BatchJobStatus),
      required: true,
    },

    requestedBy: {
      type: String,
      required: true,
      trim: true,
    },

    totalCount: {
      type: Number,
      required: true,
      min: 0,
    },

    successCount: {
      type: Number,
      required: true,
      min: 0,
    },

    failureCount: {
      type: Number,
      required: true,
      min: 0,
    },

    errors: {
      type: [
        new Schema(
          {
            index: { type: Number, required: true },
            memberId: { type: String },
            code: { type: String, required: true },
            message: { type: String, required: true },
          },
          { _id: false },
        ),
      ],
      default: [],
    },
  },
  {
    timestamps: true,
    versionKey: false,
    strict: "throw",
  },
);

batchJobSchema.index({ groupId: 1, createdAt: -1 });

export type BatchJobRecord = InferSchemaType<typeof batchJobSchema>;

export const BatchJob =
  mongoose.models.BatchJob ??
  mongoose.model("BatchJob", batchJobSchema);
