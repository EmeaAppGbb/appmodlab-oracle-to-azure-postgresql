# Data Migration Guide

This document covers migrating data from Oracle to Azure Database for PostgreSQL
using Azure Database Migration Service (DMS) and the converted SQL data scripts.

## Table of Contents

- [Migration Approaches](#migration-approaches)
- [Approach 1: SQL Script Loading](#approach-1-sql-script-loading)
- [Approach 2: Azure DMS](#approach-2-azure-dms)
- [Column Mapping Reference](#column-mapping-reference)
- [Data Validation](#data-validation)
- [Common Issues and Solutions](#common-issues-and-solutions)
- [Rollback Procedures](#rollback-procedures)

---

## Migration Approaches

Two approaches are supported:

| Approach | Best For | Downtime |
|----------|----------|----------|
| SQL script loading | Dev/test environments, small datasets (<1M rows) | Minutes |
| Azure DMS | Production, large datasets, continuous sync | Minimal (cutover only) |

---

## Approach 1: SQL Script Loading

The converted data scripts in `postgresql/data/` load seed data directly into
PostgreSQL. This is the recommended approach for development and testing.

### Prerequisites

- PostgreSQL schema already created (`postgresql/setup.sql`)
- `psql` client installed and configured
- Database connection details

### Execution

```bash
# Full setup including schema + data
psql -h <server>.postgres.database.azure.com \
     -U <username> -d skyreward \
     -f postgresql/setup.sql
```

The setup script loads data files in dependency order:

1. `01_tier_rules.sql` — Tier qualification rules (5 rows)
2. `02_rewards.sql` — Rewards catalog (15 rows)
3. `03_members.sql` — Members and partners (100 members, 5 partners)
4. `04_flights.sql` — Flight accrual records (procedurally generated)
5. `05_redemptions.sql` — Redemption transactions (procedurally generated)
6. `06_partner_transactions.sql` — Partner earn/burn transactions

### Key Oracle-to-PostgreSQL Conversions

| Oracle | PostgreSQL | Notes |
|--------|------------|-------|
| `seq_name.NEXTVAL` | `nextval('seq_name')` | Sequence syntax |
| `SYSDATE` | `CURRENT_TIMESTAMP` | Current timestamp |
| `ADD_MONTHS(d, -n)` | `d - (n \|\| ' months')::interval` | Date arithmetic |
| `DBMS_RANDOM.VALUE(a,b)` | `random() * (b-a) + a` | Random numbers |
| `TRUNC(n)` | `floor(n)::int` | Truncate to integer |
| `DECODE(col, v1, r1, ...)` | `CASE col WHEN v1 THEN r1 ... END` | Conditional |
| `ROWNUM = 1` | `LIMIT 1` | Row limiting |
| `DBMS_OUTPUT.PUT_LINE` | `RAISE NOTICE` | Console output |
| PL/SQL `DECLARE/BEGIN/END` | `DO $$ DECLARE ... END $$` | Anonymous blocks |
| `VARRAY` | `TEXT[]` (PostgreSQL array) | Array types |
| `COMMIT` (inside PL/SQL) | Implicit (DO blocks auto-commit) | Transaction control |

---

## Approach 2: Azure DMS

For production migrations, use Azure Database Migration Service with the
configuration in `scripts/dms-config.json`.

### Prerequisites

- Azure subscription with DMS resource provisioned
- Oracle source database accessible from Azure (VPN/ExpressRoute)
- Azure Database for PostgreSQL Flexible Server provisioned
- PostgreSQL schema deployed (without data)

### Step 1: Provision DMS

```bash
# Create resource group
az group create \
  --name rg-skyreward-migration \
  --location eastus

# Create DMS instance
az dms create \
  --name skyreward-ora2pg-dms \
  --resource-group rg-skyreward-migration \
  --location eastus \
  --sku-name Premium_4vCores
```

### Step 2: Configure Source Connection

Set the Oracle source connection variables in `dms-config.json`:

| Variable | Description | Example |
|----------|-------------|---------|
| `ORACLE_HOST` | Oracle server hostname or IP | `oracle-prod.internal` |
| `ORACLE_SERVICE_NAME` | Oracle service/SID | `SKYREWARD` |
| `ORACLE_USER` | Oracle user with read access | `SKYREWARD_RO` |
| `ORACLE_PASSWORD` | Oracle user password | (use Key Vault) |

### Step 3: Configure Target Connection

| Variable | Description | Example |
|----------|-------------|---------|
| `PG_SERVER` | Azure PG server name | `skyreward-pg` |
| `PG_DATABASE` | Target database name | `skyreward` |
| `PG_USER` | PostgreSQL admin user | `pgadmin` |
| `PG_PASSWORD` | PostgreSQL password | (use Key Vault) |

### Step 4: Create Migration Project

```bash
az dms project create \
  --resource-group rg-skyreward-migration \
  --service-name skyreward-ora2pg-dms \
  --name skyreward-oracle-to-postgresql \
  --source-platform Oracle \
  --target-platform AzureDbForPostgreSql
```

### Step 5: Run Migration Task

```bash
az dms project task create \
  --resource-group rg-skyreward-migration \
  --service-name skyreward-ora2pg-dms \
  --project-name skyreward-oracle-to-postgresql \
  --name full-migration-task \
  --task-type MigrateOracleAzureDbPostgreSql \
  --source-connection-json @scripts/dms-config.json
```

### Step 6: Monitor Progress

```bash
az dms project task show \
  --resource-group rg-skyreward-migration \
  --service-name skyreward-ora2pg-dms \
  --project-name skyreward-oracle-to-postgresql \
  --name full-migration-task
```

---

## Column Mapping Reference

The Oracle and PostgreSQL schemas use different column names. Key mappings:

### members

| Oracle Column | PostgreSQL Column | Notes |
|---------------|-------------------|-------|
| `JOIN_DATE` | `enrollment_date` | Renamed |
| `STATE` | `state_province` | Renamed |
| `QUALIFYING_MILES` | `ytd_miles` | Renamed |
| `QUALIFYING_SEGMENTS` | *(dropped)* | Not in PG schema |
| *(generated)* | `membership_number` | `'SR' + LPAD(member_id, 8, '0')` |
| *(derived)* | `available_miles` | Derived from total_miles |

### flights

| Oracle Column | PostgreSQL Column | Notes |
|---------------|-------------------|-------|
| `ORIGIN` | `departure_airport` | Renamed |
| `DESTINATION` | `arrival_airport` | Renamed |
| `TRAVEL_DATE` | `flight_date` | Renamed |
| `MILES_EARNED` | `total_miles` | Renamed |
| `QUALIFYING_MILES_EARNED` | `tier_miles` | Renamed |
| `STATUS` | `accrual_status` | Renamed; `POSTED`→`PROCESSED` |
| `BOOKING_REF` | `pnr_locator` | Renamed |
| *(added)* | `airline_code` | Default `'SR'` |
| *(added)* | `cabin_class` | Derived from booking_class |
| *(calculated)* | `base_miles` | Calculated from distance × class factor |

### rewards

| Oracle Column | PostgreSQL Column | Notes |
|---------------|-------------------|-------|
| `NAME` | `reward_name` | Renamed |
| `AVAILABILITY` | `quantity_available` | Renamed |
| *(generated)* | `reward_code` | Generated unique code |
| `STATUS` | `status` | `AVAILABLE`→`ACTIVE`, `LIMITED`→`ACTIVE` |
| `CATEGORY` | `category` | `DONATION`→`EXPERIENCE`, `CAR`→`CAR_RENTAL` |

### partners

| Oracle Column | PostgreSQL Column | Notes |
|---------------|-------------------|-------|
| `EARN_RATE` | `conversion_rate` | Renamed |
| `CONTRACT_START` | `agreement_start` | Renamed |
| `PARTNER_TYPE` | `partner_type` | `CREDIT_CARD`→`FINANCIAL` |
| *(generated)* | `partner_code` | Generated short code |

### partner_transactions

| Oracle Column | PostgreSQL Column | Notes |
|---------------|-------------------|-------|
| `TXN_TYPE` | `transaction_type` | `BURN`→`REDEEM` |
| `MILES` | `miles_earned` / `miles_redeemed` | Split by txn type |
| `TRANSACTION_AMOUNT` | `amount` | Renamed |
| `REFERENCE_NUMBER` | `partner_ref` | Renamed |
| `POSTED_DATE` | `processed_date` | Renamed |

### redemptions

| Oracle Column | PostgreSQL Column | Notes |
|---------------|-------------------|-------|
| `MILES_REDEEMED` | `miles_used` | Renamed |
| `BOOKING_REF` | `confirmation_code` | Renamed |
| *(added)* | `redemption_channel` | Default `'WEB'` |

---

## Data Validation

After loading data, run the validation script:

```bash
psql -h <server>.postgres.database.azure.com \
     -U <username> -d skyreward \
     -f scripts/validate-migration.sql
```

The script checks:

1. **Row counts** — All tables populated; deterministic tables match expected counts
2. **Referential integrity** — No orphan foreign key references
3. **Constraint validation** — All CHECK constraints satisfied
4. **Key aggregates** — Total miles, member counts by tier, redemption totals
5. **Data quality** — No NULL required fields, no duplicate unique values

All checks should return `PASS`. Investigate any `FAIL` results before
proceeding to production cutover.

---

## Common Issues and Solutions

### 1. Sequence Values After Migration

**Problem:** After DMS migration, sequences may not reflect the maximum ID
values, causing duplicate key errors on new inserts.

**Solution:** The DMS post-actions in `dms-config.json` include `setval()`
calls to reset all sequences. For manual migrations:

```sql
SELECT setval('seq_member_id', (SELECT COALESCE(MAX(member_id), 1) FROM members));
SELECT setval('seq_flight_id', (SELECT COALESCE(MAX(flight_id), 1) FROM flights));
-- ... repeat for all sequences
```

### 2. Oracle DATE vs PostgreSQL TIMESTAMP

**Problem:** Oracle `DATE` includes time component; PostgreSQL `DATE` does not.

**Solution:** All Oracle `DATE` columns are mapped to PostgreSQL `TIMESTAMP`
to preserve time components. The data scripts use `CURRENT_TIMESTAMP` instead
of `SYSDATE`.

### 3. Category/Status Value Mapping

**Problem:** Some Oracle enum values don't match PostgreSQL CHECK constraints.

**Solution:** The data scripts apply these mappings:
- Reward status: `AVAILABLE` → `ACTIVE`, `LIMITED` → `ACTIVE`
- Reward category: `DONATION` → `EXPERIENCE`, `CAR` → `CAR_RENTAL`
- Partner type: `CREDIT_CARD` → `FINANCIAL`
- Flight status: `POSTED` → `PROCESSED`
- Transaction type: `BURN` → `REDEEM`

### 4. Random Data Reproducibility

**Problem:** Procedurally generated data (members, flights, etc.) differs
between runs due to `random()`.

**Solution:** For reproducible test data, set the PostgreSQL random seed
before running data scripts:

```sql
SELECT setseed(0.42);  -- Any fixed value between -1 and 1
```

### 5. Foreign Key Constraint Violations During Load

**Problem:** Loading child tables before parent tables causes FK violations.

**Solution:** Data scripts must be run in order (01→06). The DMS config
includes `preActions` to drop constraints and `postActions` to re-add them.

### 6. Character Encoding

**Problem:** Oracle uses AL32UTF8; PostgreSQL uses UTF-8.

**Solution:** Both are UTF-8 compatible. Verify the PostgreSQL database
was created with `ENCODING = 'UTF8'`:

```sql
SELECT pg_encoding_to_char(encoding) FROM pg_database WHERE datname = current_database();
```

---

## Rollback Procedures

### Script-based Migration Rollback

```sql
-- Truncate in reverse dependency order
TRUNCATE partner_transactions CASCADE;
TRUNCATE redemptions CASCADE;
TRUNCATE flights CASCADE;
TRUNCATE members CASCADE;
TRUNCATE partners CASCADE;
TRUNCATE rewards CASCADE;
TRUNCATE tier_rules CASCADE;

-- Reset sequences
SELECT setval('seq_member_id', 1000000, false);
SELECT setval('seq_flight_id', 1, false);
SELECT setval('seq_redemption_id', 5000000, false);
SELECT setval('seq_reward_id', 1, false);
SELECT setval('seq_partner_txn_id', 1, false);
SELECT setval('seq_tier_rule_id', 1, false);
SELECT setval('seq_partner_id', 1000, false);
```

### DMS Migration Rollback

1. Stop the DMS migration task
2. Drop and recreate the target database
3. Re-deploy schema using `postgresql/setup.sql`
4. Investigate and fix the issue
5. Restart the migration
