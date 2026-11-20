# Monitoring — Auxilia

Local observability stack for the backend: Prometheus (scrape + alert rules),
Alertmanager (routes notifications), Grafana (dashboards).

| File | Purpose |
|---|---|
| `prometheus.yml` | Scrape config + `rule_files` + `alerting:` → Alertmanager |
| `prometheus-alerts.yml` | Symptom alerts: `HighErrorRate`, `HighLatency`, `BackendDown` |
| `prometheus-slo.yml` | Error-budget burn-rate alerts: `ErrorBudgetFastBurn`, `ErrorBudgetSlowBurn` |
| `alertmanager.yml` | **Local demo default** — inert webhook, safe to start |
| `alertmanager.slack.example.yml` | Production template — Slack receiver via `${SLACK_WEBHOOK_URL}` |
| `grafana/` | Dashboard (`dashboards/auxilia-backend.json`) + provisioning |
| `../docs/operations/MONITORING_RUNBOOK.md` | SLIs, SLOs, error budget, alert→action map |

## Start

```bash
docker compose --profile monitoring up -d
```

Prometheus http://localhost:9090 · Alertmanager http://localhost:9093 ·
Grafana http://localhost:3001 (`admin` / `${GRAFANA_ADMIN_PASSWORD:-admin}`)

## Notes

- The scrape token is a **local-demo** default — override `METRICS_TOKEN`
  (and this file) for anything real.
- `prometheus-slo.yml` requires enough traffic for `rate()` denominators to
  be meaningful; on an idle/demo backend the burn-rate alerts stay silent by
  design (0-traffic → 0/0, i.e. no alert, which is correct).
- Alert *delivery* is inert by default. See the runbook §6 to wire Slack.
- `promtool check config monitoring/prometheus.yml` validates the config and
  rule files (not run here — Docker Desktop was unavailable; YAML and
  `docker compose config` were validated instead).
