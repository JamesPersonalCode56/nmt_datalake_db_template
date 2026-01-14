#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
CURRENT_DIR=$(pwd)

echo -e "${GREEN}--- Initializing Database Template ---${NC}"

if [ ! -f .env ]; then
    cp .env.example .env [cite: 58]
fi

if ! grep -q "PROJECT_ROOT=" .env; then
    echo "PROJECT_ROOT=$CURRENT_DIR" >> .env
else
    sed -i "s|^PROJECT_ROOT=.*|PROJECT_ROOT=$CURRENT_DIR|" .env
fi

chmod 600 .env [cite: 59]

mkdir -p data backups [cite: 60]
touch data/.gitkeep backups/.gitkeep [cite: 60]

if [ -d "scripts" ]; then
    chmod +x scripts/*.sh [cite: 61]
fi

command -v docker >/dev/null 2>&1 || echo -e "${RED}Error: docker not installed${NC}" [cite: 63]
command -v docker-compose >/dev/null 2>&1 || echo -e "${RED}Error: docker-compose not installed${NC}" [cite: 64]

chmod +x setup.sh
echo -e "${GREEN}--- Setup Complete ---${NC}"