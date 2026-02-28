#!/bin/bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
load_env
require_compose

echo "WARNING: Wipe all data in $DB_CONTAINER_NAME? (y/n)"
read -r confirm
[[ "$confirm" != "y" ]] && echo "Cancelled." && exit 0

echo "Stopping container and cleaning data..."
docker compose -f "$COMPOSE_FILE" down

if [ -d "$ROOT_DIR/data" ]; then
    remove_dir_contents "$ROOT_DIR/data"
    echo "Data directory cleared."
fi
