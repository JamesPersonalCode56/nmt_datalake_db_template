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

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
load_env
require_compose

BACKUP_DIR="$ROOT_DIR/backups"
mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
FILE_NAME="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql"
KEEP_COUNT="${BACKUP_KEEP_COUNT:-3}"
CLOUD_BACKUP_ENABLED="$(echo "${CLOUD_BACKUP_ENABLED:-false}" | tr '[:upper:]' '[:lower:]')"
CLOUD_BACKUP_REMOTE="${CLOUD_BACKUP_REMOTE:-}"
CLOUD_BACKUP_BASE_PATH="${CLOUD_BACKUP_BASE_PATH:-datalake_backups}"
RCLONE_CONFIG_PATH="${RCLONE_CONFIG:-/project/secrets/rclone/rclone.conf}"

if ! [[ "$KEEP_COUNT" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: BACKUP_KEEP_COUNT must be a positive integer"
    exit 1
fi

docker exec "$DB_CONTAINER_NAME" pg_dump -U "$DB_USER" -d "$DB_NAME" --clean --if-exists --no-owner --no-privileges > "$FILE_NAME"

if [ -s "$FILE_NAME" ]; then
    gzip "$FILE_NAME"
    ls -t "$BACKUP_DIR"/"${DB_NAME}"_*.sql.gz 2>/dev/null | tail -n +"$((KEEP_COUNT + 1))" | xargs -r rm -f
else
    rm -f "$FILE_NAME"
    exit 1
fi

if [ "$CLOUD_BACKUP_ENABLED" = "true" ] || [ "$CLOUD_BACKUP_ENABLED" = "1" ] || [ "$CLOUD_BACKUP_ENABLED" = "yes" ]; then
    if [ -z "$CLOUD_BACKUP_REMOTE" ]; then
        echo "Error: CLOUD_BACKUP_REMOTE is required when CLOUD_BACKUP_ENABLED=true"
        exit 1
    fi

    CLOUD_BASE="${CLOUD_BACKUP_BASE_PATH%/}"
    if [ -n "$CLOUD_BASE" ]; then
        CLOUD_DIR="${CLOUD_BASE}/${DB_CONTAINER_NAME}"
    else
        CLOUD_DIR="${DB_CONTAINER_NAME}"
    fi
    CLOUD_TARGET_DIR="${CLOUD_BACKUP_REMOTE}:${CLOUD_DIR}"
    INCLUDE_PATTERN="${DB_NAME}_*.sql.gz"

    if [ -f "/.dockerenv" ]; then
        if ! command -v rclone >/dev/null 2>&1; then
            echo "Error: rclone not found in scheduler container"
            exit 1
        fi
        if [ ! -f "$RCLONE_CONFIG_PATH" ]; then
            echo "Error: RCLONE_CONFIG file not found at $RCLONE_CONFIG_PATH"
            exit 1
        fi
        RCLONE_CONFIG="$RCLONE_CONFIG_PATH" rclone copy "$BACKUP_DIR" "$CLOUD_TARGET_DIR" --include "$INCLUDE_PATTERN" --stats 0 --checkers 4 --transfers 1
    else
        SCHED_CONTAINER="${DB_CONTAINER_NAME}_scheduler"
        if ! docker inspect "$SCHED_CONTAINER" >/dev/null 2>&1; then
            echo "Error: Scheduler container '$SCHED_CONTAINER' not found."
            exit 1
        fi
        if [ "$(docker inspect -f '{{.State.Running}}' "$SCHED_CONTAINER" 2>/dev/null || true)" != "true" ]; then
            echo "Error: Scheduler container '$SCHED_CONTAINER' is not running."
            exit 1
        fi
        docker exec -e RCLONE_CONFIG="$RCLONE_CONFIG_PATH" "$SCHED_CONTAINER" \
            rclone copy /project/backups "$CLOUD_TARGET_DIR" --include "$INCLUDE_PATTERN" --stats 0 --checkers 4 --transfers 1
    fi
fi
