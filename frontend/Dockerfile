# ==========================================
# Stage 1: Flutter web build
# ==========================================
# No public registry image carries Flutter 3.47.8, so the build stage fetches
# the exact stable Linux SDK release from Google's release bucket. This keeps
# `docker compose up --build` self-contained and matches the version used by
# CI (subosito/flutter-action with flutter-version: "3.47.8") and local dev.
# Digest-pinned multi-arch manifests so a moving tag cannot change the build
# inputs. Dependabot's docker ecosystem keeps these digests current.
FROM debian:bookworm-slim@sha256:734a72b3d6142a71993b4bc580ca01d8ca687f77a2c422d96a961d3376b179bc AS build

ARG FLUTTER_VERSION=3.47.8
# Official SHA256 from Google's releases_linux.json manifest for 3.47.8.
ARG FLUTTER_SHA256=baf7dcc5a3dbba60fe863bf493a6cf203195621f7786eaa5a1bba02cd0d87dd2
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

RUN curl --proto '=https' --tlsv1.2 -fSL \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
      -o /tmp/flutter.tar.xz \
  && printf '%s  %s\n' "$FLUTTER_SHA256" /tmp/flutter.tar.xz | sha256sum -c - \
  && tar -xJf /tmp/flutter.tar.xz -C /opt \
  && rm -f /tmp/flutter.tar.xz \
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
RUN flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL} \
    && API_ORIGIN="$(printf '%s' "$API_BASE_URL" | sed -E 's#^(https?://[^/]+).*#\1#')" \
    && sed -i "s|__API_ORIGIN__|${API_ORIGIN}|g" nginx.conf

# ==========================================
# Stage 2: Nginx runtime
# ==========================================
# The unprivileged image runs as a non-root user and listens on port 8080.
FROM nginxinc/nginx-unprivileged:1.27.4-alpine@sha256:62a904036bfc0e4a4f2b556e34cbf17bc136b47fde8cdb4628762725f48c5782 AS runtime

# Copy the compiled Flutter web assets into Nginx's html directory.
COPY --from=build /app/build/web /usr/share/nginx/html

# SPA routing + security headers, with the API origin substituted at build.
COPY --from=build /app/nginx.conf /etc/nginx/conf.d/default.conf

# Run the web server as the non-root nginx user.
USER nginx

EXPOSE 8080
