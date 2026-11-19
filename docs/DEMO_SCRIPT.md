# Auxilia - 6-Minute Demo Script

**Target runtime:** 6:00 · **Fallbacks:** recorded backup at
`docs/assets/auxilia-demo-v1.1.webm` · Render pre-warm 5 minutes before · This
script itself is printed next to the keyboard.

**Pre-flight (5 min before)**

1. MongoDB locally (`docker compose up -d mongo`) or any `MONGODB_URI`.
2. Seed once (idempotent): `cd backend && npm run seed:demo`
   - User: `grace@auxilia.demo` / `DemoUser!2026` (seeded with 10 tasks)
   - Admin: `admin@auxilia.demo` / `AdminDemo!2026`
3. Backend: `cd backend && npm run dev` → `GET http://127.0.0.1:3000/api/health` → `{"status":"ok"}`
4. Frontend: `cd frontend && flutter run -d web-server --web-port=5199`
5. Browser window wide (≥ 1280px) — the shell shows the desktop sidebar at
   ≥ 1024px, rail at 600–1024px.

**The 6 minutes**

1. (30s) Problem statement: students juggling coursework, deadlines, zero offline guarantee.
2. (60s) Sign in (account prefilled) → Home dashboard: Live counters, XP bar at 80/100, real seeded task list.
3. (45s) Search & filter: type "network", clear, filter chips All (10) / To do (6) / Done (4).
4. (60s) Complete a task from the list (tick the checkbox) → XP toast + achievements/level-up animation, undo snackbar.
5. (45s) AI quick-add: "math assignment friday 5pm #calc" → structured preview → confirm (**mock provider labelled in UI**).
6. (45s) Reminders & sync banner (edit offline → reconnect → sync) — only if the target machine has the compose stack; call it out honestly otherwise.
7. (45s) Admin console (admin@auxilia.demo) — RBAC enforcement, then Grafana (`docker compose --profile monitoring up -d`, http://localhost:3001).
8. (45s) Pipeline story: CI green on main (44491730340), 378 backend tests, 330 frontend tests, coverage 59.8/50.3/61.1/60.7 (ratchet 58/48/59/58), Trivy/CodeQL, SonarCloud gate, v1.1 release with SBOM provenance.
9. (30s) Close with roadmap + honest limitations (no production E2E on the deployed backend; Mongo-backed tests cover task module only; demo login is intentionally non-production).

**Honesty box (read during Q&A, not during the demo)**

- Guest/offline mode: editable with zero backend — works, shown only if asked.
- OWASP ZAP is a baseline scan; `.zap/rules.tsv` intentionally empty.
- Evidence: `docs/reports/RELEASE_EVIDENCE_v1.1.md`, `docs/reports/REGRESSION_RUN_2026-11-19.md`, `docs/reports/TESTING_TOOLS_REPORT.md`.

## Fallbacks

- Pre-warm Render deployment 5 minutes before.
- Backup recording: `docs/assets/auxilia-demo-v1.1.webm` (attached to the v1.1 release).
- Manual test plan with sign-off boxes printed.
