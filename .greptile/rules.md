# Auxilia review standards

## Flutter frontend

- Follow the existing feature-first widget architecture and use Riverpod where
  that feature already uses providers. Keep view state, business logic, and
  persistence responsibilities separate.
- Navigation is registered in `frontend/lib/core/routing/app_router.dart` using
  named Material routes. Keep route arguments typed and preserve back-stack
  behavior; do not assume this repository uses `go_router`.
- Handle asynchronous work, cancellation, loading, and failure states. Do not
  silently discard errors when that can lose user data or leave stale UI.
- Preserve offline behavior and synchronization invariants: queued operations
  should be safe to retry, conflicts must remain visible, and local data should
  not be overwritten by stale server responses.
- Keep Dart null-safe, avoid unnecessary rebuilds and work in `build`, and add
  focused unit/widget tests for user-visible behavior and navigation changes.
- Check text scaling, narrow layouts, semantics, focus order, and accessible
  touch targets when changing UI.

## Express and TypeScript backend

- Preserve the Controller-Service-Repository boundaries and keep HTTP concerns
  out of persistence code.
- Validate untrusted request values before business logic. Use the existing
  Zod validation middleware and schemas where those are used; preserve the
  established calendar validation contract where it uses `express-validator`.
- Check JWT authentication and per-resource authorization separately. A valid
  token must not grant access to another user's task, group, or sync data.
- Return safe, consistent API errors. Never expose tokens, secrets, stack
  traces, database details, or raw provider responses to clients or logs.
- Review Mongoose filters, projections, indexes, pagination, and transaction
  boundaries for correctness and query cost. Do not trust client-supplied
  ownership fields.
- Add or update unit, integration, and contract tests for changed API behavior.

## Security and quality

- Check applicable OWASP Top 10 risks, especially broken access control,
  injection, authentication/session weaknesses, sensitive data exposure, and
  insecure configuration.
- Look for secrets, unsafe logging, untrusted redirects, unsafe deserialization,
  and dependency or container changes that introduce known vulnerabilities.
- Look for duplicated business rules, unnecessary complexity, unclear names,
  missing error handling, and regressions across callers or persisted data.
- Do not flag style preferences as defects unless they conflict with a stated
  repository convention or make behavior harder to maintain.
- Do not claim tests or scans passed unless their results are present in the PR.
