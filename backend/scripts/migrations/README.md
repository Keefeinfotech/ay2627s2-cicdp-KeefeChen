# Versioned database migrations

The backend uses MongoDB with Mongoose schemas. Schema changes that need data
backfills or index changes must be expressed as a pair of reversible scripts so
rollback is a deliberate, testable operation instead of a runbook sentence.

## Adding a migration

1. Copy `_TEMPLATE.mjs` to `<sequence>-<short-name>.mjs`, e.g.
   `0002-add-task-index.mjs`.
2. Set a stable `id` and implement `up(db)` and `down(db)` as exact inverses.
3. Run `npm run migrate:status` locally, then `npm run migrate:up`.
4. Verify `npm run migrate:down -- 0002-add-task-index --confirm` in staging.

Applied migrations are recorded in the `migration_history` collection. The
runner refuses to guess a rollback target: the id and `--confirm` are required.

## Production procedure

1. Take a verified snapshot before any migration that writes data
   (`scripts/backup-database.sh`, or your provider's snapshot feature).
2. Deploy the code first (backward-compatible), then run `npm run migrate:up`
   against the target environment.
3. If a rollback is needed: restore service from the previous SHA first
   (`rollback.yml`), then revert the migration with
   `npm run migrate:down -- <id> --confirm`.
4. Re-run `node scripts/smoke-test.mjs <base-url>` after either direction.

Never run a destructive `down()` without a restorable backup. Prefer additive,
forward-only changes whenever the old code can tolerate the new shape.
