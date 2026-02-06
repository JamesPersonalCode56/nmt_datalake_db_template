#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
COMPOSE_FILE="$ROOT_DIR/docker-compose.yml"

load_env() {
  if [ ! -f "$ENV_FILE" ]; then
    echo "Error: .env file not found at $ENV_FILE"
    exit 1
  fi
  set -a
  source "$ENV_FILE"
  set +a
}

require_compose() {
  if [ ! -f "$COMPOSE_FILE" ]; then
    echo "Error: docker-compose.yml not found at $COMPOSE_FILE"
    exit 1
  fi
}
