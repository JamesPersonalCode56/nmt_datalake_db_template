#!/bin/bash

# 1. Load environment variables using absolute path
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -f "$ROOT_DIR/.env" ]; then
    export $(grep -v '^#' "$ROOT_DIR/.env" | xargs)
else
    echo "Error: .env file not found at $ROOT_DIR/.env"
    exit 1
fi

echo "--- Checking system for container: $DB_CONTAINER_NAME ---"

# 2. Check if Port is already in use
PORT_CHECK=$(lsof -i -P -n | grep LISTEN | grep :$DB_PORT_EXTERNAL)
if [ ! -z "$PORT_CHECK" ]; then
    echo "Error: Port $DB_PORT_EXTERNAL is already occupied by:"
    echo "$PORT_CHECK"
    exit 1
fi

# 3. Create data directory if not exists (using absolute path)
if [ ! -d "$ROOT_DIR/data" ]; then
    mkdir -p "$ROOT_DIR/data"
    echo "Data directory created."
fi

# 4. Deployment
echo "Pulling images and starting container..."
# Explicitly point to the docker-compose file location
docker-compose -f "$ROOT_DIR/docker-compose.yml" up -d

# 5. Deployment Result
if [ $? -eq 0 ]; then
    echo "-------------------------------------------------------"
    echo "DEPLOYMENT SUCCESSFUL!"
    echo "Container: $DB_CONTAINER_NAME"
    echo "Endpoint:  $DB_HOST_IP:$DB_PORT_EXTERNAL"
    echo "Database:  $DB_NAME"
    echo "-------------------------------------------------------"
    echo "Note: If this is the first run, wait a few seconds for /init/schema.sql to execute."
else
    echo "Error: Deployment failed. Check logs with: docker logs $DB_CONTAINER_NAME"
fi