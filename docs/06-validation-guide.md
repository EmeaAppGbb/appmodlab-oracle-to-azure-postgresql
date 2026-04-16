# Validation Guide

This document covers the validation procedures for the SkyReward Airlines Oracle-to-PostgreSQL migration.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Validation Scripts](#validation-scripts)
4. [Running Validation](#running-validation)
5. [CI/CD Pipeline](#cicd-pipeline)
6. [Expected Results](#expected-results)
7. [Integration Tests](#integration-tests)
8. [Troubleshooting](#troubleshooting)

---

## Overview

The validation suite verifies that the migrated PostgreSQL database contains all expected schema objects and that the PL/pgSQL functions behave correctly. Validation is organized into five phases:

| Phase | Script | Purpose |
|-------|--------|---------|
| 1 | `postgresql/setup.sql` | Deploy all schema objects and seed data |
| 2 | `scripts/validate-schema.sql` | Verify all tables, sequences, indexes, views, functions, triggers exist |
| 3 | `scripts/validate-functions.sql` | Test each function with sample data and verify results |
| 4 | `tests/integration/test_*.sql` | End-to-end scenario tests |
| 5 | `scripts/validate-migration.sql` | Data integrity and row count validation |

## Prerequisites

- **PostgreSQL 16+** (matching the target deployment)
- **psql** client available in PATH
- Database created with user credentials (see `docker-compose.yml` for defaults):
  - Host: `localhost`, Port: `5433` (or `5432` in CI)
  - User: `skyreward_admin`, Password: `PostgresPass123`
  - Database: `skyreward`

### Quick Start with Docker

```bash
# Start PostgreSQL container
docker compose up -d postgresql

# Wait for readiness
docker compose exec postgresql pg_isready -U skyreward_admin -d skyreward

# Run full validation
./scripts/run-validation.sh
```

## Validation Scripts

### 1. Schema Validation (`scripts/validate-schema.sql`)

Checks that all expected database objects exist by querying PostgreSQL catalog tables:

| Object Type | Expected Count | Source |
|-------------|---------------|--------|
| Tables | 11 | `members`, `flights`, `rewards`, `redemptions`, `partners`, `partner_transactions`, `tier_rules`, `miles_expiry`, `audit_log`, `notifications`, `batch_processing_log` |
| Sequences | 11 | `seq_member_id`, `seq_flight_id`, etc. |
| Views | 13 | 2 business views + 11 synonym alias views |
| Materialized Views | 2 | `mvw_monthly_accruals`, `mvw_partner_summary` |
| Functions | 80+ | All PL/pgSQL functions including trigger functions and procedures |
| Triggers | 3 | `trg_flight_validation`, `trg_member_audit`, `trg_redemption_audit` |
| Indexes | 60+ | B-tree and GIN indexes (spot-checked) |
| FK Constraints | 2+ | Cross-table foreign keys from `04_constraints.sql` |

The script uses `RAISE EXCEPTION` on failure, so `psql -v ON_ERROR_STOP=1` will halt with a non-zero exit code.

### 2. Function Validation (`scripts/validate-functions.sql`)

Tests 20 functions with sample data:

- **Standalone functions**: `fn_calculate_miles`, `fn_tier_rank`, `fn_validate_redemption`, `fn_get_tier_status`
- **Validation utilities**: `validation_is_valid_email`, `validation_is_valid_airport_code`, etc.
- **Member management**: `member_mgmt_register_member`, `member_mgmt_get_member`, `member_mgmt_search_members`
- **Flight accrual**: `flight_accrual_cabin_multiplier`, `flight_accrual_calculate_base_miles`
- **Tier calculation**: `tier_calculation_get_tier_hierarchy`, `tier_calculation_evaluate_tier`
- **Redemption**: `redemption_mgmt_generate_confirmation_code`
- **Audit**: `audit_log_change`
- **Batch processing**: `batch_processing_start_batch`, `batch_processing_complete_batch`
- **Notification**: `notification_send_notification`
- **Reporting**: `reporting_get_tier_distribution`, `reporting_get_dashboard_kpis`

All tests run inside a single transaction that is **rolled back** at the end, leaving the database unchanged.

### 3. Run Validation (`scripts/run-validation.sh`)

Orchestrates all validation phases with pass/fail tracking:

```bash
# Default settings (docker-compose)
./scripts/run-validation.sh

# Custom connection
PGHOST=myhost PGPORT=5432 PGUSER=admin PGPASSWORD=secret PGDATABASE=skyreward \
  ./scripts/run-validation.sh

# Skip schema deployment (already deployed)
SKIP_SETUP=true ./scripts/run-validation.sh
```

Environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `PGHOST` | `localhost` | PostgreSQL host |
| `PGPORT` | `5433` | PostgreSQL port |
| `PGUSER` | `skyreward_admin` | Database user |
| `PGPASSWORD` | `PostgresPass123` | Database password |
| `PGDATABASE` | `skyreward` | Database name |
| `SKIP_SETUP` | `false` | Set to `true` to skip `setup.sql` deployment |

## CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/ci.yml`) runs automatically on:

- Push to `main` branch (when `postgresql/`, `scripts/`, or `tests/` files change)
- Pull requests targeting `main`
- Manual trigger via `workflow_dispatch`

### Pipeline Steps

1. **Start PostgreSQL 16** as a service container
2. **Deploy schema** using `postgresql/setup.sql`
3. **Validate schema objects** using `scripts/validate-schema.sql`
4. **Validate functions** using `scripts/validate-functions.sql`
5. **Run integration tests** from `tests/integration/test_*.sql`
6. **Run data migration validation** using `scripts/validate-migration.sql`

### Optional Extensions

The `pgmq` and `pg_cron` extensions are **not available** in the standard `postgres:16-alpine` image. The `setup.sql` script detects their absence and skips queue/scheduler setup gracefully. To test these features:

- Use a custom Docker image with `pgmq` and `pg_cron` pre-installed
- Or install them manually in your test environment

## Expected Results

### Successful Run

```
========================================
  VALIDATION SUMMARY
========================================
  ✅  PASS: Schema deployment (setup.sql)
  ✅  PASS: Schema object validation
  ✅  PASS: Function tests
  ✅  PASS: Integration: test_flight_accrual
  ✅  PASS: Integration: test_member_registration
  ✅  PASS: Integration: test_partner_transaction
  ✅  PASS: Integration: test_redemption_flow
  ✅  PASS: Integration: test_tier_upgrade
  ✅  PASS: Data migration validation

Passed: 9  |  Failed: 0  |  Total: 9
✅  ALL VALIDATIONS PASSED
```

### Tier Rules Reference

| Tier | Min Miles | Min Segments | Multiplier | Bonus % |
|------|-----------|-------------|------------|---------|
| BLUE | 0 | 0 | 1.0× | 0% |
| SILVER | 25,000 | 25 | 1.25× | 25% |
| GOLD | 50,000 | 50 | 1.5× | 50% |
| PLATINUM | 75,000 | 75 | 1.75× | 75% |
| DIAMOND | 100,000 | 100 | 2.0× | 100% |

## Integration Tests

Located in `tests/integration/`:

| Test File | Scenario |
|-----------|----------|
| `test_member_registration.sql` | Register → lookup → update profile → change status → audit trail |
| `test_flight_accrual.sql` | Calculate miles → record flight → verify balance |
| `test_tier_upgrade.sql` | Evaluate tier → check eligibility → recalculate |
| `test_redemption_flow.sql` | Validate → redeem → verify deduction → cancel → verify refund |
| `test_partner_transaction.sql` | Earn → redeem → settlement → summary |

All integration tests:
- Run inside a transaction with `ROLLBACK` to leave data unchanged
- Use `RAISE EXCEPTION` on assertion failures (compatible with `ON_ERROR_STOP`)
- Gracefully skip if prerequisite data is unavailable

## Troubleshooting

### Connection Errors

```
ERROR: Cannot connect to PostgreSQL
```

**Fix**: Verify PostgreSQL is running and connection settings are correct:
```bash
pg_isready -h localhost -p 5433 -U skyreward_admin -d skyreward
```

### Schema Deployment Failures

```
ERROR: relation "X" already exists
```

**Fix**: The database already has objects. Either:
- Drop and recreate the database: `DROP DATABASE skyreward; CREATE DATABASE skyreward;`
- Use `SKIP_SETUP=true` to skip deployment
- Add `DROP IF EXISTS` to the schema scripts (for development only)

### Missing Functions

```
❌ FAIL: FUNCTION: tier_calculation_get_qualifying_miles
```

**Fix**: Check that:
1. The function file exists in `postgresql/functions/`
2. It was included in `postgresql/setup.sql`
3. There are no syntax errors: `psql -f postgresql/functions/tier_calculation.sql`

### Function Test Failures

```
ERROR: relation "miles_transactions" does not exist
```

**Cause**: Some functions reference tables that may not exist in the current schema (e.g., `miles_transactions` vs the actual `flights` table). This indicates the function was not fully adapted from Oracle.

**Fix**: Update the function to use the correct table and column names from the PostgreSQL schema.

### Extension-Related Warnings

```
NOTICE: pgmq extension not available – skipping queue setup
NOTICE: pg_cron extension not available – skipping scheduler setup
```

**This is expected** when running on standard PostgreSQL without these extensions. Queue and scheduler features require:
- `pgmq` for reward fulfillment queue
- `pg_cron` for scheduled jobs (miles expiry, tier recalc, materialized view refresh)

### Integration Test Skips

```
SKIPPED: No member with sufficient miles found
```

**This is normal** if the seed data doesn't meet test prerequisites. Ensure data scripts ran:
```sql
SELECT COUNT(*) FROM members WHERE status = 'ACTIVE';
SELECT COUNT(*) FROM rewards WHERE status = 'ACTIVE';
SELECT COUNT(*) FROM partners WHERE status = 'ACTIVE';
```

### CI Pipeline Failures

1. Check the **Actions** tab in GitHub for detailed logs
2. Each step captures psql output – scroll to the failing step
3. Common causes:
   - Schema syntax errors in a recent commit
   - Function references to non-existent columns/tables
   - Test data assumptions not met
