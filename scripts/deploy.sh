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

CURRENT_DB_BIND=""
if docker inspect "$DB_CONTAINER_NAME" >/dev/null 2>&1; then
  CURRENT_DB_BIND="$(docker inspect -f '{{range $p, $v := .NetworkSettings.Ports}}{{if eq $p "5432/tcp"}}{{range $v}}{{println .HostIp ":" .HostPort}}{{end}}{{end}}{{end}}' "$DB_CONTAINER_NAME" 2>/dev/null | tr -d ' ' | head -n 1 || true)"
fi

if [ -n "$PORT_CHECK" ]; then
  if [ -n "$CURRENT_DB_BIND" ] && [ "$CURRENT_DB_BIND" = "${DB_HOST_IP}:${DB_PORT_EXTERNAL}" ]; then
    echo "Port $DB_PORT_EXTERNAL is currently bound by $DB_CONTAINER_NAME. Continue deploy."
  else
    echo "Error: Port $DB_PORT_EXTERNAL is already occupied by:"
    echo "$PORT_CHECK"
    exit 1
  fi
fi

docker compose -f "$COMPOSE_FILE" up -d

AUTO_MIGRATE_ON_DEPLOY="${AUTO_MIGRATE_ON_DEPLOY:-true}"
AUTO_MIGRATE_ON_DEPLOY="$(echo "$AUTO_MIGRATE_ON_DEPLOY" | tr '[:upper:]' '[:lower:]')"
if [ "$AUTO_MIGRATE_ON_DEPLOY" = "true" ] || [ "$AUTO_MIGRATE_ON_DEPLOY" = "1" ] || [ "$AUTO_MIGRATE_ON_DEPLOY" = "yes" ]; then
  "$ROOT_DIR/scripts/migrate.sh"
else
  echo "Auto migration is disabled (AUTO_MIGRATE_ON_DEPLOY=$AUTO_MIGRATE_ON_DEPLOY)."
fi

echo "-------------------------------------------------------"
echo "DEPLOYMENT SUCCESSFUL!"
echo "Container: $DB_CONTAINER_NAME"
echo "Endpoint:  $DB_HOST_IP:$DB_PORT_EXTERNAL"
echo "Database:  $DB_NAME"
echo "-------------------------------------------------------"
