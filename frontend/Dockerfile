# ==========================================
# Stage 1: Flutter web build
# ==========================================
FROM ghcr.io/cirruslabs/flutter:3.47.8 AS build

# ARG is only available in the stage where it is declared.
ARG API_BASE_URL=http://localhost:3000
ENV API_BASE_URL=${API_BASE_URL}

WORKDIR /app

# Copy dependency manifest first for layer caching.
COPY pubspec.yaml pubspec.lock* ./

# Resolve and fetch dependencies.
RUN flutter pub get

# Copy the application source.
COPY . .

# Build the release web artifact.
RUN flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL}

# ==========================================
# Stage 2: Nginx runtime
# ==========================================
FROM nginx:1.27.4-alpine AS runtime

# Copy the compiled Flutter web assets into Nginx's html directory.
COPY --from=build /app/build/web /usr/share/nginx/html

# Default Nginx configuration serves the SPA with index.html fallback
# for Flutter's client-side routing, and proxies /api/ to the backend.
RUN printf '%s\n' \
  'server {' \
  '    listen 80;' \
  '    server_name _;' \
  '    root /usr/share/nginx/html;' \
  '    index index.html;' \
  '' \
  '    location / {' \
  '        try_files $uri $uri/ /index.html;' \
  '    }' \
  '' \
  '    location /api/ {' \
  '        proxy_pass http://backend:3000;' \
  '        proxy_http_version 1.1;' \
  '        proxy_set_header Host $host;' \
  '        proxy_set_header X-Real-IP $remote_addr;' \
  '    }' \
  '}' > /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
