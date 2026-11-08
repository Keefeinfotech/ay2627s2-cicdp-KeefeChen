
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

# Install production dependencies only, then remove npm/npx from the runtime
# image. Nothing at runtime needs them (the container executes `node`
# directly), and npm ships bundled libraries with known CVEs that Trivy
# flags during the image scan.
RUN npm ci --omit=dev --ignore-scripts && npm cache clean --force \
    && rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx

# Patch Alpine packages so Trivy no longer reports known HIGH/CRITICAL
# vulnerabilities in the base image layer.
RUN apk upgrade --no-cache

# Copy compiled JavaScript
COPY --from=build /app/dist ./dist

# Expose application port
EXPOSE 3000

# Start application (same entry point as `npm start`, without npm in the image)
CMD ["node", "dist/server.js"]
