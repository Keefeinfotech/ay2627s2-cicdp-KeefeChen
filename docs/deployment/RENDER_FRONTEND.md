# Deploying the Flutter Web Frontend on Render

This guide deploys **Auxilia Web** as a separate free Docker web service on Render, alongside the existing `auxilia-backend` service. It does not change backend code, the backend Dockerfile, or any CI workflow.

## 1. What is already in the repository

| File | Purpose |
|---|---|
| `frontend/Dockerfile` | Multi-stage build: Flutter 3.47.8 SDK → `flutter build web --release --dart-define=API_BASE_URL=...` → `nginxinc/nginx-unprivileged:1.27.4-alpine` serving on port 8080. Also substitutes the API origin into the Nginx CSP at build time. |
| `frontend/nginx.conf` | SPA fallback to `index.html`, long-lived caching for fingerprinted assets, strict CSP/HSTS/security headers. No reverse proxy to compose-only hostnames. |
| `render.yaml` | Declares **two** services: `auxilia-backend` (existing) and `auxilia-web` (new). |
| `frontend/lib/core/network/api_client.dart` | Reads `API_BASE_URL` from `String.fromEnvironment` and refuses plaintext HTTP except loopback. |
| `frontend/lib/features/reminders/data/reminder_repository.dart` | Second consumer of the same `API_BASE_URL` define (`/api/v1`). |

Render converts a Docker service's **environment variables into Docker build arguments**, so setting `API_BASE_URL` in the Render dashboard is enough for `--dart-define` to receive it. Nothing is hardcoded to `localhost` in production.

## 2. Deploy the frontend service

### Option A — Apply the Blueprint (recommended)

1. Render Dashboard → **New** → **Blueprint**.
2. Select this repository and branch `main`.
3. Render reads `render.yaml` and provisions/updates both services by name. If your existing backend service has a different name, rename it to `auxilia-backend` first, otherwise Render will create a duplicate.
4. When prompted for `CORS_ORIGIN`, use the **frontend URL from step 6** (you may leave it blank now and set it after the URL exists).
5. Click **Apply**. Both services deploy; the frontend build downloads the Flutter SDK and can take several minutes on the first deploy. Subsequent builds use Render's layer cache.

### Option B — Create the web service manually

Dashboard → **New** → **Web Service**:

| Setting | Value |
|---|---|
| Language | **Docker** |
| Repository | `https://github.com/Keefeinfotech/ay2627s2-cicdp-KeefeChen` |
| Branch | `main` |
| Root Directory | `frontend` |
| Dockerfile Path | `Dockerfile` (i.e. `frontend/Dockerfile`) |
| Dockerfile Command | *(leave blank — use the Dockerfile `CMD`)* |
| Plan | **Free** |
| Region | **Singapore** (same as the backend) |
| Health Check Path | `/` |
| Auto-Deploy | Yes |

Environment variables (Render passes these to the Docker build as args):

| Key | Value |
|---|---|
| `PORT` | `8080` — nginx listens there; Render routes to the port named by `PORT` |
| `API_BASE_URL` | `https://ay2627s2-cicdp-keefechen-1.onrender.com` — the deployed backend URL from `RENDER_API_BASE_URL` |
| `TURNSTILE_SITE_KEY` | The **public** Cloudflare Turnstile site key from the same widget as the backend's `TURNSTILE_SECRET_KEY`. Compiled into the app at build time (`--dart-define`); without it `AuthService.requiresCaptcha` is false and `/api/auth/login` rejects sign-in with `CAPTCHA_REQUIRED`. |

Do **not** set `MONGODB_URI`, `JWT_SECRET` or other backend secrets on this service — the frontend never needs them. The site key is public; the secret key stays on the backend only. Also add `auxilia-web.onrender.com` to the widget's allowed hostnames in the Cloudflare dashboard, or verification will fail with a hostname mismatch.

## 3. Obtain the public URL

After the first successful deploy, the service page shows its URL:

```
https://auxilia-web.onrender.com
```

The exact subdomain depends on availability (Render may append a suffix). Copy it exactly, with no trailing slash.

## 4. Connect the frontend to the backend (CORS)

The backend enforces an allowlist (`CORS_ORIGIN`) in production. If it is not set to the frontend origin, every API call fails with `403 CORS_FORBIDDEN`.

1. Render Dashboard → `auxilia-backend` → **Environment**.
2. Set `CORS_ORIGIN` to the exact frontend URL from step 3 (comma-separated if you also use a custom domain):
   ```
   https://auxilia-web.onrender.com
   ```
3. Save; Render redeploys the backend automatically.
4. If you use a Blueprint with `sync: false`, update the value there too so future applies don't clear it.

## 5. Verification checklist

Run after both services are live. Replace `<WEB>` and `<API>` with the actual URLs.

- [ ] `curl -I https://<WEB>/` → **200**, `content-type: text/html`.
- [ ] Response header `content-security-policy` contains `connect-src` with `https://<API>` and `frame-ancestors 'none'`.
- [ ] Response header `strict-transport-security: max-age=31536000; includeSubDomains` is present.
- [ ] `curl -I https://<WEB>/some/deep/client/route` → **200** serving `index.html` (SPA fallback, not a 404).
- [ ] `curl -I https://<WEB>/assets/<fingerprinted-file>.js` → `cache-control: max-age=31536000`; `curl -I https://<WEB>/index.html` → revalidate (`max-age=0` / `no-cache`).
- [ ] `curl -s https://<API>/api/health` → `{"status":"ok"}`.
- [ ] Browser: open the frontend, sign up / sign in, create and complete a task — no `CORS_FORBIDDEN` or mixed-content errors in DevTools.
- [ ] Browser DevTools → Network: API requests go to `https://<API>/api/...` (never `localhost`).
- [ ] Reload on a deep link (e.g. `/home`) — the SPA still boots.
- [ ] Render dashboard → `auxilia-web` → **Logs**: nginx starts without `host not found in upstream` errors.

## 6. Known caveats (service plans)

- Production `auxilia-web` and `auxilia-backend` are declared on the **Starter (always-on)** plan in `render.yaml`, so they do not suspend between requests. The staging services remain on the free plan and **spin down after inactivity** — their first request can take ~50 s to wake, and `ApiClient` has a 12 s timeout. Do not use staging for demos without warming it first.
- Flutter web downloads assets (~several MB); first load on a cold connection can still be slow even with an always-on service.
- The build stage downloads the Flutter SDK each time the SDK layer cache is invalidated. Pin `FLUTTER_VERSION` (already 3.47.8) to keep CI/runtime builds consistent.

## 7. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `x-render-routing: no-server` | No service registered at that hostname — the Blueprint was not applied, or the service is suspended. Apply `render.yaml`. |
| Frontend loads but API calls fail with 403 | `CORS_ORIGIN` on the backend does not match the frontend origin exactly (see step 4). |
| Browser console: CSP refused connection to `<API>` | `API_BASE_URL` was not passed as a build arg; the CSP still has the localhost-only placeholder. Recreate the service with the env var set. |
| nginx container exits with `host not found in upstream "backend"` | An older `nginx.conf` with the `/api/` proxy is in use. Rebuild from this repository's `frontend/nginx.conf`. |
| Deep links 404 | Nginx `try_files ... /index.html` is missing; use the committed `frontend/nginx.conf`. |
| Need to revert | Render service → **Deployments** → redeploy a previous successful deploy; no code rollback needed. |

## 8. Local development remains unchanged

`docker compose --profile ... up -d --build` still builds the frontend with `API_BASE_URL=http://localhost:3000`; the Dockerfile default and the compose build arg are untouched. The E2E suite (`localhost:8080` web + `localhost:3000` API) is unaffected.
