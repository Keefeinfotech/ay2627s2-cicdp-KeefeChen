import { getSessionCacheTtlMs } from "../../config/environment.js";
import type { AuthenticatedUser } from "./auth.types.js";

interface CacheEntry {
  user: AuthenticatedUser;
  expiresAtMs: number;
}

export interface SessionCacheOptions {
  /** TTL source; defaults to SESSION_CACHE_TTL_MS (0 disables caching). */
  ttlMs?: () => number;
  /** Upper bound on retained entries so memory stays predictable. */
  maxEntries?: number;
  /** Clock, injectable for tests. */
  nowMs?: () => number;
}

const DEFAULT_MAX_ENTRIES = 5_000;

/**
 * In-process cache of validated sessions.
 *
 * Without it every authenticated request costs a MongoDB round trip; with it
 * only the first request per session within each TTL window reads the
 * database. Entries are keyed by user + session id and are dropped
 * immediately on logout, revocation, or a newer login, so revocations are
 * never delayed by the TTL.
 */
export class SessionCache {
  private readonly _entries = new Map<string, CacheEntry>();
  private readonly _byUser = new Map<string, Set<string>>();
  private readonly _ttlMs: () => number;
  private readonly _maxEntries: number;
  private readonly _now: () => number;

  constructor(options: SessionCacheOptions = {}) {
    this._ttlMs = options.ttlMs ?? getSessionCacheTtlMs;
    this._maxEntries = options.maxEntries ?? DEFAULT_MAX_ENTRIES;
    this._now = options.nowMs ?? Date.now;
  }

  get(userId: string, sessionId: string): AuthenticatedUser | null {
    const entry = this._entries.get(this._key(userId, sessionId));
    if (!entry) return null;

    if (entry.expiresAtMs <= this._now()) {
      this.invalidate(userId, sessionId);
      return null;
    }
    return entry.user;
  }

  set(userId: string, sessionId: string, user: AuthenticatedUser): void {
    const ttl = this._ttlMs();
    if (ttl <= 0) return;

    const key = this._key(userId, sessionId);
    if (!this._entries.has(key) && this._entries.size >= this._maxEntries) {
      this._evictOldest();
    }

    // Map.set keeps the original insertion order for existing keys, so the
    // oldest entry remains the first key when eviction is needed.
    this._entries.set(key, { user, expiresAtMs: this._now() + ttl });
    if (!this._byUser.has(userId)) this._byUser.set(userId, new Set());
    this._byUser.get(userId)?.add(sessionId);
  }

  invalidate(userId: string, sessionId: string): void {
    const key = this._key(userId, sessionId);
    if (!this._entries.delete(key)) return;

    const sessions = this._byUser.get(userId);
    sessions?.delete(sessionId);
    if (sessions && sessions.size === 0) this._byUser.delete(userId);
  }

  /** Drops every cached session for a user (password reset, new login while
   *  concurrent sessions are disabled). */
  invalidateUser(userId: string): void {
    const sessions = this._byUser.get(userId);
    if (!sessions) return;

    for (const sessionId of sessions) {
      this._entries.delete(this._key(userId, sessionId));
    }
    this._byUser.delete(userId);
  }

  clear(): void {
    this._entries.clear();
    this._byUser.clear();
  }

  get size(): number {
    return this._entries.size;
  }

  private _key(userId: string, sessionId: string): string {
    return `${userId}:${sessionId}`;
  }

  private _evictOldest(): void {
    const oldest = this._entries.keys().next();
    if (oldest.done) return;

    // Recover the owning user from the entry key to keep the index in sync.
    const separator = oldest.value.indexOf(":");
    const userId = oldest.value.slice(0, separator);
    const sessionId = oldest.value.slice(separator + 1);

    this._entries.delete(oldest.value);
    const sessions = this._byUser.get(userId);
    sessions?.delete(sessionId);
    if (sessions && sessions.size === 0) this._byUser.delete(userId);
  }
}

/** Shared instance used by the auth service and middleware. */
export const sessionCache = new SessionCache();
