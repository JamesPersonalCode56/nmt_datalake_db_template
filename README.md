# !!! ⚡ Quickstart (TL:DR) ⚡ !!!

## 0. Điều kiện bắt buộc (dev phải tự chuẩn bị)

- Linux machine có `bash`.
- Có Docker Engine + Docker Compose plugin (`docker compose`).
- User chạy script có quyền dùng Docker daemon (`docker` group hoặc sudo phù hợp).
- Nếu dữ liệu/log được tạo bởi root (qua container), một số lệnh dọn dẹp có thể cần `sudo`.
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
   * Mở file `secrets/rclone/rclone.conf` điền nội dung config vào.
   * Mở file `init/schema.sql` (được tạo bởi `setup.sh`): viết câu lệnh SQL tạo bảng (CREATE TABLE...)

5. **Deploy**:
    * Chạy lệnh sau để build và start database:
    ```bash
    ./scripts/deploy.sh
    ```
    * `deploy.sh` sẽ tự chạy migration (`scripts/migrate.sh`) nếu `AUTO_MIGRATE_ON_DEPLOY=true`.

6. **Kiểm tra**:
    * Đợi khoảng 15 giây cho DB khởi động, sau đó chạy health check:
    ```bash
    ./scripts/health_check.sh
    ```
    * Nếu thấy báo **HEALTHY** và các check đều OK là xong.
    * Backup tự động theo `BACKUP_SCHEDULE` trên timezone `TZ` (mặc định 03:00 mỗi ngày, giữ 3 bản)
    * Nếu bật cloud backup, mỗi lần backup local xong sẽ sync remote để danh sách file trên cloud luôn trùng với local.
    * System log được gom định kỳ theo `SYSTEM_LOG_SCHEDULE` vào `logs/`
    * Log PostgreSQL được rotate theo `DB_LOG_ROTATION_*`, rồi prune theo `DB_LOG_MAX_FILES` + `DB_LOG_MAX_SIZE_MB`

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
        *   `./scripts/backup.sh` theo `BACKUP_SCHEDULE` (upload cloud ngay sau backup nếu bật).
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
| `AUTO_MIGRATE_ON_DEPLOY` | Tự chạy migration sau deploy      | `true`               |
| `MIGRATION_TABLE`   | Bảng lưu lịch sử migration             | `schema_migrations`  |
| `CLOUD_BACKUP_ENABLED` | Bật/tắt upload backup lên cloud     | `false`              |
| `CLOUD_BACKUP_REMOTE` | Tên remote rclone                    | `nmt_user_backup`    |
| `CLOUD_BACKUP_BASE_PATH` | Thư mục gốc trên remote (script tự thêm `${DB_CONTAINER_NAME}`) | `datalake_backups` |
| `RCLONE_CONFIG`     | Path tuyệt đối tới `rclone.conf` trong container scheduler | `/project/secrets/rclone/rclone.conf` |
| `DB_LOG_ROTATION_AGE_MINUTES` | Tuổi rotate log PostgreSQL (phút) | `60` |
| `DB_LOG_ROTATION_SIZE` | Kích thước rotate log PostgreSQL | `50MB` |
| `DB_LOG_FILE_MODE` | Permission mode cho PostgreSQL log files mới tạo | `0644` |
| `DB_LOG_MAX_FILES` | Số file PostgreSQL log giữ lại tối đa | `24` |
| `DB_LOG_MAX_SIZE_MB` | Tổng dung lượng tối đa của PostgreSQL log | `1024` |
| `LOG_PRUNE_SCHEDULE` | Lịch dọn log PostgreSQL (cron 6 field) | `"0 0 * * * *"` |
| `SYSTEM_LOG_SCHEDULE` | Lịch gom system log (cron 6 field) | `"0 */2 * * * *"` |
| `SYSTEM_LOG_ROTATE_SIZE_MB` | Kích thước rotate của mỗi system log file đang active | `20` |
| `SYSTEM_LOG_MAX_SIZE_MB` | Tổng dung lượng tối đa của từng family system log (`db_system.log*`, `scheduler_system.log*`) | `512` |
| `SYSTEM_LOG_MAX_FILES` | Số file tối đa giữ lại cho từng family system log | `10` |
| `CONTAINER_LOG_MAX_SIZE` | max-size cho docker json log | `20m` |
| `CONTAINER_LOG_MAX_FILE` | max-file cho docker json log | `5` |

## 3. Maintenance Scripts

Located in the `scripts/` directory. All scripts auto-detect the project root.

| Script                | Purpose      | Description                                                                                              |
| :-------------------- | :----------- | :------------------------------------------------------------------------------------------------------- |
| **`deploy.sh`**       | **Deploy**   | Checks for port conflicts, builds/starts containers (`docker compose up -d --build`) and auto-runs migrations. |
| **`migrate.sh`**      | **Migrate**  | Applies new `migrations/*.sql` files in order and records checksums in DB table `schema_migrations`.      |
| **`health_check.sh`** | **Verify**   | Comprehensive check: Docker status, Ofelia scheduler registration, volume persistence, and connectivity. |
| **`get_url.sh`**      | **Connect**  | Generates URL-encoded connection strings for SQLAlchemy and asyncpg.                                     |
| **`backup.sh`**       | **Backup**   | Dumps DB to `backups/`, applies local retention, then syncs cloud so remote files match local backups.    |
| **`prune_logs.sh`**   | **Log Prune**| Keeps at most `DB_LOG_MAX_FILES` PostgreSQL log files and total size <= `DB_LOG_MAX_SIZE_MB` by deleting the oldest matching files first. |
| **`system_log_collector.sh`** | **System Logs** | Collects `db` + `scheduler` container logs into `logs/`, rotates the active file by `SYSTEM_LOG_ROTATE_SIZE_MB`, then prunes each file family by `SYSTEM_LOG_MAX_FILES` and `SYSTEM_LOG_MAX_SIZE_MB`. |
| **`restore.sh`**      | **Restore**  | Restores from a `.sql.gz` file. Auto-selects the latest backup if no argument is provided.               |
| **`start.sh`**        | **Recovery** | Simple wrapper to restart the container if it's stopped.                                                 |
| **`clean.sh`**        | **Reset**    | **DANGER**: Wipes the `data/` directory (factory reset). Requires container to be stopped.               |
| **`delete.sh`**       | **Teardown** | **DANGER**: Stops containers, removes volumes, networks, and deletes `data/`.                            |

## 4. Initialization

`init/` được track bằng `.gitkeep`. File `init/schema.sql` sẽ được `setup.sh` tạo runtime.

Any SQL file placed in the `init/` directory (specifically `schema.sql`) will be automatically executed by PostgreSQL **only the first time** the database is created (when `data/` is empty).

For any schema update after first deploy, create a new SQL file in `migrations/` and run `./scripts/migrate.sh` (or `./scripts/deploy.sh` with auto-migrate enabled).

## 5. Runtime files after setup/deploy

Generated locally (không track git):

- `.env`
- `secrets/rclone/rclone.conf`
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
├── secrets/            # Runtime secrets (ignored by git)
│   └── rclone/
│       └── rclone.conf # rclone OAuth config for cloud backup
├── migrations/         # SQL migrations for existing DB updates
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
    ├── migrate.sh      # Apply SQL migrations and track history
    ├── prune_logs.sh   # PostgreSQL logs retention
    ├── restore.sh      # Restore logic
    ├── start.sh        # Start service logic
    └── system_log_collector.sh # Collect container system logs
```
