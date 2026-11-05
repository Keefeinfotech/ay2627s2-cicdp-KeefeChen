/**
 * File Name: audit.model.ts
 * Description: Defines the MongoDB schema for group activity events.
 * Author: Keefe Chen
 */

import { randomUUID } from "node:crypto";
import mongoose, { Schema, type InferSchemaType } from "mongoose";

const auditEventSchema = new Schema(
  {
    eventId: {
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

    actorId: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },

    action: {
      type: String,
      required: true,
      trim: true,
      maxlength: 80,
    },

    targetType: {
      type: String,
      default: null,
      trim: true,
      maxlength: 80,
    },

    targetId: {
      type: String,
      default: null,
      trim: true,
      maxlength: 120,
    },

    metadata: {
      type: Schema.Types.Mixed,
      default: null,
    },
  },
  {
    timestamps: true,
    versionKey: false,
    strict: "throw",
  },
);

auditEventSchema.index({ groupId: 1, createdAt: -1 });
auditEventSchema.index({ groupId: 1, action: 1, createdAt: -1 });

export type AuditEventRecord = InferSchemaType<typeof auditEventSchema>;

export const AuditEvent =
  mongoose.models.AuditEvent ??
  mongoose.model("AuditEvent", auditEventSchema);
