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

escape_sed() {
  printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'
}

ROOT_ESCAPED="$(escape_sed "$CURRENT_DIR")"

if ! grep -qE '^PROJECT_ROOT=' .env; then
  printf 'PROJECT_ROOT=%s\n' "$CURRENT_DIR" >> .env
else
  sed -i -E "s|^PROJECT_ROOT=.*$|PROJECT_ROOT=$ROOT_ESCAPED|" .env
fi

chmod 600 .env

mkdir -p data backups
: > data/.gitkeep
: > backups/.gitkeep

if [ -d "scripts" ]; then
  chmod +x scripts/*.sh 2>/dev/null || true
fi

if ! command -v docker >/dev/null 2>&1; then
  echo -e "${RED}Error: docker not installed${NC}"
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo -e "${RED}Error: docker compose not installed${NC}"
  exit 1
fi

run_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
    return
  fi
  if command -v sudo >/dev/null 2>&1; then
    sudo "$@"
    return
  fi
  return 1
}

PG_IMAGE="postgres:15-alpine"
if [ -f docker-compose.yml ]; then
  IMG_LINE="$(grep -E '^[[:space:]]*image:[[:space:]]*postgres:' docker-compose.yml | head -n 1 | awk '{print $2}')"
  if [ -n "${IMG_LINE:-}" ]; then
    PG_IMAGE="$IMG_LINE"
  fi
fi

UIDGID="$(docker run --rm "$PG_IMAGE" sh -lc 'printf "%s:%s" "$(id -u postgres)" "$(id -g postgres)"' 2>/dev/null || true)"

if [ -n "${UIDGID:-}" ]; then
  if ! run_root chown -R "$UIDGID" data >/dev/null 2>&1; then
    echo -e "${RED}Warning: cannot chown ./data to $UIDGID (run setup with sudo)${NC}"
  fi
  if ! run_root chown -R "$UIDGID" backups >/dev/null 2>&1; then
    echo -e "${RED}Warning: cannot chown ./backups to $UIDGID (run setup with sudo)${NC}"
  fi
else
  echo -e "${RED}Warning: cannot resolve postgres UID:GID from image $PG_IMAGE${NC}"
fi

chmod +x setup.sh

echo -e "${GREEN}--- Setup Complete ---${NC}"
