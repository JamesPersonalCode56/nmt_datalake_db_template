#!/bin/bash
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -f "$ROOT_DIR/.env" ]; then
    export $(grep -v '^#' "$ROOT_DIR/.env" | xargs)
else
    echo "Error: .env file not found at $ROOT_DIR/.env"
    exit 1
fi

BACKUP_DIR="$ROOT_DIR/backups"
SELECTED_FILE=$1

# Auto-pick latest backup if no argument provided
if [ -z "$SELECTED_FILE" ]; then
    echo "No file specified. Searching for the latest backup in $BACKUP_DIR..."
    SELECTED_FILE=$(ls -t "$BACKUP_DIR"/${DB_NAME}_*.sql* 2>/dev/null | head -n 1)
    
    if [ -z "$SELECTED_FILE" ]; then
        echo "Error: No backup files found in $BACKUP_DIR."
        exit 1
    fi
    
    echo "Latest backup found: $SELECTED_FILE"
    read -p "Do you want to restore from this file? (y/n): " confirm
    [[ "$confirm" != "y" ]] && echo "Operation cancelled." && exit 0
fi

if [ ! -f "$SELECTED_FILE" ]; then
    echo "Error: File $SELECTED_FILE not found."
    exit 1
fi

echo "Restoring database: $DB_NAME from $SELECTED_FILE..."
# Ensure container is running before restore
docker-compose -f "$ROOT_DIR/docker-compose.yml" start

if [[ "$SELECTED_FILE" == *.gz ]]; then
    gunzip -c "$SELECTED_FILE" | docker exec -i $DB_CONTAINER_NAME psql -U $DB_USER -d $DB_NAME
else
    cat "$SELECTED_FILE" | docker exec -i $DB_CONTAINER_NAME psql -U $DB_USER -d $DB_NAME
fi

if [ $? -eq 0 ]; then
    echo "-------------------------------------------------------"
    echo "RESTORE COMPLETED SUCCESSFULLY"
    echo "-------------------------------------------------------"
else
    echo "Error: Restore failed."
    exit 1
fi