# OWASP Top 10 Security Assessment - Auxilia

**Assessment date:** 2026-11-17 · **Assessor:** engineering (internal)
**Scope:** `backend/` (Express 5 + Mongoose), `frontend/` (Flutter web + native),
`e2e/` (Playwright), `.github/workflows/`, `docker-compose.yml`, Render deployment.

This document is the enterprise-level security evaluation for the current tree.
It supersedes the 2026-10-24 version of this file, which contained several
claims that are no longer accurate (password reset, refresh-token rotation,
MFA back-end and release signing all shipped after that review).

Statuses follow OWASP conventions: **Strong** (evidenced in production),
**Adequate** (implemented, residual gaps listed), **Weak** (not implemented or
no evidence). Every claim points at the code or the artifact that proves it.

---

## A01 - Broken Access Control - **Strong**

Evidence:

- Ownership is enforced server-side, not by the client: every task/group/admin
  query is scoped by `userId` taken from the **verified session**
  (`middleware/authenticate.ts`, `task.repository.ts`, `groups` module).
- RBAC is centralised: `USER_ROLES = ["user", "admin"]`
  (`constants/security.ts`); `authorize()` compares roles case-insensitively
  and reads the role from the database, never from request input
  (`middleware/authorize.ts`).
- `/metrics` accepts either an administrator session or a `METRICS_TOKEN`
  bearer (`modules/metrics`); admin routes (`/api/admin/*`) and
  `/api/feedback/analytics/*` are `authorize("admin")`-guarded.
- Server-side guards: self-deactivation (`SELF_DEACTIVATION`), last active
  admin (`LAST_ADMIN`), admin projections exclude `passwordHash`, MFA secret
  and refresh material (`SAFE_USER_FIELDS`, `admin.repository.ts`).
- Client-side `Session.isAdmin` is UI gating only; every admin endpoint
  re-checks server-side.
- CI E2E asserts anonymous access to protected endpoints returns 401 and
  unknown routes return a structured 404 (`e2e/tests/api-blackbox.spec.ts`).

Residual risks:

- Group authorization is owner/member only; no granular Editor/Viewer roles
  (tracked as BACKLOG-11).
- Frontend route hiding is cosmetic; server enforcement is the boundary and
  is relied upon everywhere (no bypasses known).

## A02 - Security Misconfiguration - **Adequate**

Evidence:

- Backend `helmet` (`config/security.ts`): HSTS `max-age=15552000`
  (includeSubDomains; preload in production), `X-Content-Type-Options: nosniff`
  (via Helmet), `x-powered-by` disabled, `X-Frame-Options: SAMEORIGIN` (API
  JSON responses), structured CSP on the API, error bodies strip 5xx internals.
- Frontend `nginx.conf` serves the web build with a **strict** CSP
  (`default-src 'self'`; `script-src 'self' 'wasm-unsafe-eval' challenges.cloudflare.com gstatic`; `object-src 'none'`; no `unsafe-inline` scripts),
  `X-Frame-Options: DENY`, `nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`.
- `TRUST_PROXY=true` only in production; `assertRuntimeEnv` (`config/environment.ts`)
  **fails boot** in production if `JWT_SECRET` is under 16 chars, `CORS_ORIGIN`
  is unset, `CAPTCHA_ENABLED` is not `true`, or `CAPTCHA_ENABLED=true` without
  `TURNSTILE_SECRET_KEY`.
- `.dockerignore`/Dockerfile keep `.env` and dev files out of images; runtime
  stage runs unprivileged (`USER node`); npm is removed from the runtime layer.
- `.env.example` ships placeholders only; `.env` is gitignored; the 5 stray
  tracked `node_modules` files are being removed (see hygiene PR).

Residual risks:

- CSP is not enabled on the API layer in development (by design, for DX).
- `X-Frame-Options` differs between API (`SAMEORIGIN`) and web (`DENY`) - both
  intentional; do not unify without a product decision.
- CSP `style-src 'unsafe-inline'` is required by Flutter web and cannot be
  tightened without a build change.

## A03 - Software Supply Chain Failures - **Adequate**

Evidence:

- All GitHub Actions in `ci.yml` / `release.yml` are pinned to full commit
  SHAs (`actions/checkout`, `gitleaks`, `setup-node`, `sbom-action`).
- `npm audit --audit-level=high` runs in CI; **production dependencies: 0
  vulnerabilities** (verified 2026-11-17). Residual dev-only moderate advisories
  exist in the jest/eslint/glob chain (18); they are build tooling, not shipped.
- Dependabot is configured and open PRs land regularly; 2 open alerts at
  assessment time (1 moderate dev-only `minimatch`; 1 `deepmerge` advisory was
  **withdrawn** by the reporter).
- `release.yml` generates an **SBOM** (Syft, SPDX JSON) and **attests build
  provenance** (`actions/attest-build-provenance`); versions re-verified
  against tag/pubspec/package.json before packaging.
- Trivy gate blocks HIGH/CRITICAL in the runtime image; Gitleaks job in every
  CI run; Dependabot preview of new action versions.

Residual risks:

- No container image signing (web build is attested; images are not).
- `npm audit` is advisory on transitive dev packages.

## A04 - Cryptographic Failures - **Adequate**

Evidence:

- Passwords: bcrypt, rounds clamped to [10, 15] (`getBcryptRounds`); hash never
  leaves the repo layer (`select: false`); responses never include it.
- Access tokens: HS256, issuer `auxilia-api`, `jti` = session id, TTL 15m.
- Refresh tokens: opaque `sessionId.secret`; only `sha256(secret)` persisted;
  **rotated on every refresh**; replay of a superseded token outside a 10s
  grace window revokes the whole session (theft detection); session expiry via
  TTL index; `SESSION_CACHE_TTL_MS` (default 30s) bounds revocation propagation.
- MFA: TOTP backend implemented (`otplib`, `MFA_ENCRYPTION_KEY` at rest).
- Frontend stores tokens in `flutter_secure_storage`, never in shared
  preferences; HTTP-only Bearer transport means CSRF does not apply.

Residual risks:

- HS256 (shared secret) rather than RS256; an asymmetric setup is the target
  state but requires key distribution and invalidates only on rotation.
- No key-rotation drill evidence for `JWT_SECRET` / `MFA_ENCRYPTION_KEY`.
- No encryption at rest beyond the database vendor's defaults.

## A05 - Injection - **Strong**

Evidence:

- Every HTTP body/query/param validated with Zod (`validateRequest`) or
  express-validator (calendar routes, enforced by middleware); Mongo documents
  are schema-shaped; unknown fields rejected (`.strict()`).
- NoSQL injection is pinned as a regression test (`tests/regression`); text
  search escapes input; `findByIdForUser`-style dual filters everywhere.
- No eval / dynamic require of user input anywhere in `src/`.
- Frontend text rendering is Flutter-native (no `dangerouslySetInnerHTML`);
  web build runs under the strict CSP above.

Residual risks:

- Three response envelopes coexist (drift risk; tracked, not exploitable).
- Deep-link query params are not schema-validated at the router edge.

## A06 - Insecure Design - **Adequate**

Evidence:

- Deliberate least-privilege: `ADMIN`-only aggregates (no user reading of
  others' tasks); admin UI can disable accounts but cannot read tasks.
- Offline-first design is explicit and documented; guest mode cannot sync;
  onboarding shown once and persisted.
- Signup/login rate-limited; CAPTCHA (Cloudflare Turnstile) required in
  production and **enforced at boot**; timing-safe password comparison even
  for missing users; anti-enumeration on password reset (single-use 30-min
  token, generic 200 response; link only ever logged in non-production).
- Session model: one row per device; newest login wins; single-session
  semantics documented and tested.

Residual risks:

- Guest/offline mode bypasses auth by design (documented; local-only data).
- MFA enrollment has a backend but no in-app UX (BACKLOG-7).
- No account lockout after N failures (see A07).

## A07 - Identification & Authentication Failures - **Adequate**

Evidence:

- Brute force: `authRateLimiter` (default 10/15min; `AUTH_RATE_LIMIT_MAX`
  overridable), global API budget 300/15min, AI budget 20/user/hour.
- No account enumeration: identical message for bad user vs bad password;
  login failure count + `refresh_failed` / `login_failed` events logged with
  `requestId`.
- Refresh token reuse outside grace revokes the session (theft handling).
- Password reset: single-use, time-limited, hashed at rest; delivery is
  best-effort and cannot be used to probe account existence.
- MFA TOTP (authenticator apps) supported server-side.

Residual risks:

- No lockout/backoff counter on the account itself (limiter is per-IP/global).
- MFA cannot be turned on from the app yet (BACKLOG-7).
- Password policy is length-only (12+ chars); no breach corpus check.

## A08 - Software or Data Integrity Failures - **Adequate**

Evidence:

- Release pipeline signs provenance (attestation + SBOM, see A03); tagged
  releases are byte-reproducible in packaging order; `release.yml` re-runs all
  quality gates before publishing.
- Rollback workflow exists and is triggered manually with a SHA input;
  `scripts/smoke-test.mjs` validates the deployed bundle read-only.
- All third-party actions are SHA-pinned (eliminates supply-chain re-tag risk).

Residual risks:

- Container images are not signed (no cosign/sigstore verification at deploy).
- Rollback was **never rehearsed** against production; evidence template in
  `RELEASE_EVIDENCE_v1.0.0.md` is unfilled.
- No signed commits policy; maintainer key management undocumented.

## A09 - Security Logging & Monitoring Failures - **Adequate**

Evidence:

- Structured JSON logs to stdout (12-factor, Render-compatible); request id on
  every request (`middleware/requestId.ts`).
- Security event log (`shared/utils/securityLogger.ts`) with stable event
  names: `login_failed`, `refresh_failed`, `auth_failed`, `session_replaced`,
  `session_revoked_via_api`, `signup_conflict` - includes IP, path, requestId;
  never credentials, never TOTP.
- Audit module (`modules/audit`) records security-relevant domain events.
- Prometheus `/metrics` (guarded by `METRICS_TOKEN` or admin session) with
  alert rules: 5xx rate > 5% for 2m (critical), p95 latency > 1s for 5m
  (warning), backend down (critical). Grafana dashboard shipped in
  `monitoring/` with Compose profile.

Residual risks:

- **Alerts have no delivery path** - `prometheus-alerts.yml` contains rules,
  but no Alertmanager/PagerDuty/Slack routing is configured; alerts fire into
  the void.
- File log transports have no rotation; stdout capture relies on the platform.
- No centralized log retention SLA or PII redaction policy file (passwords are
  never logged; emails are partially logged on failure events).

## A10 - Mishandling of Exceptional Conditions - **Adequate**

Evidence:

- One centralized error handler (`middleware/errorHandler.ts`) maps every
  failure to `{ error, code, details? }`; `AppError` for expected failures,
  Mongoose validation to 400, JSON parse to 400, payload too large to 413, all
  else to 500 with server-side logging only (stacks never reach the client).
- Frontend: structured `ApiException` with retry/session-refresh semantics;
  `AppErrorState` / empty states everywhere; offline mode degrades gracefully.
- Smoke test and E2E assert error responses never leak stack traces.

Residual risks:

- Multi-document writes are not uniformly transactional (signup → user +
  session write is ordered but not wrapped in a Mongo session transaction).

---

## Enterprise priority actions

| # | Action | Effort | Why |
|---|---|---|---|
| 1 | Enable branch protection: require 1 review + `CI - Final Quality Gate`, block force-push | minutes | Stops unreviewed merges; closes A08 gap |
| 2 | Wire Prometheus alerts to a real destination (email/Slack/PagerDuty) | 1h | A09: alerts currently fire nowhere |
| 3 | Rehearse rollback; fill `RELEASE_EVIDENCE_v1.0.0.md` | 1h + prod window | A08: documented but never executed |
| 4 | MFA enrollment UI (BACKLOG-7) + account lockout counter | 1-2d | A07 |
| 5 | RS256 JWT migration or documented rotation drill for `JWT_SECRET` / `MFA_ENCRYPTION_KEY` | 1d | A04 |
| 6 | Envelope unification + contract tests in CI | 1-2d | A05/A06 drift risk |
| 7 | Sentry or equivalent exception grouping | 0.5d + token | A09 |
| 8 | Sign container images (cosign) and verify at deploy | 0.5d | A03/A08 |
