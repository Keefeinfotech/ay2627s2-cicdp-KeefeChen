# Project Todo List

## Phase 1 - Backend Password Strength Validation
- [x] Add password strength validation to auth.validation.ts (Zod custom refinement)
- [x] Add password strength checking logic to auth.service.ts signup
- [x] Add backend integration tests for password strength rejection
- [x] Verify rate limiting on auth routes (already exists)

## Phase 2 - Frontend Design System & Fonts
- [x] Verify fonts declared in pubspec.yaml (Inter fonts already present)
- [x] Verify Trust Blue theme (no purple, no gradients, Lucide-style icons)
- [x] Reconcile typography font-family from Roboto to Inter to match pubspec fonts

## Phase 3 - Frontend Signup Overflow Fix
- [x] Fixed AuthShell mobile bottom padding for keyboard insets (already uses viewInsets)
- [x] Fixed Column mainAxisAlignment to center and crossAxisAlignment to center
- [x] Tested on small screens via Flutter tests (no RenderFlex overflow)

## Phase 4 - Frontend Enhanced Signup
- [x] Add confirm password field to signup form
- [x] Add real-time password strength indicator (5 levels)
- [x] Add live password requirements checklist with dynamic checkmarks
- [x] Add show/hide password toggle
- [x] Prevent submission when passwords don't match or strength is too weak

## Phase 5 - Frontend Onboarding UI Refinement
- [x] Balance layout, spacing, sizing across all pages
- [x] Add 4th page for collaboration/shared progress (per requirements)
- [x] Ensure progress indicators accurate (updated _pageCount to 4)
- [x] Keep Skip/Back/Next/Get Started consistently positioned

## Phase 6 - Dummy Data Seed Scripts
- [x] Create backend seed script (backend/scripts/seed.ts)
- [x] Create data definitions (backend/scripts/seed-data.ts)
- [x] Add npm scripts (seed, seed:reset, seed:dry-run)
- [x] Support repeatable seeding without duplicates (upsert pattern)
- [x] Provide reset mechanism (--reset flag)
- [x] Create documentation (docs/development/dummy-data.md)
- [x] All 22 user/task/group/roadmap/rubric/feedback/calendar/session records seeded
- [x] TypeScript compiles, ESLint clean, all 219 backend tests pass

## Phase 7 - Testing
- [x] Add frontend widget tests for signup (password strength, confirm password, overflow)
- [x] Add backend tests for password validation
- [x] Run flutter analyze — No issues found
- [x] Run flutter test — All 276 tests pass
- [x] Run backend lint, typecheck, and tests — All 219 tests pass
- [x] Add seed script unit tests (verify idempotency, no duplicates on re-seed)

## Phase 8 - CI/CD Best Practices for PRs
- [x] Add .github/CODEOWNERS for automatic reviewer assignment
- [x] Add CONTRIBUTING.md with branch naming, Conventional Commits, PR requirements
- [x] Add workflow_dispatch trigger for manual CI re-runs
- [x] Add paths-ignore for docs-only changes to skip full CI
- [x] Update pull_request_template.md with CI/CD Checklist section
