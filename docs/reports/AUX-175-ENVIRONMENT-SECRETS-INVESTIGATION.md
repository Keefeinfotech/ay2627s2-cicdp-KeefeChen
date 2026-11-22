# AUX-175 Environment Variable & Secrets Management — Investigation

Date: 21 November 2026
Tree reviewed: `main` at `78582a0` (sprint NP-S3: Testing & Render, 17–25 Nov)
Toolchain: Node 22.14.0, npm 10.9.2, Vitest 5.1.0
Method: static audit of every environment/secrets touchpoint (source, templates,
compose, Render blueprint, CI workflows, git index) plus targeted unit tests
for the backend configuration module.

## Executive summary

1. **No secret value is committed.** The git index contains only the two
   `.env.example` templates; real `.env` files are ignored by `.gitignore`.
   Render receives all sensitive values through dashboard-injected environment
   variables declared `sync: false` in `render.yaml`; no literal appears in the
   blueprint. CI uses GitHub Secrets for the deploy hook and Sonar token.
2. **Startup fails fast with actionable errors.** `assertRuntimeEnv()` is
   called before the server listens and aggregates *all* configuration problems
   into a single `EnvError`, so a misconfigured deploy shows the full fix list
   in one Render log instead of failing silently. The new unit tests (V-3) cover
   both the happy path and four failure modes.
3. **Configuration access is centralised and defensively typed.**
   `backend/src/config/environment.ts` is the single reader of `process.env`,
   with validation/clamping for port, bcrypt rounds, token TTLs, rate limits,
   session cache TTL and AI settings. No module reads secrets ad hoc except the
   accessor module.
4. **One low-severity residual risk (R-1):** `docker-compose.yml` still carries
   a *development-only* fallback for `JWT_SECRET`. It cannot affect production
   (Render injects the real value), but it was reintroduced after an earlier
   cleanup and may be flagged by SonarCloud rule S2068. Recommended follow-up
   is documented below; it does not block closing this investigation.

## Current design

| Layer | Mechanism | Evidence |
|---|---|---|
| Local templates | Root `.env.example` points developers to `backend/.env.example`; the backend template documents every variable with placeholders (`REPLACE_ME`) and empty values for real secrets | `backend/.env.example` |
| Local runtime | `docker-compose.yml` injects configuration explicitly; `JWT_SECRET` is read from the host environment / `.env` | `docker-compose.yml` lines 92–112 |
| Application | `backend/src/config/environment.ts` — typed getters with safe defaults; `getJwtSecret()` enforces a minimum 16-character secret; `assertRuntimeEnv()` validates the full production contract | `environment.ts` lines 1–189 |
| Startup gate | `assertRuntimeEnv()` runs in `server.ts` before binding the port | `backend/src/server.ts` lines 14, 27 |
| Production (Render) | `render.yaml` declares `MONGODB_URI`, `JWT_SECRET`, `CORS_ORIGIN`, `TURNSTILE_SECRET_KEY` as `sync: false` (prompted in dashboard, never stored in git); non-secrets `NODE_ENV`, `TRUST_PROXY`, `CAPTCHA_ENABLED`, `AI_PROVIDER` are pinned publicly. `PORT` is injected by Render and not overridden | `render.yaml` lines 20–66 |
| Frontend build | Public `API_BASE_URL` and Turnstile **site** key are compile-time `--dart-define` values; the Turnstile **secret** key stays server-side | `render.yaml` lines 68–93; commit `fc35b8a` |
| CI/CD | Gitleaks secret scan on every PR (pinned image digest, `--redact`, exit 1 on finding); deploy hook and Sonar token supplied via GitHub Secrets; DAST job uses an explicitly `ci-test-only` JWT secret | `.github/workflows/ci.yml` lines 167–186; `deploy-production.yml` line 45; `dast.yml` line 30 |
| Version control | `.gitignore` ignores `.env` and `.env.*` with an explicit `!.env.example` allowlist | `.gitignore` |

## Findings

| # | Finding | Severity | Status |
|---|---|---|---|
| F-1 | No real `.env` or secret value is tracked; only `.env.example` files are committed | High | Verified — no action |
| F-2 | Secrets are dashboard/GitHub Secrets injected; `render.yaml` commits no literal secret values and uses `sync: false` for all four sensitive keys | High | Verified — no action |
| F-3 | Fail-fast startup validation aggregates all missing/invalid values; `.env.example` uses obvious placeholders | Medium | Verified — no action |
| F-4 | Public vs secret values are separated correctly (Turnstile site key is public, secret key server-side; `API_BASE_URL` is a public build argument) | Medium | Verified — no action |
| F-5 | `docker-compose.yml` line 101 uses `${JWT_SECRET:-auxilia-local-development-secret-change-me}` so a fresh clone boots without setup. Commit `5813d36` (10 Nov) removed the hard-coded dev default, but `81c0b86` (15 Nov) reintroduced one as a shell fallback. Production is unaffected, but the value is a literal credential-shaped string in a tracked file | Low | Residual risk R-1 — recommended follow-up |

## Verification performed

| # | Check | Command / action | Result |
|---|---|---|---|
| V-1 | Tracked environment files | `git ls-files \| Select-String '(^\|/)\.env'` | Only `.env.example` and `backend/.env.example` tracked; no real `.env` |
| V-2 | Ignore rules | Inspect `.gitignore` | `.env`, `.env.*` ignored; `!.env.example` re-includes only templates |
| V-3 | Configuration unit tests | `cd backend && npx vitest run tests/unit/env.test.ts` | **17 passed (17)** — 13 existing + 4 new `assertRuntimeEnv` tests added under this ticket |
| V-4 | Startup gate | Code review of `backend/src/server.ts` | `assertRuntimeEnv()` invoked before `app.listen(...)` |
| V-5 | Render blueprint | Static review of `render.yaml` | 4 secrets `sync: false`; no literal secret values; `PORT` left to Render |
| V-6 | CI secret scanning | Static review of `.github/workflows/ci.yml` | Gitleaks job pinned by digest, read-only mount, `--redact`, `--exit-code 1` |
| V-7 | Compose fallback | `git log -S "auxilia-local-development-secret-change-me"` | Reintroduced in `81c0b86`; documented as R-1 |

### Tests added under this ticket (test-only, no production changes)

`backend/tests/unit/env.test.ts` — new `describe("assertRuntimeEnv (AUX-175 startup gate)")`:
accepts a complete production configuration; aggregates all production problems
into one error; requires `TURNSTILE_SECRET_KEY` when CAPTCHA is enabled;
requires `AI_API_KEY` for a non-mock AI provider. `restoreEnv()` helper ensures
each test restores every variable it touches.

## Residual risk R-1 and recommendation

Remove the development fallback in `docker-compose.yml` (line 101):

```yaml
JWT_SECRET: ${JWT_SECRET}
```

and document that `JWT_SECRET` must be set in the local `.env` before
`docker compose up`. This restores the intent of `5813d36` and avoids
SonarCloud S2068 findings. It is deliberately **not** applied in this change
set: it alters the fresh-clone developer experience and belongs in a separate
compose-hygiene PR with a README update. Production is already correct because
Render injects a real secret and the blueprint declares it `sync: false`.

## Ticket mapping / closure recommendation

- **AUX-175** — investigation complete. All secrets handling reviewed, verified
  by 17 passing unit tests and static checks, with one low-priority,
  non-production follow-up recorded as R-1. Ready to move to **Done** with this
  report attached; R-1 should be raised as a separate low-priority ticket.
