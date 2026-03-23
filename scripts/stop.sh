#!/bin/bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
load_env
require_compose

if ! docker inspect "$DB_CONTAINER_NAME" >/dev/null 2>&1; then
    echo "Container $DB_CONTAINER_NAME not found."
    exit 0
fi

DB_RUNNING="$(docker inspect -f '{{.State.Running}}' "$DB_CONTAINER_NAME" 2>/dev/null || echo false)"
SCHED_CONTAINER="${DB_CONTAINER_NAME}_scheduler"
SCHED_RUNNING="$(docker inspect -f '{{.State.Running}}' "$SCHED_CONTAINER" 2>/dev/null || echo false)"

if [ "$DB_RUNNING" != "true" ] && [ "$SCHED_RUNNING" != "true" ]; then
    echo "Containers are already stopped."
    exit 0
fi

echo "Stopping services for $DB_CONTAINER_NAME..."
docker compose -f "$COMPOSE_FILE" stop
