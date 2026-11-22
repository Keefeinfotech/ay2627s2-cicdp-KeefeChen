# CI/CD configuration reference

The workflows are fully versioned, but a few settings live in GitHub/Render and
must be configured once before the pipeline is operational. This is the single
checklist for a new environment.

## 1. Repository settings

Run with an admin token (see [scripts/configure-branch-protection.sh](../../scripts/configure-branch-protection.sh)):

```bash
GH_TOKEN=<admin-token> ./scripts/configure-branch-protection.sh
```

This requires `CI - Final Quality Gate`, 1 approving review, up-to-date branches
and no force-push/deletion on `main` and `develop`.

## 2. Repository variables and secrets

| Scope | Name | Purpose |
|---|---|---|
| Repository variable | `FRONTEND_API_BASE_URL` | API origin baked into published web images (defaults to the production backend URL) |
| Repository variable | `LAST_GOOD_SHA` | Written automatically by `deploy-production.yml`; do not set manually except during incident recovery |
| Repository secret | `RENDER_API_KEY` | Optional; required for exact-SHA deploys. Grant deploy permission only. |
| Environment `production` variable | `RENDER_SERVICE_ID` | Backend service id for the Deploy API |
| Environment `production` variable | `RENDER_API_BASE_URL` | Public health/smoke target |
| Environment `production` secret | `RENDER_API_KEY` | Preferred: deploy the exact CI SHA |
| Environment `production` secret | `RENDER_DEPLOY_HOOK_URL` | Fallback when the API key is absent |
| Environment `staging` | same four names | Point at `auxilia-backend-staging`, never the production service |

Environment-scoped values override repository-scoped ones, so staging and
production cannot share a deploy hook or base URL. Add required reviewers to the
`production` environment in GitHub Settings → Environments.

## 3. Deploy paths after this change

1. `CI` passes on `main` → `deploy-production.yml` deploys `github.sha` via
   Render's Deploy API (falls back to the hook), polls `/api/health`, runs
   `scripts/smoke-test.mjs`, and records `LAST_GOOD_SHA`.
2. Any failure triggers `rollback.yml` automatically with `LAST_GOOD_SHA`.
3. `promote.yml` deploys an explicit SHA to the selected environment with that
   environment's own service id/hook/base URL, then health-checks and smokes.
4. `publish-image.yml` builds immutable SHA-tagged GHCR images from the same
   revisions so deploys no longer depend on a fresh source build.

## 4. First-time verification

- Run `promote.yml` against **staging** with a known-good SHA and confirm the
  service becomes healthy and the smoke suite passes.
- Run `rollback.yml` against **staging** with the previous SHA. This is the
  rollback rehearsal required by the release evidence.
- Confirm a deliberately failing smoke triggers auto-rollback in a non-prod
  environment before relying on it in production.
- Configure production monitoring using [monitoring/README.md](../../monitoring/README.md#production-wiring)
  and verify a test alert reaches Slack.
