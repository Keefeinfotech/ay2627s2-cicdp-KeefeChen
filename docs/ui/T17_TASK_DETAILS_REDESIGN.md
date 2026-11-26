# T17 — Task details redesign (source-grounded)

The only task-details surface in this repository is the `TaskEditor` modal sheet in
[`frontend/lib/features/home/widgets/task_editor.dart`](../../frontend/lib/features/home/widgets/task_editor.dart).
The wireframe attachment is not present in the workspace, so this redesign is based on
that widget and the app’s canonical design tokens rather than a new, invented page.

Live mockup: [`t17-task-details-proposal.html`](t17-task-details-proposal.html)

## What changed from the first pass

| First pass (invented) | Grounded version |
| --- | --- |
| Standalone desktop task page with fictional course `CS-201` | Centred 640px `TaskEditor` modal over the real Tasks shell |
| Purple/blue gradients and 14px radii | Flat Trust Blue, `Ds.rLg` / `AppRadius.md` radii, no gradients |
| Made-up nav labels and stats | `ShellDestination` labels: Home, Tasks, Projects, Groups, Calendar, AI Assistant, Reports, Profile |
| 64px top bar | 52px `_CompactShellHeader` from `AppShell` |
| Arbitrary spacing | `Ds` 4px scale and `AppSpacing` values |
| Generic badges | Actual priority colours from `TaskCard` and `PriorityBadge` |

## Source of truth

| Concern | Source | Values used |
| --- | --- | --- |
| Primary palette | `core/design_system/ds_tokens.dart`, `core/theme/app_colors.dart`, `core/theme/app_theme.dart` | `#1D4ED8` primary, `#2563EB` secondary, `#DBEAFE` selected container, `#F1F5F9` canvas, `#0F172A` text |
| Priority | `features/home/widgets/task_card.dart` lines 45–49 | Low `#1055C2`, Medium `#C78600`, High `#C62828` |
| Dark mode | `app_theme.dart` `_darkScheme`, `app_colors.dart` dark surfaces | `#0F172A` canvas, `#1E293B` surface, `#263449` container, `#60A5FA` primary |
| Spacing/radius | `ds_tokens.dart`, `app_spacing.dart` | 4 / 8 / 12 / 16 / 24 / 32 / 48; radius 6 / 8 / 10 / 999 |
| Type | `app_typography.dart` | Roboto 20/600 title, 15/600 label, 14/1.55 body, 11.5/600 caption |
| Interaction | `app_theme.dart` `ThemeData` | hover `primary @ 6%`, focus `primary @ 10%`, splash `primary @ 12%`, card `Ds.elevation1`, modal `Ds.elevation4` |
| Modal geometry | `task_editor.dart` lines 227, 241–242 | max width 640, max height 92% of viewport, scrollable body, sticky footer |
| Shell geometry | `app_shell.dart` line 474; `app_navigation.dart` lines 29, 257 | 52px header, 248px sidebar, 92px rail |
| Content width | `app_spacing.dart` `AppSizes.maxContentWidth` | 1120px |

## Layout decisions

1. **Keep the sheet, do not invent a details page.** Editing happens in a modal;
   the redesign preserves the handle, scrollable body and sticky action footer.
2. **One primary action.** Only `Save changes` uses the filled primary style.
   `Cancel`, `Clear due date` and `Clear reminder` remain text buttons.
3. **Priority is status, not decoration.** High uses `Ds.dangerRed` only in the
   priority control and the corresponding task card; blue is reserved for
   primary actions and selection.
4. **No label wrapping.** Schedule buttons are equal-width with ellipsis, and
   stack below 600px. The segmented control shrinks its font to 12px on phones.
5. **States come from the theme.** Hover and focus use the exact alpha values
   already configured in `AppTheme._build`, so the HTML and Flutter stay aligned.

## Implementation notes

- Replace the hardcoded CSS variables with `Theme.of(context).colorScheme`
  lookups when porting to Flutter; do not introduce new colour literals.
- Keep `AppTextField`, `SegmentedButton`, `ActionChip`/`InputChip` and `AppButton`
  so validation, semantics and widget tests continue to work.
- The error row maps to `_scheduleError` in `TaskEditor`; it should only appear
  after `validateSchedule` fails, not as a permanent visual element.
- Preserve `_isDirty` / `_requestClose` behaviour — the visual redesign must not
  bypass the unsaved-changes confirmation.

## Implemented in Flutter

The redesign has been applied to the app, not just the mockup:

- `frontend/lib/features/home/widgets/task_editor.dart`
  - Grouped the form into **Basics**, **Organise**, **Priority** and **Schedule**
    sections with a hairline section rule instead of an undifferentiated list.
  - Added `PriorityBadge` / `StatusBadge` context under the sheet title so the
    current priority and due state are visible without scrolling.
  - Added `_scheduleControls`; schedule buttons stack below 440px and use
    single-line ellipsis, so labels never wrap or overflow on phones.
  - Kept the 640px / 92%-height geometry, sticky footer, validation, dirty-state
    guard and all existing text labels used by widget tests.
- `frontend/lib/core/widgets/app_button.dart`
  - Primary buttons now read `Theme.of(context).colorScheme.primary` instead of
    the legacy `Ds.trustBlue` literal, so every primary action follows the
    active professional Trust Blue scheme.
  - Button labels/icons use the paired `colorScheme.onPrimary` foreground instead
    of hardcoded white. This keeps dark mode at WCAG AA contrast on the lighter
    Trust Blue primary surface.
- `frontend/lib/core/theme/app_colors.dart`
  - Added `darkWarning` (`#FBBF24`) so medium priority stays legible in dark
    mode without introducing a one-off colour literal in a feature widget.
