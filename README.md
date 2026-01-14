# Database Template for Datalake Automation

Professional, production-ready template for deploying and managing isolated PostgreSQL instances within a Datalake architecture.

# Quick Start 5 dòng tiếng Việt:
    1. Đổi tên folder template thành tên project (ví dụ: db_payment)
    2. Chạy file "./setup.sh"
    3. Copy + Paste code schema mới vào "init/schema.sql"
    4. Chỉnh file ".env"
    5. Chạy file "./scripts/deploy.sh" để build mới hoàn toàn
* Đọc thêm về các script .sh khác để biết
* Database tự backup mỗi ngày lúc 03:00 gmt+7 (default là 3 bản) dùng ofelia 

## 1. Quick Start Workflow

1.  **Initialize**: Run the setup script to prepare the environment.
    ```bash
    ./setup.sh
    ```
    * This copies `.env.example` to `.env`.
    * Creates `data/` and `backups/` directories.
    * Sets `.env` permissions to `600` for security.
    * Grants execution permissions to all scripts.

2.  **Configuration**: Edit `.env` with your specific database credentials, port, and Tailscale IP.

3.  **Deployment**: Launch the containerized database.
    ```bash
    ./scripts/deploy.sh
    ```
    * Validates that the external port is not already occupied.
    * Triggers `docker-compose up` using absolute paths.

---

## 2. Maintenance Scripts Reference

All scripts support execution from any directory as they resolve the project root automatically.

| Script | Function | Key Feature |
| :--- | :--- | :--- |
| **`deploy.sh`** | Initial setup & deployment | Port conflict validation. |
| **`backup.sh`** | Automated SQL dumping | Keeps only the 3 latest compressed backups. |
| **`restore.sh`**| Data recovery | Auto-detects the latest backup if no file is specified. |
| **`start.sh`** | Service recovery | Restarts the container if it is found to be down. |
| **`clean.sh`** | Reset database | Wipes all physical data in the `data/` folder. |
| **`delete.sh`** | Full teardown | Deletes the container, network, volumes, and project data. |

---

## 3. Production Features

### High Availability & Monitoring
* **Healthchecks**: The container uses `pg_isready` to report its status to the Docker engine every 10 seconds.
* **Auto-Restart**: Configured with `restart: always` to ensure persistent uptime.

### Storage & Security
* **Network Isolation**: Bound specifically to the `DB_HOST_IP` (Tailscale) to prevent public internet exposure.
* **Log Rotation**: Docker logs are limited to 10MB per file with a maximum of 3 files to prevent disk exhaustion.
* **Persistence**: Data is mapped to the local `data/` directory for easy migrations.

---

## 4. Directory Structure

```text
.
├── backups/           # Compressed SQL dumps (Rotation: 3)
├── data/              # PostgreSQL physical data files
├── init/              # Initialization SQL scripts (schema.sql)
├── scripts/           # Core management shell scripts
├── .env               # Configuration (Credentials & Network)
├── docker-compose.yml # Container orchestration config
└── setup.sh           # Project initializer