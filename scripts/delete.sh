#!/bin/bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
load_env
require_compose

echo "CRITICAL WARNING: This will PERMANENTLY DELETE the database and all data. Type 'DELETE' to confirm:"
read -r confirm

if [ "$confirm" != "DELETE" ]; then
    echo "Operation cancelled."
    exit 0
fi

echo "Destroying container, network and volumes..."
docker compose -f "$COMPOSE_FILE" down --rmi all -v --remove-orphans

if [ -d "$ROOT_DIR/data" ]; then
    remove_dir "$ROOT_DIR/data"
    echo "Data directory deleted."
fi
