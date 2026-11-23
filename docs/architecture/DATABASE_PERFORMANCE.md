# Database Performance and Monitoring Notes

This note records the performance-related decisions made for Auxilia's MongoDB design and the monitoring practice to follow before adding further indexes. It complements the database design in Section 7.5 of the SDD.

## Index changes applied

| Collection | Change | Reason |
|---|---|---|
| `tasks` | Added `{ userId: 1, updatedAt: -1 }` (`ix_sync_tasks_owner_updated`) | The offline change feed queries owned tasks by `updatedAt > since`. Without a supporting index this is a collection scan. |
| `tasks` | Added `{ assigneeId: 1, updatedAt: -1 }` (`ix_sync_tasks_assignee_updated`) | `fetchChangesSince()` uses `$or` over owner and assignee; the assignee branch needs its own index. |
| `reminders` | Removed the redundant single-field `taskId` index | The compound `{ taskId: 1, userId: 1 }` index already serves every task-scoped reminder query. Fewer indexes reduce write overhead. |

## Monitoring practice

Do not add indexes speculatively. Before introducing a new index:

1. Enable MongoDB profiling (or Atlas Query Profiler) on the relevant environment and capture slow queries for the task dashboard, search and synchronisation endpoints.
2. Run `explain("executionStats")` on the captured queries and confirm whether an existing compound index is used (`IXSCAN` rather than `COLLSCAN`).
3. Check index selectivity and key order against the equality, sort and range parts of the query. A compound index should place equality fields first, then sort fields, then range fields.
4. Review the Atlas Performance Advisor for suggested indexes and for unused or overlapping indexes.
5. Remove indexes that show no meaningful benefit; every additional index is maintained on each insert and update.

## Deliberately not added

- A productivity/analytics snapshot collection. Task counts, completion rates, overdue counts and streaks remain derived from `tasks` by the analytics service and cached in Redis. A separate collection would duplicate state and require invalidation on every task write. Reconsider only if measured aggregation latency becomes a bottleneck.
- A notification-delivery collection. Reminders remain in-app; delivery records would only be justified if push notifications were introduced.
- A change to `reminders._id`. Reminders are not part of the offline sync protocol, so client-generated identifiers are not required; the primary key remains an ObjectId. Only `reminders.userId` was migrated to a String UUID to match `users._id`.
