#!/bin/bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
load_env

LOG_DIR="$ROOT_DIR/logs"
MAX_FILES="${DB_LOG_MAX_FILES:-10}"
MAX_SIZE_MB="${DB_LOG_MAX_SIZE_MB:-2048}"
MAX_SIZE_BYTES=0
FILE_COUNT=0
TOTAL_SIZE_BYTES=0

if ! [[ "$MAX_FILES" =~ ^[0-9]+$ ]]; then
  echo "Error: DB_LOG_MAX_FILES must be a non-negative integer"
  exit 1
fi

if ! [[ "$MAX_SIZE_MB" =~ ^[0-9]+$ ]]; then
  echo "Error: DB_LOG_MAX_SIZE_MB must be a non-negative integer"
  exit 1
fi

mkdir -p "$LOG_DIR"
MAX_SIZE_BYTES=$((MAX_SIZE_MB * 1024 * 1024))

while IFS= read -r file; do
  FILE_COUNT=$((FILE_COUNT + 1))
  TOTAL_SIZE_BYTES=$((TOTAL_SIZE_BYTES + $(wc -c < "$file")))
done < <(find "$LOG_DIR" -maxdepth 1 -type f -name 'postgresql-*.log' -print | sort)

if [ "$FILE_COUNT" -le "$MAX_FILES" ] && [ "$TOTAL_SIZE_BYTES" -le "$MAX_SIZE_BYTES" ]; then
  exit 0
fi

while IFS= read -r file; do
  if [ "$FILE_COUNT" -le "$MAX_FILES" ] && [ "$TOTAL_SIZE_BYTES" -le "$MAX_SIZE_BYTES" ]; then
    break
  fi
  FILE_SIZE_BYTES=$(wc -c < "$file")
  rm -f -- "$file"
  FILE_COUNT=$((FILE_COUNT - 1))
  TOTAL_SIZE_BYTES=$((TOTAL_SIZE_BYTES - FILE_SIZE_BYTES))
done < <(find "$LOG_DIR" -maxdepth 1 -type f -name 'postgresql-*.log' -printf '%T@ %p\n' | sort -n | awk '{ $1=""; sub(/^ /, ""); print }')
