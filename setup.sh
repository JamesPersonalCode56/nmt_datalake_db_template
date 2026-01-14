#!/bin/bash

# 1. Define colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}--- Initializing Database Template ---${NC}"

# 2. Check for .env file
if [ ! -f .env ]; then
    echo "Creating .env from .env.example..."
    cp .env.example .env
    echo -e "${RED}ACTION REQUIRED: Edit .env file with your specific configurations.${NC}"
else
    echo ".env file already exists."
fi

if [ -f .env ]; then
    chmod 600 .env
    echo "Secured .env permissions (600)."
fi

# 3. Create required directories
echo "Creating data and backups directories..."
mkdir -p data backups
# Ensure giteep files are preserved if they exist
touch data/.gitkeep backups/.gitkeep

# 4. Fix permissions for all scripts
echo "Setting executable permissions for scripts..."
if [ -d "scripts" ]; then
    chmod +x scripts/*.sh
    echo "Permissions set for scripts/ folder."
else
    echo -e "${RED}Error: scripts/ directory not found!${NC}"
fi

# 5. Dependency check
echo "Checking dependencies..."
command -v docker >/dev/null 2>&1 || { echo -e "${RED}Error: docker is not installed.${NC}"; }
command -v docker-compose >/dev/null 2>&1 || { echo -e "${RED}Error: docker-compose is not installed.${NC}"; }
command -v tailscale >/dev/null 2>&1 || { echo -e "${RED}Warning: tailscale not found. Remote access might fail.${NC}"; }

# 6. Final instructions
chmod +x setup.sh
echo -e "${GREEN}--- Setup Complete ---${NC}"
echo "Next steps:"
echo "1. Configure your .env file"
echo "2. Run ./scripts/deploy.sh to start the database"