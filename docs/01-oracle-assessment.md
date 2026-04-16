# Oracle Database Assessment — SkyReward Airlines Loyalty Program

> **Application:** SkyReward Airlines Loyalty Program  
> **Source Database:** Oracle 19c  
> **Target Database:** Azure Database for PostgreSQL — Flexible Server  
> **Assessment Date:** 2026-04-16  
> **Schema Owner:** `SKYREWARD`

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Schema Inventory](#2-schema-inventory)
3. [Tables](#3-tables)
4. [Sequences](#4-sequences)
5. [Indexes](#5-indexes)
6. [Constraints](#6-constraints)
7. [Views](#7-views)
8. [Materialized Views](#8-materialized-views)
9. [PL/SQL Packages](#9-plsql-packages)
10. [Standalone Functions](#10-standalone-functions)
11. [Standalone Procedures](#11-standalone-procedures)
12. [Triggers](#12-triggers)
13. [Oracle Advanced Queuing (AQ)](#13-oracle-advanced-queuing-aq)
14. [DBMS_SCHEDULER Jobs](#14-dbms_scheduler-jobs)
15. [Synonyms](#15-synonyms)
16. [Oracle-Specific SQL & Built-in Functions](#16-oracle-specific-sql--built-in-functions)
17. [Data Type Mapping](#17-data-type-mapping)
18. [Migration Complexity Matrix](#18-migration-complexity-matrix)
19. [Risk Summary & Recommendations](#19-risk-summary--recommendations)

---

## 1. Executive Summary

The SkyReward Airlines loyalty program database contains **11 tables**, **10 sequences**, **10 PL/SQL packages** (spec + body), **3 standalone functions**, **3 standalone procedures**, **2 standard views**, **2 materialized views**, **3 triggers**, **1 Oracle AQ queue**, **3 DBMS_SCHEDULER jobs**, and **public/private synonyms**. The schema relies heavily on Oracle-specific features including PL/SQL packages, `BULK COLLECT`/`FORALL`, autonomous transactions (`PRAGMA AUTONOMOUS_TRANSACTION`), Oracle AQ (`DBMS_AQ`/`DBMS_AQADM`), `DBMS_SCHEDULER`, `DBMS_MVIEW`, bitmap indexes, Oracle Text indexes (`CTXSYS.CONTEXT`), `CONNECT BY` hierarchical queries, and `DBMS_RANDOM`/`DBMS_OUTPUT`.

**Overall estimated complexity: Medium-High.** Tables, sequences, views, and basic PL/SQL logic convert with straightforward effort. The primary challenges are: converting PL/SQL packages to PostgreSQL schemas of functions, replacing Oracle AQ with `pg_notify`/pgmq, converting `DBMS_SCHEDULER` jobs to `pg_cron`, and handling Oracle-specific SQL idioms (`DECODE`, `NVL`, `MONTHS_BETWEEN`, `SYSDATE`, `CONNECT BY`, `SYS_CONTEXT`).

---

## 2. Schema Inventory

| Object Type            | Count | Source Directory         |
|------------------------|------:|--------------------------|
| Tables                 |    11 | `oracle/schema/`         |
| Sequences              |    10 | `oracle/schema/`         |
| B-tree Indexes         |   ~45 | `oracle/schema/`         |
| Bitmap Indexes         |   ~18 | `oracle/schema/`         |
| Oracle Text Indexes    |     1 | `oracle/schema/`         |
| CHECK Constraints      |   ~25 | `oracle/schema/`         |
| Foreign Keys           |     6 | `oracle/schema/`         |
| Unique Constraints     |     3 | `oracle/schema/`         |
| PL/SQL Packages        |    10 | `oracle/packages/`       |
| Standalone Functions   |     3 | `oracle/functions/`      |
| Standalone Procedures  |     3 | `oracle/procedures/`     |
| Views                  |     2 | `oracle/views/`          |
| Materialized Views     |     2 | `oracle/views/`          |
| Triggers               |     3 | `oracle/triggers/`       |
| Oracle AQ Queues       |     1 | `oracle/queues/`         |
| DBMS_SCHEDULER Jobs    |     3 | `oracle/scheduler/`      |
| Public Synonyms        |    16 | `oracle/synonyms/`       |
| Private Synonyms       |    11 | `oracle/synonyms/`       |
| Custom Object Types    |     1 | `oracle/queues/`         |

---

## 3. Tables

### 3.1 Table Inventory

| # | Table Name              | Columns | CLOB Cols | Key Oracle Features                             |
|---|-------------------------|--------:|----------:|--------------------------------------------------|
| 1 | `members`               |      26 |         1 | `SYSDATE` defaults, `USER` default, `NUMBER(10)` |
| 2 | `flights`               |      22 |         0 | FK → members, `NUMBER(10,2)`                      |
| 3 | `rewards`               |      16 |         2 | Oracle Text index on `description` CLOB           |
| 4 | `redemptions`           |      14 |         1 | FKs → members, rewards                            |
| 5 | `partners`              |      14 |         1 | `NUMBER(5,2)` conversion rate                     |
| 6 | `partner_transactions`  |      16 |         0 | FKs → members, partners                           |
| 7 | `tier_rules`            |      14 |         0 | Tier qualification business rules                 |
| 8 | `miles_expiry`          |      12 |         0 | FK → members, batch processing linkage            |
| 9 | `audit_log`             |      11 |         2 | `USER` default, `SYS_CONTEXT` session ID          |
| 10| `notifications`         |      14 |         1 | Priority queue semantics                          |
| 11| `batch_processing_log`  |      12 |         2 | `USER` default, batch job orchestration           |

### 3.2 Oracle-Specific Column Defaults

| Oracle Default        | Affected Tables                                        | PostgreSQL Equivalent           |
|-----------------------|--------------------------------------------------------|---------------------------------|
| `DEFAULT SYSDATE`     | members, flights, rewards, redemptions, partners, partner_transactions, tier_rules, miles_expiry, audit_log, notifications, batch_processing_log | `DEFAULT CURRENT_TIMESTAMP` or `DEFAULT now()` |
| `DEFAULT USER`        | members, audit_log, batch_processing_log               | `DEFAULT current_user`          |

### 3.3 CLOB Columns

| Table                 | Column(s)                        | PostgreSQL Equivalent |
|-----------------------|----------------------------------|-----------------------|
| `members`             | `notes`                          | `TEXT`                |
| `rewards`             | `description`, `terms_conditions`| `TEXT`                |
| `redemptions`         | `notes`                          | `TEXT`                |
| `partners`            | `notes`                          | `TEXT`                |
| `audit_log`           | `old_values`, `new_values`       | `JSONB` (recommended) |
| `notifications`       | `body`                           | `TEXT`                |
| `batch_processing_log`| `error_message`, `parameters`    | `TEXT` / `JSONB`      |

---

## 4. Sequences

| # | Sequence Name         | START WITH | CACHE   | Oracle Feature          | PostgreSQL Equivalent                          |
|---|-----------------------|------------|---------|-------------------------|------------------------------------------------|
| 1 | `seq_member_id`       | 1000000    | NOCACHE | `NOCYCLE`               | `CREATE SEQUENCE ... START WITH 1000000`       |
| 2 | `seq_flight_id`       | 1          | 100     | `CACHE 100`             | `CREATE SEQUENCE ... CACHE 100`                |
| 3 | `seq_redemption_id`   | 5000000    | 50      | `CACHE 50`              | `CREATE SEQUENCE ... CACHE 50 START WITH 5000000` |
| 4 | `seq_reward_id`       | 1          | NOCACHE | `NOCYCLE`               | `CREATE SEQUENCE ...`                          |
| 5 | `seq_partner_txn_id`  | 1          | 100     | `CACHE 100`             | `CREATE SEQUENCE ... CACHE 100`                |
| 6 | `seq_tier_rule_id`    | 1          | NOCACHE | `NOCYCLE`               | `CREATE SEQUENCE ...`                          |
| 7 | `seq_audit_id`        | 1          | 200     | `CACHE 200`             | `CREATE SEQUENCE ... CACHE 200`                |
| 8 | `seq_notification_id` | 1          | 100     | `CACHE 100`             | `CREATE SEQUENCE ... CACHE 100`                |
| 9 | `seq_partner_id`      | 1000       | NOCACHE | `NOCYCLE`               | `CREATE SEQUENCE ... START WITH 1000`          |
| 10| `seq_expiry_batch_id` | 1          | NOCACHE | `NOCYCLE`               | `CREATE SEQUENCE ...`                          |

**Migration notes:**
- Oracle `NOCACHE` → PostgreSQL default (no caching; optionally add `CACHE 1`).
- `NOCYCLE` is default in PostgreSQL, so no change needed.
- `sequence.NEXTVAL` → `nextval('sequence')`.
- `sequence.CURRVAL` → `currval('sequence')`.

---

## 5. Indexes

### 5.1 B-tree Indexes (~45)

Standard B-tree indexes migrate directly to PostgreSQL `CREATE INDEX`. No changes required.

### 5.2 Bitmap Indexes (~18)

| Table                   | Bitmap Index Columns                     |
|-------------------------|------------------------------------------|
| `members`               | `tier_status`, `status`, `gender`, `country` |
| `flights`               | `cabin_class`, `accrual_status`, `status` |
| `redemptions`           | `status`, `redemption_channel`           |
| `rewards`               | `category`, `status`, `min_tier_required`|
| `partner_transactions`  | `transaction_type`, `status`             |
| `miles_expiry`          | `source_type`, `status`                  |
| `notifications`         | `notification_type`, `channel`, `status` |

**Oracle → PostgreSQL:**

| Oracle Construct          | PostgreSQL Equivalent                                             |
|---------------------------|-------------------------------------------------------------------|
| `CREATE BITMAP INDEX ...` | No direct equivalent. Use standard B-tree indexes on low-cardinality columns, or partial indexes. For analytic workloads, consider BRIN indexes. |

### 5.3 Oracle Text Index (1)

| Table    | Column        | Oracle Syntax                                       |
|----------|---------------|-----------------------------------------------------|
| `rewards`| `description` | `INDEXTYPE IS CTXSYS.CONTEXT PARAMETERS ('SYNC (ON COMMIT)')` |

**Oracle → PostgreSQL:**

| Oracle Construct               | PostgreSQL Equivalent                                    |
|--------------------------------|----------------------------------------------------------|
| `CTXSYS.CONTEXT` (Oracle Text) | `GIN` index on `to_tsvector()` column; use `tsvector` / `tsquery` for full-text search. Consider adding a generated `tsvector` column. |

---

## 6. Constraints

All `PRIMARY KEY`, `UNIQUE`, `FOREIGN KEY`, and `CHECK` constraints migrate directly. Oracle constraint syntax is compatible with PostgreSQL.

**Notable CHECK constraints use `IN (...)` lists** — these are fully supported in PostgreSQL.

| Oracle Feature                      | PostgreSQL Equivalent |
|-------------------------------------|-----------------------|
| `CONSTRAINT pk_xxx PRIMARY KEY (...)` | Same syntax           |
| `CONSTRAINT uk_xxx UNIQUE (...)`      | Same syntax           |
| `CONSTRAINT fk_xxx FOREIGN KEY (...)` | Same syntax           |
| `CONSTRAINT chk_xxx CHECK (...)`      | Same syntax           |
| `COMMENT ON TABLE / COLUMN`           | Same syntax           |

---

## 7. Views

### 7.1 `vw_member_summary`

**Purpose:** Comprehensive member view with aggregated flight/redemption stats and tier ranking.

| Oracle-Specific Construct         | Usage in View                                         | PostgreSQL Equivalent                        |
|-----------------------------------|-------------------------------------------------------|----------------------------------------------|
| `MONTHS_BETWEEN(SYSDATE, date)`  | Membership duration in months                         | `EXTRACT(YEAR FROM age(...)) * 12 + EXTRACT(MONTH FROM age(...))` or `DATE_PART('year', age(now(), date)) * 12 + DATE_PART('month', age(now(), date))` |
| `SYSDATE`                         | Current date/time                                     | `CURRENT_TIMESTAMP` or `now()`               |
| `NVL(expr, default)`              | Null-safe defaults for aggregates                     | `COALESCE(expr, default)`                    |
| `DECODE(col, val1, res1, ...)`    | Tier → star display mapping                           | `CASE col WHEN val1 THEN res1 ... END`       |
| `TRUNC(date - SYSDATE)`           | Days until tier expiry                                | `(date::date - CURRENT_DATE)` or `DATE_PART('day', date - now())` |
| `TRUNC(SYSDATE, 'YYYY')`          | First day of current year                             | `DATE_TRUNC('year', CURRENT_DATE)`           |
| `RANK() OVER (...)`               | Analytic ranking                                      | Same syntax (fully supported)                |
| `\|\|` (string concat)            | Name concatenation                                    | Same syntax (fully supported)                |

### 7.2 `vw_tier_status_report`

**Purpose:** Tier distribution and analytics for management reporting.

| Oracle-Specific Construct          | PostgreSQL Equivalent                                 |
|------------------------------------|-------------------------------------------------------|
| `DECODE(tier, v1, r1, v2, r2, ...)` | `CASE tier WHEN v1 THEN r1 WHEN v2 THEN r2 ... END`  |
| `NVL(expr, 0)`                      | `COALESCE(expr, 0)`                                   |
| `NULLIF(SUM(...) OVER (), 0)`       | Same syntax (supported)                                |
| `TRUNC(SYSDATE, 'YYYY')`            | `DATE_TRUNC('year', CURRENT_DATE)`                     |

---

## 8. Materialized Views

### 8.1 `mvw_monthly_accruals`

| Attribute         | Oracle Value                | PostgreSQL Equivalent                                  |
|-------------------|-----------------------------|--------------------------------------------------------|
| Build             | `BUILD IMMEDIATE`           | Automatic on creation (default)                        |
| Refresh           | `REFRESH FAST ON DEMAND`    | `CREATE MATERIALIZED VIEW ... AS ...` + manual `REFRESH MATERIALIZED VIEW` via `pg_cron` |
| Query Rewrite     | `ENABLE QUERY REWRITE`      | Not supported natively. Application must query the MV directly. |
| `TO_CHAR(date, 'YYYY-MM')` | Date formatting    | `TO_CHAR(date, 'YYYY-MM')` (same syntax supported)    |
| `TO_NUMBER(TO_CHAR(...))` | Extract year/month as number | `EXTRACT(YEAR FROM date)`, `EXTRACT(MONTH FROM date)` |

### 8.2 `mvw_partner_summary`

| Attribute         | Oracle Value                  | PostgreSQL Equivalent                                  |
|-------------------|-------------------------------|--------------------------------------------------------|
| Refresh           | `REFRESH COMPLETE ON DEMAND`  | `REFRESH MATERIALIZED VIEW` (complete refresh only)    |
| Query Rewrite     | `ENABLE QUERY REWRITE`        | Not supported. Application queries MV directly.         |

**Key differences:**
- PostgreSQL does not support **incremental/fast refresh** of materialized views. All refreshes are complete.
- PostgreSQL supports `REFRESH MATERIALIZED VIEW CONCURRENTLY` (requires a unique index) for non-blocking reads during refresh.
- Query rewrite (automatic optimizer redirection) is **not available** in PostgreSQL.

---

## 9. PL/SQL Packages

Oracle PL/SQL packages have **no direct equivalent** in PostgreSQL. Each package must be decomposed into individual functions/procedures, optionally organized under a PostgreSQL **schema** namespace.

### 9.1 Package Inventory

| # | Package Name              | Procedures | Functions | Key Oracle Features Used                                           |
|---|---------------------------|------------|-----------|---------------------------------------------------------------------|
| 1 | `pkg_member_mgmt`         | 5          | 3         | `%TYPE`, `%ROWTYPE`, custom RECORD types, `TABLE OF ... INDEX BY PLS_INTEGER`, `RAISE_APPLICATION_ERROR`, `INITCAP`, `SEQ.NEXTVAL/CURRVAL`, `FOR ... LOOP`, `SQL%ROWCOUNT`, `COMMIT/ROLLBACK` |
| 2 | `pkg_flight_accrual`      | 4          | 2         | `%TYPE`, RECORD types, collection types, `BULK COLLECT`, `FORALL`, `SEQ.NEXTVAL`, `FETCH FIRST N ROWS ONLY` |
| 3 | `pkg_tier_calculation`    | 3          | 5         | RECORD types, `TABLE OF ... INDEX BY`, `CONNECT BY`/`START WITH` hierarchical query, `ADD_MONTHS`, `BOOLEAN` return |
| 4 | `pkg_redemption_mgmt`     | 3          | 3         | `DBMS_RANDOM.VALUE`, `BOOLEAN` return, `SEQ.NEXTVAL`, `ADD_MONTHS`, `NVL` |
| 5 | `pkg_partner_integration` | 4          | 2         | `SYS_REFCURSOR` return, cross-package calls, `NVL`                  |
| 6 | `pkg_reporting`           | 1          | 6         | `SYS_REFCURSOR`, `UNION ALL` KPIs, `%ROWTYPE`, `CLOB` building, `CHR(10)`, `RPAD`/`LPAD`, `FETCH FIRST N ROWS ONLY`, `DECODE` |
| 7 | `pkg_batch_processing`    | 5          | 3         | `BULK COLLECT`, `FORALL`, `SYS_REFCURSOR`, `DBMS_OUTPUT`, `ADD_MONTHS`, `LAST_DAY`, cross-package calls |
| 8 | `pkg_validation`          | 3          | 6         | `REGEXP_LIKE`, `BOOLEAN` return, `RAISE_APPLICATION_ERROR`, `LENGTH` |
| 9 | `pkg_audit`               | 2          | 3         | **`PRAGMA AUTONOMOUS_TRANSACTION`**, `SYS_CONTEXT('USERENV','SESSIONID')`, `SEQ.NEXTVAL`, `SYS_REFCURSOR` |
| 10| `pkg_notification`        | 4          | 2         | `BULK COLLECT`, `FORALL`, `SYS_REFCURSOR`, `FETCH FIRST N ROWS ONLY` |

### 9.2 Migration Strategy per Package

| Oracle Package → | PostgreSQL Target                    | Complexity |
|------------------|--------------------------------------|------------|
| `pkg_member_mgmt`         | Schema `member_mgmt` with individual functions | Medium     |
| `pkg_flight_accrual`      | Schema `flight_accrual` with functions          | Medium     |
| `pkg_tier_calculation`    | Schema `tier_calculation` with functions         | Medium-High (CONNECT BY) |
| `pkg_redemption_mgmt`     | Schema `redemption_mgmt` with functions          | Medium     |
| `pkg_partner_integration` | Schema `partner_integration` with functions      | Medium     |
| `pkg_reporting`           | Schema `reporting` with functions                | Low-Medium |
| `pkg_batch_processing`    | Schema `batch_processing` with functions         | Medium     |
| `pkg_validation`          | Schema `validation` with functions               | Low        |
| `pkg_audit`               | Schema `audit` with functions                    | **High** (autonomous txn) |
| `pkg_notification`        | Schema `notification` with functions             | Medium     |

### 9.3 Oracle PL/SQL → PostgreSQL PL/pgSQL Construct Mapping

| Oracle PL/SQL Construct                        | PostgreSQL PL/pgSQL Equivalent                                   |
|------------------------------------------------|------------------------------------------------------------------|
| `CREATE OR REPLACE PACKAGE ... AS`             | Use a **schema** for namespace; create individual `FUNCTION`/`PROCEDURE` |
| `PACKAGE BODY`                                 | Individual function/procedure bodies                              |
| Package constants (`c_xxx CONSTANT ...`)       | Use a config table, `SET` variables, or inline constants          |
| `TYPE t_rec IS RECORD (...)`                   | `CREATE TYPE t_rec AS (...)` or use anonymous record              |
| `TYPE t_tab IS TABLE OF ... INDEX BY PLS_INTEGER` | Use arrays (`type[]`), `SETOF`, or temp tables               |
| `%TYPE`                                        | Direct column type reference or explicit type                     |
| `%ROWTYPE`                                     | Table name as type (e.g., `members%ROWTYPE` → `members`)          |
| `RAISE_APPLICATION_ERROR(-20xxx, msg)`         | `RAISE EXCEPTION 'msg' USING ERRCODE = 'P0001'`                  |
| `PRAGMA AUTONOMOUS_TRANSACTION`                | **No direct equivalent.** Use `dblink` loopback, separate connection via `pg_background`, or application-level handling |
| `DBMS_OUTPUT.PUT_LINE(...)`                    | `RAISE NOTICE '%', ...`                                          |
| `BULK COLLECT INTO`                            | `SELECT ... INTO` array variables, or use `SETOF` / cursors      |
| `FORALL i IN ... SAVE EXCEPTIONS`             | Standard `FOR` loop or batch `UPDATE ... WHERE id = ANY(array)`. No `SAVE EXCEPTIONS` equivalent — use `BEGIN ... EXCEPTION` blocks |
| `SQL%ROWCOUNT`                                 | `GET DIAGNOSTICS row_count = ROW_COUNT`                          |
| `SQL%BULK_EXCEPTIONS`                          | No direct equivalent; use exception handling per statement        |
| `SYS_REFCURSOR`                                | `REFCURSOR` or `RETURNS TABLE(...)` / `RETURNS SETOF`            |
| `FOR rec IN (SELECT ...) LOOP`                 | Same syntax supported in PL/pgSQL                                 |
| `COMMIT` / `ROLLBACK` inside procedure         | Remove — PostgreSQL procedures use caller's transaction. For autonomous behavior, use `dblink` or separate session |
| `EXCEPTION WHEN NO_DATA_FOUND`                 | `EXCEPTION WHEN NO_DATA_FOUND` (same)                             |
| `EXCEPTION WHEN OTHERS`                        | `EXCEPTION WHEN OTHERS` (same)                                    |
| `SQLERRM`                                      | `SQLERRM` (same)                                                  |
| `SQLCODE`                                       | `SQLSTATE`                                                        |
| `BOOLEAN` return from function                  | Supported in PL/pgSQL (but not in pure SQL until PG16)            |
| `FETCH FIRST N ROWS ONLY`                      | `LIMIT N` or `FETCH FIRST N ROWS ONLY` (SQL:2008 syntax, supported) |
| `DBMS_RANDOM.VALUE(low, high)`                 | `random() * (high - low) + low` or `floor(random() * (high - low + 1) + low)` |
| `PRAGMA EXCEPTION_INIT(name, -code)`           | No equivalent; use named error conditions                         |

---

## 10. Standalone Functions

### 10.1 `fn_calculate_miles` (DETERMINISTIC)

| Attribute          | Oracle                                  | PostgreSQL Equivalent                           |
|--------------------|-----------------------------------------|-------------------------------------------------|
| Signature          | `FUNCTION fn_calculate_miles(...) RETURN NUMBER DETERMINISTIC` | `CREATE FUNCTION fn_calculate_miles(...) RETURNS NUMERIC IMMUTABLE` |
| `DETERMINISTIC`    | Hint for optimizer caching              | `IMMUTABLE` (or `STABLE` if reads DB)           |
| `CASE ... END`     | Used for multiplier logic               | Same syntax                                      |
| `GREATEST(...)`    | Minimum miles floor                     | Same syntax                                      |
| `ROUND(...)`       | Rounding                                | Same syntax                                      |

**Complexity: Low** — Pure computation, no DB access.

### 10.2 `fn_get_tier_status`

| Attribute          | Oracle                                  | PostgreSQL Equivalent                           |
|--------------------|-----------------------------------------|-------------------------------------------------|
| Signature          | `FUNCTION ... RETURN VARCHAR2`          | `RETURNS TEXT`                                   |
| `ADD_MONTHS(TRUNC(SYSDATE), -12)` | Rolling 12-month window   | `CURRENT_DATE - INTERVAL '12 months'`           |
| `NVL(expiry_date, SYSDATE + 1)` | NULL handling              | `COALESCE(expiry_date, CURRENT_DATE + 1)`       |
| `TO_CHAR(num, '999,999')`       | Number formatting          | `TO_CHAR(num, '999,999')` (same)                |
| Cursor FOR loop                  | Tier iteration             | Same syntax in PL/pgSQL                          |

**Complexity: Low**

### 10.3 `fn_validate_redemption`

| Attribute             | Oracle                                  | PostgreSQL Equivalent                       |
|-----------------------|-----------------------------------------|---------------------------------------------|
| Nested function       | `FUNCTION tier_rank(...) RETURN NUMBER IS` (nested inside outer function) | Declare as separate helper function, or inline `CASE` |
| `NVL(...)`            | NULL defaults                           | `COALESCE(...)`                              |
| `SYSDATE NOT BETWEEN` | Date range check                       | `CURRENT_DATE NOT BETWEEN ...`               |

**Complexity: Low-Medium** — Nested function must be extracted or inlined.

---

## 11. Standalone Procedures

### 11.1 `pr_expire_miles`

| Oracle Feature                         | PostgreSQL Equivalent                                |
|----------------------------------------|------------------------------------------------------|
| `OUT` parameters                       | `OUT` parameters or `RETURNS RECORD`                 |
| `TYPE ... IS RECORD` / `TABLE OF ... INDEX BY PLS_INTEGER` | Composite type + array, or temp table |
| `COMMIT` inside loop (every 1000 rows) | Remove mid-procedure `COMMIT` — use `CALL` from application with `COMMIT` between batches, or restructure as batch function |
| `DBMS_OUTPUT.PUT_LINE`                 | `RAISE NOTICE`                                        |
| `MOD(count, 1000)`                     | `MOD(count, 1000)` (same) or `count % 1000`          |
| Cross-package call: `pkg_batch_processing.start_batch(...)` | `batch_processing.start_batch(...)` |
| Cross-package call: `pkg_notification.send_notification(...)` | `notification.send_notification(...)` |

**Complexity: Medium-High** — Mid-transaction `COMMIT` is not supported inside PostgreSQL functions; must restructure as a `PROCEDURE` (PG11+) or batch from the application.

### 11.2 `pr_recalculate_tiers`

| Oracle Feature                         | PostgreSQL Equivalent                                |
|----------------------------------------|------------------------------------------------------|
| Nested `FUNCTION tier_rank()`          | Separate helper function or inline `CASE`            |
| `OUT` parameters (5)                   | `OUT` parameters or `RETURNS RECORD`                 |
| `COMMIT` inside loop                   | Must restructure — use PostgreSQL `PROCEDURE` with `COMMIT` (PG11+) |
| `ADD_MONTHS(SYSDATE, 12)`             | `CURRENT_DATE + INTERVAL '12 months'`                |
| `TO_CHAR(miles, '999,999')`           | Same syntax                                           |
| `NVL(expiry_date, SYSDATE + 1)`       | `COALESCE(...)`                                      |

**Complexity: Medium-High**

### 11.3 `pr_process_bulk_accrual`

| Oracle Feature                         | PostgreSQL Equivalent                                |
|----------------------------------------|------------------------------------------------------|
| `BULK COLLECT INTO` (5 parallel arrays)| `SELECT ... INTO` array vars, or use temp table / `SETOF` |
| `FORALL i IN ... SAVE EXCEPTIONS`     | `UPDATE ... WHERE id = ANY(array)` for bulk ops; individual `FOR` loop for row-level logic |
| `PRAGMA EXCEPTION_INIT(name, -24381)` | No equivalent; handle DML errors in loop              |
| `SQL%BULK_EXCEPTIONS`                  | No equivalent                                         |
| `FETCH FIRST p_batch_size ROWS ONLY`  | `LIMIT p_batch_size` or `FETCH FIRST ... ROWS ONLY`  |
| `ADD_MONTHS(date, 36)`                | `date + INTERVAL '36 months'`                         |
| `GREATEST(NVL(last_activity, date), date)` | `GREATEST(COALESCE(last_activity, date), date)` |
| `DBMS_OUTPUT.PUT_LINE`                | `RAISE NOTICE`                                        |

**Complexity: High** — `BULK COLLECT`/`FORALL`/`SAVE EXCEPTIONS` pattern has no single PostgreSQL equivalent; requires restructuring.

---

## 12. Triggers

### 12.1 Trigger Inventory

| # | Trigger Name            | Table        | Timing           | Events                     | Key Oracle Features |
|---|-------------------------|--------------|------------------|----------------------------|---------------------|
| 1 | `trg_member_audit`      | `members`    | `AFTER`          | `INSERT OR UPDATE OR DELETE`| `:OLD`/`:NEW`, `INSERTING`/`UPDATING`/`DELETING`, calls `pkg_audit.log_change` (autonomous txn) |
| 2 | `trg_flight_validation` | `flights`    | `BEFORE`         | `INSERT OR UPDATE`         | `:NEW` mutation, `RAISE_APPLICATION_ERROR`, `SELECT INTO` from other table, `COUNT(*)` duplicate check |
| 3 | `trg_redemption_audit`  | `redemptions`| `AFTER`          | `INSERT OR UPDATE`         | `:OLD`/`:NEW`, `INSERTING`/`UPDATING`, `NVL`, `TO_CHAR`, calls `pkg_audit.log_change` |

### 12.2 Oracle → PostgreSQL Trigger Mapping

| Oracle Construct                        | PostgreSQL Equivalent                                         |
|-----------------------------------------|---------------------------------------------------------------|
| `CREATE OR REPLACE TRIGGER ... FOR EACH ROW` | `CREATE FUNCTION trg_fn() RETURNS TRIGGER` + `CREATE TRIGGER ... FOR EACH ROW EXECUTE FUNCTION trg_fn()` |
| `DECLARE ... BEGIN ... END`             | Function body in `$$DECLARE ... BEGIN ... END$$`              |
| `:OLD.column` / `:NEW.column`           | `OLD.column` / `NEW.column`                                   |
| `INSERTING` / `UPDATING` / `DELETING`   | `TG_OP = 'INSERT'` / `TG_OP = 'UPDATE'` / `TG_OP = 'DELETE'` |
| `RAISE_APPLICATION_ERROR(-20xxx, msg)`  | `RAISE EXCEPTION '%', msg`                                    |
| Mutating `:NEW.column := value` (BEFORE)| `NEW.column := value; RETURN NEW;`                            |
| `RETURN;` (implicit in AFTER triggers)  | `RETURN NULL;` (for AFTER triggers) or `RETURN NEW;` (BEFORE) |
| Autonomous transaction call from trigger | **Challenge**: `pkg_audit.log_change` uses `PRAGMA AUTONOMOUS_TRANSACTION`. In PostgreSQL, use `dblink` for autonomous audit logging, or log asynchronously via `pg_notify`. |

**Complexity: Medium** — Trigger syntax differences are mechanical. The `PRAGMA AUTONOMOUS_TRANSACTION` in the audit package (called from triggers) requires special handling.

---

## 13. Oracle Advanced Queuing (AQ)

### 13.1 Queue Components

| Component               | Oracle Implementation                                | PostgreSQL Equivalent                                 |
|-------------------------|------------------------------------------------------|-------------------------------------------------------|
| Queue payload type      | `CREATE TYPE reward_fulfillment_msg_t AS OBJECT (...)` | `CREATE TYPE reward_fulfillment_msg_t AS (...)` (composite type) or use JSONB payload |
| Queue table             | `DBMS_AQADM.CREATE_QUEUE_TABLE(...)`                 | Table-based queue (e.g., `pgmq` extension), or use `pg_notify` + table |
| Queue                   | `DBMS_AQADM.CREATE_QUEUE(...)`                       | `pgmq.create('reward_fulfillment')` or custom table    |
| Start queue             | `DBMS_AQADM.START_QUEUE(...)`                        | No equivalent needed (queue is always active)           |
| Enqueue                 | `DBMS_AQ.ENQUEUE(...)`                               | `INSERT INTO queue_table` or `pgmq.send(...)`          |
| Dequeue                 | `DBMS_AQ.DEQUEUE(...)`                               | `SELECT ... FOR UPDATE SKIP LOCKED` + `DELETE`, or `pgmq.read(...)` |
| Priority + ENQ_TIME sort| `sort_list => 'PRIORITY,ENQ_TIME'`                   | `ORDER BY priority, enqueued_at` in SELECT              |
| Retry/expiration        | `max_retries => 5, retry_delay => 300`               | Application-level retry logic or pgmq configuration     |
| `DBMS_AQ.NO_WAIT`       | Non-blocking dequeue                                 | `NOWAIT` clause or `pgmq.read(..., timeout => 0)`       |
| `SQLCODE = -25228`       | No messages available                                | Empty result set from `SELECT`                           |

### 13.2 Enqueue/Dequeue Procedures

- `enqueue_fulfillment` — Gathers data via JOINs, builds message, calls `DBMS_AQ.ENQUEUE`. Convert to `INSERT INTO` queue table.
- `dequeue_and_fulfill` — Loop with `DBMS_AQ.DEQUEUE`, processes each message, updates `redemptions`. Convert to `SELECT FOR UPDATE SKIP LOCKED` pattern.

**Complexity: High** — Oracle AQ is a full messaging subsystem. PostgreSQL alternatives (`pgmq`, `LISTEN/NOTIFY` + table, or external broker like Azure Service Bus) require architectural decisions.

**Recommended approach:** Use the [`pgmq`](https://github.com/tembo-io/pgmq) extension on Azure PostgreSQL Flexible Server, or implement a lightweight queue table with `SELECT ... FOR UPDATE SKIP LOCKED`.

---

## 14. DBMS_SCHEDULER Jobs

### 14.1 Job Inventory

| # | Job Name               | Schedule                            | Action               | Max Duration | PostgreSQL Equivalent |
|---|------------------------|--------------------------------------|-----------------------|-------------|-----------------------|
| 1 | `JOB_EXPIRE_MILES`     | Daily at 02:00                       | Calls `pr_expire_miles` | 2 hours   | `pg_cron` job         |
| 2 | `JOB_TIER_RECALC`      | Daily at 03:00                       | Calls `pr_recalculate_tiers` | 4 hours | `pg_cron` job     |
| 3 | `JOB_MVW_REFRESH`      | Daily at 04:00                       | Calls `DBMS_MVIEW.REFRESH` for both MVs | 1 hour | `pg_cron` job  |

### 14.2 DBMS_SCHEDULER → pg_cron Mapping

| Oracle DBMS_SCHEDULER Feature          | PostgreSQL (`pg_cron`) Equivalent                                |
|----------------------------------------|------------------------------------------------------------------|
| `CREATE_JOB(job_type => 'PLSQL_BLOCK', job_action => '...')` | `cron.schedule('job_name', 'cron_expr', 'SQL command')` |
| `repeat_interval => 'FREQ=DAILY;BYHOUR=2;...'` | `'0 2 * * *'` (cron syntax)                         |
| `max_failures => 3`                    | No built-in equivalent; implement in wrapper function            |
| `max_run_duration => INTERVAL '2' HOUR`| No built-in equivalent; implement timeout in function            |
| `logging_level => LOGGING_FULL`        | Log to `batch_processing_log` table from function                |
| `DBMS_MVIEW.REFRESH(...)`              | `REFRESH MATERIALIZED VIEW CONCURRENTLY mvw_name`               |
| `SET_ATTRIBUTE` for job config          | Job parameters stored in `cron.job` table                       |

**Example pg_cron conversions:**

```sql
-- JOB_EXPIRE_MILES: Daily at 2 AM
SELECT cron.schedule('job_expire_miles', '0 2 * * *', 'CALL pr_expire_miles()');

-- JOB_TIER_RECALC: Daily at 3 AM
SELECT cron.schedule('job_tier_recalc', '0 3 * * *', 'CALL pr_recalculate_tiers()');

-- JOB_MVW_REFRESH: Daily at 4 AM
SELECT cron.schedule('job_mvw_refresh', '0 4 * * *', $$
  REFRESH MATERIALIZED VIEW CONCURRENTLY mvw_monthly_accruals;
  REFRESH MATERIALIZED VIEW CONCURRENTLY mvw_partner_summary;
$$);
```

**Complexity: Low-Medium** — `pg_cron` is available on Azure PostgreSQL Flexible Server. Job logic is straightforward; advanced features (max_failures, run_duration) need wrapper logic.

---

## 15. Synonyms

### 15.1 Public Synonyms (16)

| Oracle Construct                              | PostgreSQL Equivalent                            |
|-----------------------------------------------|--------------------------------------------------|
| `CREATE PUBLIC SYNONYM x FOR schema.object`   | No direct equivalent. Use `search_path` to include target schema, or create `VIEW` aliases. |

### 15.2 Private Synonyms (11)

| Oracle Construct                              | PostgreSQL Equivalent                            |
|-----------------------------------------------|--------------------------------------------------|
| `CREATE SYNONYM short_name FOR table_name`    | No synonym support. Use `search_path`, or create short-named `VIEW` wrappers. |

**Migration strategy:** Set `search_path` to include the application schema, eliminating the need for most synonyms. For specific short aliases, create simple views:
```sql
CREATE VIEW mem AS SELECT * FROM members;
```

**Complexity: Low**

---

## 16. Oracle-Specific SQL & Built-in Functions

### 16.1 Function Mapping

| Oracle Function / Feature               | PostgreSQL Equivalent                                           | Used In |
|------------------------------------------|-----------------------------------------------------------------|---------|
| `SYSDATE`                               | `CURRENT_TIMESTAMP`, `now()`, or `CURRENT_DATE`                 | Tables, views, packages, triggers, procedures, scheduler |
| `SYSTIMESTAMP`                           | `CURRENT_TIMESTAMP` or `clock_timestamp()`                      | Scheduler |
| `USER`                                   | `current_user`                                                   | Tables, audit |
| `NVL(a, b)`                              | `COALESCE(a, b)`                                                | Views, packages, procedures |
| `NVL2(a, b, c)`                          | `CASE WHEN a IS NOT NULL THEN b ELSE c END`                     | — |
| `DECODE(expr, v1, r1, ...)`             | `CASE expr WHEN v1 THEN r1 ... END`                             | Views |
| `MONTHS_BETWEEN(d1, d2)`                | `EXTRACT(YEAR FROM age(d1,d2))*12 + EXTRACT(MONTH FROM age(d1,d2))` | Views |
| `ADD_MONTHS(date, n)`                    | `date + INTERVAL 'n months'` (dynamic: `date + (n * INTERVAL '1 month')`) | Packages, procedures, scheduler |
| `TRUNC(date, 'YYYY')`                   | `DATE_TRUNC('year', date)`                                      | Views, packages |
| `TRUNC(date, 'MM')`                     | `DATE_TRUNC('month', date)`                                     | Packages |
| `LAST_DAY(date)`                         | `(DATE_TRUNC('month', date) + INTERVAL '1 month - 1 day')::date` | Packages |
| `TO_CHAR(date, 'YYYY-MM-DD')`           | `TO_CHAR(date, 'YYYY-MM-DD')` (same)                            | Procedures, packages |
| `TO_CHAR(number, '999,999')`            | `TO_CHAR(number, '999,999')` (same)                              | Functions, procedures |
| `TO_NUMBER(string)`                      | `string::NUMERIC` or `CAST(string AS NUMERIC)`                   | Views |
| `INITCAP(string)`                        | `INITCAP(string)` (same)                                         | Packages |
| `UPPER(string)`                          | `UPPER(string)` (same)                                           | Packages, triggers |
| `LOWER(string)`                          | `LOWER(string)` (same)                                           | Packages |
| `LPAD(string, n, char)`                 | `LPAD(string, n, char)` (same)                                   | Packages |
| `RPAD(string, n)`                        | `RPAD(string, n)` (same)                                         | Packages |
| `SUBSTR(string, start, len)`            | `SUBSTRING(string FROM start FOR len)` or `SUBSTR(...)` (same)   | Packages |
| `LENGTH(string)`                         | `LENGTH(string)` (same)                                          | Packages |
| `CHR(10)`                                | `CHR(10)` (same)                                                 | Packages |
| `REGEXP_LIKE(str, pattern)`             | `str ~ pattern` or `REGEXP_MATCHES(str, pattern)`                | Packages |
| `GREATEST(a, b)`                         | `GREATEST(a, b)` (same)                                          | Functions, procedures |
| `ROUND(number)`                          | `ROUND(number)` (same)                                           | Functions, views |
| `NULLIF(a, b)`                           | `NULLIF(a, b)` (same)                                            | Views |
| `SYS_CONTEXT('USERENV','SESSIONID')`    | `pg_backend_pid()` or `current_setting('app.session_id')`        | Audit package |
| `DBMS_RANDOM.VALUE(low, high)`          | `floor(random() * (high - low + 1) + low)`                       | Redemption package |
| `DBMS_OUTPUT.PUT_LINE(...)`             | `RAISE NOTICE '%', ...`                                          | Procedures |
| `DBMS_MVIEW.REFRESH(...)`              | `REFRESH MATERIALIZED VIEW ...`                                  | Scheduler |
| `CONNECT BY ... START WITH`              | `WITH RECURSIVE ... AS (...)` (recursive CTE)                   | Tier calculation package |
| `LEVEL` (in hierarchical query)          | Computed column in recursive CTE                                 | Tier calculation package |
| `FETCH FIRST N ROWS ONLY`               | `LIMIT N` (preferred) or `FETCH FIRST N ROWS ONLY` (also supported) | Packages, procedures |
| `ORDER BY ... NULLS LAST`               | `ORDER BY ... NULLS LAST` (same)                                 | Packages |
| `sequence.NEXTVAL`                       | `nextval('sequence')`                                            | All packages |
| `sequence.CURRVAL`                       | `currval('sequence')`                                            | Member mgmt package |
| `COMMIT` inside PL/SQL                   | Remove from functions; use in `PROCEDURE` (PG11+) or manage at app layer | Packages, procedures |
| `ROLLBACK` inside PL/SQL                 | Remove from functions; use `EXCEPTION` blocks with re-raise      | Packages, procedures |
| `FOR UPDATE`                             | `FOR UPDATE` (same)                                               | Member mgmt package |
| `\|\|` (string concat)                   | `\|\|` (same)                                                    | All |

### 16.2 CONNECT BY Hierarchical Query

Used in `pkg_tier_calculation.get_tier_hierarchy`:

```sql
-- Oracle
SELECT tier_name, min_miles, LEVEL AS tier_level
FROM tier_rules
WHERE status = 'ACTIVE'
START WITH min_miles = 0
CONNECT BY PRIOR min_miles < min_miles
ORDER BY LEVEL;
```

**PostgreSQL equivalent using recursive CTE:**

```sql
WITH RECURSIVE tier_hierarchy AS (
  SELECT tier_name, min_miles, min_segments, miles_multiplier, bonus_miles_pct,
         1 AS tier_level
  FROM tier_rules
  WHERE status = 'ACTIVE' AND min_miles = 0

  UNION ALL

  SELECT t.tier_name, t.min_miles, t.min_segments, t.miles_multiplier, t.bonus_miles_pct,
         th.tier_level + 1
  FROM tier_rules t
  JOIN tier_hierarchy th ON t.min_miles > th.min_miles
  WHERE t.status = 'ACTIVE'
)
SELECT DISTINCT ON (tier_name) *
FROM tier_hierarchy
ORDER BY tier_name, tier_level;
```

---

## 17. Data Type Mapping

| Oracle Data Type         | PostgreSQL Equivalent       | Notes                                      |
|--------------------------|-----------------------------|--------------------------------------------|
| `NUMBER(10)`             | `INTEGER` or `BIGINT`       | `INTEGER` for ≤ 2B, `BIGINT` for larger    |
| `NUMBER(12)`             | `BIGINT`                    | Exceeds `INTEGER` range                    |
| `NUMBER(15)`             | `BIGINT`                    |                                             |
| `NUMBER(10,2)`           | `NUMERIC(10,2)`             | Exact decimal                               |
| `NUMBER(12,2)`           | `NUMERIC(12,2)`             |                                             |
| `NUMBER(5,2)`            | `NUMERIC(5,2)`              |                                             |
| `NUMBER(3,1)`            | `NUMERIC(3,1)`              |                                             |
| `NUMBER(8)`              | `INTEGER`                   |                                             |
| `NUMBER(5)`              | `INTEGER` or `SMALLINT`     |                                             |
| `NUMBER(3)`              | `SMALLINT`                  |                                             |
| `NUMBER(1)`              | `SMALLINT`                  |                                             |
| `VARCHAR2(n)`            | `VARCHAR(n)`                | Direct mapping                              |
| `DATE`                   | `TIMESTAMP`                 | Oracle `DATE` includes time component       |
| `CLOB`                   | `TEXT`                      | Or `JSONB` for structured data (audit logs) |
| `RAW(16)`                | `BYTEA`                     | Used in AQ message handle                   |
| Custom `OBJECT` type     | Composite type (`CREATE TYPE ... AS (...)`) | AQ payload |

---

## 18. Migration Complexity Matrix

| # | Object / Feature                          | Count | Complexity  | Effort (Days) | Risk   | Notes |
|---|-------------------------------------------|------:|-------------|---------------|--------|-------|
| 1 | **Tables** (DDL + data types)             |    11 | 🟢 Low       | 1–2           | Low    | Type mapping is mechanical (`NUMBER`→`INTEGER`/`NUMERIC`, `VARCHAR2`→`VARCHAR`, `DATE`→`TIMESTAMP`, `CLOB`→`TEXT`) |
| 2 | **Sequences**                             |    10 | 🟢 Low       | 0.5           | Low    | Direct equivalent; change `.NEXTVAL` → `nextval()` |
| 3 | **B-tree Indexes**                        |   ~45 | 🟢 Low       | 0.5           | Low    | Direct equivalent |
| 4 | **Bitmap Indexes**                        |   ~18 | 🟡 Medium    | 1             | Low    | Replace with B-tree or partial indexes |
| 5 | **Oracle Text Index**                     |     1 | 🟡 Medium    | 1             | Medium | Replace with GIN + `tsvector` |
| 6 | **Constraints** (PK/UK/FK/CHECK)          |   ~34 | 🟢 Low       | 0.5           | Low    | Direct equivalent |
| 7 | **Standard Views**                        |     2 | 🟡 Medium    | 1             | Low    | Rewrite `DECODE`→`CASE`, `NVL`→`COALESCE`, `MONTHS_BETWEEN`→`age()`, `SYSDATE`→`now()` |
| 8 | **Materialized Views**                    |     2 | 🟡 Medium    | 1             | Medium | No fast refresh or query rewrite in PG; refresh via `pg_cron` |
| 9 | **PL/SQL Packages** (10 × spec+body)      |    10 | 🔴 High      | 10–15         | High   | Decompose into schemas + individual functions; convert all PL/SQL idioms |
| 10| **Standalone Functions**                  |     3 | 🟢 Low       | 1             | Low    | `DETERMINISTIC`→`IMMUTABLE`; minor syntax changes |
| 11| **Standalone Procedures**                 |     3 | 🟠 Med-High  | 3–4           | Medium | `BULK COLLECT`/`FORALL`, mid-txn `COMMIT`, `DBMS_OUTPUT` |
| 12| **Triggers**                              |     3 | 🟡 Medium    | 2             | Medium | Separate into trigger function + trigger; handle `:OLD`/`:NEW`, `TG_OP` |
| 13| **Oracle AQ** (queue + enqueue/dequeue)   |     1 | 🔴 High      | 3–5           | High   | No native equivalent; use `pgmq`, `LISTEN/NOTIFY` + table, or Azure Service Bus |
| 14| **DBMS_SCHEDULER Jobs**                   |     3 | 🟡 Medium    | 1–2           | Low    | Convert to `pg_cron`; available on Azure PG Flexible Server |
| 15| **Synonyms** (public + private)           |    27 | 🟢 Low       | 0.5           | Low    | Use `search_path` and/or view aliases |
| 16| **`PRAGMA AUTONOMOUS_TRANSACTION`**       |     1 | 🔴 High      | 2–3           | High   | Used in `pkg_audit.log_change`, called from triggers. Requires `dblink` loopback or architectural change |
| 17| **`SYS_CONTEXT` / Session Info**          |     1 | 🟡 Medium    | 0.5           | Low    | Replace with `pg_backend_pid()` or custom GUC |
| 18| **`CONNECT BY` Hierarchical Query**       |     1 | 🟡 Medium    | 0.5           | Low    | Convert to recursive CTE |
| 19| **Custom Object Type** (AQ payload)       |     1 | 🟢 Low       | 0.5           | Low    | `CREATE TYPE ... AS (...)` |

### Summary Totals

| Complexity Level | Object Count | Estimated Effort |
|------------------|-------------:|------------------|
| 🟢 Low           | ~120          | 5–6 days         |
| 🟡 Medium        | ~25           | 7–8 days         |
| 🟠 Medium-High   | 3             | 3–4 days         |
| 🔴 High          | 12            | 15–23 days       |
| **Total**        | **~160**      | **30–41 days**   |

---

## 19. Risk Summary & Recommendations

### 19.1 High-Risk Items

| Risk Area                                    | Impact | Mitigation Strategy                                                  |
|----------------------------------------------|--------|----------------------------------------------------------------------|
| **PL/SQL Package Decomposition (10 packages)** | High   | Decompose each package into a PostgreSQL schema with individual functions. Maintain a mapping document (Oracle package.procedure → PG schema.function). Unit test each function independently. |
| **`PRAGMA AUTONOMOUS_TRANSACTION` (audit logging)** | High | Option A: Use `dblink` loopback connection for autonomous commits. Option B: Use `pg_background` extension. Option C: Buffer audit records in a temporary table and flush after main transaction. Option D: Use application-level audit logging. |
| **Oracle AQ → PostgreSQL Queuing**           | High   | Evaluate `pgmq` extension (available on Azure PG). Alternative: `LISTEN/NOTIFY` + queue table with `FOR UPDATE SKIP LOCKED`. For cloud-scale: consider Azure Service Bus as external broker. |
| **Mid-Transaction COMMIT in Procedures**     | Medium | PostgreSQL `PROCEDURE` (PG11+) supports `COMMIT` within the body. Refactor Oracle procedures as PostgreSQL `PROCEDURE` (not `FUNCTION`). Alternatively, restructure batch loops to be called iteratively from the application. |

### 19.2 Recommendations

1. **Phase the migration**: Start with tables, sequences, constraints, and indexes (low risk). Then migrate views and functions. Finally, tackle packages, triggers, AQ, and scheduler jobs.
2. **Use `pgmq` for queuing**: The `pgmq` extension is available on Azure PostgreSQL Flexible Server and provides a PostgreSQL-native queue that closely matches Oracle AQ semantics.
3. **Enable `pg_cron`**: Available on Azure PostgreSQL Flexible Server for scheduled job execution. Replaces `DBMS_SCHEDULER` with minimal effort.
4. **Audit logging strategy**: Evaluate whether `PRAGMA AUTONOMOUS_TRANSACTION` behavior is truly required. If audit records can be committed with the main transaction, the migration simplifies significantly.
5. **Test materialized views**: Since PostgreSQL lacks fast refresh and query rewrite, benchmark `REFRESH MATERIALIZED VIEW CONCURRENTLY` performance and adjust refresh schedules in `pg_cron` accordingly.
6. **Convert `CLOB` audit columns to `JSONB`**: The `old_values` and `new_values` columns in `audit_log` store JSON strings. Using `JSONB` in PostgreSQL enables indexing and querying audit data natively.
7. **Use Ora2Pg for initial DDL conversion**: Ora2Pg can automate bulk conversion of tables, sequences, indexes, views, and basic PL/SQL. Manual review is required for packages, triggers, and Oracle-specific constructs.
