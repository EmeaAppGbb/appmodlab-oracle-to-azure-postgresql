# Step 3 — Azure Database for PostgreSQL Setup

> **Target:** Azure Database for PostgreSQL — Flexible Server (v16)  
> **SKU:** Standard_D2s_v3 (General Purpose, 2 vCores, 8 GB RAM)  
> **Region:** West Europe  
> **Database:** `skyreward`

---

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Local Development (Docker)](#3-local-development-docker)
4. [Azure Deployment](#4-azure-deployment)
5. [Required PostgreSQL Extensions](#5-required-postgresql-extensions)
6. [Post-Deployment Configuration](#6-post-deployment-configuration)
7. [Connecting to the Database](#7-connecting-to-the-database)
8. [Troubleshooting](#8-troubleshooting)

---

## 1. Overview

This step provisions the target PostgreSQL environment for the SkyReward Airlines
loyalty-program migration. Two environments are available:

| Environment | Purpose | Connection |
|---|---|---|
| **Docker (local)** | Development & testing | `localhost:5433` |
| **Azure Flexible Server** | Staging / production | `<server>.postgres.database.azure.com:5432` |

---

## 2. Prerequisites

- **Docker Desktop** (for local development)
- **Azure CLI** (`az`) ≥ 2.55 (for Azure deployment)
- An active Azure subscription with `Contributor` role on the target resource group

---

## 3. Local Development (Docker)

The `docker-compose.yml` at the repository root includes a PostgreSQL 16 container
alongside the existing Oracle XE container.

```bash
# Start both Oracle and PostgreSQL containers
docker compose up -d

# Verify PostgreSQL is healthy
docker compose ps postgresql

# Connect via psql
psql -h localhost -p 5433 -U skyreward_admin -d skyreward
```

| Setting | Value |
|---|---|
| Host | `localhost` |
| Port | `5433` (mapped from container 5432) |
| Database | `skyreward` |
| User | `skyreward_admin` |
| Password | `PostgresPass123` |

Any SQL scripts placed in `postgresql/` are automatically executed on first
container start via the Docker `initdb.d` mechanism.

---

## 4. Azure Deployment

### 4.1 Infrastructure-as-Code

All Azure resources are defined in `infra/main.bicep`:

| Resource | Purpose |
|---|---|
| PostgreSQL Flexible Server | Target database (v16, Standard_D2s_v3) |
| `skyreward` database | Application database |
| Firewall rules | Allow Azure services + developer client IP |
| Azure Database Migration Service | Orchestrate data migration |

### 4.2 Deploy

```bash
# Set the admin password (or you'll be prompted)
export PG_ADMIN_PASSWORD='<strong-password>'

# Optionally override resource group / location
export RESOURCE_GROUP='rg-skyreward-migration'
export LOCATION='westeurope'

# Run the deployment
chmod +x infra/deploy.sh
./infra/deploy.sh
```

The script will:
1. Detect your public IP for the firewall rule.
2. Create the resource group if it doesn't exist.
3. Deploy the Bicep template.
4. Print the connection string.

### 4.3 Parameter File

`infra/parameters.json` contains sensible defaults. For production, update the
`administratorPassword` reference to point to your Azure Key Vault:

```json
"administratorPassword": {
  "reference": {
    "keyVault": { "id": "/subscriptions/.../Microsoft.KeyVault/vaults/<vault>" },
    "secretName": "postgresql-admin-password"
  }
}
```

---

## 5. Required PostgreSQL Extensions

The following extensions are enabled on the Azure Flexible Server via the
`azure.extensions` server parameter and are needed for the SkyReward schema:

| Extension | Purpose | Oracle Equivalent |
|---|---|---|
| `uuid-ossp` | Generate UUIDs (`uuid_generate_v4()`) | `SYS_GUID()` |
| `pg_trgm` | Trigram-based full-text / fuzzy search | Oracle Text / `CONTAINS()` |
| `pg_cron` | Scheduled jobs inside PostgreSQL | `DBMS_SCHEDULER` |
| `pgmq` | Lightweight message queuing | Oracle Advanced Queuing (AQ) |

### Enabling Extensions Locally (Docker)

The Docker PostgreSQL image supports these extensions out of the box. Create them
in the `skyreward` database:

```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS pg_cron;    -- requires shared_preload_libraries
CREATE EXTENSION IF NOT EXISTS pgmq;
```

> **Note:** `pg_cron` must be loaded via `shared_preload_libraries`. For the Docker
> container you can add a custom `postgresql.conf` or pass
> `-c shared_preload_libraries=pg_cron` as a command argument.

---

## 6. Post-Deployment Configuration

After the Azure deployment completes:

1. **Enable extensions** — The Bicep template sets `azure.extensions` and
   `shared_preload_libraries` automatically. Verify in the Azure Portal under
   *Server parameters*.

2. **Create extensions in the database:**
   ```bash
   psql "host=<server>.postgres.database.azure.com port=5432 \
         dbname=skyreward user=skyreward_admin sslmode=require" \
     -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";" \
     -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;" \
     -c "CREATE EXTENSION IF NOT EXISTS pg_cron;" \
     -c "CREATE EXTENSION IF NOT EXISTS pgmq;"
   ```

3. **Run the schema migration** — See [Step 4](04-schema-migration.md) (upcoming).

---

## 7. Connecting to the Database

### Azure

```bash
psql "host=<server>.postgres.database.azure.com port=5432 \
      dbname=skyreward user=skyreward_admin sslmode=require"
```

### Local Docker

```bash
psql -h localhost -p 5433 -U skyreward_admin -d skyreward
# Password: PostgresPass123
```

### Connection String (ADO.NET / JDBC-style)

```
Host=<server>.postgres.database.azure.com;Port=5432;Database=skyreward;Username=skyreward_admin;Password=<password>;SslMode=Require;
```

---

## 8. Troubleshooting

| Issue | Resolution |
|---|---|
| `FATAL: password authentication failed` | Verify the password matches what was set during deployment. |
| Extension not available on Azure | Ensure `azure.extensions` includes the extension name (Portal → Server parameters). |
| Cannot connect from local machine | Check the firewall rule includes your current public IP. Re-run `deploy.sh` to auto-detect. |
| `pg_cron` functions fail | Confirm `shared_preload_libraries` includes `pg_cron` and the server was restarted. |
| Port 5433 already in use locally | Stop any existing PostgreSQL instance or change the port mapping in `docker-compose.yml`. |
