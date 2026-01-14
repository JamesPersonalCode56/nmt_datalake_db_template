#!/bin/bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
load_env
require_compose

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

# 0) Basic presence checks (critical-ish but don't exit)
if ! container_exists "$DB_CONTAINER_NAME"; then
  echo "Warning: Container '$DB_CONTAINER_NAME' not found."
fi

# 1. Kiểm tra trạng thái Healthcheck
echo "[1/5] Docker Healthcheck Status:"
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

# 2. Kiểm tra Scheduler (Ofelia) đã nhận Job chưa
echo -e "\n[2/5] Scheduler Jobs (Ofelia):"
SCHED="${DB_CONTAINER_NAME}_scheduler"
if container_exists "$SCHED"; then
  safe docker logs "$SCHED" 2>&1 | grep "scheduler started" >/dev/null \
    && echo "Result: Scheduler started." \
    || echo "Warning: Scheduler might not be started (check logs)."

  if container_running "$SCHED"; then
    safe docker exec "$SCHED" ofelia list >/dev/null 2>&1 \
      && docker exec "$SCHED" ofelia list \
      || echo "Warning: Cannot list ofelia jobs (ofelia list failed)."
  else
    echo "Warning: Scheduler container exists but not running."
  fi
else
  echo "Warning: Scheduler container '$SCHED' not found."
fi

# 3. Kiểm tra Volume Mapping (Data & Init)
echo -e "\n[3/5] Volume & Storage Status:"
if [ -d "$ROOT_DIR/data/base" ]; then
  echo "Result: Data persistence confirmed."
else
  echo "Warning: Data directory seems empty or not initialized."
fi

if have_cmd du; then
  safe du -sh "$ROOT_DIR/data" "$ROOT_DIR/backups" \
    || echo "Warning: du failed (permissions/path)."
else
  echo "Warning: 'du' not found."
fi

# 4. Kiểm tra Database Initialization (schema.sql)
echo -e "\n[4/5] Schema Initialization:"
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

# 5. Kiểm tra Network Isolation (Port Binding)
echo -e "\n[5/5] Network Binding:"
if have_cmd nc; then
  safe nc -zv "$DB_HOST_IP" "$DB_PORT_EXTERNAL" 2>&1 | grep "succeeded" >/dev/null \
    && echo "Result: Connect succeeded to $DB_HOST_IP:$DB_PORT_EXTERNAL" \
    || echo "Warning: Cannot connect to $DB_HOST_IP:$DB_PORT_EXTERNAL"
else
  echo "Warning: 'nc' not found. Skipped network check."
fi

echo -e "\n--- CHECK COMPLETE ---"
