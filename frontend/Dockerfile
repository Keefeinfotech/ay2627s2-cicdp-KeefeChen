# ==========================================
# Stage 1: Flutter web build
# ==========================================
FROM ghcr.io/cirruslabs/flutter:3.47.8 AS build

# ARG is only available in the stage where it is declared.
ARG API_BASE_URL=http://localhost:3000
ENV API_BASE_URL=${API_BASE_URL}

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
