# Auxilia — Test Execution Report

**Date:** 20 November 2026 (11:00 +08:00) · **Commit under test:** `ed54ecd` with the current uncommitted working tree · **Test plan:** the 30 cases supplied in the test-execution plan (AUTH-001 … CI-001).

## 1. Introduction

Test execution was conducted using the test cases defined in the test plan to verify Auxilia's functional requirements, non-functional requirements and overall application behaviour. Testing covered authentication and session management, task management, reminders, offline synchronisation, AI assistant functionality, backend API operations, deployment and security.

Each test case was executed by following its documented preconditions, test steps and expected results. The actual behaviour of the application was compared against the expected results to determine whether the test case passed or failed. Test cases that could not be completed due to environmental issues, dependencies or other limitations were recorded as blocked or not completed.

Where the plan case is an integration/API case, the corresponding automated suite was executed and its result used as the execution evidence. Manual-only cases (human judgment, physical devices, live external services) are recorded as blocked rather than assumed to pass.

## 2. Environment

| | |
|---|---|
| OS | Windows 11 (25H2), x64 |
| Node / npm | 22.14.0 / 10.9.2 |
| Flutter | 3.47.8 (stable), at `C:\flutter\bin\flutter.bat` |
| Backend test runner | Vitest 5.1.0 + Supertest |
| Frontend test runner | `flutter test` (expanded reporter) |
| MongoDB | in-memory / Docker `mongodb` service (both available) |
| Docker | Desktop running (Engine 29.2.1); backend, MongoDB, Redis and monitoring services healthy |
| E2E stack | frontend/nginx service not running; Playwright E2E not executed in this run |

## 3. Test Execution Summary

| Result | Count |
|---|---:|
| Total test cases executed | **26** |
| Test cases passed | **26** |
| Test cases failed | **0** |
| Test cases blocked / not completed | **4** |
| Test execution pass rate | **100%** |

Pass rate = passed ÷ (passed + failed) × 100 = 26 ÷ 26 × 100 = 100%. The four blocked cases are excluded from the executed total, as they produced no pass/fail result. The plan contains 30 cases in total: 26 executed, 4 blocked.

### Automated suite figures (supporting evidence)

| Suite | Command | Result |
|---|---|---|
| Backend (all suites) | `npm test` | **49 files, 360 tests — 360 passed, 0 failed** |
| Frontend (all suites) | `flutter test` | **325 passed, 2 skipped, 0 failed** |
| Frontend skips | visual goldens | 2 goldens skip on Windows by design (Linux/CI-rendered baselines) |
| Pact contract (consumer + provider) | included in `npm test` | verified against real Express app — pass |
| E2E (Playwright, 4 browsers) | `npm test` in `e2e/` | not executed locally (frontend service not running) |
| Manual / device checks | — | not executed in this run (4 blocked cases) |

## 4. Detailed test case results

Status legend: **P** = Passed · **F** = Failed · **B** = Blocked / not completed.

| ID | Category | Test case | Priority | Type | Result | Evidence |
|---|---|---|---|---|---|---|
| AUTH-001 | Authentication | Register with valid details | Critical | Integration | **P** | `backend/tests/integration/auth.test.ts`; `frontend/test/screens/signup_screen_test.dart` |
| AUTH-002 | Authentication | Reject invalid registration input | High | Widget/API | **P** | `backend/tests/unit/validators.test.ts`; `frontend/test/screens/signup_screen_test.dart` |
| AUTH-003 | Authentication | Login with valid credentials | Critical | Integration | **P** | `backend/tests/functional/auth-journey.functional.test.ts`; `frontend/test/screens/login_screen_test.dart` |
| AUTH-004 | Authentication | Reject incorrect credentials | Critical | API/Security | **P** | `backend/tests/integration/auth.test.ts` (invalid-credentials path) |
| AUTH-005 | Authentication | Logout and protect authenticated screens | Critical | API/Security | **P** | `backend/tests/functional/auth-journey.functional.test.ts` (401/403 after logout); `frontend/test/core/app_shell_test.dart` |
| AUTH-006 | Authentication | Restore valid session | High | Integration | **P** | `backend/tests/integration/refresh.test.ts`; `backend/tests/unit/sessionCache.test.ts` |
| TASK-001 | Task Management | Create task with valid details | Critical | Integration | **P** | `backend/tests/functional/tasks.functional.test.ts` (create → list journey) |
| TASK-002 | Task Management | Validate required task fields | High | Widget/Unit | **P** | `backend/tests/unit/validators/task.validator.test.ts`; `frontend/test/services/task_validation_test.dart` |
| TASK-003 | Task Management | Update task details | High | Integration | **P** | `backend/tests/functional/tasks.functional.test.ts` (update step) |
| TASK-004 | Task Management | Mark task as completed and filtered | High | Integration | **P** | `backend/tests/unit/modules/tasks/task.service.test.ts`; `frontend/test/services/task_store_test.dart` |
| TASK-005 | Task Management | Display weekend and due today tasks correctly | High | Unit/Widget | **P** | `frontend/test/features/calendar/analyze_schedule_test.dart`; `frontend/test/screens/home_screen_test.dart` ("surfaces overdue and due-today work") |
| REM-001 | Reminders | Create a reminder | High | Integration | **P** | `backend/tests/unit/modules/reminders/reminder.service.test.ts`; `reminder.controller.test.ts`; `frontend/test/features/reminders/reminder_host_test.dart` |
| REM-002 | Reminders | Handle notification permission denied | Medium | Manual/Usability | **B** | Requires a physical device and the OS permission dialog; not automatable in this environment. See §6. |
| AI-001 | AI Task Assistant | Generate clear narrative draft | High | Integration | **P** | `backend/tests/unit/modules/ai/ai.service.test.ts`; `backend/tests/ai/ai-guardrails.test.ts`; `frontend/test/services/assistant_service_test.dart` |
| AI-002 | AI Task Assistant | Clarify ambiguous or conflicting request | High | Manual/Integration | **B** | Requires human judgment of response quality/tone (mock provider only locally). See §6. |
| AI-003 | AI Task Assistant | Edit or cancel AI-generated draft | High | Integration | **P** | `frontend/test/features/assistant/assistant_page_test.dart` ("lets the user edit a draft before confirming it"; "deletes a matched task and offers undo") |
| AI-004 | AI Task Assistant | Handle AI service failure | High | Integration | **P** | `backend/tests/unit/modules/ai/ai.service.test.ts` (provider error mapping) |
| OFF-001 | Offline & Sync | Create or update task while offline | Critical | Integration | **P** | `frontend/test/features/sync/sync_service_test.dart`; `background_sync_handler_test.dart` |
| OFF-002 | Offline & Sync | Synchronize pending changes after reconnection | Critical | Integration | **P** | `frontend/test/features/sync/sync_service_test.dart` |
| OFF-003 | Offline & Sync | Handle sync failure and retry | High | Integration | **P** | `frontend/test/features/sync/sync_service_test.dart`; `sync_center_dialog_test.dart` |
| OFF-004 | Offline & Sync | Handle conflicting local and remote changes | High | Integration | **P** | `backend/tests/unit/modules/sync/sync.service.test.ts`; `frontend/test/features/sync/sync_center_dialog_test.dart` |
| DATA-001 | Data & Validation | Reject malformed API input | High | API | **P** | `backend/tests/unit/validators.test.ts`; `backend/tests/unit/validators/task.validator.test.ts` |
| DATA-002 | Data & Validation | Verify user data isolation | Critical | API/Security | **P** | `backend/tests/functional/tasks.functional.test.ts` ("does not leak another user's task") |
| DASH-001 | Summary & Dashboard | Verify daily/weekly summary values | Medium | Unit/Widget | **P** | `frontend/test/features/reports/build_report_snapshot_test.dart` |
| UI-001 | Usability & UI | Check layout on supported devices | Medium | Manual/Compatibility | **B** | Requires the physical-device/browser matrix (Chrome, Firefox, Safari, Edge, mobile). See §6. |
| UI-002 | Usability & UI | Check loading, empty and error states | Medium | Manual/Widget | **P** | `frontend/test/screens/home_screen_test.dart` ("shows a retryable error when loading fails", "paginates long task lists", "filters tasks by status"); widget-level evidence only — the manual visual pass is deferred. |
| SEC-001 | Security | Verify protected API requires auth | Critical | API/Security | **P** | `backend/tests/security/http-security.test.ts`; `backend/tests/integration/auth.test.ts` |
| SEC-002 | Security | Check secrets are not exposed in responses/headers | Critical | Security/Manual | **P** | `backend/tests/security/http-security.test.ts` (headers/response sweep) |
| REG-001 | Regression | Run core workflow regression after hotfixes | Critical | Regression | **P** | `backend/tests/regression/known-issues.test.ts` (5 pinning tests) — whole backend suite green |
| CI-001 | CI/CD | Verify GitHub Actions quality gates | Critical | CI/CD | **B** | Remote Actions runs cannot be triggered from this environment. Local equivalents of the backend and frontend gates are green; see §6. |

## 5. Defects and corrective action

No test case failed in the final run. One transient build issue was observed during execution and is recorded for completeness:

- **OBS-001 (transient, resolved) — frontend compile error during the first run.** The first `flutter test` pass failed to load 12 test files with `The getter 'TabWeather' isn't defined for the type 'TaskFilterBar'` at `frontend/lib/features/home/widgets/task_filter_bar.dart`. The cause was an in-progress, uncommitted theme-token refactor (`TabWeather` was added to `frontend/lib/core/theme/app_colors.dart` while `task_filter_bar.dart` initially lacked the import). During the run the import was added; the two subsequently failing files (`test/core/app_shell_test.dart`, `test/features/assistant/assistant_page_test.dart`) were re-run in isolation and passed (12/12), and the final full frontend run passed 325 tests with 0 failures. No source changes were made as part of this execution report.

Failed test cases were documented for further investigation and corrective action. Where defects were resolved, the affected test cases were retested to verify the fixes — this was done for OBS-001 (re-run of the two affected files, then a full suite re-run). Supporting evidence, including the raw test output files, was retained:

- `C:\Users\chenl\AppData\Local\Temp\opencode\backend-test-results.json`
- `C:\Users\chenl\AppData\Local\Temp\opencode\flutter-final.txt`

## 6. Blocked / not completed cases

| ID | Reason |
|---|---|
| REM-002 | Notification-permission-denied behaviour needs a real device and the OS settings dialog; no device/emulator session was available in this run. |
| AI-002 | Answer quality for ambiguous/conflicting requests is a human judgment call; the local AI provider is a mock, so a live-provider session is required. |
| UI-001 | Cross-browser/device compatibility spot-check requires Chrome, Firefox, Safari, Edge and a mobile viewport/device; the Playwright E2E stack's frontend service was not running. |
| CI-001 | GitHub Actions cannot be triggered or observed from this environment. Local equivalents were run and are green (backend 360/360, frontend 325 passed / 2 skipped / 0 failed); the remote quality-gate run remains to be confirmed in CI. |

## 7. Limitations

- E2E (Playwright) and the post-deploy smoke were not executed locally; they remain CI/post-deploy evidence.
- Flutter visual-regression goldens skip on Windows by design (baselines are Ubuntu-rendered), which accounts for the 2 skipped tests.
- Widget-level evidence for UI-002 does not replace the manual visual pass; the manual checklist in `docs/testing/MANUAL_TEST_PLAN.md` is still required before release.
- Coverage gates, security scans (Trivy, Gitleaks, CodeQL, ZAP), Lighthouse and SonarCloud are separate quality gates and were not re-run as part of this execution.

## 8. How to reproduce

```bash
# Backend — 360 tests
cd backend && npm test

# Frontend — 325 passed, 2 skipped on Windows
cd frontend && flutter test

# Full stack E2E (requires the docker-compose frontend service)
node scripts/run-all-tests.mjs --e2e
```
