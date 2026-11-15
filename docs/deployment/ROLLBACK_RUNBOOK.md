# Rollback Runbook

## When to roll back

- `/api/health` fails after deploy.
- Error rate spikes (Prometheus alert).
- Critical user-facing regression reported.

## Steps

1. Identify the last known good commit SHA (`git log --oneline`).
2. Run the **Rollback Production** workflow (`rollback.yml`) with that SHA.
3. The workflow creates a `rollback/<sha>` branch and triggers the Render deploy hook.
4. Wait for health check (up to 5 min).
5. Run smoke tests against production.
6. If DB migration ran, execute the down-migration.
7. Post an in-app announcement banner (see `AnnouncementBanner` widget).

## Verification

- `curl https://<backend>/api/health` returns 200.
- Smoke test suite passes.
- Grafana shows error rate back to baseline.

## Post-rollback

- File an incident report.
- Schedule a post-deployment review.
