#!/bin/bash
set -euo pipefail

trap 'echo "Error: Restore failed at line $LINENO"' ERR

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" [cite: 22]
if [ -f "$ROOT_DIR/.env" ]; then [cite: 22]
    export $(grep -v '^#' "$ROOT_DIR/.env" | xargs) [cite: 22]
else
    exit 1
fi

BACKUP_DIR="$ROOT_DIR/backups" [cite: 23]
SELECTED_FILE=${1:-$(ls -t "$BACKUP_DIR"/${DB_NAME}_*.sql* 2>/dev/null | head -n 1)} [cite: 23, 24]

if [ -z "$SELECTED_FILE" ] || [ ! -f "$SELECTED_FILE" ]; then
    echo "Error: Backup file not found."
    exit 1
fi

docker-compose -f "$ROOT_DIR/docker-compose.yml" start

if [[ "$SELECTED_FILE" == *.gz ]]; then
    gunzip -c "$SELECTED_FILE" | docker exec -i $DB_CONTAINER_NAME psql -U $DB_USER -d $DB_NAME [cite: 28]
else
    cat "$SELECTED_FILE" | docker exec -i $DB_CONTAINER_NAME psql -U $DB_USER -d $DB_NAME [cite: 29]
fi

echo "-------------------------------------------------------"
echo "RESTORE COMPLETED SUCCESSFULLY"
echo "-------------------------------------------------------"