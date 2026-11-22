import { describe, expect, it } from "vitest";

import { Reminder } from "../../../../src/modules/reminders/reminder.model.js";

describe("reminder schema identity", () => {
  it("stores userId as a String so it can reference users._id", () => {
    const path = Reminder.schema.path("userId");
    expect(path).toBeDefined();
    expect((path as { instance?: string }).instance).toBe("String");
  });

  it("validates a UUID owner without an ObjectId cast error", async () => {
    const uuid = "550e8400-e29b-41d4-a716-446655440000";
    const reminder = new Reminder({
      userId: uuid,
      message: "Revise calculus",
      dueAt: new Date("2026-11-22T09:00:00Z"),
    });

    await expect(reminder.validate()).resolves.toBeUndefined();
    expect(reminder.userId).toBe(uuid);
  });

  it("keeps only the compound taskId index, not a redundant single-field one", () => {
    const indexes = Reminder.schema.indexes() as Array<
      [Record<string, unknown>]
    >;
    const hasCompound = indexes.some(
      ([fields]) => fields.taskId === 1 && fields.userId === 1,
    );
    const hasSingle = indexes.some(
      ([fields]) => Object.keys(fields).length === 1 && fields.taskId === 1,
    );

    expect(hasCompound).toBe(true);
    expect(hasSingle).toBe(false);
  });
});
