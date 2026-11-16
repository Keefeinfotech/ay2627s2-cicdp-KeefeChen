# API Performance Baseline

Recorded 2026-11-16 on a Windows development machine (Node v22.14.0,
express-rate-limit with the default in-memory store; no Redis attached).
This is an **indicative local baseline**, not a staging/production SLO
measurement. Re-measure in CI and on a deployed instance before setting
budget alerts from it.

## How to reproduce

```bash
cd backend
npm run test:performance
# custom budget / duration / concurrency:
PERF_DURATION_S=30 PERF_CONCURRENCY=50 PERF_MAX_P95_MS=500 npm run test:performance
```

The smoke test boots the real Express app in-process on an ephemeral port and
drives concurrent HTTP traffic through it. No MongoDB or Redis is required —
measurements cover the DB-free hot paths (`/api/health`, the 401 handler on
`/api/ai/chat`, the 404 handler). The exit code is non-zero when the health
p95 budget is exceeded or any request returns 5xx.

CI runs the same smoke on demand via the
`Performance - API Latency & Error Budget` workflow_dispatch job (see
`.github/workflows/ci.yml`); the optional `tests/performance/k6-load-test.js`
scenario covers load against a deployed environment.

## Recorded results (duration=10s, concurrency=20, 4243 requests)

| Probe | Requests | Errors | avg (ms) | p50 | p90 | p95 | p99 | max |
|-------|----------|--------|----------|-----|-----|-----|-----|-----|
| GET `/api/health` | 3819 | 0 | 47.1 | 44.9 | 59.1 | 65.9 | 105.1 | 175.6 |
| POST `/api/ai/chat` (401) | 212 | 0 | 47.1 | 44.7 | 59.8 | 66.8 | 90.4 | 177.9 |
| GET `/api/__nope__` (404) | 212 | 0 | 47.1 | 44.9 | 58.5 | 65.6 | 101.4 | 158.3 |

- Health p95 = **65.9 ms** (budget 500 ms) — PASS
- 5xx/transport errors = **0** — PASS

## Notes

- Latency is dominated by the in-process HTTP stack and the baseline API
  middleware chain; nothing here touches the database. When scaling work is
  done, re-baseline against an instance with Redis attached (`REDIS_URL=...`)
  and measure the `/api/health` path and the AI 401 path before enabling
  autoscaling rules.
- Rate limiting fails open when Redis is unreachable; do not derive
  "already overloaded" conclusions from 200s on a degraded limiter. Watch the
  `redis.connection_error` and `redis.connect_failed` log events instead.
