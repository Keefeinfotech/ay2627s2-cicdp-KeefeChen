# Rollback Runbook

## When to roll back

- `/api/health` fails after deploy.
- Error rate spikes (Prometheus alert).
- Critical user-facing regression reported.

## Steps

1. Identify the last known good commit SHA. The deploy workflow records it in
   the `LAST_GOOD_SHA` repository variable after every successful smoke run.
2. Run the **Rollback Production** workflow (`rollback.yml`) with:
   - `commit_sha`: the last known good SHA,
   - `environment`: `production` (or `staging`),
   - `reason`: the incident reference.
3. The workflow calls Render's Deploy API with that exact commit, so the
   service is restored to the revision that passed CI. It no longer pushes a
   `rollback/<sha>` branch or relies on a deploy hook that deploys `main` HEAD.
4. The workflow polls `/api/health` for up to 10 minutes and then runs
   `node scripts/smoke-test.mjs <base-url>`. Both must pass.
5. If a data migration ran, restore the pre-migration snapshot if required and
   revert it explicitly with
   `npm run migrate:down -- <migration-id> --confirm` (see
   [backend/scripts/migrations/README.md](../../backend/scripts/migrations/README.md)).
6. Post an in-app announcement banner (see `AnnouncementBanner` widget).

Production deploys that fail health/smoke trigger `rollback.yml` automatically
with the recorded `LAST_GOOD_SHA`. Check the Rollback Production run to confirm
it completed.

## Verification

- `curl https://<backend>/api/health` returns 200.
- Smoke test suite passes.
- Grafana shows error rate back to baseline.

## Post-rollback

- File an incident report.
- Schedule a post-deployment review.
- Rehearse this runbook against staging at least once per release cycle.
