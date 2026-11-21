# Enterprise Auth Hardening - Auxilia

This documents the login/signup hardening added on `feature/enterprise-auth`.

## What was implemented

| Control | How it works | Where |
| --- | --- | --- |
| CAPTCHA (Cloudflare Turnstile) | Optional-by-default, enforced in production. Token verified server-side via Cloudflare `siteverify`. | `backend/src/utils/captcha.ts`, `backend/src/middleware/captcha.ts` |
| Single active session | Each login gets a unique JWT `jti`; only the newest `jti` is stored on the user. Older tokens return `SESSION_REPLACED`. | `backend/src/utils/session.ts`, `backend/src/middleware/authenticate.ts`, `backend/src/modules/auth/auth.service.ts` |
| Logout | Clears the stored session so the token cannot be reused. | `POST /api/auth/logout` |
| Current user | Session-aware identity endpoint. | `GET /api/auth/me` |
| CORS allow-list | Explicit origins, methods, headers and preflight cache. Unknown origins get `403 CORS_FORBIDDEN`. | `backend/src/app.ts`, `backend/src/config/security.ts`, `backend/src/middleware/errorHandler.ts` |
| Rate limiting | Auth endpoints are limited per IP; AI endpoints per authenticated user. | `backend/src/middleware/rateLimiter.ts`, `backend/src/modules/auth/auth.routes.ts`, `backend/src/modules/ai/ai.routes.ts` |
| Secure headers | `helmet` + `x-powered-by` disabled. | `backend/src/app.ts`, `backend/src/config/security.ts` |
| Proxy awareness | `TRUST_PROXY=true` so real client IPs are used behind Render/Cloudflare. | `backend/src/app.ts` |
| Startup validation | Production refuses to boot without CAPTCHA or CORS config. | `backend/src/config/environment.ts` |

## Configuration

```env
# Sessions
ALLOW_CONCURRENT_SESSIONS=false   # false = newer login signs older device out
TRUST_PROXY=true                  # behind a reverse proxy

# Cloudflare Turnstile
CAPTCHA_ENABLED=false             # forced true in production
TURNSTILE_SECRET_KEY=             # server only, never in the app
TURNSTILE_SITE_KEY=               # public, passed to Flutter at build time
```

Flutter build:

```bash
flutter run -d chrome --dart-define=TURNSTILE_SITE_KEY=<public-site-key>
```

Without the site key the client skips CAPTCHA, which matches local development.

## Why these choices

- **Turnstile over reCAPTCHA**: privacy-friendly, no user puzzles for most
  visitors, and a simple server verification call.
- **Single session by default**: matches common enterprise expectations and
  limits token replay. It is a config flag, not a hard architectural lock.
- **Fail closed**: if CAPTCHA is enabled but misconfigured, auth returns `503`
  instead of silently allowing traffic.
- **No secret in the app**: only the public site key ships with the client.

## Verified

```
backend  : npm run typecheck     -> clean
backend  : npm run test:coverage -> 90 passed (14 files), ~95% statements
frontend : flutter analyze       -> no issues
frontend : flutter test          -> 58 passed
```

## Token transport: Bearer vs cookies

**Decision (2026-11-17): keep HTTP `Authorization: Bearer` for all clients;
do not introduce session cookies.**

Rationale:

- **CSRF immunity by construction.** Bearer tokens are not attached by the
  browser automatically, so the entire CSRF class does not apply; no
  double-submit token, SameSite=strict/lax trade-offs, or origin-checking
  middleware is required.
- **Mobile-first client.** Flutter native apps cannot use cookies portably;
  a cookie path would create a second, browser-only auth mode to test and
  keep in sync. One transport, one security model.
- **Explicit, testable revocation.** The token carries `jti`; the server
  validates a revocable session per device (`authenticate.ts` +
  `session.cache.ts`, 30s bound); logout and refresh-reuse detection revoke
  server-side. This is the property that matters for theft response, and it
  does not depend on cookie semantics.

Trade-offs accepted:

- Tokens live in platform-secure storage (`flutter_secure_storage`); XSS on
  the web build would expose them like any other JS-reachable credential.
  Mitigated by the strict CSP (`script-src` without `unsafe-inline`), no
  `localStorage` use, and short-lived access tokens (15m).
- Cookie-based browser auth (HttpOnly, Secure, SameSite=Lax) remains the
  industry-standard *alternative*; adopting it later would mean a dual
  transport with CSRF protection - deferred deliberately, not forgotten.

The refresh-token rotation, reuse detection, session revocation, password
reset and MFA features listed as "not done" in the original draft of this
document have since shipped; see `docs/compliance/OWASP_IMPLEMENTATION.md`
(A04/A07) and `docs/release/RELEASE_NOTES_v1.0.0.md` for the current state.
