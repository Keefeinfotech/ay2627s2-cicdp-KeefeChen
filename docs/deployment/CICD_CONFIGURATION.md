# CI/CD configuration reference

The workflows are fully versioned, but a few settings live in GitHub/Render and
must be configured once before the pipeline is operational. This is the single
checklist for a new environment.

> **Target architecture (enterprise):** Auxilia is moving to an **integrated Release Workflow** where **Production CD is a stage inside the release pipeline** (trigger → artifact promotion → staging deploy/verify → approval gate → production CD → post-deploy verify → rollback). See [RELEASE_WORKFLOW_INTEGRATED.md](./RELEASE_WORKFLOW_INTEGRATED.md) for the full design, stages, responsibilities, and Mermaid diagram.

## 1. Repository settings

Run with an admin token (see [scripts/configure-branch-protection.sh](../../scripts/configure-branch-protection.sh)):

```bash
GH_TOKEN=<admin-token> ./scripts/configure-branch-protection.sh
```

This requires `CI - Final Quality Gate`, 1 approving review, up-to-date branches,
and no force-push/deletion on `main` and `develop`.

## 2. Repository variables and secrets

| Scope | Name | Purpose |
|---|---|---|
| Repository variable | `FRONTEND_API_BASE_URL` | API origin baked into published web images (defaults to the production backend URL) |
| Repository variable | `TURNSTILE_SITE_KEY` | Public site key passed to the web image build (empty disables CAPTCHA locally) |
| Repository variable | `LAST_GOOD_SHA` | Written automatically by deploy workflows; do not set manually except during incident recovery |
| Repository secret | `RENDER_API_KEY` | Optional; required for exact-SHA deploys. Grant deploy permission only. |
| Environment `production` variable | `RENDER_SERVICE_ID` | Backend service id for the Deploy API |
| Environment `production` variable | `RENDER_API_BASE_URL` | Public health/smoke target |
| Environment `production` secret | `RENDER_API_KEY` | Preferred: deploy the exact CI SHA |
| Environment `production` secret | `RENDER_DEPLOY_HOOK_URL` | Fallback when the API key is absent |
| Environment `staging` | same four names | Point at `auxilia-backend-staging`, never the production service |

Environment-scoped values override repository-scoped ones, so staging and production cannot share a deploy hook or base URL. Add required reviewers to the `production` environment in **GitHub Settings → Environments** (required for the integrated release approval gate).

## 3. Deploy paths (current)

1. **Combined Release + CD (recommended for releases):** push tag `vX.Y.Z` → `.github/workflows/release.yml` runs verify/build/package → publishes GitHub Release (SBOM/provenance) → deploys the same SHA to **staging** → smoke → **production deploy after `production` Environment approval** → smoke → records `LAST_GOOD_SHA` / auto-rollback on failure.
2. `promote.yml` deploys an explicit SHA to a selected environment (`staging` or `production`) with environment-scoped settings (ad hoc/manual promotion).
3. `rollback.yml` restores a specified good SHA to an environment with verification.
4. `publish-image.yml` builds immutable SHA-tagged GHCR images to support artifact/digest promotion.
5. `.github/workflows/deploy-production.yml` is **manual only** (`workflow_dispatch`) for emergency use (does not auto-run on CI success on `main`).

See [RELEASE_WORKFLOW_INTEGRATED.md](./RELEASE_WORKFLOW_INTEGRATED.md) for the full target/stage model.

## 4. First-time verification (staging + rollback rehearsal)

- Run `promote.yml` against **staging** with a known-good SHA; confirm healthy and smoke passes.
- Run `rollback.yml` against **staging** to the previous SHA (rollback rehearsal).
- Validate failure handling in a non-production environment before relying on automated rollback in production.
- Configure monitoring/alerts per `monitoring/README.md` and the operations runbook.