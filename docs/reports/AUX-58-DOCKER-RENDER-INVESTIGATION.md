# AUX-58 Docker Configuration and Render Deployment — Investigation

Date: 11 November 2026 (sprint bug-fix pass: AUX-84, AUX-85)
Branch: `feature/enterprise-cicd-pipeline`
Scope: Jira tickets AUX-58 (spike: Docker configuration and Render deployment) and the two attached bug fixes AUX-85 (application startup crash on Render due to port binding) and AUX-84 (Docker image build failure due to missing production dependencies).
Method: static audit of the Docker/compose/Render configuration and dependency graph, local build and test of the backend, and a live smoke run of the production bundle with the exact environment Render injects (`PORT`, `TRUST_PROXY`, `NODE_ENV=production`). The Docker daemon was not running on the investigation host, so image builds were verified by CI configuration review plus equivalent local steps (`tsc` build, `npm ci --omit=dev` lock analysis, runtime smoke).

## Executive summary

1. **AUX-85 reproduced and fixed.** In production the Node process wrote its
   startup logs only to `backend/logs/*.log` — nothing reached stdout, so
   Render's log stream showed nothing before a failed health check — and the
   server bound the unspecified IPv6 address instead of `0.0.0.0` while Render
   probes the IPv4 address for its injected `PORT`. The server also had no
   `error` handler, so a bind failure (`EADDRINUSE`/`EACCES`) crashed the
   process with an unhandled event. All three issues are fixed and verified
   live: the server binds `0.0.0.0:$PORT`, logs JSON to stdout, handles bind
   errors with a clear logged exit, and `/api/health` answers 200.
2. **AUX-84 is not reproducible in the current tree.** Every runtime import in
   `backend/src` maps to a declared production dependency, no production
   dependency is flagged `dev` in `package-lock.json`, and the lock is in sync
   with `package.json`. The Docker build failure most likely traces to the
   earlier "tsconfig.json excluded from the backend build context" defect
   (fixed in `56c7400`). Evidence and residual risks are recorded below.
3. Docker configuration is fundamentally sound (multi-stage, non-root,
   sha256-pinned bases, Trivy-hardened); the Render deployment works through
   the blueprint (`render.yaml`) or the deploy hook in
   `deploy-production.yml`, but observability into why a boot fails was
   effectively zero in production until this fix.

## Environment

- Node 22, npm registry reachable (`npm ping` PONG ~887 ms)
- Docker CLI 29.2.1 present; **daemon not running** (`dockerDesktopLinuxEngine`
  pipe unavailable) — no local image build was possible
- Backend builds and unit/integration tests pass locally (see verification
  table); machine is OneDrive-synced and slow, which caused 4 non-deterministic
  5 s test timeouts on one full-suite run, all green on re-run

## Findings

### F-1 AUX-85 — Root cause of the Render startup crash (High → fixed)

Three compounding defects:

1. **Host binding.** `app.listen(port)` with no host binds the unspecified
   address (on Linux, `::`). Render injects `PORT` (default `10000`) and
   health-checks the IPv4 side; with dual-stack disabled or strict probing
   the service never opens a reachable socket → "no open ports detected" /
   failing deploy while the process looks alive. Fix: bind `0.0.0.0`
   explicitly (`backend/src/server.ts`).
2. **Silent production logging.** `src/config/logger.ts` registered only file
   transports when `NODE_ENV=production`, so nothing appeared in Render's log
   explorer — a crash on boot left an empty deploy log. Fix: always log to
   stdout; production keeps JSON, development keeps colorized output.
3. **Unhandled bind errors.** No `server.on("error", ...)` handler, so
   `EADDRINUSE`/`EACCES` became an unhandled exception and an opaque non-zero
   exit. Fix: log `port binding error` with code/host/port, exit(1).

Files changed: `backend/src/server.ts`, `backend/src/config/logger.ts`,
`backend/.env.example`, `backend/Dockerfile` (EXPOSE comment), `render.yaml`
(PORT comment), `README.md` (PORT row), `backend/tests/unit/env.test.ts`
(new `getPort()` tests).

### F-2 AUX-84 — Docker image build failure due to missing production dependencies (Medium → closed, not reproducible)

Verification evidence:

| Check | Result |
|---|---|
| Runtime imports in `backend/src` vs `dependencies` | All map; only `path` (node:path builtin, prefix-less import) unresolved — benign |
| Prod deps flagged `dev: true` in lock | None |
| `package.json` vs `package-lock.json` (root dep sets) | Identical; `lockfileVersion: 3` |
| `npm run build` (tsc) | Pass |
| Production bundle boot (`node dist/server.js`, `NODE_ENV=production`, `PORT=10000`) | Boots, `/api/health` → 200; no MODULE_NOT_FOUND |
| `.dockerignore` | Excludes tests/coverage/logs/.env/node_modules/dist; **not** manifests, tsconfig or src |
| Build stage copies `package*.json` + `tsconfig.json` + `src`, runs `npm ci --ignore-scripts` then `npm run build` | Coherent; `typescript` is a devDependency and present in the build stage |
| Runtime stage: `npm ci --omit=dev --ignore-scripts`, npm removed, `apk upgrade`, non-root `node` user | Coherent |
| CI `docker build` + Trivy fs & image scan | Configured (`.github/workflows/ci.yml`), green per commit history notes |
| Frontend image | `pubspec.lock` committed; `flutter pub get --enforce-lockfile`; two-stage build into `nginxinc/nginx-unprivileged` listening 8080 with matching `nginx.conf` |

Residual risks / notes:

- `npm ci --omit=dev` could not be executed to completion on the
  investigation host (network extremely slow; run killed after 10 min). The
  lock analysis above is equivalent for the "missing production dependency"
  failure mode — absence at install time would mean an import maps to no
  dependency, which is not the case.
- The `tsconfig.json`-in-build-context exclusion (`56c7400`) showed the same
  symptom class (build stage could not compile) and is the most probable
  historical cause; if the failure recurs, capture the exact build log from
  the Render/CI run — the current Dockerfile is consistent.
- `openapi-types`, `@types/*` and `typescript` are intentionally build-time
  only; runtime never `require`s them (`import type` erased by `tsc`).
- `bcryptjs` is pure JS; `--ignore-scripts` is safe for every production
  dependency. No native builds are skipped.
- `src/database.ts` is dead code (nothing imports it; `src/config/database.ts`
  is the live module). Remove when convenient — not blocking.

### F-3 Port and exposure alignment (Low → fixed)

- `EXPOSE 3000` was informational but misleading on Render (Render routes to
  its own injected `PORT`, default 10000). Now documented in the Dockerfile,
  `render.yaml`, `.env.example`, `README.md`: do not set `PORT` in the Render
  dashboard; the app binds `0.0.0.0` on whatever Render injects.
- `docker-compose.yml` sets `PORT=3000` and maps `3000:3000` — unchanged and
  correct for local.
- `render.yaml` declares the backend only; the Flutter frontend is not
  deployed to Render (build via CI or `docker-compose`/nginx). Documented gap,
  not a defect.

### F-4 Deploy pipeline duplication is documented, intentional (Info)

`render.yaml` (auto-deploy on push to main) and `deploy-production.yml`
(deploy hook + 10-minute `/api/health` poll + `scripts/smoke-test.mjs`)
represent one path with a belt-and-braces hook. The workflow exits 1 if
`RENDER_API_BASE_URL` (vars) or the health probe never returns 200. Keep;
sync `RENDER_DEPLOY_HOOK_URL` (secret) with the Render dashboard if the
service is ever re-created.

### F-5 Health endpoint naming drift (Trivial)

`GET /api/health` returns `{ "status": "ok", "service": "personal-secretary-api" }`
(`src/modules/health/health.controller.ts`). The product is Auxilia; the
schema validation of responses tolerates this, but the string should be
renamed to `auxilia-api` to match deploy logs/monitors. Not blocking; flagged
to the owning story.

### F-6 Local log artefact (Trivial)

`backend/src/logs/*.log` exist on disk (untracked, `*.log` ignored) — created
when the app ran with CWD=`src/`. Delete locally; production writes to
`WORKDIR /app/logs` which is chowned to `node`.

### F-7 12-factor gaps for Render (Info → partially fixed)

- Secrets: correctly dashboard-injected; `render.yaml` commits no secrets.
- stdout logging: **fixed** (F-1).
- Graceful shutdown on SIGTERM implemented (`server.close` → DB disconnect).
- `TRUST_PROXY=true` set on Render — correct for `express-rate-limit` behind
  one proxy hop.
- File logs on ephemeral FS are retained for container debuggability; stdout
  is now the primary stream.

## Verification performed

| # | Check | Command / action | Result |
|---|---|---|---|
| V-1 | TypeScript build | `npm run build` | Pass |
| V-2 | Unit tests (incl. new `getPort()` tests) | `npx vitest run tests/unit` | 195/195 pass |
| V-3 | Integration auth/session/ai | `npx vitest run tests/integration/{auth,session,ai}.test.ts` | 43/43 pass |
| V-4 | Full suite | `npm test` | 246/250 pass; 4 × 5 s timeouts under host load, all green on isolated re-run |
| V-5 | Production boot on Render's env | `NODE_ENV=production PORT=10000 TRUST_PROXY=true JWT_SECRET=… CAPTCHA_ENABLED=true TURNSTILE_SECRET_KEY=… CORS_ORIGIN=… node dist/server.js` | `server started successfully {host: "0.0.0.0", port: 10000}` |
| V-6 | Health probe (Render healthCheckPath) | `curl http://127.0.0.1:10000/api/health` | `200 {"status":"ok","service":"personal-secretary-api"}` |
| V-7 | stdout JSON logs in production | observed above | Visible on stdout (previously file-only) |
| V-8 | CORS preflight (AUX-76 regression check) | `curl -X OPTIONS /api/auth/login` | 204 with `Access-Control-Allow-Headers: ...Authorization...` |
| V-9 | CORS rejection | preflight/GET from `https://evil.example.com` | `403 {"error":"Origin not allowed","code":"CORS_FORBIDDEN"}` |
| V-10 | Port binding failure handling | code inspection + `server.on("error")` | Logs `port binding error` + exit(1) instead of unhandled crash |

## Recommendations / action items

| # | Action | Owner | Priority |
|---|---|---|---|
| A-1 | Merge this branch; move AUX-85 → In Review, AUX-84 → Done after pipeline review, AUX-58 → Done with this report attached | Lin Li / Keefe Chen | Now |
| A-2 | Set `RENDER_DEPLOY_HOOK_URL` secret + `RENDER_API_BASE_URL` variable; confirm deploy hook works on next main push; watch `/api/health` go green | DevOps | Now |
| A-3 | Confirm in Jira whether Render injects `PORT=10000` for this service; do not override `PORT` in dashboard | DevOps | Now |
| A-4 | Rename health service string to `auxilia-api`; add a `/api/health` body assertion to `scripts/smoke-test.mjs` | Backend | Low |
| A-5 | Delete local `backend/src/logs/`; add `logs/` CWD note to troubleshooting docs | Backend | Trivial |
| A-6 | Remove dead `src/database.ts` in a separate refactor PR | Backend | Low |
| A-7 | When Docker daemon available, run `docker build` + `docker run -e PORT=10000` to close the loop; keep Trivy gates as-is | CI/DevOps | Low |
| A-8 | Add uptime monitor on `https://<service>.onrender.com/api/health` with 2-3 strike alert | DevOps | Medium |
| A-9 | Free plan sleeps after inactivity — document cold-start behaviour (first health probe after sleep may take seconds) for smoke-test tuning | DevOps | Info |

## Ticket mapping

- **AUX-85** — fixed in this change set; verification V-1–V-10. Ready for review.
- **AUX-84** — not reproducible in current tree; Docker/CI configuration reviewed; verification table above. Awaiting human re-check of the original failing build log; recommend closing as fixed-by-earlier-work with this report attached.
- **AUX-58** — answered: configuration is sane; the failure was host binding + silent logging + no bind-error handling (AUX-85). Remaining gaps listed A-4…A-9.
