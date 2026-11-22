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
| `prometheus-prod.yml` | Production scrape template (HTTPS + `METRICS_TOKEN`, hosted Alertmanager) |
| `alertmanager.prod.yml` | Production alert delivery via `${SLACK_WEBHOOK_URL}` |
| `grafana/provisioning/datasources/prometheus-prod.yml` | Production Grafana datasource via `${PROMETHEUS_URL}` |
| `grafana/` | Dashboard (`dashboards/auxilia-backend.json`) + provisioning |
| `../docs/operations/MONITORING_RUNBOOK.md` | SLIs, SLOs, error budget, alert→action map |

## Start

```bash
docker compose --profile monitoring up -d
```

Prometheus http://localhost:9090 · Alertmanager http://localhost:9093 ·
Grafana http://localhost:3001 (`admin` / `${GRAFANA_ADMIN_PASSWORD:-admin}`)

## Production wiring

The `monitoring` Compose profile is local-only. To monitor the deployed service:

1. Set a strong random `METRICS_TOKEN` on the Render backend (never the local
   demo token) and keep the same value in your hosted Prometheus secret store.
2. Render the templates with secrets injected at deploy time — never commit the
   rendered files:
   ```bash
   METRICS_TOKEN="$METRICS_TOKEN" BACKEND_METRICS_URL="<backend-host>" \
     ALERTMANAGER_HOST="<alertmanager-host>" \
     envsubst < monitoring/prometheus-prod.yml > /etc/prometheus/prometheus.yml
   SLACK_WEBHOOK_URL="$SLACK_WEBHOOK_URL" \
     envsubst < monitoring/alertmanager.prod.yml > /etc/alertmanager/alertmanager.yml
   ```
   Copy `prometheus-alerts.yml` and `prometheus-slo.yml` next to the rendered
   Prometheus config, then run `promtool check config` before restarting.
3. Mount `grafana/provisioning/datasources/prometheus-prod.yml` **instead of**
   `prometheus.yml` in the production Grafana instance and keep the dashboard
   provisioner from `grafana/provisioning/dashboards/`.
4. Verify delivery by firing a test alert in Alertmanager and confirming it
   reaches `#alerts-auxilia`. Until step 4 passes, alerts are not operational.

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
