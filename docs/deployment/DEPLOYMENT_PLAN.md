# Deployment Plan — Auxilia

## Timeline (milestones)

| Phase | Owner | Target |
|---|---|---|
| 1. Staging deploy (auto on PR merge to `develop`) | DevOps | T+0 |
| 2. Smoke tests on staging | QA | T+15m |
| 3. Manual approval (GitHub Environment) | Release manager | T+30m |
| 4. Production deploy (Render backend + static frontend) | DevOps | T+45m |
| 5. Health check + smoke tests | QA | T+60m |
| 6. Post-deployment review | Team | T+1d |

## Resource allocation

- **DevOps**: pipeline, Render, secrets, rollback
- **Backend dev**: migrations, API compatibility
- **Frontend dev**: build, CDN, a11y
- **QA**: smoke/e2e tests, monitoring dashboards

## Risk management

| Risk | Mitigation |
|---|---|
| Bad migration | Reversible migrations; backup before deploy |
| Secret leak | GitHub Secrets + Render env; gitleaks in CI |
| Frontend/backend version skew | API versioning; backward-compatible changes |
| Free-tier cold start | Health-check retry loop (30x) |

## Rollback procedures

1. Trigger `rollback.yml` with the previous commit SHA.
2. Re-deploy backend via Render deploy hook.
3. If DB migration ran, run the down-migration.
4. Verify `/api/health` and smoke tests.
5. Notify users via in-app banner.

See `docs/deployment/ROLLBACK_RUNBOOK.md`.
