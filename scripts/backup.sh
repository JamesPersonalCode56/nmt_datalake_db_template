#!/bin/bash

# 1. Load environment variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "Error: .env file not found."
    exit 1
fi

BACKUP_DIR="./backups"
mkdir -p $BACKUP_DIR
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
FILE_NAME="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql"

echo "Starting backup for database: $DB_NAME..."

# 2. Perform backup
docker exec -t $DB_CONTAINER_NAME pg_dump -U $DB_USER $DB_NAME > $FILE_NAME

if [ $? -eq 0 ]; then
    echo "Backup successful: $FILE_NAME"
    gzip $FILE_NAME
    echo "Backup compressed: ${FILE_NAME}.gz"
    
    # --- 3. ROTATION LOGIC: Keep only the 3 latest backups ---
    echo "Cleaning up old backups (keeping only the 3 newest)..."
    
    # List files by time (newest first), skip the first 3, and delete the rest
    ls -t $BACKUP_DIR/${DB_NAME}_*.sql.gz 2>/dev/null | tail -n +4 | xargs -r rm
    
    echo "Cleanup finished."
    echo "Current backups in $BACKUP_DIR:"
    ls -lh $BACKUP_DIR/${DB_NAME}_*.sql.gz
else
    echo "Error: Backup failed."
    rm -f $FILE_NAME
    exit 1
fi