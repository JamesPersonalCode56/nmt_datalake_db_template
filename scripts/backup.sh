#!/bin/bash
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -f "$ROOT_DIR/.env" ]; then
    export $(grep -v '^#' "$ROOT_DIR/.env" | xargs)
else
    echo "Error: .env file not found at $ROOT_DIR/.env"
    exit 1
fi

BACKUP_DIR="$ROOT_DIR/backups"
mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
FILE_NAME="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql"

echo "Starting backup for database: $DB_NAME..."
docker exec -t $DB_CONTAINER_NAME pg_dump -U $DB_USER $DB_NAME > "$FILE_NAME"

if [ $? -eq 0 ]; then
    echo "Backup successful: $FILE_NAME"
    gzip "$FILE_NAME"
    # Keep only 3 latest backups
    ls -t "$BACKUP_DIR"/${DB_NAME}_*.sql.gz 2>/dev/null | tail -n +4 | xargs -r rm
    echo "Cleanup finished. Current backups:"
    ls -lh "$BACKUP_DIR"
else
    echo "Error: Backup failed."
    rm -f "$FILE_NAME"
    exit 1
fi