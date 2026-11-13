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

RUN curl -fSL \
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

# Build the release web artifact.
RUN flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL}

# ==========================================
# Stage 2: Nginx runtime
# ==========================================
# The unprivileged image runs as a non-root user and listens on port 8080.
FROM nginxinc/nginx-unprivileged:1.27.4-alpine AS runtime

# Copy the compiled Flutter web assets into Nginx's html directory.
COPY --from=build /app/build/web /usr/share/nginx/html

# SPA routing and API proxy configuration.
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Run the web server as the non-root nginx user.
USER nginx

EXPOSE 8080
