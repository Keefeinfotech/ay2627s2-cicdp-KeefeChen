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
| Proxy awareness | `TRUST_PROXY=true` so real client IPs are used behind Railway/Cloudflare. | `backend/src/app.ts` |
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

## Not done (needs your decision)

- Refresh tokens / token rotation (would change the client contract).
- Email verification and password reset (requires email provider).
- MFA/TOTP (new dependency and enrolment flow).
- Server-side session store (Redis) if you scale beyond one API instance.
