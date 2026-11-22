# AUX-178 User Feedback States for API & Network Latency — Investigation & Verification

Date: 21 November 2026
Tree reviewed: `main` at `78582a0` (sprint NP-S3: Testing & Render, 17–25 Nov)
Toolchain: Flutter 3.47.8 / Dart 3.13.7
Method: static review of the Flutter networking and shell layers, followed by
targeted unit and widget tests. Implementation landed in `1c797e8`
(`feat(frontend): slow/failing API latency feedback banner and error fallback`).

## Executive summary

1. **Problem confirmed.** Before this change the client surfaced failures only
   as per-call exceptions; there was no global indication that a session was
   running against a slow or failing backend, so repeated timeouts looked like
   a series of unrelated errors.
2. **Implemented solution.** A singleton `LatencyMonitor` observes every API
   call's duration and transport outcome, derives three quality states
   (`good` / `degraded` / `slow`), and drives a dismissible, accessible
   `LatencyBanner` in the app shell. `ApiClient` now records timeouts,
   connection failures and 5xx responses and throws friendly, non-leaking
   `ApiException` messages.
3. **Verified.** 10 monitor unit tests and 4 new banner widget tests pass
   (14/14). Existing `api_client_test.dart` error-state tests remain green.
4. **No production code changed under this closure pass** — the only additions
   are the four widget tests that were missing from the evidence set.

## Implementation review

### F-1 Latency signal collection (implemented, verified)

`frontend/lib/core/network/latency_monitor.dart`:

- Rolling window of the last **10** samples (`windowSize`).
- **Degraded** when the rolling average (or latest sample) reaches **1500 ms**.
- **Slow** when any sample reaches **4000 ms**, or after **2 consecutive**
  failed requests (`slowFailureStreak`).
- A single fast success clears the failure streak; `dismiss()` hides the banner
  until quality returns to `good` and then degrades again; `reset()` is called
  on logout so one user's network state does not leak into the next
  (`auth_service.dart` line 149).

### F-2 User-facing feedback (implemented, verified)

- `frontend/lib/core/widgets/latency_banner.dart` renders nothing while healthy,
  a tertiary-toned *"Slow network - responses are taking longer than usual."*
  when degraded, and an error-toned *"Connection is very slow - requests may
  time out."* when slow.
- Includes a `Semantics(liveRegion: true, label: message)` announcement for
  screen readers and a `Dismiss` `IconButton`.
- Mounted once at app-shell level (`app_shell.dart` line 323), so it is visible
  on every screen without duplicating per-widget logic.

### F-3 Error-message states (implemented, verified)

`frontend/lib/core/network/api_client.dart`:

- Every request is wrapped in a `Stopwatch`; success, timeout and
  `http.ClientException` outcomes are recorded (`_execute`, lines 282–301).
- Timeouts → *"The server took too long to respond. Please try again."*
- Transport failures → *"Could not reach the server. Check your connection and
  try again."*
- 5xx → `recordServerError()` plus a safe generic message; raw server bodies
  are never rendered (`_errorFor`, lines 327–354).
- 401 still triggers the existing `onUnauthorized` refresh hook.

### F-4 Test coverage gap (closed in this pass)

Only the monitor logic had direct tests; the banner widget had none. Added
`frontend/test/core/latency_banner_test.dart` with four widget tests covering
the hidden/healthy state, both messages, and dismiss/re-arm behaviour.

## Verification performed

| # | Check | Command / action | Result |
|---|---|---|---|
| V-1 | Latency state machine | `cd frontend && flutter test test/core/latency_monitor_test.dart` | **10/10 passed** (good/degraded/slow transitions, failure streak, streak clearing, dismiss/re-arm, 5xx, bounded window) |
| V-2 | Banner widget states | `cd frontend && flutter test test/core/latency_banner_test.dart` | **4/4 passed** (healthy → nothing, degraded message, slow message, dismiss and re-arm) |
| V-3 | Combined run | `flutter test test/core/latency_monitor_test.dart test/core/latency_banner_test.dart` | **14/14 passed** |
| V-4 | ApiClient error states | Static review + existing `test/core/api_client_test.dart` | Timeout, ClientException and "never renders raw 5xx bodies" cases covered |
| V-5 | Wiring | Grep of `frontend/lib` | Monitor recorded in `api_client.dart`; banner mounted in `app_shell.dart`; reset on logout in `auth_service.dart` |

## Residual risks / notes

- Thresholds are compile-time constants, not remotely configurable; a future
  tune requires a release. This is acceptable for the current scope.
- The banner reports global session quality, not a per-endpoint status; a fast
  endpoint is still covered by the warning when another endpoint is slow.
- No telemetry is emitted from the monitor — quality is UI-only, which keeps
  the implementation dependency-free.

## Ticket mapping / closure recommendation

- **AUX-178** — investigation answered and implementation verified: users now
  receive explicit degraded/slow feedback for API and network problems, with
  accessible, dismissible UI and safe error messages. 14 targeted tests pass.
  Ready to move to **Done** with this report attached.
