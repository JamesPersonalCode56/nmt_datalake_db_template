#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}--- Initializing Database Template ---${NC}"

if [ ! -f .env ]; then
  cp .env.example .env
fi

chmod 600 .env

mkdir -p data backups

if [ -d "scripts" ]; then
  chmod +x scripts/*.sh 2>/dev/null || true
fi

command -v docker >/dev/null 2>&1 || { echo -e "${RED}Error: docker not installed${NC}"; exit 1; }
docker compose version >/dev/null 2>&1 || { echo -e "${RED}Error: docker compose not installed${NC}"; exit 1; }

chmod +x setup.sh
echo -e "${GREEN}--- Setup Complete ---${NC}"