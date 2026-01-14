#!/bin/bash
set -euo pipefail

trap 'echo "Error: Health check failed at line $LINENO"' ERR

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "$ROOT_DIR/.env" ] && export $(grep -v '^#' "$ROOT_DIR/.env" | xargs)

echo "--- PRODUCTION VERIFICATION: $DB_CONTAINER_NAME ---"

# 1. Kiểm tra trạng thái Healthcheck được định nghĩa trong yml
echo "[1/5] Docker Healthcheck Status:"
HEALTH_STATUS=$(docker inspect -f '{{.State.Health.Status}}' $DB_CONTAINER_NAME)
if [ "$HEALTH_STATUS" == "healthy" ]; then
    echo "Result: DB is HEALTHY (pg_isready passed)."
else
    echo "Result: DB is $HEALTH_STATUS (check docker logs)."
fi

# 2. Kiểm tra Scheduler (Ofelia) đã nhận Job chưa
echo -e "\n[2/5] Scheduler Jobs (Ofelia):"
docker logs ${DB_CONTAINER_NAME}_scheduler 2>&1 | grep "scheduler started" || echo "Warning: Scheduler might not be started."
docker exec ${DB_CONTAINER_NAME}_scheduler ofelia list || echo "Error: Cannot list ofelia jobs."

# 3. Kiểm tra Volume Mapping (Data & Init)
echo -e "\n[3/5] Volume & Storage Status:"
if [ -d "$ROOT_DIR/data/base" ]; then
    echo "Result: Data persistence confirmed."
else
    echo "Warning: Data directory seems empty."
fi
du -sh "$ROOT_DIR/data" "$ROOT_DIR/backups"

# 4. Kiểm tra Database Initialization (schema.sql)
echo -e "\n[4/5] Schema Initialization:"
TABLE_COUNT=$(docker exec $DB_CONTAINER_NAME psql -U $DB_USER -d $DB_NAME -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';")
echo "Result: $TABLE_COUNT tables found in public schema."

# 5. Kiểm tra Network Isolation (Port Binding)
echo -e "\n[5/5] Network Binding:"
nc -zv $DB_HOST_IP $DB_PORT_EXTERNAL 2>&1 | grep "succeeded" || echo "Warning: Cannot connect to $DB_HOST_IP:$DB_PORT_EXTERNAL"

echo -e "\n--- CHECK COMPLETE ---"