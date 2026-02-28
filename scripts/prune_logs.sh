#!/bin/bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
load_env

LOG_DIR="$ROOT_DIR/logs"
RETENTION_DAYS="${DB_LOG_RETENTION_DAYS:-14}"

if ! [[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]]; then
  echo "Error: DB_LOG_RETENTION_DAYS must be a non-negative integer"
  exit 1
fi

mkdir -p "$LOG_DIR"

if [ "$RETENTION_DAYS" -eq 0 ]; then
  find "$LOG_DIR" -type f -name 'postgresql-*.log' -delete
else
  find "$LOG_DIR" -type f -name 'postgresql-*.log' -mtime +"$RETENTION_DAYS" -delete
fi
