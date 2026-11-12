import { describe, expect, it } from "vitest";
import { SessionCache } from "../../src/modules/auth/session.cache";
import type { AuthenticatedUser } from "../../src/modules/auth/auth.types";

const user = (id: string): AuthenticatedUser => ({
  id,
  email: `${id}@example.com`,
  role: "user",
});

describe("SessionCache", () => {
  it("returns a cached entry until it expires", () => {
    let now = 1_000;
    const cache = new SessionCache({ ttlMs: () => 30_000, nowMs: () => now });

    cache.set("user-1", "session-1", user("user-1"));
    expect(cache.get("user-1", "session-1")?.id).toBe("user-1");

    now += 29_999;
    expect(cache.get("user-1", "session-1")).not.toBeNull();

    now += 1;
    expect(cache.get("user-1", "session-1")).toBeNull();
    expect(cache.size).toBe(0);
  });

  it("never returns another user's or session's entry", () => {
    const cache = new SessionCache({ ttlMs: () => 30_000 });
    cache.set("user-1", "session-1", user("user-1"));

    expect(cache.get("user-2", "session-1")).toBeNull();
    expect(cache.get("user-1", "session-2")).toBeNull();
  });

  it("treats a TTL of 0 as caching disabled", () => {
    const cache = new SessionCache({ ttlMs: () => 0 });
    cache.set("user-1", "session-1", user("user-1"));

    expect(cache.get("user-1", "session-1")).toBeNull();
    expect(cache.size).toBe(0);
  });

  it("evicts the oldest entry when the cap is reached", () => {
    const cache = new SessionCache({ ttlMs: () => 30_000, maxEntries: 2 });

    cache.set("user-1", "session-1", user("user-1"));
    cache.set("user-1", "session-2", user("user-1"));
    cache.set("user-1", "session-3", user("user-1"));

    expect(cache.size).toBe(2);
    expect(cache.get("user-1", "session-1")).toBeNull();
    expect(cache.get("user-1", "session-2")).not.toBeNull();
    expect(cache.get("user-1", "session-3")).not.toBeNull();
  });

  it("invalidate drops only the given entry", () => {
    const cache = new SessionCache({ ttlMs: () => 30_000 });
    cache.set("user-1", "session-1", user("user-1"));
    cache.set("user-1", "session-2", user("user-1"));

    cache.invalidate("user-1", "session-1");

    expect(cache.get("user-1", "session-1")).toBeNull();
    expect(cache.get("user-1", "session-2")).not.toBeNull();
    expect(cache.size).toBe(1);
  });

  it("invalidate is safe to call for unknown keys", () => {
    const cache = new SessionCache({ ttlMs: () => 30_000 });
    expect(() => cache.invalidate("user-1", "session-1")).not.toThrow();
  });

  it("invalidateUser drops every session for one user only", () => {
    const cache = new SessionCache({ ttlMs: () => 30_000 });
    cache.set("user-1", "session-1", user("user-1"));
    cache.set("user-1", "session-2", user("user-1"));
    cache.set("user-2", "session-3", user("user-2"));

    cache.invalidateUser("user-1");

    expect(cache.get("user-1", "session-1")).toBeNull();
    expect(cache.get("user-1", "session-2")).toBeNull();
    expect(cache.get("user-2", "session-3")).not.toBeNull();
    expect(cache.size).toBe(1);
  });

  it("clear empties the cache and its user index", () => {
    const cache = new SessionCache({ ttlMs: () => 30_000 });
    cache.set("user-1", "session-1", user("user-1"));
    cache.set("user-2", "session-2", user("user-2"));

    cache.clear();

    expect(cache.size).toBe(0);
    expect(cache.get("user-1", "session-1")).toBeNull();

    cache.set("user-1", "session-3", user("user-1"));
    expect(cache.get("user-1", "session-3")).not.toBeNull();
  });

  it("keeps the per-user index in sync when an entry expires by TTL", () => {
    let now = 0;
    const cache = new SessionCache({ ttlMs: () => 10, nowMs: () => now });

    cache.set("user-1", "session-1", user("user-1"));
    now = 10;
    expect(cache.get("user-1", "session-1")).toBeNull();

    // A later set for the same key must work after the expired drop.
    cache.set("user-1", "session-1", user("user-1"));
    expect(cache.get("user-1", "session-1")).not.toBeNull();
  });
});
