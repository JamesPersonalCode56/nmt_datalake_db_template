#!/bin/bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
load_env
require_compose

MIGRATIONS_DIR="${MIGRATIONS_DIR:-$ROOT_DIR/migrations}"
MIGRATION_TABLE="${MIGRATION_TABLE:-schema_migrations}"

if ! [[ "$MIGRATION_TABLE" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
  echo "Error: MIGRATION_TABLE is invalid: $MIGRATION_TABLE"
  exit 1
fi

if ! docker inspect "$DB_CONTAINER_NAME" >/dev/null 2>&1; then
  echo "Error: DB container '$DB_CONTAINER_NAME' not found. Run deploy first."
  exit 1
fi

if [ "$(docker inspect -f '{{.State.Running}}' "$DB_CONTAINER_NAME" 2>/dev/null || true)" != "true" ]; then
  echo "Error: DB container '$DB_CONTAINER_NAME' is not running."
  exit 1
fi

for _ in $(seq 1 30); do
  if docker exec "$DB_CONTAINER_NAME" pg_isready -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

if ! docker exec "$DB_CONTAINER_NAME" pg_isready -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; then
  echo "Error: DB is not ready for migrations."
  exit 1
fi

mkdir -p "$MIGRATIONS_DIR"

if ! command -v sha256sum >/dev/null 2>&1; then
  echo "Error: sha256sum not found."
  exit 1
fi

create_sql="CREATE TABLE IF NOT EXISTS public.\"$MIGRATION_TABLE\" (
  filename TEXT PRIMARY KEY,
  checksum TEXT NOT NULL,
  applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
);"
docker exec "$DB_CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -c "$create_sql" >/dev/null

mapfile -t MIGRATION_FILES < <(find "$MIGRATIONS_DIR" -maxdepth 1 -type f -name '*.sql' | sort)

if [ ${#MIGRATION_FILES[@]} -eq 0 ]; then
  echo "No migration files found in $MIGRATIONS_DIR"
  exit 0
fi

sql_escape() {
  local value="$1"
  printf '%s' "${value//\'/\'\'}"
}

APPLIED=0
SKIPPED=0

for migration_file in "${MIGRATION_FILES[@]}"; do
  filename="$(basename "$migration_file")"
  checksum="$(sha256sum "$migration_file" | awk '{print $1}')"
  filename_esc="$(sql_escape "$filename")"

  existing_checksum="$(docker exec "$DB_CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -t -A -c \
    "SELECT checksum FROM public.\"$MIGRATION_TABLE\" WHERE filename = '$filename_esc' LIMIT 1;")"
  existing_checksum="$(trim "$existing_checksum")"

  if [ -n "$existing_checksum" ]; then
    if [ "$existing_checksum" = "$checksum" ]; then
      echo "Skip: $filename (already applied)"
      SKIPPED=$((SKIPPED + 1))
      continue
    fi
    echo "Error: checksum mismatch for $filename"
    echo "Existing: $existing_checksum"
    echo "Current:  $checksum"
    exit 1
  fi

  echo "Apply: $filename"
  docker exec -i "$DB_CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 < "$migration_file"
  docker exec "$DB_CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -c \
    "INSERT INTO public.\"$MIGRATION_TABLE\" (filename, checksum) VALUES ('$filename_esc', '$checksum');" >/dev/null
  APPLIED=$((APPLIED + 1))
done

echo "Migration done. applied=$APPLIED skipped=$SKIPPED total=${#MIGRATION_FILES[@]}"
