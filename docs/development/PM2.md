# PM2 Runtime in the Backend Container

**Decision date:** 2026-11-17 · **Owner:** Engineering · **Status:** adopted

## What changed

The production image (`backend/Dockerfile`, runtime stage) previously executed
`node dist/server.js` directly. It now executes `pm2-runtime dist/server.js`
(fork mode).

## Why

- PM2 gives the container an extra supervision layer on top of Docker's
  restart policy and Render's health-gated deploys: restarts on crash, forwards
  SIGTERM to the child (graceful shutdown), keeps a lightweight process log.
- Fork mode only - no PM2 clustering. Render's free tier runs a single
  instance; clustering buys nothing there and complicates the session cache
  story (in-memory cache is per-process).

## Trade-offs accepted

- The runtime image grows by PM2's transitive dependency tree (~hundreds of
  packages), re-introducing npm tooling that was previously removed to keep
  Trivy clean. Trivy findings on this layer should be reviewed on every
  dependency bump.
- Use the `pm2` package's built-in `pm2-runtime` binary, **not** the
  standalone `pm2-runtime` wrapper package: the wrapper shells out to `npx`,
  which we deliberately remove from the runtime image.
- The container runs as the unprivileged `node` user; PM2 writes its state to
  `$HOME/.pm2` (`/home/node`), which the base image provides.

## What was rejected and why

- **Removing supervision entirely** (previous state): Docker restart policy
  covers container restarts but not in-process crashes with an otherwise
  healthy container.
- **PM2 cluster mode**: zero benefit on one instance; fragments the in-memory
  session/rate-limit caches.
- **PM2 on the host/VM outside the container**: we deploy to Render; the
  container is the unit of operation.

## Reversibility

To revert, restore `CMD ["node", "dist/server.js"]` in `backend/Dockerfile`
and drop the `npm install -g pm2-runtime@5.4.1` layer. No application code
changes are involved.
