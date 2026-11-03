/**
 * File Name: rubric.model.ts
 * Description: Defines the MongoDB schema for parsed assessment rubrics.
 * Author: Keefe Chen
 */

import { randomUUID } from "node:crypto";
import mongoose, { Schema, type InferSchemaType } from "mongoose";

import { RUBRIC_VERSION } from "./rubric.types.js";

const criterionSchema = new Schema(
  {
    name: {
      type: String,
      required: true,
      trim: true,
      minlength: 1,
      maxlength: 200,
    },

    description: {
      type: String,
      default: null,
      maxlength: 1000,
    },

    weight: {
      type: Number,
      required: true,
      min: 0,
      max: 100,
    },
  },
  { _id: false },
);

const rubricSchema = new Schema(
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

    /**
     * Original pasted rubric text, kept so marker evidence stays auditable.
     */
    sourceText: {
      type: String,
      required: true,
      maxlength: 30000,
    },

    /**
     * SHA-256 of the normalised source text for change detection.
     */
    checksum: {
      type: String,
      required: true,
      index: true,
    },

    version: {
      type: Number,
      default: RUBRIC_VERSION,
      required: true,
    },

    criteria: {
      type: [criterionSchema],
      required: true,
    },

    createdBy: {
      type: String,
      required: true,
      trim: true,
    },
  },
  {
    timestamps: true,
    versionKey: false,
    strict: "throw",
    toJSON: {
      transform: (_document, result: Record<string, unknown>) => {
        delete result.__v;
        return result;
      },
    },
  },
);

rubricSchema.index({ groupId: 1, createdAt: -1 });

export type RubricDocument = InferSchemaType<typeof rubricSchema>;

export const Rubric =
  mongoose.models.Rubric ??
  mongoose.model("Rubric", rubricSchema);
