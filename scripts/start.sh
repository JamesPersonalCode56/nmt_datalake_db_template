#!/bin/bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
load_env
require_compose

STATUS="$(docker inspect -f '{{.State.Running}}' "$DB_CONTAINER_NAME" 2>/dev/null || echo false)"


if [ "$STATUS" == "true" ]; then
    echo "Container $DB_CONTAINER_NAME is already running."
else
    echo "Starting $DB_CONTAINER_NAME..."
    docker compose -f "$COMPOSE_FILE" start || docker compose -f "$COMPOSE_FILE" up -d
fi