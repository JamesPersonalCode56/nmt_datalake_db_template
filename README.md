# !!! ⚡ Quickstart (TL:DR) ⚡ !!!

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
   * Mở file `.env` vừa được tạo: điền user, password, database name, port và IP (Tailscale).
   * Mở file `init/schema.sql`: viết câu lệnh SQL tạo bảng (CREATE TABLE...) nếu cần khởi tạo dữ liệu ban đầu.

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
    * Tự động backup bằng Ofelia mỗi 03:00 gmt+7 (lưu tối đa 3 bản backup)

7. **Cách connect tới DB**:
    * Điền database url vào `.env` ở project nơi chạy services:
    ```
    DATABASE_URL=postgresql://USER:PASSWORD@HOST:PORT/DBNAME?param1=value1&param2=value2
    ```

    Example:
    ```
    DATABASE_URL=postgresql://manhnd:123@100.115.36.121:5432/db_payment?sslmode=disable
    ```
    * Lưu ý: password phải URL-encode nếu có ký tự đặc biệt: @ : / ? # % & + =…

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
    *   **Task**: Executes `./scripts/backup.sh` daily at **03:00 AM** (default).

## 2. Configuration (`.env`)

Run `./setup.sh` to generate the `.env` file from `.env.example`.

| Variable | Description | Example |
| :--- | :--- | :--- |
| `DB_CONTAINER_NAME` | Unique name for the Docker container | `payment_db` |
| `DB_IMAGE` | PostgreSQL Docker image version | `postgres:15-alpine` |
| `DB_HOST_IP` | Bind IP address (use Tailscale/LAN IP) | `100.x.y.z` |
| `DB_PORT_EXTERNAL` | Port exposed to the host | `5432` |
| `DB_NAME` | Database name | `payment_db` |
| `DB_USER` | Database superuser | `admin` |
| `DB_PASSWORD` | Database password | `secure_pass` |
| `PROJECT_ROOT` | Absolute path to project (auto-set by setup.sh) | `/mnt/data/db_payment` |

## 3. Maintenance Scripts

Located in the `scripts/` directory. All scripts auto-detect the project root.

| Script | Purpose | Description |
| :--- | :--- | :--- |
| **`deploy.sh`** | **Deploy** | Checks for port conflicts, builds images, and starts containers (`docker compose up -d`). |
| **`health_check.sh`** | **Verify** | Comprehensive check: Docker status, Ofelia scheduler registration, volume persistence, and connectivity. |
| **`backup.sh`** | **Backup** | Dumps the DB to `backups/`. Retains only the 3 most recent files to save space. |
| **`restore.sh`** | **Restore** | Restores from a `.sql.gz` file. Auto-selects the latest backup if no argument is provided. |
| **`start.sh`** | **Recovery** | Simple wrapper to restart the container if it's stopped. |
| **`clean.sh`** | **Reset** | **DANGER**: Wipes the `data/` directory (factory reset). Requires container to be stopped. |
| **`delete.sh`** | **Teardown** | **DANGER**: Stops containers, removes volumes, networks, and deletes `data/` + `backups/`. |

## 4. Initialization

Any SQL file placed in the `init/` directory (specifically `schema.sql`) will be automatically executed by PostgreSQL **only the first time** the database is created (when `data/` is empty).

## 5. Directory Structure

```text
.
├── .env                # Environment variables (Credentials, Network)
├── .gitignore
├── docker-compose.yml  # Docker services config
├── Dockerfile          # Custom Scheduler image definition
├── README.md           # This documentation
├── setup.sh            # Initial setup script
├── backups/            # Storage for SQL dumps (created by setup.sh)
├── data/               # Persistent DB storage (created by setup.sh)
├── init/
│   └── schema.sql      # Initial SQL schema (tables, indexes)
└── scripts/
    ├── _common.sh      # Shared script logic
    ├── backup.sh       # Backup logic
    ├── clean.sh        # Data cleanup logic
    ├── delete.sh       # Full teardown logic
    ├── deploy.sh       # Deployment logic
    ├── health_check.sh # System health verification
    ├── restore.sh      # Restore logic
    └── start.sh        # Start service logic
```
