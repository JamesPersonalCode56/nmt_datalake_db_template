#!/bin/bash
set -euo pipefail

trap 'echo "Error: Deployment failed at line $LINENO"' ERR

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
load_env
require_compose

mkdir -p "$ROOT_DIR/logs"
if ! chmod 777 "$ROOT_DIR/logs" 2>/dev/null; then
  if command -v sudo >/dev/null 2>&1; then
    sudo chmod 777 "$ROOT_DIR/logs"
  else
    echo "Error: cannot set write permission on $ROOT_DIR/logs"
    exit 1
  fi
fi

PORT_CHECK=""
if command -v ss >/dev/null 2>&1; then
  PORT_CHECK="$(ss -lntp 2>/dev/null | awk '{print $4,$6}' | grep -F ":${DB_PORT_EXTERNAL} " || true)"
elif command -v lsof >/dev/null 2>&1; then
  PORT_CHECK="$(lsof -i -P -n 2>/dev/null | grep LISTEN | grep -F ":${DB_PORT_EXTERNAL}" || true)"
else
  echo "Warning: ss/lsof not found, skipping port check."
fi

if [ -n "$PORT_CHECK" ]; then
  echo "Error: Port $DB_PORT_EXTERNAL is already occupied by:"
  echo "$PORT_CHECK"
  exit 1
fi

docker compose -f "$COMPOSE_FILE" up -d

echo "-------------------------------------------------------"
echo "DEPLOYMENT SUCCESSFUL!"
echo "Container: $DB_CONTAINER_NAME"
echo "Endpoint:  $DB_HOST_IP:$DB_PORT_EXTERNAL"
echo "Database:  $DB_NAME"
echo "-------------------------------------------------------"
