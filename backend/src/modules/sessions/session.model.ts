/**
 * File Name: session.model.ts
 * Description: Defines the MongoDB schema for group study sessions.
 * Author: Keefe Chen
 */

import { randomUUID } from "node:crypto";
import mongoose, { Schema, type InferSchemaType } from "mongoose";

import { SESSION_STATUSES } from "./session.types.js";

const studySessionSchema = new Schema(
  {
    _id: {
      type: String,
      default: () => randomUUID(),
      immutable: true,
    },

    groupId: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },

    title: {
      type: String,
      required: true,
      trim: true,
      minlength: 1,
      maxlength: 150,
    },

    description: {
      type: String,
      default: null,
      maxlength: 2000,
    },

    startsAt: {
      type: Date,
      required: true,
    },

    endsAt: {
      type: Date,
      required: true,
    },

    location: {
      type: String,
      default: null,
      trim: true,
      maxlength: 200,
    },

    /**
     * Optional capacity limit. Null means unlimited.
     */
    maxAttendees: {
      type: Number,
      default: null,
      min: 1,
      max: 200,
    },

    attendeeIds: {
      type: [String],
      default: [],
    },

    createdBy: {
      type: String,
      required: true,
      trim: true,
    },

    status: {
      type: String,
      enum: SESSION_STATUSES,
      default: "scheduled",
      required: true,
      index: true,
    },
  },
  {
    timestamps: true,
    versionKey: false,
    strict: "throw",
  },
);

studySessionSchema.index({ groupId: 1, startsAt: 1 });
studySessionSchema.index({ groupId: 1, status: 1, startsAt: -1 });

export type StudySessionDocument = InferSchemaType<typeof studySessionSchema>;

export const StudySession =
  mongoose.models.StudySession ??
  mongoose.model("StudySession", studySessionSchema);
