# Auxilia — UI/UX Review (Dashboard & Design System)

Date: 20 November 2026 · Scope: Flutter frontend (`frontend/lib`), focusing on the student dashboard shown in the supplied screenshot and the shared design tokens/widgets it depends on.

## Method

Inspected the actual widgets and theme files, then validated changes with `dart format`, `flutter analyze --no-fatal-infos`, and the full `flutter test` suite. No backend, API, authentication, routing, data or task logic was changed.

## Findings and fixes

| # | Severity | Where | Problem | Fix |
|---|---|---|---|---|
| 1 | High | `dashboard_header.dart`, `animated_tab.dart` | `TabWeather` was declared **twice** with stale "weather" values (`moss` = slate, `persimmon` = orange-red). Two independent copies drift from the Trust Blue system. | Single `TabWeather` in `app_colors.dart`: Trust Blue for all/open/XP, deep trust blue for to-do, red only for overdue, green only for completed. Both consumers now import it. |
| 2 | High | `dashboard_header.dart` | KPI cards had **coloured borders and tinted shadows** (red overdue, green done, blue XP) — a rainbow effect that conflicts with "Trust Blue primary, subtle green accents". | Uniform neutral surface + `scheme.outlineVariant` border for all five cards; colour appears only in a small semantic icon tile. |
| 3 | High | `home_screen.dart` + `dashboard_header.dart` | The header added its own `EdgeInsets.all(16)` inside the screen's `EdgeInsets.fromLTRB(16, …)`, so the brand/KPI content sat **16px further right than the search field** (visible in the screenshot). | Header no longer owns outer padding or a second 1120px constraint; the parent controls alignment. |
| 4 | Medium | `dashboard_header.dart` | Level progress bar used a slate accent (`TabWeather.pending`) and raw sizes (radius 4, height 8). | Uses `scheme.primary` (Trust Blue) and `AppRadius.xs` / `AppSizes.progressHeight`. |
| 5 | Medium | `dashboard_header.dart` | Five KPI cards had no consistent minimum height; values/labels could shift with content or text scaling. | `AppSizes.statCardMinHeight` (104) on every card; uniform `iconTile` (36), `iconMd` (20) icon and `AppSpacing` padding. |
| 6 | Medium | `dashboard_header.dart` | KPI grid used raw breakpoint `620`, gap and a hardcoded 3-column divisor; cramped on small phones. | `AppSizes.compactBreakpoint` (620) and `tightBreakpoint` (360): 2 columns on very small phones, 3 on narrow, 5 on wide; gaps from `AppSpacing`. |
| 7 | Medium | `dashboard_header.dart` | A **duplicate `BrandMark`** (gradient + sparkle) shadowed the shared one in `app_avatar.dart`. | Removed the duplicate; uses the shared, theme-aware `BrandMark` (consistent with the auth screens). |
| 8 | Low | `animated_tab.dart` | Count badge used raw `fontSize: 12`, padding `6/2` and border `1.5`, breaking the type/spacing scale. | Uses `textTheme.labelSmall`, `AppSpacing.sm`/`xxs`, `AppSizes.hairline`. |
| 9 | Low | `app_theme.dart` | TextButton (44) and IconButton (44×44) minimum sizes differed from the shared 48px touch target. | Both use `AppSizes.touchTarget` (48) — satisfies Android 48dp and iOS 44pt guidelines. |
| 10 | Low | `home_screen.dart`, `responsive_page_layout.dart`, `app_button.dart` | Repeated raw `1120`, `16/24/16/16` padding and `18px` spinner sizes. | Replaced with `AppSizes.maxContentWidth`, `AppSpacing.lg`/`xl` and `AppSizes.iconMd`. |
| 11 | Low | `app_spacing.dart` | No tokens existed for the recurring icon tile, stat-card height, progress height, hairline and responsive breakpoints. | Added them to `AppSizes` so future screens reuse the same values. |
| 12 | Medium | `app_colors.dart`, `dashboard_header.dart`, `animated_tab.dart` | Dark-theme semantic accents (deep blue/green/red) were too dark for text and icons on dark surfaces. | `TabWeather.display(accent, scheme)` maps to lighter dark variants for text/icons while keeping the semantic hue. |

## Design direction compliance

- Trust Blue (`#2563EB`) is now the default accent for all neutral/open states; green is reserved for completion and red for overdue.
- No purple/violet colours or purple gradients are present in `frontend/lib`.
- Roboto typography comes from the central `AppTypography` scale; no new font sizes were introduced.
- No emojis were introduced as UI icons.

## Deliberately not changed

- **Avatar glyph choices** (`AvatarAccent.glyphChoices`) include emoji characters. They are user-selected *avatar content* persisted in user profiles, not action/navigation icons; removing them would break saved avatars and the avatar editor (functionality/data constraint).
- **Legacy colour token names** (`pacific`, `moss`, `saffron`, `persimmon`) remain as aliases in `AppColors` — feature widgets depend on them, and their values already point at the Trust Blue palette.
- Admin/report screens with bespoke chart geometry — changing them would be a redesign beyond this dashboard review; they already use theme colours.
- Dark canvas: the existing dark theme uses Trust Blue surfaces/accents; the global light/dark choice was left intact.

## Validation

| Check | Result |
|---|---|
| `dart format lib` | clean |
| `flutter analyze --no-fatal-infos` | No issues found |
| `flutter test` | 325 passed; 2 goldens skipped off Linux (CI is the golden gate) |
| Golden baselines | untouched — TaskCard was not modified |
| Backend / API / auth / data | untouched |
