# Local all-in-one Jenkins controller for the Auxilia project.
#
# The stock jenkins/jenkins image has Java but no Node.js, Flutter or Docker
# CLI, so this image extends it with everything the root Jenkinsfile needs:
#
#   - Node.js 22 (matches CI: .github/workflows/ci.yml uses Node 22)
#   - Flutter 3.47.8 stable (matches CI and pubspec.lock constraints)
#   - git, curl, xz, unzip (Flutter tool requires git and a writable SDK)
#   - Docker CLI + Docker Compose v2 (the deploy stage rebuilds and
#     restarts the local stack via the host's Docker socket)
#
# Build once, reuse everywhere:
#   docker compose --profile jenkins up -d --build
#
# Note: the Flutter SDK adds ~2.5 GB to the image. This is a one-time local
# build; remove the profile's images if you no longer need Jenkins.

FROM jenkins/jenkins:lts-jdk21

ARG NODE_VERSION=22.14.0
ARG FLUTTER_VERSION=3.47.8

USER root

# System packages: tooling and the Docker CLI (dockerd is not needed; the
# host socket is mounted). Compose is installed below as a CLI plugin.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      xz-utils \
      unzip \
      git \
      docker.io \
 && rm -rf /var/lib/apt/lists/*

# Docker Compose v2 as a CLI plugin (pinned; Debian's package name for
# compose varies by release, a pinned plugin does not).
RUN mkdir -p /usr/local/lib/docker/cli-plugins \
 && curl -fSSL -o /usr/local/lib/docker/cli-plugins/docker-compose \
      "https://github.com/docker/compose/releases/download/v2.29.7/docker-compose-linux-x86_64" \
 && chmod +x /usr/local/lib/docker/cli-plugins/docker-compose \
 && docker compose version

# Node.js (official binary tarball, x64).
RUN curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" \
 && tar -xJf "node-v${NODE_VERSION}-linux-x64.tar.xz" -C /usr/local --strip-components=1 \
 && rm "node-v${NODE_VERSION}-linux-x64.tar.xz" \
 && node --version \
 && npm --version

# Flutter SDK (stable, Linux x64). Flutter requires git; mark the SDK
# directory as safe so the jenkins user can run the tool.
RUN curl -fSSL -o flutter.tar.xz \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
 && tar -xJf flutter.tar.xz -C /opt \
 && rm flutter.tar.xz \
 && git config --system --add safe.directory /opt/flutter \
 && chown -R jenkins:jenkins /opt/flutter

USER jenkins

ENV PATH="/opt/flutter/bin:${PATH}"

# Verify the SDK works for the jenkins user, silence analytics, and warm the
# web-artifact cache so the first pipeline run does not download it.
RUN flutter --version \
 && flutter config --no-analytics \
 && dart --disable-analytics \
 && flutter precache --web
