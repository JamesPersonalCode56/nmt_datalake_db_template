#!/bin/bash

# 1. Load environment variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "Error: .env file not found."
    exit 1
fi

BACKUP_DIR="./backups"
SELECTED_FILE=$1

# 2. Logic to pick the latest file if no argument is provided
if [ -z "$SELECTED_FILE" ]; then
    echo "No file specified. Searching for the latest backup in $BACKUP_DIR..."
    
    # Get the newest file by modification time (ls -t)
    LATEST=$(ls -t $BACKUP_DIR/*.sql* 2>/dev/null | head -n 1)
    
    if [ -z "$LATEST" ]; then
        echo "Error: No backup files found in $BACKUP_DIR."
        exit 1
    fi
    
    SELECTED_FILE=$LATEST
    echo "Latest backup found: $SELECTED_FILE"
    
    # Confirmation for automation safety
    read -p "Do you want to restore from this file? (y/n): " confirm
    if [ "$confirm" != "y" ]; then
        echo "Operation cancelled."
        exit 0
    fi
fi

# 3. Check if the selected file exists
if [ ! -f "$SELECTED_FILE" ]; then
    echo "Error: File $SELECTED_FILE not found."
    exit 1
fi

echo "Restoring database: $DB_NAME from $SELECTED_FILE..."

# 4. Handle .gz or plain .sql
if [[ "$SELECTED_FILE" == *.gz ]]; then
    gunzip -c "$SELECTED_FILE" | docker exec -i $DB_CONTAINER_NAME psql -U $DB_USER -d $DB_NAME
else
    cat "$SELECTED_FILE" | docker exec -i $DB_CONTAINER_NAME psql -U $DB_USER -d $DB_NAME
fi

# 5. Result check
if [ $? -eq 0 ]; then
    echo "-------------------------------------------------------"
    echo "RESTORE COMPLETED SUCCESSFULLY"
    echo "File: $SELECTED_FILE"
    echo "-------------------------------------------------------"
else
    echo "Error: Restore failed."
    exit 1
fi