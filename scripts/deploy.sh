#!/bin/bash
set -euo pipefail

trap 'echo "Error: Deployment failed at line $LINENO"' ERR

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" 
if [ -f "$ROOT_DIR/.env" ]; then 
    export $(grep -v '^#' "$ROOT_DIR/.env" | xargs) 
else
    exit 1
fi

PORT_CHECK=$(lsof -i -P -n | grep LISTEN | grep :$DB_PORT_EXTERNAL || true) 
if [ ! -z "$PORT_CHECK" ]; then
    echo "Error: Port $DB_PORT_EXTERNAL is already occupied by:"
    echo "$PORT_CHECK"
    exit 1
fi

docker-compose -f "$ROOT_DIR/docker-compose.yml" up -d

echo "-------------------------------------------------------"
echo "DEPLOYMENT SUCCESSFUL!"
echo "Container: $DB_CONTAINER_NAME"
echo "Endpoint:  $DB_HOST_IP:$DB_PORT_EXTERNAL"
echo "Database:  $DB_NAME"
echo "-------------------------------------------------------"