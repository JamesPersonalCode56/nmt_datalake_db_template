#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -f "$ROOT_DIR/.env" ]; then
    export $(grep -v '^#' "$ROOT_DIR/.env" | xargs)
else
    echo "Error: .env file not found at $ROOT_DIR/.env"
    exit 1
fi

echo "WARNING: Wipe all data in $DB_CONTAINER_NAME? (y/n)"
read -r confirm
[[ "$confirm" != "y" ]] && echo "Cancelled." && exit 0

echo "Stopping container and cleaning data..."
docker compose -f "$ROOT_DIR/docker compose.yml" down

if [ -d "$ROOT_DIR/data" ]; then
    sudo rm -rf "$ROOT_DIR/data/"*
    echo "Data directory cleared."
fi