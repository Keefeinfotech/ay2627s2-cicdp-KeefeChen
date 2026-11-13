import { describe, expect, it } from "vitest";

import seedData from "../../scripts/seed-data.json";

describe("seed data", () => {
  it("has non-empty collections", () => {
    const data = seedData as Record<string, unknown[]>;
    for (const [key, value] of Object.entries(data)) {
      expect(Array.isArray(value), `${key} should be an array`).toBe(true);
      expect(value.length, `${key} should not be empty`).toBeGreaterThan(0);
    }
  });

  it("users have unique emails", () => {
    const data = seedData as { users: { email: string }[] };
    const emails = data.users.map((u) => u.email.toLowerCase());
    expect(new Set(emails).size).toBe(emails.length);
  });

  it("groups reference valid owner indices", () => {
    const data = seedData as {
      users: unknown[];
      groups: { ownerIndex: number }[];
    };
    for (const g of data.groups) {
      expect(g.ownerIndex).toBeGreaterThanOrEqual(0);
      expect(g.ownerIndex).toBeLessThan(data.users.length);
    }
  });

  it("memberships reference valid user and group indices", () => {
    const data = seedData as {
      users: unknown[];
      groups: unknown[];
      memberships: { userIndex: number; groupIndex: number }[];
    };
    for (const m of data.memberships) {
      expect(m.userIndex).toBeGreaterThanOrEqual(0);
      expect(m.userIndex).toBeLessThan(data.users.length);
      expect(m.groupIndex).toBeGreaterThanOrEqual(0);
      expect(m.groupIndex).toBeLessThan(data.groups.length);
    }
  });
});