#!/bin/bash
set -euo pipefail

cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        rm -f "${FILE_NAME:-}"
    fi
    exit $exit_code
}

trap 'cleanup' ERR

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" 
if [ -f "$ROOT_DIR/.env" ]; then 
    export $(grep -v '^#' "$ROOT_DIR/.env" | xargs) 
else
    exit 1 
fi

BACKUP_DIR="$ROOT_DIR/backups" 
mkdir -p "$BACKUP_DIR" 
TIMESTAMP=$(date +%Y%m%d_%H%M%S) 
FILE_NAME="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql" 

docker exec $DB_CONTAINER_NAME pg_dump -U $DB_USER $DB_NAME > "$FILE_NAME" 

if [ -s "$FILE_NAME" ]; then
    gzip "$FILE_NAME" 
    ls -t "$BACKUP_DIR"/${DB_NAME}_*.sql.gz 2>/dev/null | tail -n +4 | xargs -r rm 
else
    rm -f "$FILE_NAME" 
    exit 1 
fi