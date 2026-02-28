#!/bin/bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
load_env

LOG_DIR="$ROOT_DIR/logs"
MAX_SIZE_MB="${SYSTEM_LOG_MAX_SIZE_MB:-20}"
MAX_FILES="${SYSTEM_LOG_MAX_FILES:-5}"
RETENTION_DAYS="${SYSTEM_LOG_RETENTION_DAYS:-14}"
MAX_SIZE_BYTES=0

validate_positive_int() {
  local value="$1"
  [[ "$value" =~ ^[1-9][0-9]*$ ]]
}

validate_non_negative_int() {
  local value="$1"
  [[ "$value" =~ ^[0-9]+$ ]]
}

if ! validate_positive_int "$MAX_SIZE_MB"; then
  echo "Error: SYSTEM_LOG_MAX_SIZE_MB must be a positive integer"
  exit 1
fi

if ! validate_positive_int "$MAX_FILES"; then
  echo "Error: SYSTEM_LOG_MAX_FILES must be a positive integer"
  exit 1
fi

if ! validate_non_negative_int "$RETENTION_DAYS"; then
  echo "Error: SYSTEM_LOG_RETENTION_DAYS must be a non-negative integer"
  exit 1
fi

MAX_SIZE_BYTES=$((MAX_SIZE_MB * 1024 * 1024))
mkdir -p "$LOG_DIR"

rotate_file() {
  local file="$1"
  local size=0
  local i=0
  [ -f "$file" ] || return 0
  size="$(wc -c < "$file" | tr -d '[:space:]')"
  [ "$size" -le "$MAX_SIZE_BYTES" ] && return 0
  rm -f "${file}.${MAX_FILES}"
  for ((i=MAX_FILES-1; i>=1; i--)); do
    if [ -f "${file}.${i}" ]; then
      mv "${file}.${i}" "${file}.$((i+1))"
    fi
  done
  mv "$file" "${file}.1"
  : > "$file"
}

prune_file_family() {
  local file="$1"
  local pattern=""
  pattern="$(basename "$file")*"
  if [ "$RETENTION_DAYS" -eq 0 ]; then
    find "$LOG_DIR" -type f -name "$pattern" -delete
  else
    find "$LOG_DIR" -type f -name "$pattern" -mtime +"$RETENTION_DAYS" -delete
  fi
}

collect_logs() {
  local container="$1"
  local slug="$2"
  local log_file="$LOG_DIR/${slug}.log"
  local cursor_file="$LOG_DIR/.${slug}.cursor"
  local since="10m"
  local now_utc=""
  if [ -f "$cursor_file" ]; then
    since="$(cat "$cursor_file")"
  fi
  now_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if docker inspect "$container" >/dev/null 2>&1; then
    if ! docker logs --since "$since" --timestamps "$container" >> "$log_file" 2>&1; then
      printf '%s collector_error container=%s\n' "$now_utc" "$container" >> "$log_file"
    fi
  else
    printf '%s container_not_found container=%s\n' "$now_utc" "$container" >> "$log_file"
  fi
  printf '%s\n' "$now_utc" > "$cursor_file"
  rotate_file "$log_file"
  prune_file_family "$log_file"
}

collect_logs "$DB_CONTAINER_NAME" "db_system"
collect_logs "${DB_CONTAINER_NAME}_scheduler" "scheduler_system"
