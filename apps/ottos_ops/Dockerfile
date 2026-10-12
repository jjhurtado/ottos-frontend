# The operations panel as a static site behind Caddy, which also forwards /api
# to the backend: the same image serves staging and production, and the panel
# talks to its own origin (no OTTOS_API_URL, no CORS).
#
# Build from the repository root (the panel needs packages/ottos_core):
#   docker build -f apps/ottos_ops/Dockerfile -t ottos-panel .
# Run:
#   docker run -p 8080:8080 -e OTTOS_BACKEND_URL=http://backend:8080 ottos-panel

# --- Build: the exact Flutter of the project, checked against its published sha256.
FROM debian:bookworm-slim AS build

ARG FLUTTER_VERSION=3.47.7
ARG FLUTTER_SHA256=af7455f540df951184c7953fbe3cf884766e7541dacf8571f9f582db03dd6230

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils \
 && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o /tmp/flutter.tar.xz \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
 && echo "${FLUTTER_SHA256}  /tmp/flutter.tar.xz" | sha256sum -c - \
 && tar -xJf /tmp/flutter.tar.xz -C /opt \
 && rm /tmp/flutter.tar.xz \
 && git config --global --add safe.directory /opt/flutter

ENV PATH="/opt/flutter/bin:${PATH}" \
    FLUTTER_SUPPRESS_ANALYTICS=true \
    PUB_CACHE=/root/.pub-cache

RUN flutter config --no-analytics --enable-web >/dev/null && flutter precache --web

WORKDIR /src
# Dependencies first, so code changes reuse this layer. The pub workspace
# needs every member's pubspec, the courier app's included.
COPY pubspec.yaml pubspec.lock ./
COPY packages/ottos_core/pubspec.yaml packages/ottos_core/
COPY apps/ottos_ops/pubspec.yaml apps/ottos_ops/
COPY apps/ottos_courier/pubspec.yaml apps/ottos_courier/
RUN flutter pub get --enforce-lockfile

COPY packages/ottos_core packages/ottos_core
COPY apps/ottos_ops apps/ottos_ops
# The engine's files from our own domain, not Google's CDN (it may be blocked from Cuba).
RUN cd apps/ottos_ops && flutter build web --release --no-web-resources-cdn

# --- Serve: only the built site and the Caddyfile.
FROM caddy:2.11.7-alpine

COPY apps/ottos_ops/Caddyfile /etc/caddy/Caddyfile
COPY --from=build /src/apps/ottos_ops/build/web /srv

ENV PORT=8080
EXPOSE 8080
