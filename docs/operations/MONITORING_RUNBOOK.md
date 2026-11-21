# Monitoring & Alerting Runbook — Auxilia

**Audience:** whoever is on the hook when this page opens (project owner +
graders/demo audience). **Prerequisites:** none beyond the files referenced
here. **Last verified:** 2026-11-19 (see
`docs/reports/REGRESSION_RUN_2026-11-19.md`).

## 1. What this runbook covers

The Auxilia backend exports `/metrics` (prom-client, bearer-guarded with
`METRICS_TOKEN`). Prometheus scrapes it (every 10s) and evaluates **two kinds
of rules**:

- **Symptom rules** (`monitoring/prometheus-alerts.yml`) — threshold-based:
  `HighErrorRate` (5xx rate > 5% over 5m for 2m, critical),
  `HighLatency` (p95 > 1s over 5m for 5m, warning),
  `BackendDown` (`up == 0` for 1m, critical).
- **SLO burn-rate rules** (`monitoring/prometheus-slo.yml`) — error-budget
  based, complementary to the symptom rules:
  `ErrorBudgetFastBurn` (5xx ratio > 7.2% for 2m, critical) and
  `ErrorBudgetSlowBurn` (> 3% for 15m, warning).

Alerts go to Alertmanager (`monitoring/alertmanager.yml` in the local compose
profile — an inert webhook). For a real receiver, see
`monitoring/alertmanager.slack.example.yml` (Slack webhook via
`${SLACK_WEBHOOK_URL}`) or §6 of this runbook.

## 2. SLIs, SLOs and the error budget

| SLI | Definition | SLO | Window |
|---|---|---|---|
| Availability | non-5xx responses ÷ total responses | **99.5%** | 28 days |
| Latency | responses answered within 1s ÷ total | **99.0%** | 28 days |

**Error budget** for availability: 0.5% of requests may fail, i.e. the 28-day
budget is ~180 min of equivalent downtime (or ~0.5% of volume). The SLO is
deliberately **99.5%**, not 99.9% — the reference deployment (Render free
tier) has cold starts and no multi-AZ guarantee; an honest SLO beats an
aspirational one.

Error-budget policy:

- **< 50% of budget consumed** — normal feature work.
- **50–100% consumed** — feature freeze for the rest of the window; only
  reliability fixes merge.
- **> 100% consumed** — incident review required before any feature release;
  rollback (via `.github/workflows/rollback.yml`) is the default remediation.

Measure the budget from Prometheus directly:

```promql
# Availability SLI over 28 days
1 - sum(increase(http_requests_total{status=~"5.."}[28d]))
      / sum(increase(http_requests_total[28d]))
```

## 3. Alert → action map

| Alert | First move | If escalating |
|---|---|---|
| `BackendDown` | `curl -fsS https://<deploy>/api/health`. Check Render logs and `docker compose ps` if local | Roll back via `.github/workflows/rollback.yml`; then `node scripts/smoke-test.mjs https://<deploy>` to confirm recovery (health 200 / unauth 401 / unknown 404) |
| `HighErrorRate` | Grafana "Auxilia Backend" dashboard → error-rate panel; check recent deploys; inspect backend logs for the top failing route | Identify whether it is one route failing consistently (rollback is usually right) vs one bad user/input (fix forward) |
| `HighLatency` | Check Grafana latency panel + `/metrics` rate. Check Mongo connection health (mongoose pool) and Redis (rate limiter) if dashboards show pool exhaustion | Throttle the expensive route (rate limiter config) or roll back the last deploy |
| `ErrorBudgetFastBurn` / `ErrorBudgetSlowBurn` | Same as `HighErrorRate`; check the Grafana error-rate panel and confirm the burn rate in the Prometheus expression browser (query from the alert rule) | Declare a reliability freeze (§2) |

## 4. Starting the stack locally

```bash
docker compose --profile monitoring up -d
# Prometheus   http://localhost:9090  (Alerts tab shows FIRING/INACTIVE)
# Alertmanager http://localhost:9093
# Grafana      http://localhost:3001  (admin / ${GRAFANA_ADMIN_PASSWORD:-admin})
```

Dashboards are provisioned from `monitoring/grafana/dashboards/`; the data
source from `monitoring/grafana/provisioning/`. The scrape token is a
local-demo default — set `METRICS_TOKEN` and update `monitoring/prometheus.yml`
for anything real.

## 5. What is not wired yet (read before trusting this)

- **No on-call rotation exists.** Alerts currently land nowhere actionable
  outside the local stack — `alertmanager.yml` points at an inert webhook,
  and `alertmanager.slack.example.yml` is the ready-to-use Slack template
  (§1). Choose a real receiver and mount it before shipping to production.
- **No external SLO measurement service.** The SLO is computed from the
  backend's own `/metrics`; if the process is down, you measure nothing
  (that is what `BackendDown` is for). A hosted synthetic check (e.g. an
  external uptime prober hitting `/api/health`) is the obvious next step.
- **Staging smoke is not wired** — `scripts/smoke-test.mjs` runs post-deploy
  against production only. k6 runs are manual (`workflow_dispatch`).

## 6. Wiring a real receiver (Slack)

1. `export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."`
   (or supply it to compose: `SLACK_WEBHOOK_URL=... docker compose --profile monitoring up -d`).
2. Point compose at the example config instead of the demo one, and pass the
   variable into the alertmanager service environment (see the header comment
   in `monitoring/alertmanager.slack.example.yml`).
3. Restart: `docker compose --profile monitoring up -d --force-recreate alertmanager`.
4. Verify with a test alert:
   `curl -XPOST http://localhost:9093/api/v2/alerts -H 'Content-Type: application/json' -d '[{"labels":{"alertname":"TestAlert","severity":"warning"}}]'`

## 7. Incident closure checklist

- [ ] User-facing impact stated (duration, error budget consumed).
- [ ] `smoke-test.mjs` green against the restored deployment.
- [ ] Post-incident note committed to the repo (what happened, what changed,
      which alert — if any — fired, which alert should have fired but didn't).
- [ ] Any missed detection gets a regression fix: new/adjusted alert rule in
      `monitoring/prometheus-alerts.yml` or `prometheus-slo.yml`.
