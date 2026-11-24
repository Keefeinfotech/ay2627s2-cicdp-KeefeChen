# Deployment Plan - Auxilia

## Integrated Release Workflow (target)

Production delivery is performed inside the **Release Workflow** (not as a disconnected automation): **Release Trigger → Artifact Promotion (same SHA/digest) → Staging Deployment → Staging Verification → Release Approval/Gate → Production Deployment (CD) → Post-Deployment Verification → Rollback/Recovery**. See [RELEASE_WORKFLOW_INTEGRATED.md](./RELEASE_WORKFLOW_INTEGRATED.md) for the full architecture, Mermaid diagram, and responsibilities.

## Timeline (milestones) — example release window

| Phase | Owner | Target |
|---|---|---|
| 1. Release trigger + artifact promotion (tag/approved RC, CI green) | Release manager / automation | T+0 |
| 2. Staging deploy (same promoted artifact/SHA) | DevOps / automation | T+10m |
| 3. Staging verification (health + smoke + integration checks) | QA / automation | T+25m |
| 4. Release approval (GitHub Environment gate) | Release manager | T+40m |
| 5. Production CD (same artifact, no rebuild) + post-deploy verification | DevOps / automation + QA | T+60m |
| 6. Post-deployment review / monitoring watch | Team | T+1d |

> **Current state note:** Some repositories may still run a separate “deploy after CI on main” job; the target is consolidation into the Release Workflow for all formal releases (emergency hotfixes may follow a documented break-glass path).

## Resource allocation

- **DevOps**: pipelines, Render/GH environments, secrets, rollback execution
- **Backend dev**: migrations, API compatibility
- **Frontend dev**: build integrity, environment config (`API_BASE_URL`), accessibility checks
- **QA**: staging/production smoke, E2E/regression evidence, monitoring validation

## Risk management

| Risk | Mitigation |
|---|---|
| Bad migration | Reversible migrations where possible; backup before deploy; verify validators |
| Secret/config drift | GitHub/Render secret managers; environment separation; startup env validation |
| Frontend/backend version skew | Promote same SHA; API compatibility discipline; versioned releases |
| Free-tier cold start / deploy latency | Bounded health polling; clear timeouts; documented retry behavior |
| Unauthorized production change | Required reviewers on `production` environment; protected branches; auditable workflow logs |

## Rollback procedures

1. Trigger `rollback.yml` (manual) with the previous known-good commit SHA, or rely on automated rollback from the Release Workflow on prod deploy/smoke failure (where enabled).
2. Redeploy the pinned good SHA via Render Deploy API (environment-scoped).
3. If a migration ran and is unsafe to roll forward, apply the documented down-migration procedure.
4. Verify `GET /api/health` and run `scripts/smoke-test.mjs` against the restored environment.
5. Communicate impact internally; update incident notes and `LAST_GOOD_SHA` if needed.

See `docs/deployment/ROLLBACK_RUNBOOK.md` (and `docs/operations/MONITORING_RUNBOOK.md`).
