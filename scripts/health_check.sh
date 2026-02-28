#!/bin/bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
load_env
require_compose

BACKUP_DIR="${BACKUP_DIR:-$ROOT_DIR/backups}"
KEEP_COUNT="${BACKUP_KEEP_COUNT:-3}"

echo "--- PRODUCTION VERIFICATION: $DB_CONTAINER_NAME ---"

have_cmd() { command -v "$1" >/dev/null 2>&1; }

container_exists() {
  docker inspect "$1" >/dev/null 2>&1
}

container_running() {
  [ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null || echo false)" = "true" ]
}

safe() {
  set +e
  "$@"
  local rc=$?
  set -e
  return $rc
}

if ! container_exists "$DB_CONTAINER_NAME"; then
  echo "Warning: Container '$DB_CONTAINER_NAME' not found."
fi

echo "[1/6] Docker Healthcheck Status:"
if container_exists "$DB_CONTAINER_NAME"; then
  HEALTH_STATUS="$(docker inspect -f '{{.State.Health.Status}}' "$DB_CONTAINER_NAME" 2>/dev/null)"
  if [ "$HEALTH_STATUS" = "healthy" ]; then
    echo "Result: DB is HEALTHY (pg_isready passed)."
  else
    echo "Result: DB is ${HEALTH_STATUS:-unknown} (check docker logs)."
  fi
else
  echo "Result: skipped (db container not found)."
fi

echo -e "\n[2/6] Scheduler Reliability (Ofelia):"
SCHED="${DB_CONTAINER_NAME}_scheduler"
if container_exists "$SCHED"; then
  if container_running "$SCHED"; then
    RESTART_POLICY="$(docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' "$SCHED" 2>/dev/null || true)"
    if [ "$RESTART_POLICY" = "always" ] || [ "$RESTART_POLICY" = "unless-stopped" ]; then
      echo "Result: Restart policy is $RESTART_POLICY."
    else
      echo "Warning: Restart policy is '$RESTART_POLICY' (recommend always/unless-stopped)."
    fi
    SCHEDULE_LABEL="$(docker inspect -f '{{ index .Config.Labels "ofelia.job-local.db-backup.schedule" }}' "$SCHED" 2>/dev/null || true)"
    if [ -n "$SCHEDULE_LABEL" ] && [ "$SCHEDULE_LABEL" != "<no value>" ]; then
      echo "Result: Backup schedule label is '$SCHEDULE_LABEL'."
    else
      echo "Warning: Missing Ofelia backup schedule label."
    fi
    NO_OVERLAP="$(docker inspect -f '{{ index .Config.Labels "ofelia.job-local.db-backup.no-overlap" }}' "$SCHED" 2>/dev/null || true)"
    if [ "$NO_OVERLAP" = "true" ]; then
      echo "Result: no-overlap is enabled."
    else
      echo "Warning: no-overlap is not enabled."
    fi
    safe docker logs --tail 300 "$SCHED" 2>&1 | grep -E 'New job registered|Starting scheduler' >/dev/null \
      && echo "Result: Scheduler running, job registered." \
      || echo "Warning: Scheduler running but no job registration found in logs."
  else
    echo "Warning: Scheduler container exists but not running."
  fi
else
  echo "Warning: Scheduler container '$SCHED' not found."
fi

echo -e "\n[3/6] Backup Freshness:"
mkdir -p "$BACKUP_DIR"
LATEST_BACKUP="$(ls -t "$BACKUP_DIR"/"${DB_NAME}"_*.sql.gz 2>/dev/null | head -n 1 || true)"
BACKUP_COUNT="$(find "$BACKUP_DIR" -maxdepth 1 -type f -name "${DB_NAME}_*.sql.gz" | wc -l | tr -d ' ')"
if [ -n "$LATEST_BACKUP" ]; then
  LAST_BACKUP_TS="$(stat -c %Y "$LATEST_BACKUP" 2>/dev/null || true)"
  if [ -n "$LAST_BACKUP_TS" ]; then
    NOW_TS="$(date +%s)"
    AGE_HOURS="$(( (NOW_TS - LAST_BACKUP_TS) / 3600 ))"
    echo "Result: Latest backup '$LATEST_BACKUP' (${AGE_HOURS}h old)."
  else
    echo "Result: Latest backup '$LATEST_BACKUP'."
  fi
else
  echo "Warning: No backup file found yet."
fi
if [[ "$KEEP_COUNT" =~ ^[1-9][0-9]*$ ]] && [ "$BACKUP_COUNT" -gt "$KEEP_COUNT" ]; then
  echo "Warning: Backup count is $BACKUP_COUNT (expected <= $KEEP_COUNT)."
else
  echo "Result: Backup count is $BACKUP_COUNT (keep=$KEEP_COUNT)."
fi

echo
echo "[4/6] Volume & Storage Status:"

PGDATA_PATH="$(docker exec "$DB_CONTAINER_NAME" sh -lc 'echo "${PGDATA:-/var/lib/postgresql/data}"' 2>/dev/null || true)"

if [ -n "${PGDATA_PATH:-}" ]; then
  if docker exec "$DB_CONTAINER_NAME" sh -lc "[ -d '$PGDATA_PATH/base' ]" >/dev/null 2>&1; then
    echo "Result: Data persistence confirmed."
    docker exec "$DB_CONTAINER_NAME" sh -lc "du -sh '$PGDATA_PATH' || true"
  else
    echo "Warning: PGDATA exists but not initialized (missing base/)."
    docker exec "$DB_CONTAINER_NAME" sh -lc "ls -la '$PGDATA_PATH' | head -n 50 || true"
  fi
else
  echo "Warning: Cannot resolve PGDATA path from container."
fi

du -sh "$BACKUP_DIR" 2>/dev/null || echo "Warning: Cannot read backups dir on host."

echo -e "\n[5/6] Schema Initialization:"
if container_running "$DB_CONTAINER_NAME"; then
  TABLE_COUNT="$(docker exec "$DB_CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -t -c \
    "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | tr -d '[:space:]' || true)"
  if [ -n "$TABLE_COUNT" ]; then
    echo "Result: $TABLE_COUNT tables found in public schema."
  else
    echo "Warning: Cannot query table count (psql failed)."
  fi
else
  echo "Result: skipped (db container not running)."
fi

echo -e "\n[6/6] Network Binding:"
if have_cmd nc; then
  safe nc -zv "$DB_HOST_IP" "$DB_PORT_EXTERNAL" 2>&1 | grep "succeeded" >/dev/null \
    && echo "Result: Connect succeeded to $DB_HOST_IP:$DB_PORT_EXTERNAL" \
    || echo "Warning: Cannot connect to $DB_HOST_IP:$DB_PORT_EXTERNAL"
else
  echo "Warning: 'nc' not found. Skipped network check."
fi

echo -e "\n--- CHECK COMPLETE ---"
