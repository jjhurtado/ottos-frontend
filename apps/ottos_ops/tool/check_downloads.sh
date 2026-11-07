#!/bin/sh
# REQ-023: checks /descargas of the panel's Caddyfile with Docker, against a fake
# bucket. Not in CI (it needs Docker). Run from the repository root:
#   sh apps/ottos_ops/tool/check_downloads.sh
set -eu

image=caddy:2.11.7-alpine
caddyfile="$(cd "$(dirname "$0")/.." && pwd)/Caddyfile"
work=$(mktemp -d)
net=ottos-downloads-$$
trap 'docker rm -f "$net-up" "$net-on" "$net-off" >/dev/null 2>&1; docker network rm "$net" >/dev/null 2>&1; rm -rf "$work"' EXIT

# The fake bucket: 404 for one file, otherwise echoes what reached it.
cat >"$work/Caddyfile" <<'EOF'
{
	admin off
	auto_https off
}
:9000 {
	respond /public/ottos/apk-release/ottos-missing.apk "<Error><Code>NoSuchKey</Code></Error>" 404
	respond "{method} {path} host={host} range={header.Range} auth={header.Authorization}" 206
}
EOF

docker network create "$net" >/dev/null
docker run -d --name "$net-up" --network "$net" -v "$work/Caddyfile:/etc/caddy/Caddyfile:ro" "$image" >/dev/null
docker run -d --name "$net-on" --network "$net" -p 127.0.0.1:18471:8080 -v "$caddyfile:/etc/caddy/Caddyfile:ro" \
  -e APK_BUCKET_UPSTREAM="http://$net-up:9000" -e OTTOS_BACKEND_URL=http://localhost:9 "$image" >/dev/null
docker run -d --name "$net-off" -p 127.0.0.1:18472:8080 -v "$caddyfile:/etc/caddy/Caddyfile:ro" \
  -e APK_BUCKET_UPSTREAM= -e OTTOS_BACKEND_URL=http://localhost:9 "$image" >/dev/null
sleep 2

fails=0
expect() { # expect <what> <expected> <actual>
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected '$2', got '$3'"; fails=$((fails + 1)); fi
}
on=http://127.0.0.1:18471
status() { curl -s -o /dev/null -w '%{http_code}' "$@"; }

body=$(curl -s -H 'Range: bytes=100-' -H 'Authorization: Bearer x' "$on/descargas/ottos-1.0.1.apk")
expect 'GET is rewritten to the prefix, Range passed, no credentials' \
  'GET /public/ottos/apk-release/ottos-1.0.1.apk host='"$net-up"' range=bytes=100- auth=' "$body"
expect 'Content-Type of an APK' 'application/vnd.android.package-archive' \
  "$(curl -s -o /dev/null -w '%{content_type}' "$on/descargas/ottos-1.0.1.apk")"
expect 'HEAD allowed' 206 "$(status -I "$on/descargas/ottos-1.0.1.apk")"
expect 'missing file is a plain 404' 404 "$(status "$on/descargas/ottos-missing.apk")"
expect 'POST refused' 404 "$(status -X POST "$on/descargas/ottos-1.0.1.apk")"
for path in /descargas /descargas/ /descargas/otra.apk /descargas/ottos-1.txt /descargas/sub/ottos-1.apk \
  /descargas/ottos-1.apk/ '/descargas/..%2Fottos-1.apk' '/descargas/ottos-..%2F..%2Fx.apk'; do
  expect "refused $path" 404 "$(status "$on$path")"
done
expect 'empty APK_BUCKET_UPSTREAM answers 404' 404 "$(status http://127.0.0.1:18472/descargas/ottos-1.0.1.apk)"
expect 'the panel still answers' ok "$(curl -s "$on/healthz")"

[ "$fails" -eq 0 ] && echo 'All checks passed' || { echo "$fails checks failed"; exit 1; }
