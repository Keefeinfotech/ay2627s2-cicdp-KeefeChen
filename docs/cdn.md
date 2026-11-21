# CDN & Static Asset Caching — Basic Setup

Status: **basic, in place**. `frontend/nginx.conf` now sends cache headers a
CDN can honour, and this document describes how to put a CDN in front.

## What the nginx config does

| Path                              | Cache-Control                          |
| --------------------------------- | -------------------------------------- |
| `/index.html`                     | `no-cache` (always revalidate)         |
| `/canvaskit/*`, `/assets/*`, `/icons/*`, `flutter_service_worker.js` | `public, max-age=31536000, immutable` |
| `*.js`, `*.css`, `*.wasm`         | `public, max-age=86400`                |
| everything else (SPA fallback)    | `no-cache`                             |

## Putting a CDN in front (Cloudflare example)

1. Point the Auxilia frontend DNS at Cloudflare (proxied, orange cloud).
2. Cache rule: cache everything matching `\.(js|css|wasm|png|woff2?|svg)$`
   and the `/canvaskit/*`, `/assets/*` paths; respect origin `Cache-Control`.
3. Bypass cache for `/api/*` (proxied to the backend) — API responses are
   dynamic and must not be cached at the edge.
4. Purge (or version) assets on each frontend deploy; `flutter build web`
   regenerates `canvaskit` and `assets` deterministically.

## Notes / limitations

- Flutter web bundles are not content-hashed end to end, so entry-point
  bundles use a 1-day cache rather than `immutable`.
- If you move static hosting to an object store + CDN (S3/GCS/R2), keep
  `index.html` on `no-cache` and upload assets before the HTML.
