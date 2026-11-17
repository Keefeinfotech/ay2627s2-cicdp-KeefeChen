
# ==========================================
# Stage 1: Build
# ==========================================
FROM node:22-alpine@sha256:0e1754758c2df4cfa3e68d59e2e1b7374bb7fd9ea6328eaaacf15cc934af8202 AS build

WORKDIR /app

# Copy dependency manifests
COPY package*.json ./

# Install dependencies
RUN npm ci --ignore-scripts

# Copy TypeScript configuration and source
COPY tsconfig.json ./
COPY src ./src

# Compile TypeScript
RUN npm run build


# ==========================================
# Stage 2: Production Runtime
# ==========================================
FROM node:22-alpine@sha256:0e1754758c2df4cfa3e68d59e2e1b7374bb7fd9ea6328eaaacf15cc934af8202 AS runtime

WORKDIR /app

ENV NODE_ENV=production

# Copy dependency manifests
COPY package*.json ./

# Install production dependencies, then install pm2 ONCE for the process
# supervisor, then remove npm/npx from the runtime image. npm ships with
# bundled libraries that Trivy flags; pm2 itself is executed by node
# directly, so removing npm/npx does not break it. The standalone
# `pm2-runtime` wrapper package shells out to npx and therefore cannot be
# used here - use the `pm2-runtime` binary that ships with `pm2` itself.
# PM2 (fork mode) forwards SIGTERM to the app and restarts it on crash —
# extra supervision on top of the container's restart policy. Cost: the image
# grows and npm's transitive tree is re-introduced, so Trivy findings on
# this layer should be re-checked after changing it.
RUN npm ci --omit=dev --ignore-scripts && npm install -g pm2@7.1.2 \
    && npm cache clean --force \
    && rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx

# Patch Alpine packages so Trivy no longer reports known HIGH/CRITICAL
# vulnerabilities in the base image layer.
RUN apk upgrade --no-cache

# Copy compiled JavaScript
COPY --from=build /app/dist ./dist

# Runtime writes application logs to ./logs, so hand ownership to the
# unprivileged runtime user before dropping privileges.
RUN mkdir -p /app/logs && chown -R node:node /app

# Informational only. Render injects its own PORT (default 10000) and routes
# to it; the server binds 0.0.0.0 on process.env.PORT. docker-compose maps
# 3000:3000 and sets PORT=3000 explicitly.
EXPOSE 3000

# Run the compiled server as the unprivileged node user instead of root.
USER node

# Start application under pm2 (fork mode via pm2-runtime; no clustering on
# Render's single instance). pm2-runtime exec-forms the child so SIGTERM
# reaches node, and PM2 restarts the process on crash.
CMD ["pm2-runtime", "dist/server.js"]
