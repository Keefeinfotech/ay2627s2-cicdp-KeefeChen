/**
 * File Name: preference.model.ts
 * Description: Per-user preferences: notification settings, appearance,
 *              timezone and locale. One document per user; created lazily
 *              with defaults on first read.
 * Author: Keefe Chen
 */

import { randomUUID } from "node:crypto";
import mongoose, { Schema, type Model } from "mongoose";

export const THEMES = ["system", "light", "dark"] as const;
export type Theme = (typeof THEMES)[number];

export interface PreferenceRecord {
  _id: string;
  userId: string;
  notifications: {
    enabled: boolean;
    email: boolean;
    push: boolean;
    inApp: boolean;
    reminderMinutesBefore: number;
  };
  appearance: {
    theme: Theme;
    fontScale: number;
  };
  timezone: string;
  locale: string;
  createdAt: Date;
  updatedAt: Date;
}

const preferenceSchema = new Schema<PreferenceRecord>(
  {
    _id: { type: String, default: () => randomUUID(), immutable: true },
    userId: { type: String, required: true, unique: true, index: true },
    notifications: {
      enabled: { type: Boolean, default: true },
      email: { type: Boolean, default: true },
      push: { type: Boolean, default: false },
      inApp: { type: Boolean, default: true },
      reminderMinutesBefore: { type: Number, default: 30, min: 0, max: 1440 },
    },
    appearance: {
      theme: { type: String, enum: THEMES, default: "system" },
      fontScale: { type: Number, default: 1, min: 0.8, max: 2 },
    },
    timezone: { type: String, default: "UTC", maxlength: 64 },
    locale: { type: String, default: "en", maxlength: 16 },
  },
  { timestamps: true, versionKey: false },
);

export const Preference: Model<PreferenceRecord> =
  (mongoose.models.Preference as Model<PreferenceRecord>) ??
  mongoose.model<PreferenceRecord>("Preference", preferenceSchema);
