# Microservices Split — Implemented (Basic)

Status: **implemented and integrated, intentionally basic**. Auxilia remains a
modular monolith; the notification-service is a real, running extraction
candidate, not just a design sketch. It is a basic integration: synchronous
HTTP with in-process queueing, no broker, no retries.

## Candidate seam: notification delivery

Notifications (reminder emails, future push/SMS) are a good first candidate
because they:

- change independently of the task domain,
- are naturally asynchronous and retryable,
- have a simple, stable contract (`recipient`, `channel`, `message`).

## What is implemented

`backend/prototype/notification-service/` — a zero-dependency Node service:

| Method | Path      | Purpose                                  |
| ------ | --------- | ---------------------------------------- |
| GET    | `/health` | Liveness probe (used by compose).        |
| POST   | `/notify` | Accepts a notification; logs it (stub).  |

Integration points:

- **docker-compose.yml** — `notification-service` runs as its own container
  (port 3100, health-checked); the `backend` service depends on it and gets
  `NOTIFICATION_SERVICE_URL=http://notification-service:3100`.
- **Backend client** — `backend/src/services/notification.service.ts`:
  `fetch`-based HTTP client, 2s timeout, fail-open (logs and drops when the
  service is unreachable or unset).
- **Background job** — `notification.send` registered in
  `backend/src/shared/jobs/`; callers enqueue instead of blocking the request
  path.
- **Reminder hook** — creating a reminder enqueues a notification email to
  the user (`reminder.service.ts`).
- **Local runs without compose** — set `NOTIFICATION_SERVICE_URL` in
  `backend/.env` (see `.env.example`) or leave it unset to no-op.

Run it standalone: `node backend/prototype/notification-service/src/index.mjs`

## Not done (deliberately)

- No production deployment (`render.yaml` unchanged), no Kubernetes, no CDN
  for it.
- No broker, no retries, no persistence — `shared/jobs/queue.ts` is
  in-process only; swap its internals for RabbitMQ without touching callers.
- No auth between services (compose-internal network trust).
- `/notify` logs instead of sending real email; move `email.service.ts`
  behind the contract to make it real.

## Next steps if scale justifies it

1. Publish `notification.send` to RabbitMQ instead of the in-process queue.
2. Real delivery (SMTP/push) inside the service + delivery status tracking.
3. Service-to-service auth (mTLS or signed tokens).
4. Deploy as its own Render service / container with its own dashboards.
