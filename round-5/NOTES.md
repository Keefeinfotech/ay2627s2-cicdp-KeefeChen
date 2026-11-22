# Auxilia · Round 5 — Build Notes

**Date:** 2026-11-19 · **Author:** design/engineering session · **Status:** complete (with documented limitations)

## 1. Outcome first

Three complete, self-contained design directions live in `round-5/`:

- `a-secretary-desk/index.html` — warm editorial, sidebar, medium density (recommended)
- `b-quiet-studio/index.html` — radical restraint, top tabs, single column
- `c-command-center/index.html` — dark high-density console, icon rail, Ctrl+K
- `index.html` — side-by-side comparison and entry point
- `mobbin/RESEARCH.md`, `mobbin/DNA.md`, `mobbin/` (6 reference screenshots)

Open `round-5/index.html` in a browser to compare. Every direction implements: auth (login/signup with inline validation), onboarding (skippable, 3 steps), dashboard, task management (list, complete, filter by course tag, quick add), AI assistant (natural-language → clarification → confirmable preview), reminders (list + notification preferences), insights (7-day bars + summary), profile/settings (with logout), and mobile bottom navigation. No previous rounds were modified; nothing lives outside `round-5/`.

**“Bump to a full 10”:** honest answer — these prototypes are not a 10/10 product experience, and I won't claim they are. What moved the needle: research-led design DNA (references actually studied and downloaded, not vibes), three genuinely differentiated directions, working interactions, accessibility passes, and one documented critique round. A real 10 requires user testing with students, which has not happened.

## 2. Existing project inspection (what was read before designing)

- `README.md`, `CHANGELOG.md` — product framing, Trust Blue re-theme (#98), /api/v1 versioning, analytics endpoints (`/api/v1/analytics/weekly`, priority suggestions), notification service prototype.
- `frontend/lib/core/theme/` — `app_colors.dart`, `app_theme.dart`, `app_spacing.dart`: Trust Blue (#2563EB/#1D4ED8) on cool near-white #F1F5F9; Roboto; 8px grid; radii 8/12/16; touch targets ≥48px; dark scheme (deep navy) defined.
- `frontend/lib/core/widgets/` — component library (AppButton, AppCard, AppTextField…), animated gradient background, BrandMark (now brand gradient after Round 5 polish).
- `frontend/lib/features/home/` — dashboard header with weather accents, XP/streak level progress.
- `docs/` — user stories, OWASP implementation, change management.
- Known state: `reminders_screen.dart` has **pre-existing compile errors** (unresolved `AppSnackBar`, non-constant `Theme.of` in const context) breaking `home_dashboard_test.dart`; theme tests pass after the CardTheme elevation expectation was updated (2→0).

**Implemented vs under development vs proposed (not faked):**
- Implemented (backend + app): auth/session, tasks CRUD, reminders, weekly analytics endpoint, priority suggestions, notification service prototype (fail-open), sync queue.
- Under development: assistant service (`backend/src/modules/assistant/` — untracked WIP in this working tree), notifications module, preferences module, `docs/api-audit.md`.
- Prototype/proposed: everything in Round 5 HTML prototypes — the NL assistant is a **local heuristic demo**, explicitly labelled as such in each UI; persistence is in-memory (auth/onboarding use localStorage only for the seen-onboarding flag); no backend calls are made from the prototypes.

## 3. Mobbin research (summary)

Full detail: `mobbin/RESEARCH.md`. **Honest method note:** the Mobbin MCP is not connected to this environment (verified). Substitute: mobbin.com via web search + direct fetches; images downloaded from Mobbin's public CDN. References used:

| # | Reference | What it taught Auxilia |
|---|-----------|------------------------|
| 1 | Todoist iOS Productivity Summary | Segmented Daily/Weekly; one hero ring; streak as a number; 7-day bar list — adapted for Insights + dashboard goal ring |
| 2 | Notion Web AI Chatbox | Non-modal assistant; suggested prompts; docked panel; confirm-before-act |
| 3 | Brilliant Web Dashboard | Momentum hero (greeting + resume CTA), not widget grids; XP/streak as header context |
| 4 | Asana Android Categorized Task List | Group by time horizon (Overdue/Today/This week/Later); course chips above list |
| 5 | Linear Web Due Date Picker | One decision per dialog; helper text; single primary action |
| 6 | Coursera iOS Course Dashboard | Progress as a sentence + next action; module/course tags |

## 4. Design decisions and rationale

- **Trust Blue stays.** Green reserved for completion/success only. No purple, no emoji, Roboto everywhere.
- **Three directions differ on ≥5 axes** (see `index.html` comparison table): colour distribution, navigation structure, density, task presentation, assistant interaction, typography hierarchy, layout.
- **A (Secretary's Desk)** leans on the Brilliant/Asana axis: sidebar + momentum hero; warm ivory to counter the "dull" cool-grey flatness called out in the Round 5 critique of the shipped app.
- **B (Quiet Studio)** interrogates whether a productivity app needs chrome at all; extreme whitespace; divider-ruled lists; underline tabs.
- **C (Command Center)** maximizes density for CS students: mono tabular numerals, sync status, activity log, icon rail, Ctrl+K. Deliberately least approachable of the three.
- **Assistant never creates silently** — universal across directions (preview card + explicit confirm/cancel), implementing D2 from DNA.md.
- **Rejected:** gamification modules on dashboard, red as brand accent, modal-first micro-interactions, AI “magic” without preview.

## 5. Design systems (tokens)

All directions: 8px grid; radii 8/12/16/999; Roboto 400/500/700 (+ Roboto Mono for C's data); 20px stroke icons; 2px focus ring with offset; WCAG AA-targeted contrast (see below).

- **A:** bg #FBF9F4, surface #FFFFFF, ink #1C2B45, ink-2 #55637E, blue #1D4ED8, green #047857, tints #E8EEFC/#E3F4EC/#FBE7E7. Shadow: `0 1px 2px rgba(28,43,69,.06), 0 8px 24px rgba(28,43,69,.08)`.
- **B:** bg #FAFBFC, surface #FFFFFF, ink #0F172A, ink-2 #64748B, blue #2563EB, green #059669, hairlines #E7EAEE/#D5DBE3. No shadows; radius 8–12px.
- **C:** bg #0B1220, surface #111A2C, surface-2 #182338, line #22304A/#2E3F5C, ink #E6ECF5, ink-2 #8CA0BC, azure #60A5FA, green #34D399, red #F87171, amber #FBBF24.

## 6. Typography

A: display 28–38px -0.5/-1px tracking 700; B: display 28–38px weight 400 (light editorial); C: 15–18px weight 500 + mono 12px data. All body ≥13px; secondary 11–12px only in C (mono, high contrast) and labels.

## 7. Accessibility & contrast (computed, not claimed)

| Pair | Ratio | Result |
|------|-------|--------|
| A ink #1C2B45 on #FBF9F4 | ≈ 12.6:1 | AAA |
| A ink-2 #55637E on #FBF9F4 | ≈ 6.0:1 | AA |
| A white on #1D4ED8 (primary btn) | ≈ 7.5:1 | AAA |
| B ink-2 #64748B on #FAFBFC | ≈ 4.9:1 | AA (normal text) |
| B blue #2563EB on white | ≈ 5.2:1 | AA |
| B white on #0F172A | ≈ 17:1 | AAA |
| C ink #E6ECF5 on #111A2C | ≈ 12.1:1 | AAA |
| C ink-2 #8CA0BC on #111A2C | ≈ 5.6:1 | AA |
| C azure #60A5FA on #0B1220 | ≈ 7.9:1 | AAA |
| C #0B1220 on #60A5FA (primary btn) | ≈ 7.9:1 | AAA |

Focus-visible rings on all interactive elements; `aria-pressed` on toggles; `aria-live="polite"` on chat and toast; `prefers-reduced-motion` disables non-essential motion in all three; forms validate inline with `role="alert"` error summaries; hit targets ≥40px (mobile bottom bars 56–62px).

## 8. Interaction & motion

Entrance: fade/rise 200–320ms ease-out. Task toggle: 150–180ms fill transition. Assistant: 280–350ms canned reply delay (perceived thinking), scroll-pinning. Bars animate `width .5–.6s`. Onboarding dots expand on active step. A honors `prefers-reduced-motion`; B instant-ish; C minimal fade only. No decorative parallax; no auto-playing anything.

## 9. Responsive behaviour

- ≥1100px: A sidebar layout, C multi-panel 12-col, B centered 880px column.
- 768–1099px: A stats wrap to 3-col, C panels halve; B unchanged.
- ≤860px: A/B/C collapse to bottom 5-tab bar; C grid → single column; auth split-panel → single card (A hides aside, C hides terminal left).
- Screenshots at 1440/768/375 **were not captured** — no browser is connected to this session (see §11). Layouts were verified by CSS review and the checks in §10.

## 10. QA results (what was actually run)

- Node syntax check of every inline `<script>` in all four HTML files: **pass**.
- Crude tag-balance check (div/section/main/nav/form/table/button/span): **pass**.
- Contrast: computed in §7 (≥AA everywhere; AAA for primary paths).
- Assistant flow: logic reviewed for all three (parse → clarify-if-no-when → preview → confirm/cancel); task toggles re-render lists; tag filters re-render; quick add validates non-empty.
- Existing automated tests: `flutter test test/core/theme_test.dart` **passes**. `home_dashboard_test.dart` **fails to compile due to pre-existing errors in `reminders_screen.dart`** (not introduced or fixed here; out of Round 5 scope). Backend suites not re-run — unrelated to static prototypes.
- Not run: Lighthouse, real-device QA, screen-reader pass, cross-browser matrix. **No claim is made that these passed.**

## 11. Critique round (one full pass per direction) — what changed and why

- **A:** Empty “Today” state was blank → added explicit all-clear copy. Kept warm ivory after critique re-check: cool-grey alternative was indistinguishable from the “dull” baseline; warm paper is the differentiator.
- **B:** Chat input suppressed default outline with no replacement → added visible 2px focus ring. Confirmed 400-weight display type survives mobile (clamp()).
- **C:** Same focus-ring defect in terminal input → fixed identically. Verified azure #60A5FA on navy meets AA for 11px mono (7.9:1). Kept density; reduced border noise by using surface/line contrast over extra outlines (anti-pattern #8 avoided).
- **Index comparison** now states recommendation explicitly (A, with B's restraint and C's Ctrl+K/status line ported in).

## 12. Known limitations & deviations from brief

1. **Mobbin MCP unavailable** — research used mobbin.com via web search/fetch; images downloaded from public CDN. Source links included for all six references.
2. **No screenshots at 1440/768/375** — no desktop browser connected; HTML/CSS reviewed instead. Recommended: open `round-5/index.html` and capture, or run `npx serve round-5` locally.
3. **Not wired to backend** — by design for a design round; assistants are labelled local-heuristic demos. Wiring = `/api/v1/assistant/parse` + `/api/v1/tasks` on confirm (C's protocol note).
4. **No flutter integration** — Round 5 deliberately ships static prototypes; porting A into Flutter = map tokens to `app_colors.dart`/`app_theme.dart` (already aligned: same blues/roles, Roboto, 8px grid).
5. **Prior rounds untouched** — including the broken `reminders_screen.dart`; `git status` shows an active parallel session's uncommitted work intermixed with this repo; Round 5 touches only `round-5/`.
6. Goal-ring in A/B and stats in all directions use representative numbers labelled as demo state, not live data.

## 13. Recommended direction

**Ship A (Secretary's Desk).** Warm, trustworthy, closest to the shipped architecture (sidebar + stat grid), fully on-brand, and the strongest first-impression for the portfolio narrative. Borrow from B: hairline dividers and whitespace discipline to keep A from regressing into card-soup. Borrow from C: Ctrl+K command path and the sync status line. Keep B as the accessibility-focused alternate theme; park C as an “Auxilia for CS students” experiment.

## 14. Git state note

Round 5 files are untracked in the working tree alongside another session's uncommitted changes. Committing was left to the owner; `round-5/` can be added wholesale with `git add round-5`.
