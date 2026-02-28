#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}--- Initializing Database Template ---${NC}"

if [ ! -f "$ROOT_DIR/.env" ]; then
  cp "$ROOT_DIR/.env.example" "$ROOT_DIR/.env"
fi

chmod 600 "$ROOT_DIR/.env"

mkdir -p "$ROOT_DIR/data" "$ROOT_DIR/backups" "$ROOT_DIR/init" "$ROOT_DIR/logs"
touch "$ROOT_DIR/init/schema.sql"
touch "$ROOT_DIR/logs/.gitkeep"
chmod 777 "$ROOT_DIR/logs"

if [ -d "$ROOT_DIR/scripts" ]; then
  chmod +x "$ROOT_DIR"/scripts/*.sh 2>/dev/null || true
fi

command -v docker >/dev/null 2>&1 || { echo -e "${RED}Error: docker not installed${NC}"; exit 1; }
docker compose version >/dev/null 2>&1 || { echo -e "${RED}Error: docker compose not installed${NC}"; exit 1; }

chmod +x "$ROOT_DIR/setup.sh"
echo -e "${GREEN}--- Setup Complete ---${NC}"
