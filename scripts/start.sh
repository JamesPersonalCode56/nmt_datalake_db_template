#!/bin/bash
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -f "$ROOT_DIR/.env" ]; then
    export $(grep -v '^#' "$ROOT_DIR/.env" | xargs)
else
    echo "Error: .env file not found."
    exit 1
fi

STATUS=$(docker inspect -f '{{.State.Running}}' $DB_CONTAINER_NAME 2>/dev/null)

if [ "$STATUS" == "true" ]; then
    echo "Container $DB_CONTAINER_NAME is already running."
else
    echo "Starting $DB_CONTAINER_NAME..."
    docker-compose -f "$ROOT_DIR/docker-compose.yml" start || docker-compose -f "$ROOT_DIR/docker-compose.yml" up -d
fi