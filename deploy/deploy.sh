#!/usr/bin/env bash
# GridPop — publish the web build to a Linux server (WSL, macOS, Linux).
#
#   HOST=ubuntu@203.0.113.10 ./deploy/deploy.sh
#   HOST=ubuntu@game.example.com KEY=~/.ssh/gridpop.pem ./deploy/deploy.sh
#
# Environment:
#   HOST    user@server (required)
#   KEY     private key file (optional)
#   PORT    ssh port, default 22
#   TARGET  web root on the server, default /var/www/gridpop
#
# The server needs nginx (see deploy/README.md) and rsync.
set -euo pipefail

HOST="${HOST:-}"
KEY="${KEY:-}"
PORT="${PORT:-22}"
TARGET="${TARGET:-/var/www/gridpop}"

if [ -z "$HOST" ]; then
  echo "HOST is required, e.g. HOST=ubuntu@203.0.113.10 $0" >&2
  exit 2
fi
if [ ! -f build/web/index.html ]; then
  echo "build/web is missing. Run:" >&2
  echo "  flutter build web --release --pwa-strategy=none --no-web-resources-cdn" >&2
  exit 2
fi

SSH_OPTS=(-p "$PORT" -o StrictHostKeyChecking=accept-new)
if [ -n "$KEY" ]; then
  SSH_OPTS+=(-i "$KEY")
fi

echo "==> precompressing text payloads"
find build/web -type f \
  \( -name '*.js' -o -name '*.json' -o -name '*.wasm' -o -name '*.css' -o -name '*.svg' \) \
  -exec gzip -9 -k -f {} \;

echo "==> uploading build/web to $HOST:$TARGET"
rsync -az --delete --info=progress2 -e "ssh ${SSH_OPTS[*]}" \
  build/web/ "$HOST:$TARGET/"

echo "==> validating and reloading nginx"
ssh "${SSH_OPTS[@]}" "$HOST" \
  "sudo nginx -t && sudo systemctl reload nginx"

echo "==> done"
echo "    http://${HOST#*@}/"
