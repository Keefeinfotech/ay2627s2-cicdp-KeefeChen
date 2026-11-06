import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => {
  const save = vi.fn();
  const find = vi.fn();
  const findById = vi.fn();
  const findByIdAndDelete = vi.fn();
  const reminderConstructor = vi.fn().mockImplementation(function (
    this: Record<string, unknown>,
    input: Record<string, unknown>,
  ) {
    Object.assign(this, input, { save });
  });

  Object.assign(reminderConstructor, {
    find,
    findById,
    findByIdAndDelete,
  });

  return {
    save,
    find,
    findById,
    findByIdAndDelete,
    Reminder: reminderConstructor,
  };
});

vi.mock("../../../../src/modules/reminders/reminder.model.js", () => ({
  Reminder: mocks.Reminder,
}));

import { reminderService } from "../../../../src/modules/reminders/reminder.service.js";

const reminder = (overrides: Record<string, unknown> = {}) => ({
  _id: "reminder-1",
  userId: "user-1",
  message: "Revise calculus",
  dueAt: new Date("2026-11-10T09:00:00Z"),
  completed: false,
  save: mocks.save,
  ...overrides,
});

describe("reminder service", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("lists reminders ordered by due date", async () => {
    const rows = [reminder()];
    const sort = vi.fn().mockResolvedValue(rows);
    mocks.find.mockReturnValue({ sort });

    await expect(reminderService.findAll("user-1")).resolves.toBe(rows);
    expect(mocks.find).toHaveBeenCalledWith({ userId: "user-1" });
    expect(sort).toHaveBeenCalledWith({ dueAt: 1 });
  });

  it("finds a reminder by id", async () => {
    const value = reminder();
    mocks.findById.mockResolvedValue(value);

    await expect(reminderService.findById("reminder-1")).resolves.toBe(value);
    expect(mocks.findById).toHaveBeenCalledWith("reminder-1");
  });

  it("creates and saves a pending reminder", async () => {
    const saved = reminder({ _id: "reminder-new" });
    mocks.save.mockResolvedValue(saved);

    const result = await reminderService.create(
      "user-1",
      "Revise calculus",
      new Date("2026-11-10T09:00:00Z"),
    );

    expect(result).toBe(saved);
    expect(mocks.Reminder).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: "user-1",
        message: "Revise calculus",
      }),
    );
    expect(mocks.save).toHaveBeenCalledOnce();
  });

  it("marks an existing reminder as completed", async () => {
    const value = reminder();
    mocks.findById.mockResolvedValue(value);
    mocks.save.mockResolvedValue({ ...value, completed: true });

    const result = await reminderService.complete("reminder-1");

    expect(mocks.findById).toHaveBeenCalledWith("reminder-1");
    expect(value.completed).toBe(true);
    expect(value.completedAt).toBeInstanceOf(Date);
    expect(mocks.save).toHaveBeenCalledWith();
    expect(result).toMatchObject({ completed: true });
  });

  it("returns null when completing a missing reminder", async () => {
    mocks.findById.mockResolvedValue(null);

    await expect(reminderService.complete("missing")).resolves.toBeNull();
    expect(mocks.save).not.toHaveBeenCalled();
  });

  it("deletes a reminder by id", async () => {
    mocks.findByIdAndDelete.mockResolvedValue({ deletedCount: 1 });

    await expect(reminderService.delete("reminder-1")).resolves.toEqual({
      deletedCount: 1,
    });
    expect(mocks.findByIdAndDelete).toHaveBeenCalledWith("reminder-1");
  });

  it("lists pending reminders due before a cutoff", async () => {
    const rows = [reminder()];
    const sort = vi.fn().mockResolvedValue(rows);
    mocks.find.mockReturnValue({ sort });
    const before = new Date("2026-11-12T00:00:00Z");

    await expect(reminderService.findPending("user-1", before)).resolves.toBe(
      rows,
    );
    expect(mocks.find).toHaveBeenCalledWith({
      userId: "user-1",
      completed: false,
      dueAt: { $lte: before },
    });
    expect(sort).toHaveBeenCalledWith({ dueAt: 1 });
  });
});
