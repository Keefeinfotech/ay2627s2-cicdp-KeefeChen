import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => {
  const save = vi.fn();
  const find = vi.fn();
  const findOne = vi.fn();
  const findOneAndDelete = vi.fn();
  const findOneAndUpdate = vi.fn();
  const create = vi.fn();
  const reminderConstructor = vi.fn().mockImplementation(function (
    this: Record<string, unknown>,
    input: Record<string, unknown>,
  ) {
    Object.assign(this, input, { save });
  });

  Object.assign(reminderConstructor, {
    find,
    findOne,
    findOneAndDelete,
    findOneAndUpdate,
    create,
  });

  return {
    save,
    find,
    findOne,
    findOneAndDelete,
    findOneAndUpdate,
    create,
    Reminder: reminderConstructor,
  };
});

vi.mock("../../../../src/modules/reminders/reminder.model.js", () => ({
  Reminder: mocks.Reminder,
  REMINDER_RECURRENCES: ["none", "daily", "weekly", "monthly"],
}));

vi.mock("../../../../src/modules/users/user.model.js", () => ({
  User: {
    findById: vi.fn().mockReturnValue({
      select: vi.fn().mockReturnValue({
        lean: vi.fn().mockResolvedValue({ email: "user@example.com" }),
      }),
    }),
  },
}));

vi.mock("../../../../src/shared/jobs/index.js", () => ({
  enqueue: vi.fn().mockReturnValue(true),
}));

vi.mock("../../../../src/modules/users/user.model.js", () => ({
  User: {
    findById: vi.fn().mockReturnValue({
      select: vi.fn().mockReturnValue({
        lean: vi.fn().mockResolvedValue({ email: "user@example.com" }),
      }),
    }),
  },
}));

vi.mock("../../../../src/shared/jobs/index.js", () => ({
  enqueue: vi.fn().mockReturnValue(true),
}));

import { reminderService } from "../../../../src/modules/reminders/reminder.service.js";

const reminder = (overrides: Record<string, unknown> = {}) => ({
  _id: "reminder-1",
  userId: "user-1",
  taskId: null,
  message: "Revise calculus",
  dueAt: new Date("2026-11-10T09:00:00Z"),
  recurrence: "none",
  enabled: true,
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

  it("finds a reminder by id scoped to the user (IDOR prevention)", async () => {
    const value = reminder();
    mocks.findOne.mockResolvedValue(value);

    await expect(
      reminderService.findById("reminder-1", "user-1"),
    ).resolves.toBe(value);
    expect(mocks.findOne).toHaveBeenCalledWith({
      _id: "reminder-1",
      userId: "user-1",
    });
  });

  it("creates and saves a pending reminder", async () => {
    const saved = reminder({ _id: "reminder-new" });
    mocks.save.mockResolvedValue(saved);

    const result = await reminderService.create("user-1", {
      message: "Revise calculus",
      dueAt: new Date("2026-11-10T09:00:00Z"),
    });

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
    mocks.findOne.mockResolvedValue(value);
    mocks.save.mockResolvedValue({ ...value, completed: true });

    const result = await reminderService.complete("reminder-1", "user-1");

    expect(mocks.findOne).toHaveBeenCalledWith({
      _id: "reminder-1",
      userId: "user-1",
    });
    expect(value.completed).toBe(true);
    expect(value.completedAt).toBeInstanceOf(Date);
    expect(mocks.save).toHaveBeenCalledWith();
    expect(result).toMatchObject({ completed: true });
  });

  it("spawns the next occurrence when completing a recurring reminder", async () => {
    const value = reminder({ recurrence: "daily" });
    mocks.findOne.mockResolvedValue(value);
    mocks.save.mockResolvedValue(value);
    const select = vi.fn().mockReturnValue({
      lean: vi.fn().mockResolvedValue(null),
    });
    mocks.findOne
      .mockResolvedValueOnce(value) // complete() lookup
      .mockReturnValueOnce({ select }); // existing-next lookup

    await reminderService.complete("reminder-1", "user-1");

    expect(mocks.create).toHaveBeenCalledTimes(1);
    expect(mocks.create.mock.calls[0][0]).toMatchObject({
      userId: "user-1",
      recurrence: "daily",
    });
  });

  it("does not spawn a duplicate when the next occurrence already exists", async () => {
    const value = reminder({ recurrence: "weekly" });
    mocks.findOne.mockResolvedValueOnce(value);
    mocks.save.mockResolvedValue(value);
    const select = vi.fn().mockReturnValue({
      lean: vi.fn().mockResolvedValue({ _id: "next-1" }),
    });
    mocks.findOne.mockReturnValueOnce({ select });

    await reminderService.complete("reminder-1", "user-1");

    expect(mocks.create).not.toHaveBeenCalled();
  });

  it("returns null when completing a missing reminder", async () => {
    mocks.findOne.mockResolvedValue(null);

    await expect(
      reminderService.complete("missing", "user-1"),
    ).resolves.toBeNull();
    expect(mocks.save).not.toHaveBeenCalled();
  });

  it("deletes a reminder by id scoped to the user", async () => {
    mocks.findOneAndDelete.mockResolvedValue({ _id: "reminder-1" });

    await expect(
      reminderService.delete("reminder-1", "user-1"),
    ).resolves.toEqual({ _id: "reminder-1" });
    expect(mocks.findOneAndDelete).toHaveBeenCalledWith({
      _id: "reminder-1",
      userId: "user-1",
    });
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

  it("lists upcoming enabled reminders within the requested window", async () => {
    const rows = [reminder()];
    const limit = vi.fn().mockResolvedValue(rows);
    const sort = vi.fn().mockReturnValue({ limit });
    mocks.find.mockReturnValue({ sort });

    await expect(reminderService.upcoming("user-1", 14)).resolves.toBe(rows);
    expect(mocks.find).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: "user-1",
        completed: false,
        enabled: true,
      }),
    );
  });

  it("advances recurring occurrences in UTC regardless of server timezone", async () => {
    const originalTZ = process.env.TZ;
    try {
      // US DST ends on 2027-11-07: a local-time implementation would shift
      // the next occurrence by one hour when moving to standard time.
      process.env.TZ = "America/New_York";
      const dueAt = new Date("2027-11-07T12:00:00Z");
      const value = reminder({ recurrence: "daily", dueAt });

      mocks.findOne.mockReset();
      mocks.create.mockReset();
      mocks.findOne.mockResolvedValueOnce(value);
      mocks.save.mockResolvedValue(value);
      mocks.findOne.mockReturnValueOnce({
        select: vi.fn().mockReturnValue({
          lean: vi.fn().mockResolvedValue(null),
        }),
      });

      await reminderService.complete("reminder-1", "user-1");

      const created = mocks.create.mock.calls[0][0] as { dueAt: Date };
      expect(created.dueAt.toISOString()).toBe("2027-11-08T12:00:00.000Z");
    } finally {
      if (originalTZ === undefined) delete process.env.TZ;
      else process.env.TZ = originalTZ;
    }
  });
});
