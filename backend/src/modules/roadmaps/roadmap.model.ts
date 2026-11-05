/**
 * File Name: roadmap.model.ts
 * Description: Defines the MongoDB schema for group roadmaps.
 * Author: Keefe Chen
 */

import { randomUUID } from "node:crypto";
import mongoose, { Schema, type InferSchemaType } from "mongoose";

import {
  ROADMAP_ITEM_STATUSES,
  ROADMAP_SOURCES,
  ROADMAP_STATUSES,
} from "./roadmap.types.js";

const roadmapItemSchema = new Schema(
  {
    itemId: {
      type: String,
      default: () => randomUUID(),
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

    /**
     * Name of the rubric criterion that generated this item, when the
     * roadmap was proposed from a rubric.
     */
    criterion: {
      type: String,
      default: null,
      trim: true,
      maxlength: 200,
    },

    weight: {
      type: Number,
      default: null,
      min: 0,
      max: 100,
    },

    estimateHours: {
      type: Number,
      default: null,
      min: 0,
      max: 1000,
    },

    status: {
      type: String,
      enum: ROADMAP_ITEM_STATUSES,
      default: "pending",
    },

    order: {
      type: Number,
      default: 0,
      min: 0,
    },
  },
  { _id: false },
);

const roadmapSchema = new Schema(
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
      maxlength: 200,
    },

    description: {
      type: String,
      default: null,
      maxlength: 2000,
    },

    source: {
      type: String,
      enum: ROADMAP_SOURCES,
      default: "manual",
      required: true,
    },

    status: {
      type: String,
      enum: ROADMAP_STATUSES,
      default: "draft",
      required: true,
      index: true,
    },

    createdBy: {
      type: String,
      required: true,
      trim: true,
    },

    approvedAt: {
      type: Date,
      default: null,
    },

    items: {
      type: [roadmapItemSchema],
      default: [],
    },
  },
  {
    timestamps: true,
    versionKey: false,
    strict: "throw",
  },
);

roadmapSchema.index({ groupId: 1, status: 1, createdAt: -1 });
roadmapSchema.index(
  {
    _id: 1,
    groupId: 1,
  },
  {
    unique: true,
    name: "unique_roadmap_in_group",
  },
);

export type RoadmapDocument = InferSchemaType<typeof roadmapSchema>;

export const Roadmap =
  mongoose.models.Roadmap ??
  mongoose.model("Roadmap", roadmapSchema);
