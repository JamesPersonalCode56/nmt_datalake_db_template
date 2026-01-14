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

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" [cite: 2]
if [ -f "$ROOT_DIR/.env" ]; then [cite: 2, 3]
    export $(grep -v '^#' "$ROOT_DIR/.env" | xargs) [cite: 3]
else
    exit 1 [cite: 3]
fi

BACKUP_DIR="$ROOT_DIR/backups" [cite: 3]
mkdir -p "$BACKUP_DIR" [cite: 3]
TIMESTAMP=$(date +%Y%m%d_%H%M%S) [cite: 3]
FILE_NAME="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql" [cite: 3]

docker exec $DB_CONTAINER_NAME pg_dump -U $DB_USER $DB_NAME > "$FILE_NAME" [cite: 3]

if [ -s "$FILE_NAME" ]; then
    gzip "$FILE_NAME" [cite: 4]
    ls -t "$BACKUP_DIR"/${DB_NAME}_*.sql.gz 2>/dev/null | tail -n +4 | xargs -r rm [cite: 5]
else
    rm -f "$FILE_NAME" [cite: 6]
    exit 1 [cite: 6]
fi