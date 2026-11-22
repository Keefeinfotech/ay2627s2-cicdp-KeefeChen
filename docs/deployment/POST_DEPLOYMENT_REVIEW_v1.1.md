# Post-Deployment Review — v1.1

**Status:** retrospective review compiled 22 November 2026 from committed
evidence. Metrics that were not captured at release time are marked
`Not captured` rather than estimated; they become mandatory from the next
release per [TEST_PLAN.md](../testing/TEST_PLAN.md).

## Deployment

- Date: 19 November 2026
- Version / commit: `v1.1` → `b90d82b`
- Environment: production (Render, Singapore)
- CI run: <https://github.com/Keefeinfotech/ay2627s2-cicdp-KeefeChen/actions/runs/44491730340> (11/11 jobs green)
- Deploy run: <https://github.com/Keefeinfotech/ay2627s2-cicdp-KeefeChen/actions/runs/44494233091> (success)
- CAB decision: none was recorded at the time; retrospective governance gap
  closed by [GOVERNANCE.md](../change-management/GOVERNANCE.md) on 22 Nov 2026.
  Future releases must carry a `CAB-YYYYMMDD-nn` ID.

## What went well

- Exact CI-passed SHA deployed via Render API; health poll and smoke 3/3 passed.
- Production headers verified: CSP, HSTS, `x-frame-options: SAMEORIGIN`.
- Backend 378 tests / coverage 59.84/50.34/61.09/60.66 vs 58/48/59/58 ratchet;
  frontend 330 tests / 62.5% vs 62% gate.
- Pact 3/3, Mongo-backed 8/8, Stryker 100.00, accessibility suite caught and
  fixed 3 real WCAG AA defects before release.
- `LAST_GOOD_SHA` recorded; auto-rollback path configured in `deploy-production.yml`.

## Issues encountered

- Stale coverage figures were discovered on 21 Nov (60% in docs/Jenkins vs
  62% in CI) and corrected in `QA_VERIFICATION_2026-11-21.md` — but two
  documents (`RELEASE_CHECKLIST.md`, `DEPENDENCIES.md`) remained stale until the
  22 Nov audit. Both fixed in this change set.
- Manual NFR gates (screen reader, physical-device 200% scale, DB backup,
  production rollback rehearsal, HTTPS/CORS verification) were not evidenced.
- Alert delivery in the local monitoring profile is an inert webhook.

## Metrics

- Error rate before/after: Not captured at release time (Grafana dashboard
  provisioned; historical snapshot not attached). Capture from next release.
- p95 latency before/after: Not captured at release time. Local baseline is
  65.9 ms (`docs/testing/PERFORMANCE_BASELINE.md`); production value not sampled.
- Deploy duration: health poll succeeded within the 10-minute window; exact
  duration not recorded.
- Test pass rate: 100% of blocking suites (328 passed + 2 skipped frontend).
- DDE / Defect Density / Escaped Defects: not measured historically; framework
  and backfilled log now in `docs/quality/`.

## Action items

- [x] Fix stale 60% coverage gate in `RELEASE_CHECKLIST.md`.
- [x] Correct bot-configuration statement in `DEPENDENCIES.md`.
- [x] Create RTM, test-case catalogue, defect log, quality metrics, governance,
      code-review policy and CMDB.
- [ ] Execute and evidence one manual NFR gate.
- [ ] Capture before/after error rate and p95 for the next release.
- [ ] Configure required reviewers on the `production` environment and record
      a CAB decision ID.
- [ ] Rehearse rollback against staging once per release cycle.

## Lessons learned

Deployment engineering is mature; the missing piece is formal governance
evidence (traceability, defect analytics, approval records). Those artifacts
now exist and must be maintained as part of each release, not rebuilt at audit
time.
