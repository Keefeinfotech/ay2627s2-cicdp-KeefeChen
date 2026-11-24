/**
 * File Name: preference.service.ts
 * Description: Preferences persistence. Missing documents are created
 *              lazily with schema defaults on first read.
 * Author: Keefe Chen
 */

import { Preference, type PreferenceRecord } from "./preference.model.js";

const deepMergeSection = <T extends Record<string, unknown>>(
  base: T,
  patch: Partial<T>,
): T => ({ ...base, ...patch });

export const preferenceService = {
  async get(userId: string): Promise<PreferenceRecord> {
    const existing = await Preference.findOne({ userId }).lean();
    if (existing) return existing as unknown as PreferenceRecord;

    const created = await Preference.create({ userId });
    return created.toObject() as PreferenceRecord;
  },

  async update(
    userId: string,
    input: {
      notifications?: Partial<PreferenceRecord["notifications"]>;
      appearance?: Partial<PreferenceRecord["appearance"]>;
      timezone?: string;
      locale?: string;
    },
  ): Promise<PreferenceRecord> {
    const current = await preferenceService.get(userId);

    const update: Record<string, unknown> = {};

    if (input.notifications) {
      update.notifications = deepMergeSection(
        { ...current.notifications },
        input.notifications,
      );
    }
    if (input.appearance) {
      update.appearance = deepMergeSection(
        { ...current.appearance },
        input.appearance,
      );
    }
    if (input.timezone !== undefined) update.timezone = input.timezone;
    if (input.locale !== undefined) update.locale = input.locale;

    const updated = await Preference.findOneAndUpdate(
      { userId },
      { $set: update },
      { new: true, upsert: true, setDefaultsOnInsert: true },
    ).lean();

    return updated as unknown as PreferenceRecord;
  },

  async updateNotifications(
    userId: string,
    input: Partial<PreferenceRecord["notifications"]>,
  ): Promise<PreferenceRecord> {
    return preferenceService.update(userId, { notifications: input });
  },

  async updateAppearance(
    userId: string,
    input: Partial<PreferenceRecord["appearance"]>,
  ): Promise<PreferenceRecord> {
    return preferenceService.update(userId, { appearance: input });
  },

  async updateTimezone(
    userId: string,
    timezone: string,
  ): Promise<PreferenceRecord> {
    return preferenceService.update(userId, { timezone });
  },
};
