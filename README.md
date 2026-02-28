# !!! ⚡ Quickstart (TL:DR) ⚡ !!!

## 0. Điều kiện bắt buộc (dev phải tự chuẩn bị)

- Linux machine có `bash`.
- Có Docker Engine + Docker Compose plugin (`docker compose`).
- User chạy script có quyền dùng Docker daemon (`docker` group hoặc sudo phù hợp).
- Nếu dữ liệu/log được tạo bởi root (qua container), một số lệnh dọn dẹp có thể cần `sudo`.
- `DB_HOST_IP` trong `.env` phải là IP có thật trên máy đó.
- `DB_PORT_EXTERNAL` không được trùng với service khác.

1. **Chuẩn bị Project**:
    * Đổi tên folder `__database_template__` thành tên project (ví dụ: `db_payment`).
    * Di chuyển vào thư mục project:
    ```bash
    cd /path/to/db_payment
    ```

2. **Cấp quyền thực thi**:
   ```bash
   chmod +x setup.sh
   ```

3. **Khởi tạo môi trường**:
    * Chạy script setup để tạo file config và các thư mục cần thiết:
    ```bash
    ./setup.sh
    ```

4. **Cấu hình**:
   * Mở file `.env` vừa được tạo: điền user, password, database name, port và IP (Tailscale/LAN).
   * Điều chỉnh backup:
     * `BACKUP_KEEP_COUNT`: số bản backup giữ lại.
     * `BACKUP_SCHEDULE`: lịch Ofelia (cron 6 field: giây phút giờ ngày-tháng tháng thứ).
     * `TZ`: timezone dùng để tính lịch backup.
   * Điều chỉnh logging:
     * Log PostgreSQL nằm ở `logs/`.
     * Log hệ thống (stdout/stderr của `db` + `scheduler`) cũng nằm ở `logs/`.
   * Mở file `init/schema.sql` (được tạo bởi `setup.sh`): viết câu lệnh SQL tạo bảng (CREATE TABLE...) nếu cần khởi tạo dữ liệu ban đầu.

5. **Deploy**:
    * Chạy lệnh sau để build và start database:
    ```bash
    ./scripts/deploy.sh
    ```

6. **Kiểm tra**:
    * Đợi khoảng 15 giây cho DB khởi động, sau đó chạy health check:
    ```bash
    ./scripts/health_check.sh
    ```
    * Nếu thấy báo **HEALTHY** và các check đều OK là xong.
    * Backup tự động theo `BACKUP_SCHEDULE` trên timezone `TZ` (mặc định 03:00 mỗi ngày, giữ 3 bản)
    * System log được gom định kỳ theo `SYSTEM_LOG_SCHEDULE` vào `logs/`
    * Log PostgreSQL được rotate theo `DB_LOG_ROTATION_*`

7. **Cách connect tới DB**:
    * Chạy script hỗ trợ để lấy connection string (URL) chính xác:
    ```bash
    ./scripts/get_url.sh
    ```
    * Copy output và điền vào `.env` ở project client (nơi chạy services):
    ```
    DATABASE_URL=postgresql://USER:PASSWORD@HOST:PORT/DBNAME?sslmode=disable
    ```

---

# PostgreSQL Database Template

A production-ready, containerized PostgreSQL solution designed for Data Lake architectures. It features automated backups, strict network isolation, and self-healing capabilities.

## 1. System Architecture

The setup consists of two main services orchestrated via Docker Compose:

*   **Database (`db`)**:
    *   **Image**: Official PostgreSQL (version defined in `.env`).
    *   **Persistence**: Data stored locally in `./data`.
    *   **Security**: Binds only to a specific IP (e.g., Tailscale IP) to prevent public access.
    *   **Healthcheck**: Native `pg_isready` check ensures the DB is responsive.

*   **Scheduler (`scheduler`)**:
    *   **Image**: Custom build based on `mcuadros/ofelia`.
    *   **Role**: Runs sidecar to the database to handle periodic tasks.
    *   **Tasks**:
        *   `./scripts/backup.sh` theo `BACKUP_SCHEDULE`.
        *   `./scripts/prune_logs.sh` theo `LOG_PRUNE_SCHEDULE`.
        *   `./scripts/system_log_collector.sh` theo `SYSTEM_LOG_SCHEDULE`.

## 2. Configuration (`.env`)

Run `./setup.sh` to generate the `.env` file from `.env.example`.

| Variable            | Description                            | Example              |
| :------------------ | :------------------------------------- | :------------------- |
| `DB_CONTAINER_NAME` | Unique name for the Docker container   | `payment_db`         |
| `DB_IMAGE`          | PostgreSQL Docker image version        | `postgres:16-alpine` |
| `DB_HOST_IP`        | Bind IP address (use Tailscale/LAN IP) | `100.x.y.z`          |
| `DB_PORT_EXTERNAL`  | Port exposed to the host               | `5432`               |
| `DB_NAME`           | Database name                          | `payment_db`         |
| `DB_USER`           | Database superuser                     | `admin`              |
| `DB_PASSWORD`       | Database password                      | `secure_pass`        |
| `DOCKER_SOCKET`     | Docker socket path (rootless/rootful) | `/var/run/docker.sock` |
| `TZ`                | Timezone cho scheduler                 | `Asia/Ho_Chi_Minh`   |
| `BACKUP_KEEP_COUNT` | Số backup giữ lại                      | `3`                  |
| `BACKUP_SCHEDULE`   | Lịch backup (cron 6 field)             | `"0 0 3 * * *"`      |
| `DB_LOG_ROTATION_AGE_MINUTES` | Tuổi rotate log PostgreSQL (phút) | `60` |
| `DB_LOG_ROTATION_SIZE` | Kích thước rotate log PostgreSQL | `20MB` |
| `DB_LOG_RETENTION_DAYS` | Số ngày giữ file log PostgreSQL | `14` |
| `LOG_PRUNE_SCHEDULE` | Lịch dọn log PostgreSQL (cron 6 field) | `"0 30 3 * * *"` |
| `SYSTEM_LOG_SCHEDULE` | Lịch gom system log (cron 6 field) | `"0 */2 * * * *"` |
| `SYSTEM_LOG_MAX_SIZE_MB` | Kích thước tối đa mỗi file system log | `20` |
| `SYSTEM_LOG_MAX_FILES` | Số file rotate system log giữ lại | `5` |
| `SYSTEM_LOG_RETENTION_DAYS` | Số ngày giữ system log | `14` |
| `CONTAINER_LOG_MAX_SIZE` | max-size cho docker json log | `10m` |
| `CONTAINER_LOG_MAX_FILE` | max-file cho docker json log | `3` |

## 3. Maintenance Scripts

Located in the `scripts/` directory. All scripts auto-detect the project root.

| Script                | Purpose      | Description                                                                                              |
| :-------------------- | :----------- | :------------------------------------------------------------------------------------------------------- |
| **`deploy.sh`**       | **Deploy**   | Checks for port conflicts, builds images, and starts containers (`docker compose up -d`).                |
| **`health_check.sh`** | **Verify**   | Comprehensive check: Docker status, Ofelia scheduler registration, volume persistence, and connectivity. |
| **`get_url.sh`**      | **Connect**  | Generates URL-encoded connection strings for SQLAlchemy and asyncpg.                                     |
| **`backup.sh`**       | **Backup**   | Dumps the DB to `backups/`. Retention controlled by `BACKUP_KEEP_COUNT`.                                  |
| **`prune_logs.sh`**   | **Log Prune**| Removes PostgreSQL file logs in `logs/` older than `DB_LOG_RETENTION_DAYS`.                                |
| **`system_log_collector.sh`** | **System Logs** | Collects `db` + `scheduler` container logs into `logs/` with size/file retention limits. |
| **`restore.sh`**      | **Restore**  | Restores from a `.sql.gz` file. Auto-selects the latest backup if no argument is provided.               |
| **`start.sh`**        | **Recovery** | Simple wrapper to restart the container if it's stopped.                                                 |
| **`clean.sh`**        | **Reset**    | **DANGER**: Wipes the `data/` directory (factory reset). Requires container to be stopped.               |
| **`delete.sh`**       | **Teardown** | **DANGER**: Stops containers, removes volumes, networks, and deletes `data/`.                            |

## 4. Initialization

`init/` được track bằng `.gitkeep`. File `init/schema.sql` sẽ được `setup.sh` tạo runtime.

Any SQL file placed in the `init/` directory (specifically `schema.sql`) will be automatically executed by PostgreSQL **only the first time** the database is created (when `data/` is empty).

## 5. Runtime files after setup/deploy

Generated locally (không track git):

- `.env`
- `init/schema.sql`
- `data/` contents
- `backups/` contents
- `logs/` runtime logs (`postgresql-*.log`, `db_system.log`, `scheduler_system.log`, cursor files)

## 6. Directory Structure

```text
.
├── .env.example        # Environment template (tracked)
├── .env                # Runtime env created by setup.sh (not tracked)
├── .gitignore
├── docker-compose.yml  # Docker services config
├── Dockerfile          # Custom Scheduler image definition
├── README.md           # This documentation
├── setup.sh            # Initial setup script
├── backups/            # Storage for SQL dumps (created by setup.sh)
├── data/               # Persistent DB storage (created by setup.sh)
├── logs/               # PostgreSQL file logs + container system logs
│   └── .gitkeep
├── init/
│   └── .gitkeep        # Keep empty dir in git; schema.sql is runtime-generated
└── scripts/
    ├── _common.sh      # Shared script logic
    ├── backup.sh       # Backup logic
    ├── clean.sh        # Data cleanup logic
    ├── delete.sh       # Full teardown logic
    ├── deploy.sh       # Deployment logic
    ├── get_url.sh      # Helper to get connection URL
    ├── health_check.sh # System health verification
    ├── prune_logs.sh   # PostgreSQL logs retention
    ├── restore.sh      # Restore logic
    ├── start.sh        # Start service logic
    └── system_log_collector.sh # Collect container system logs
```
