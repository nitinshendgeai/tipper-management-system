# ── Stage 1: Build ────────────────────────────────────────────────────────────
FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app

# Copy dependency manifest first for better layer caching
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy the rest of the source tree
COPY . .

# Build the Flutter web app in release mode
RUN flutter build web --release

# ── Stage 2: Serve ────────────────────────────────────────────────────────────
FROM nginx:1.27-alpine

# Remove the default nginx static assets
RUN rm -rf /usr/share/nginx/html/*

# Copy the compiled Flutter web output
COPY --from=builder /app/build/web /usr/share/nginx/html

# Nginx config: serve on port 8080 and handle Flutter's client-side routing
RUN printf 'server {\n\
    listen 8080;\n\
    root /usr/share/nginx/html;\n\
    index index.html;\n\
\n\
    # Serve pre-compressed assets when available\n\
    gzip_static on;\n\
\n\
    location / {\n\
        try_files $uri $uri/ /index.html;\n\
    }\n\
}\n' > /etc/nginx/conf.d/default.conf

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
