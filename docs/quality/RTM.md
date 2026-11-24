# Requirements Traceability Matrix (RTM) — Auxilia

**Version:** 1.0 · **Created:** 22 November 2026 · **Owner:** Keefe Chen
**Scope:** critical-path functional requirements (FR-001…FR-024) and non-functional
requirements (NFR-G01…NFR-G14). This matrix is a retrospective governance
artifact created from in-repo evidence; the original SRS/Jira board remain
external. Where the source document says an item is Planned/Partial, this matrix
does **not** claim it is verified.

**Status key:** Verified · Partial · Not built · Planned.

| Req ID | Requirement (short) | Source | Design ref | Implementation ref | Test case IDs / automated tests | Latest result | Evidence | Status |
|---|---|---|---|---|---|---|---|---|
| FR-001 | Guest/local task CRUD works offline | USER_STORIES NP-8, NP-9, NP-10 | `docs/architecture/ERD.md` (Task) | `frontend/lib/features/home/data/task_store.dart`, `data/task_repository.dart`, `screens/home_screen.dart`, `widgets/task_editor.dart` | TC-001–TC-004; `frontend/test/services/task_store_test.dart`; `frontend/test/screens/home_screen_test.dart` | 330/330 frontend tests pass | `QA_VERIFICATION_2026-11-21.md` | Verified |
| FR-002 | Priority, due date, course/tags on every task | NP-13, NP-29 | ERD Task fields | `frontend/lib/features/home/models/task.dart`, `widgets/task_card.dart`, `widgets/task_filter_bar.dart` | TC-005, TC-006; `frontend/test/widgets/task_card_test.dart`, `frontend/test/services/task_validation_test.dart` | pass | `REGRESSION_RUN_2026-11-19.md` | Verified |
| FR-003 | Dashboard due-today/overdue counts | NP-11 | — | `frontend/lib/features/home/widgets/dashboard_header.dart`, `features/home/screens/home_screen.dart` | TC-007; `frontend/test/screens/home_dashboard_test.dart` | pass | QA verification | Verified |
| FR-004 | Undo delete/complete without double XP | NP-9 | gamification model | `frontend/lib/features/home/data/gamification.dart`, `task_store.dart` | TC-008, TC-009; `frontend/test/services/gamification_test.dart`, `task_store_test.dart` | pass | QA verification | Verified |
| FR-005 | Search, filter, pagination (server + UI) | README API; NP-29 | — | `backend/src/modules/tasks/`, `frontend/lib/features/home/data/api_task_repository.dart` | TC-010; `backend/tests/unit/validators/task.query-design.test.ts` (EP/BVA/UC); `frontend/test/services/api_task_repository_pagination_test.dart` | pass | `TESTING_TOOLS_REPORT.md` | Verified |
| FR-006 | Versioned local storage with v1→v2 migration | NP-10 | storage envelope `auxilia.tasks.v2.*` | `frontend/lib/features/home/data/task_repository.dart` | TC-011; `frontend/test/services/task_repository_test.dart` | pass | QA verification | Verified |
| FR-007 | XP, levels, achievements | NP-15, AUX-7 | gamification | `frontend/lib/features/home/data/gamification.dart`, `widgets/achievements_dialog.dart` | TC-012; `frontend/test/services/gamification_test.dart` | pass | QA verification | Verified |
| FR-008 | Progress summaries and charts | NP-15, AUX-7 | — | `frontend/lib/features/reports/` | TC-013; `frontend/test/features/reports/build_report_snapshot_test.dart` | pass | QA verification | Verified |
| FR-009 | One-time onboarding, persists completion | AUX-1 | — | `frontend/lib/features/onboarding/` | TC-014 (M-01–M-04); `frontend/test/features/onboarding/onboarding_store_test.dart` | automated pass; manual result not recorded | manual plan §1 | Partial |
| FR-010 | Signup/login, JWT, silent refresh, session restore | AUX-2, NP-18 | `docs/architecture/ENTERPRISE_AUTH.md` | `backend/src/modules/auth/`, `frontend/lib/features/authentication/`, `frontend/lib/core/network/api_client.dart` | TC-015–TC-017; `backend/tests/integration/auth.test.ts`, `refresh.test.ts`, `session.test.ts`; `frontend/test/features/authentication/auth_service_test.dart` | pass | QA verification | Verified |
| FR-011 | Password reset via single-use token | AUX-3 | ENTERPRISE_AUTH | `backend/src/modules/auth/`, `frontend/lib/features/authentication/screens/forgot_password_screen.dart`, `reset_password_screen.dart` | TC-018; `backend/tests/integration/refresh.test.ts` | pass; live SMTP not exercised | `USER_STORIES.md` AUX-3 | Partial |
| FR-012 | TOTP MFA | AUX-4 | ENTERPRISE_AUTH | `backend/src/modules/auth/mfa*` | `backend/tests/integration/auth.test.ts` | backend pass; client enrolment UI missing (BACKLOG-7) | `USER_STORIES.md` AUX-4 | Partial |
| FR-013 | Natural-language quick-add parser | NP-46 | — | `frontend/lib/features/task_management/domain/usecases/parse_quick_add.dart` | TC-019; `frontend/test/features/task_management/parse_quick_add_test.dart` | pass | QA verification | Verified |
| FR-014 | AI assistant; task changes only after confirmation | NP-19, NP-46 | `docs/architecture/AI_INTEGRATION_REPORT.md` | `backend/src/modules/ai/`, `frontend/lib/features/assistant/` | TC-020–TC-022; `backend/tests/ai/ai-guardrails.test.ts`, `backend/tests/integration/ai.test.ts`; `frontend/test/features/assistant/assistant_page_test.dart` | 7/7 guardrails pass | `TESTING_STRATEGY.md` | Verified (mock provider only) |
| FR-015 | In-app reminders, grouping, snooze | NP-14 | — | `frontend/lib/features/reminders/` | TC-023; `frontend/test/features/reminders/reminder_host_test.dart` | pass | `USER_STORIES.md` NP-14 | Verified (in-app only) |
| FR-016 | Durable offline queue, backoff, dead-letter | NP-26, NP-48 | — | `frontend/lib/features/sync/data/sync_queue_store.dart`, `sync_service.dart` | TC-024, TC-025; `frontend/test/features/sync/sync_service_test.dart` | pass | QA verification | Verified |
| FR-017 | Sync on launch/resume/reconnect (app lifecycle) | NP-27 | — | `frontend/lib/features/sync/data/background_sync_handler.dart` | TC-026; `frontend/test/features/sync/background_sync_handler_test.dart` | pass | QA verification | Verified (no OS background) |
| FR-018 | Conflict detection and Keep mine/Use server | NP-49 | CAS via `expectedUpdatedAt` | `frontend/lib/features/sync/models/sync_conflict.dart`, `sync_service.dart` | TC-027; `frontend/test/features/sync/sync_service_test.dart` | pass | `USER_STORY_CICD_REPORT.md` | Verified (whole-task resolution) |
| FR-019 | Sync status banner + details centre | NP-47 | — | `frontend/lib/features/sync/widgets/sync_status_banner.dart`, `sync_center_dialog.dart` | TC-028; `frontend/test/features/sync/sync_center_dialog_test.dart` | pass | QA verification | Verified |
| FR-020 | Groups, invitations, shared assignments | NP-45a/b, NP-44 | `docs/architecture/ERD.md` (Group/Invite) | `backend/src/modules/groups/`, `frontend/lib/features/groups/` | TC-029; `backend/tests/unit/modules/groups/*`; `frontend/test/features/groups/groups_page_test.dart` | service tests pass; controller paths excluded from coverage | `USER_STORIES.md` NP-45a | Partial |
| FR-021 | Admin console and RBAC | `docs/admin/ADMINISTRATION.md` | `docs/architecture/ENTERPRISE_AUTH.md` | `backend/src/modules/admin/`, `frontend/lib/features/admin/` | TC-030; `backend/tests/integration/admin.test.ts`, `frontend/test/features/admin/admin_dashboard_test.dart` | pass | QA verification | Verified |
| FR-022 | Responsive shell (bar/rail/sidebar) + named routes | NP-7, NP-50 | — | `frontend/lib/core/layout/app_shell.dart`, `core/routing/app_router.dart` | TC-031; `frontend/test/core/app_shell_test.dart`, `frontend/test/core/initial_route_test.dart` | pass | QA verification | Verified |
| FR-023 | Accessibility: labels, contrast, 200% text scale | G11, NP-11 | design system tokens | `frontend/lib/core/widgets/`, `frontend/lib/core/theme/` | TC-032–TC-035 (M-05, M-32–M-35); `frontend/test/accessibility/accessibility_test.dart`, `frontend/test/core/theme_test.dart`, `e2e/tests/a11y.spec.ts` | 3/3 guidelines pass; 3 WCAG defects fixed; physical-device pass unevidenced | `REGRESSION_RUN_2026-11-19.md` | Partial |
| FR-024 | Cloud deploy, health, smoke, rollback | NP-16; syllabus 4.4/4.5 | `docs/deployment/DEPLOYMENT_PLAN.md` | `render.yaml`, `docker-compose.yml`, `.github/workflows/deploy-production.yml`, `rollback.yml`, `scripts/smoke-test.mjs` | TC-036, TC-037; smoke 3/3 | health 200, smoke 3/3 pass | `RELEASE_EVIDENCE_v1.1.md` | Verified |
| NFR-G01…G06 | Type safety, formatting, tests, coverage, build | `NFR_RELEASE_GATES.md` | — | `backend/vitest.config.mts`, `frontend/tool/check_coverage.dart`, `ci.yml` | automated gates in `ci.yml` | all green on v1.1 run 44491730340 | release evidence | Verified |
| NFR-G07…G10 | Dependency, secret, auth/input, privacy gates | `NFR_RELEASE_GATES.md` | — | Trivy, Gitleaks, CodeQL, Zod, `PRIVACY.md` | CI jobs + `backend/tests/security/` | green; Trivy report-only | release evidence | Partial (G7 report-only) |
| NFR-G11…G14 | Accessibility, reliability, performance, compatibility | `NFR_RELEASE_GATES.md` | — | widget tests, p95 load smoke, pinned toolchains | TC-032–TC-035; `backend/tests/performance/` | green; manual NFR gates unevidenced | release evidence | Partial |

## Maintenance rules

1. Any change to a requirement, design document, source file or test must update
   the corresponding row in this matrix in the same PR.
2. A story is **Done** only when every mapped test has a recorded result and the
   row says Verified; "Partial" rows must link to an open backlog issue.
3. Do not map Planned/Backlog items (e.g. OS notifications, rubric-to-roadmap,
   MFA enrolment UI) as Verified — see `docs/planning/USER_STORIES.md` Backlog.
4. Review this matrix at each release gate; attach the reviewed version to the
   release evidence.
