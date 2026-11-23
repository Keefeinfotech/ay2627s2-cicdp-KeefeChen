# Repository Security Rules — Auxilia

**Version:** 1.0 · **Created:** 23 November 2026 · **Owner:** Release owner
**Purpose:** record the GitHub-side security settings that cannot be expressed
in committed repository files, so they are auditable and reproducible. Where a
setting is not yet applied, it is listed as an action item. Companion to
[SECURITY_GOVERNANCE.md](SECURITY_GOVERNANCE.md).

## 1. Branch protection / rulesets

| Branch | Required PR | Required status check | Approvals | Force push / delete | Status |
|---|---|---|---|---|---|
| `main` | Yes | `CI - Final Quality Gate` (SonarCloud recommended) | 0 (solo project; raise to 1 if a reviewer is available) | blocked | Partially applied — see `change-management-process.md` |
| `develop` | Yes | `CI - Final Quality Gate` | 0 | blocked | Partially applied |
| `release/**` | Yes | `CI - Final Quality Gate` | 0 | blocked | Partially applied |

Action items: enforce the required status check on both rulesets (currently
documented but not fully enforced — see `change-management-process.md`
"Repository files vs GitHub settings").

## 2. GitHub Actions permissions

- Workflow-level `permissions` default to least privilege where set; the
  repository default should be "read-only" (Settings → Actions → General →
  Workflow permissions).
- `deploy-production.yml` is the only workflow with `actions: write` (to
  persist `LAST_GOOD_SHA`); all others use `contents: read` (and
  `security-events: write` for Trivy SARIF).
- `approval.yml` uses the `approval` environment and `pull_request` trigger
  with `contents: read` only.

## 3. Actions allowlist and pinning

- Only GitHub-owned, `actions/`, `github/`, and explicitly approved
  third-party actions (`aquasecurity`, `docker`, `SonarSource`, `subosito`,
  `anchore`, `zaproxy`, `treosh`, `reactivecircus`, `aquasecurity`) are used.
- Every third-party action is pinned to a full 40-char commit SHA (see
  `check-action-pins.mjs`). The `actions-security` CI job enforces this and
  fails the build on any unpinned ref.
- Allowed third-party actions must be added with their SHA in the PR that
  introduces them, and reviewed per `CODE_REVIEW_POLICY.md` Tier 1.

## 4. Secrets and pull-request safety

- No workflow triggered by `pull_request` references repository secrets; the
  audit of `dast.yml` (PR-triggered) confirms it uses `JWT_SECRET=ci-test-only-jwt-secret`
  (a literal test value) and no secret values.
- Production secrets (`JWT_SECRET`, `MONGODB_URI`, `RENDER_API_KEY`, etc.) are
  injected by Render / GitHub Secrets and are never committed.
- Push protection and secret scanning should be enabled in repository settings.

## 5. Environments

| Environment | Purpose | Reviewers | Required before deploy |
|---|---|---|---|
| `production` | Render production deploy | To be configured | Yes (manual gate recommended for Normal/High-risk releases) |
| `approval` | Approval workflow gate | To be configured | Advisory (currently runs without a manual gate) |

Action items: configure required reviewers on both environments so the CAB
approval is enforced rather than advisory (see `GOVERNANCE.md`).

## 6. Dependency and supply-chain settings

- Dependabot security updates: enabled (Dependabot configured for npm, Pub and
  GitHub Actions in `.github/dependabot.yml`).
- Dependency Review: enabled on PRs (repo public; `DEPENDENCY_REVIEW_ENABLED`
  variable set).
- SBOM generation: `sbom.yml` (Syft) on push to `main`; SBOM artifacts also
  generated in CI via Trivy.
- Build provenance: `attest-build-provenance` in `release.yml`.
- SLSA attestation: `attest` step in `sbom.yml` (public repos only).
- Trivy SARIF uploads to code scanning: report-only (findings triaged per release).

## 7. Audit trail

- Changes to these settings are recorded in
  `docs/change-management/change-log.md` and, when they affect release
  behaviour, in the release evidence file. Apply the change-management process
  (issue → evaluate → approve → implement → review → test → merge → document).
