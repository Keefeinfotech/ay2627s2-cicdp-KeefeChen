# Auxilia frontend

Flutter client for Auxilia, an offline-first student task manager with optional
accounts and an AI study assistant. Tasks, XP, and achievements work without a
network connection; authentication and the assistant use the Express API.

## Run

```bash
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000
```

`API_BASE_URL` defaults to `http://localhost:3000`. CAPTCHA is disabled unless
`TURNSTILE_SITE_KEY` is supplied at build time.

## Structure

```
lib/core/        design tokens, shared widgets, API client, named routes
lib/features/
  onboarding/     first-launch product introduction and completion store
  authentication/ login, signup, startup gate, auth/session/captcha
  home/           dashboard, task model/store/repository, editor, gamification
  assistant/      chat screen, composer, bubbles, assistant API service
  profile/        profile and local-data actions sheet
lib/app.dart      MaterialApp shell and theme wiring
lib/main.dart     ProviderScope entry point
```

The older `lib/screens`, `lib/widgets`, `lib/models`, `lib/services`,
`lib/routing`, `lib/theme`, and `lib/utils` paths are thin re-export shims kept
for backward compatibility. New code should import from `lib/core` or
`lib/features`.

## Launch flow

1. First launch shows the four-page onboarding introduction. Skip and Get
   Started both persist completion in shared preferences under
   `auxilia.onboarding.completed.v1`.
2. Get Started opens the separate sign-in screen. Create Account opens
   registration; both use the existing email/password API.
3. A returning unauthenticated user goes straight to sign-in. A valid stored
   session skips both and restores the dashboard.
4. Guest access remains available from sign-in and keeps tasks on the device.

The backend supports email/password signup and login only. Google/GitHub OAuth
and password reset are not implemented, so the UI does not simulate them; the
forgot-password link explains that reset is unavailable.

## Routes

| Route | Screen |
|-------|--------|
| `/` | Startup gate (onboarding, sign-in, or dashboard) |
| `/onboarding` | First-launch product introduction |
| `/welcome` | Compatibility alias for sign-in |
| `/login` | Sign in |
| `/signup` | Create an account |
| `/home` | Task dashboard (accepts `HomeArgs`) |
| `/assistant` | AI chat (accepts `AssistantArgs`) |

Unknown routes fall back to the startup gate.

## Design system

- Palette and semantic colours: `lib/core/theme/app_colors.dart`
- Spacing, radius, and sizing tokens: `lib/core/theme/app_spacing.dart`
- Typography scale and Inter font family: `lib/core/theme/app_typography.dart`
- Light/dark Material 3 themes: `lib/core/theme/app_theme.dart`
- Shared components: `lib/core/widgets/`

Inter Regular, Medium, SemiBold, and Bold are bundled in `assets/fonts/`.
Deep Navy is the primary brand colour; white and soft grey carry surfaces; teal
is reserved for success states. Primary actions use Clear Blue.

## Checks

```bash
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test --coverage
dart run tool/check_coverage.dart 60
flutter build web --release
```
