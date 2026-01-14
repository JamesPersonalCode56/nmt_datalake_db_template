#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
CURRENT_DIR=$(pwd)

echo -e "${GREEN}--- Initializing Database Template ---${NC}"

if [ ! -f .env ]; then
    cp .env.example .env 
fi

if ! grep -q "PROJECT_ROOT=" .env; then
    echo "PROJECT_ROOT=$CURRENT_DIR" >> .env
else
    sed -i "s|^PROJECT_ROOT=.*|PROJECT_ROOT=$CURRENT_DIR|" .env
fi

chmod 600 .env 

mkdir -p data backups 
touch data/.gitkeep backups/.gitkeep 

if [ -d "scripts" ]; then
    chmod +x scripts/*.sh 
fi

command -v docker >/dev/null 2>&1 || echo -e "${RED}Error: docker not installed${NC}" 
command -v docker compose >/dev/null 2>&1 || echo -e "${RED}Error: docker compose not installed${NC}" 

chmod +x setup.sh
echo -e "${GREEN}--- Setup Complete ---${NC}"