import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => {
  const findOne = vi.fn();
  const create = vi.fn();
  const findOneAndUpdate = vi.fn();
  return { findOne, create, findOneAndUpdate };
});

vi.mock("../../../../src/modules/preferences/preference.model.js", () => ({
  Preference: {
    findOne: mocks.findOne,
    create: mocks.create,
    findOneAndUpdate: mocks.findOneAndUpdate,
  },
}));

import { preferenceService } from "../../../../src/modules/preferences/preference.service.js";

const record = () => ({
  userId: "user-1",
  notifications: { email: true, push: true },
  appearance: { theme: "system", fontScale: 1 },
  timezone: "UTC",
  locale: "en",
});

const leanQuery = (value: unknown) => ({
  lean: vi.fn().mockResolvedValue(value),
});

describe("preferenceService", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.findOne.mockReturnValue(leanQuery(record()));
    mocks.create.mockResolvedValue({ toObject: record });
    mocks.findOneAndUpdate.mockReturnValue(leanQuery(record()));
  });

  it("returns existing preferences", async () => {
    await expect(preferenceService.get("user-1")).resolves.toMatchObject({
      userId: "user-1",
    });
    expect(mocks.create).not.toHaveBeenCalled();
  });

  it("creates defaults lazily on first read", async () => {
    mocks.findOne.mockReturnValue(leanQuery(null));
    await expect(preferenceService.get("user-1")).resolves.toMatchObject({
      locale: "en",
    });
    expect(mocks.create).toHaveBeenCalledWith({ userId: "user-1" });
  });

  it("merges notification and appearance sections", async () => {
    await expect(
      preferenceService.update("user-1", {
        notifications: { email: false },
        appearance: { theme: "dark" },
        timezone: "Asia/Singapore",
        locale: "en-GB",
      }),
    ).resolves.toBeTruthy();
    expect(mocks.findOneAndUpdate).toHaveBeenCalledWith(
      { userId: "user-1" },
      {
        $set: {
          notifications: { email: false, push: true },
          appearance: { theme: "dark", fontScale: 1 },
          timezone: "Asia/Singapore",
          locale: "en-GB",
        },
      },
      expect.objectContaining({ new: true, upsert: true }),
    );
  });

  it("handles an empty update without touching sections", async () => {
    await expect(preferenceService.update("user-1", {})).resolves.toBeTruthy();
    expect(mocks.findOneAndUpdate).toHaveBeenCalledWith(
      { userId: "user-1" },
      { $set: {} },
      expect.objectContaining({ upsert: true }),
    );
  });

  it("updates a single section through the convenience methods", async () => {
    await preferenceService.updateNotifications("user-1", { push: false });
    await preferenceService.updateAppearance("user-1", { fontScale: 1.25 });
    await preferenceService.updateTimezone("user-1", "Europe/London");
    expect(mocks.findOneAndUpdate).toHaveBeenCalledTimes(3);
  });
});
