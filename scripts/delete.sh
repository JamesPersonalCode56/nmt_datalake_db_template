#!/bin/bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -f "$ROOT_DIR/.env" ]; then
    export $(grep -v '^#' "$ROOT_DIR/.env" | xargs)
else
    echo "Error: .env file not found at $ROOT_DIR/.env"
    exit 1
fi

echo "CRITICAL WARNING: This will PERMANENTLY DELETE the database and all data. Type 'DELETE' to confirm:"
read -r confirm

if [ "$confirm" != "DELETE" ]; then
    echo "Operation cancelled."
    exit 0
fi

echo "Destroying container, network and volumes..."
docker-compose -f "$ROOT_DIR/docker-compose.yml" down --rmi all -v --remove-orphans

if [ -d "$ROOT_DIR/data" ]; then
    sudo rm -rf "$ROOT_DIR/data"
    echo "Data directory deleted."
fi