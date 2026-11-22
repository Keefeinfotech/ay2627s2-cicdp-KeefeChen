# ==========================================
# Stage 1: Flutter web build
# ==========================================
# No public registry image carries Flutter 3.47.8, so the build stage fetches
# the exact stable Linux SDK release from Google's release bucket. This keeps
# `docker compose up --build` self-contained and matches the version used by
# CI (subosito/flutter-action with flutter-version: "3.47.8") and local dev.
FROM debian:bookworm-slim AS build

ARG FLUTTER_VERSION=3.47.8
ARG API_BASE_URL=http://localhost:3000
ENV API_BASE_URL=${API_BASE_URL}
# Public Cloudflare Turnstile site key. Compiled into the app via --dart-define
# below so AuthService.requiresCaptcha is true and the invisible widget runs.
# Empty by default so local docker-compose builds stay CAPTCHA-free.
ARG TURNSTILE_SITE_KEY=
ENV TURNSTILE_SITE_KEY=${TURNSTILE_SITE_KEY}
ENV PATH="/opt/flutter/bin:${PATH}"

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    xz-utils \
    unzip \
    libglu1-mesa \
    fontconfig \
  && rm -rf /var/lib/apt/lists/*

RUN curl --proto '=https' --tlsv1.2 -fSL \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
      | tar -xJ -C /opt \
  # Flutter refuses to run from a git repository owned by another user.
  && git config --global --add safe.directory /opt/flutter \
  && flutter --version

WORKDIR /app

# Copy the lockfile with the manifest so dependency resolution is reproducible.
COPY pubspec.yaml pubspec.lock ./

# Resolve dependencies strictly from the committed lockfile.
RUN flutter pub get --enforce-lockfile

# Copy the application source.
COPY . .

# Build the release web artifact, then render the CSP placeholder in
# nginx.conf with the SAME API origin the app was compiled against. Render
# passes its service env var as a Docker build argument; docker-compose passes
# the localhost URL. Deriving the origin (scheme + host) keeps paths/trailing
# slashes out of the CSP connect-src directive.
RUN flutter build web --release \
    --dart-define=API_BASE_URL=${API_BASE_URL} \
    --dart-define=TURNSTILE_SITE_KEY=${TURNSTILE_SITE_KEY} \
    && API_ORIGIN="$(printf '%s' "$API_BASE_URL" | sed -E 's#^(https?://[^/]+).*#\1#')" \
    && sed -i "s|__API_ORIGIN__|${API_ORIGIN}|g" nginx.conf

# ==========================================
# Stage 2: Nginx runtime
# ==========================================
# The unprivileged image runs as a non-root user and listens on port 8080.
FROM nginxinc/nginx-unprivileged:1.27.4-alpine AS runtime

# Copy the compiled Flutter web assets into Nginx's html directory.
COPY --from=build /app/build/web /usr/share/nginx/html

# SPA routing + security headers, with the API origin substituted at build.
COPY --from=build /app/nginx.conf /etc/nginx/conf.d/default.conf

# Patch Alpine packages so Trivy no longer reports known HIGH/CRITICAL
# vulnerabilities in the base image layer (mirrors the backend runtime stage).
USER root
RUN apk upgrade --no-cache

# Run the web server as the non-root nginx user.
USER nginx

EXPOSE 8080
