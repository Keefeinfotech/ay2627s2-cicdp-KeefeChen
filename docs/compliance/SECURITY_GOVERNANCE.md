# Security Governance — Auxilia

**Version:** 1.0 · **Created:** 23 November 2026 · **Owner:** Release owner
**Purpose:** map Auxilia to the layered enterprise DevSecOps model (source →
build → test → deploy → runtime) and define the severity policy, exception
process and remediation tracking. Companion to
[NFR_RELEASE_GATES.md](NFR_RELEASE_GATES.md), [GOVERNANCE.md](../change-management/GOVERNANCE.md)
and [DEFECT_LOG.md](../quality/DEFECT_LOG.md).

## 1. Layered security stack implemented

| Layer | Practice | Tool in Auxilia | Where it runs | Gate? |
|---|---|---|---|---|
| Source control | branch protection, rulesets | GitHub Rulesets (settings), `pr-conventions` job | GitHub | Yes |
| Secret scanning | detect leaked secrets | Gitleaks (Docker, network-isolated) + `assertRuntimeEnv()` startup gate | `ci.yml` secret-scan; backend startup | Yes |
| Dependency scanning (SCA) | vulnerable deps, audit | Dependabot (npm/pub/actions), `npm audit` (production) | `ci.yml` backend job, `.github/dependabot.yml` | Yes (audit) |
| Dependency review | inspect PR dependency diff | Dependency Review Action | `ci.yml` PRs | Yes (high) |
| SAST / code security | secure coding rules | SonarCloud (quality gate), CodeQL (security-extended) | `ci.yml` | Yes |
| IaC / configuration | scan Dockerfiles, workflows | Trivy config (filesystem scan includes IaC), `check-action-pins.mjs` | `ci.yml` security-scan, actions-security | Yes |
| Container security | image vulnerability scanning, hardening | Trivy (image), non-root runtime, digest-pinned base images, npm/npx removed | `ci.yml`, `docker-compose.yml`, `render.yaml` | Yes (CRITICAL/HIGH) |
| Application testing | DAST, API security | OWASP ZAP baseline (advisory), `backend/tests/security/`, AI guardrails | `dast.yml`, `ci.yml` | Advisory |
| Supply chain | SBOM, signing, provenance | Syft SBOM + SLSA attestation (`sbom.yml`), Trivy SBOM artifacts (`ci.yml`), build-provenance attestation (`release.yml`) | `sbom.yml`, `ci.yml`, `release.yml` | Recommended |
| Pipeline security | protected workflows, least privilege, pinned actions | workflow `permissions`, pinned actions, `check-action-pins.mjs` | all workflows | Yes (pins) |
| Deployment | approval gates, protected environments | GitHub Environments (`production`), `approval.yml`, `deploy-production.yml` health poll + smoke, auto-rollback | deploy workflows | Controlled |
| Runtime | monitoring, threat detection, logging | Prometheus, Alertmanager, Grafana, SLO burn-rate rules, runbook | `monitoring/`, `docs/operations/` | Yes (local) |
| Governance | risk management, remediation tracking | change-management process, CCB/CAB, DEFECT_LOG, QUALITY_METRICS, RUBRIC | docs/ | Yes |

## 2. Security gate policy (severity → action)

| Finding type | Severity | Policy | Enforcement |
|---|---|---|---|
| Secret in tracked file | any | **Block merge**; rotate the secret; record as escaped defect if it reached production | Gitleaks exit 1 |
| Critical vulnerability | CRITICAL | **Block release**; fix before any merge to `main` | Trivy `exit-code: 1` |
| High vulnerability | HIGH | **Block** unless a documented exception (security + CAB) | Trivy `exit-code: 1`; exception recorded in `DEFECT_LOG.md` with expiry |
| Medium/Low vulnerability | MEDIUM/LOW | Triage per release; accepted risk recorded in release notes | Report-only SARIF |
| SonarCloud quality gate fail | any | **Block merge** | `sonarqube-automatic` + Final Quality Gate |
| CodeQL security-extended | any | **Block merge** | CodeQL job |
| Dependency Review (PR) | high/critical | **Block PR** | dependency-review job |
| DAST high finding | high | Advisory until staging is in place; must be triaged per release | `dast.yml` |
| IaC / configuration (Trivy config) | CRITICAL/HIGH | **Block** | Trivy filesystem scan (`scan-type: fs`) |
| Unpinned third-party Action | any | **Block merge** | `actions-security` job (check-action-pins.mjs) |
| Unapproved production deployment | any | **Block** | GitHub Environment reviewers + `deploy-production.yml` |

## 3. Exceptions and remediation tracking

- Any exception to a blocking gate must be raised as a change request
  (`.github/ISSUE_TEMPLATE/change_request.md`) with the residual risk, a CAB
  decision ID and an expiry date, and recorded in `docs/quality/DEFECT_LOG.md`.
- Security and privacy gates (G8, G9, G10 in `NFR_RELEASE_GATES.md`) cannot be
  waived.
- Remediation deadlines follow severity: Critical ≤ 7 days, High ≤ 30 days,
  Medium ≤ 90 days, Low = next sprint. Overdue findings are escalated at the
  next CAB meeting.
- Retrospective vulnerability tracking is backfilled from CI runs and SonarCloud;
  live tracking happens through the change-management process.

## 4. Staging DAST (recommended next step)

The project currently runs OWASP ZAP as a baseline scan against the backend on
backend-touching PRs (`.github/workflows/dast.yml`). A true staging DAST
against a deployed environment is recommended once a staging Render service
exists; until then, DAST remains advisory and is not a release gate. Adding a
staging deployment is tracked as future work.

## 5. Runtime security and monitoring

- `/metrics` is bearer/admin-guarded; Prometheus scrapes it; Alertmanager routes
  alerts; Grafana dashboards are provisioned as code.
- SLO burn-rate rules (`monitoring/prometheus-slo.yml`) implement an error-budget
  policy (99.5% availability, 99.0% latency over 28 days).
- Alert delivery in the local profile is an inert webhook; the Slack template
  (`monitoring/alertmanager.slack.example.yml`) is committed but unproven.
- No external uptime prober exists; `BackendDown` covers process death.

## 6. Repository security rules (settings outside the repo)

These cannot be set via committed files and are verified/recorded in
`docs/operations/REPOSITORY_SECURITY_RULES.md`:

- Branch protection / rulesets for `main`, `develop`, `release/**`.
- Required status check `CI - Final Quality Gate` (and SonarCloud) on `main`.
- Required reviewers on the `production` GitHub Environment.
- Actions permissions: only trusted actions allowed; SHA pinning enforced by
  `actions-security` job.
- Secret scanning and push protection enabled on the repository.
- Dependabot security updates enabled.
