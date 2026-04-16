# ora2pg Migration Assessment Report

## SkyReward Airlines — Oracle to Azure PostgreSQL

**Assessment Date:** 2026-04-16
**Tool Version:** ora2pg 24.x (simulated)
**Source Database:** Oracle XE 21c (XEPDB1)
**Target Database:** Azure Database for PostgreSQL — Flexible Server 16
**Schema:** SKYREWARD

---

## 1. Executive Summary

| Metric | Value |
|---|---|
| **Total Object Count** | 135 |
| **Total PL/SQL Lines** | 4,507 |
| **Overall Migration Level** | **B-3** (Moderate complexity) |
| **Estimated Cost (person-days)** | 18–25 |
| **Automatic Conversion Rate** | ~62% |
| **Manual Intervention Required** | ~38% |

The SkyReward Airlines Oracle database is a mid-complexity loyalty program system with 10 PL/SQL packages, 3 standalone functions, 3 standalone procedures, 11 tables, 10 sequences, 3 triggers, 2 materialized views, 2 standard views, 1 Oracle AQ queue, 3 DBMS_SCHEDULER jobs, and 50 synonyms. The primary migration challenges are Oracle Advanced Queuing (DBMS_AQ), DBMS_SCHEDULER jobs, PRAGMA AUTONOMOUS_TRANSACTION, BULK COLLECT/FORALL patterns, Oracle Text indexes, and bitmap indexes.

---

## 2. Object Inventory & Complexity Scores

### 2.1 Object Count Summary

| Object Type | Count | Lines | Conversion Effort | Cost (days) |
|---|---|---|---|---|
| Tables | 11 | 293 | A — Automatic | 0.5 |
| Sequences | 10 | 66 | A — Automatic | 0.25 |
| Indexes (B-tree) | 46 | — | A — Automatic | 0.25 |
| Indexes (Bitmap) | 16 | — | B — Minor manual | 0.5 |
| Indexes (Oracle Text) | 1 | — | C — Major rewrite | 0.5 |
| Constraints / Comments | 130 | 130 | A — Automatic | 0.25 |
| Packages (spec + body) | 10 | 2,208 | B/C — Mixed | 8–10 |
| Standalone Functions | 3 | 175 | B — Minor manual | 1 |
| Standalone Procedures | 3 | 302 | B — Minor manual | 1.5 |
| Views | 2 | 133 | B — Minor manual | 0.5 |
| Materialized Views | 2 | 93 | B — Minor manual | 1 |
| Triggers | 3 | 174 | B — Minor manual | 1 |
| Synonyms | 50 | 44 | A — Drop (N/A in PG) | 0.25 |
| Oracle AQ (Queues) | 1 | 160 | C — Major rewrite | 2 |
| DBMS_SCHEDULER Jobs | 3 | 194 | C — Major rewrite | 1.5 |
| **TOTAL** | **135** | **4,507** | | **18–25** |

### 2.2 Migration Complexity Score (ora2pg scale: 1–10)

| Object Type | Complexity Score | Level |
|---|---|---|
| Tables | 2 | A |
| Sequences | 1 | A |
| Packages | 6 | B-C |
| Functions | 4 | B |
| Procedures | 5 | B |
| Views | 3 | B |
| Materialized Views | 4 | B |
| Triggers | 5 | B |
| Synonyms | 1 | A (drop) |
| Oracle AQ (Queues) | 9 | C |
| DBMS_SCHEDULER | 7 | C |
| **Weighted Average** | **4.3** | **B-3** |

---

## 3. Detailed Object Analysis

### 3.1 Tables (11 tables, 293 lines) — Effort: A

All tables convert cleanly with data type mapping. Key conversion notes:

| Table | Columns | Oracle-Specific Features | Notes |
|---|---|---|---|
| `members` | 26 | `SYSDATE` defaults, `USER` default, `CLOB`, `NUMBER(x)` | Standard mapping |
| `flights` | 23 | `SYSDATE` defaults, `NUMBER(x,y)` | Standard mapping |
| `rewards` | 17 | `CLOB` (2 columns), `SYSDATE` defaults | `CLOB` → `text` |
| `redemptions` | 15 | `CLOB`, `SYSDATE` defaults | Standard mapping |
| `partners` | 14 | `CLOB`, `SYSDATE` defaults | Standard mapping |
| `partner_transactions` | 16 | `SYSDATE` defaults | Standard mapping |
| `tier_rules` | 15 | `SYSDATE` defaults, Y/N checks | Standard mapping |
| `miles_expiry` | 12 | `SYSDATE` defaults | Standard mapping |
| `audit_log` | 11 | `USER` default, `CLOB`, `SYSDATE` | `USER` → `CURRENT_USER` |
| `notifications` | 14 | `CLOB`, `SYSDATE` defaults | Standard mapping |
| `batch_processing_log` | 12 | `USER` default, `CLOB`, `SYSDATE` | Standard mapping |

### 3.2 Sequences (10 sequences, 66 lines) — Effort: A

All sequences convert directly. `NOCACHE`/`CACHE`/`NOCYCLE` syntax is compatible.

| Sequence | Start Value | Cache | Notes |
|---|---|---|---|
| `seq_member_id` | 1000000 | NOCACHE | Direct conversion |
| `seq_flight_id` | 1 | CACHE 100 | Direct conversion |
| `seq_redemption_id` | 5000000 | CACHE 50 | Direct conversion |
| `seq_reward_id` | 1 | NOCACHE | Direct conversion |
| `seq_partner_txn_id` | 1 | CACHE 100 | Direct conversion |
| `seq_tier_rule_id` | 1 | NOCACHE | Direct conversion |
| `seq_audit_id` | 1 | CACHE 200 | Direct conversion |
| `seq_notification_id` | 1 | CACHE 100 | Direct conversion |
| `seq_partner_id` | 1000 | NOCACHE | Direct conversion |
| `seq_expiry_batch_id` | 1 | NOCACHE | Direct conversion |

### 3.3 Indexes — Effort: A/B/C Mixed

| Index Type | Count | Conversion | Notes |
|---|---|---|---|
| B-tree | 46 | A — Automatic | Direct CREATE INDEX |
| Bitmap | 16 | B — Convert to B-tree or GIN | PostgreSQL has no bitmap indexes; use standard B-tree for low-cardinality or partial indexes |
| Oracle Text (CTXSYS.CONTEXT) | 1 | C — Rewrite to `tsvector`/GIN | `idx_rewards_desc_text` on `rewards(description)` → `CREATE INDEX ... USING GIN (to_tsvector('english', description))` |

### 3.4 PL/SQL Packages — Detailed Analysis

#### 3.4.1 PKG_AUDIT (127 lines) — Effort: B

| Item | Detail |
|---|---|
| **Spec lines** | 43 |
| **Body lines** | 84 |
| **Procedures** | `log_change`, `purge_audit_records` |
| **Functions** | `get_audit_trail`, `get_member_audit_trail`, `get_audit_summary` |

**Conversion Issues:**

| Line(s) | Issue | Severity | Resolution |
|---|---|---|---|
| 57 | `PRAGMA AUTONOMOUS_TRANSACTION` | High | Rewrite using `dblink` to self or refactor to remove autonomous transaction. In PG, audit inserts should use a separate connection or deferred approach. |
| 64 | `seq_audit_id.NEXTVAL` | Low | → `nextval('seq_audit_id')` |
| 67 | `SYS_CONTEXT('USERENV', 'SESSIONID')` | Medium | → `pg_backend_pid()` or `current_setting('app.session_id')` |
| 64 | `USER` | Low | → `CURRENT_USER` |
| 64 | `SYSDATE` | Low | → `CURRENT_TIMESTAMP` or `NOW()` |
| 78 | `SYS_REFCURSOR` | Low | → `REFCURSOR` (PL/pgSQL native) |
| 104 | `NVL(...)` | Low | → `COALESCE(...)` |
| 120 | `SQL%ROWCOUNT` | Low | → `GET DIAGNOSTICS row_count = ROW_COUNT` |

#### 3.4.2 PKG_BATCH_PROCESSING (280 lines) — Effort: B-C

| Item | Detail |
|---|---|
| **Spec lines** | 68 |
| **Body lines** | 212 |
| **Procedures** | `complete_batch`, `run_miles_expiry`, `run_tier_recalculation`, `run_data_cleanup`, `run_ytd_miles_reset`, `run_statement_generation` |
| **Functions** | `start_batch`, `get_batch_status`, `get_batch_history` |

**Conversion Issues:**

| Line(s) | Issue | Severity | Resolution |
|---|---|---|---|
| 121–128 | `TYPE ... IS TABLE OF` + `BULK COLLECT INTO` | High | Replace with PL/pgSQL `ARRAY` or cursor-based `FOR` loop. No BULK COLLECT in PG. |
| 146 | `FORALL i IN ... LAST` | High | Replace with `FOR` loop or `UPDATE ... WHERE id = ANY(array)` pattern |
| 155–172 | Collection iteration `.FIRST .. .LAST` | Medium | Replace with PG array iteration `FOREACH ... IN ARRAY` |
| 170 | `DBMS_OUTPUT.PUT_LINE(...)` | Low | → `RAISE NOTICE '%', ...` |
| 81 | `seq_expiry_batch_id.NEXTVAL` | Low | → `nextval(...)` |
| 169 | `WHEN OTHERS THEN` + `SQLERRM` | Low | → `EXCEPTION WHEN OTHERS THEN` + `SQLERRM` (same in PG) |
| 264–265 | `TRUNC(..., 'MM')`, `LAST_DAY(...)` | Low | → `date_trunc('month', ...)`, `(date_trunc('month', ...) + interval '1 month' - interval '1 day')` |
| 54 | `ADD_MONTHS(SYSDATE, -1)` | Low | → `CURRENT_DATE - interval '1 month'` |

#### 3.4.3 PKG_FLIGHT_ACCRUAL (289 lines) — Effort: B-C

| Item | Detail |
|---|---|
| **Spec lines** | 79 |
| **Body lines** | 210 |
| **Procedures** | `record_flight`, `process_pending_accruals`, `reverse_accrual`, `retroactive_accrual` |
| **Functions** | `calculate_base_miles`, `calculate_bonus_miles` |

**Conversion Issues:**

| Line(s) | Issue | Severity | Resolution |
|---|---|---|---|
| 9–19 | `TYPE t_flight_rec IS RECORD (... %TYPE)` | Medium | Convert `%TYPE` references to explicit types. PG supports `%TYPE` in PL/pgSQL but not in package-level type declarations (no packages). |
| 198–204 | `TYPE ... IS TABLE OF` + `BULK COLLECT INTO` | High | Replace with cursor or array approach |
| 224 | `FORALL i IN ...` | High | Replace with loop or set-based `UPDATE` |
| 130 | `FETCH FIRST n ROWS ONLY` | Low | → `LIMIT n` |
| 268 | `RAISE_APPLICATION_ERROR(-20030, ...)` | Medium | → `RAISE EXCEPTION '%', ...` with custom SQLSTATE |
| 311 | `ADD_MONTHS(SYSDATE, -12)` | Low | → `CURRENT_DATE - interval '12 months'` |

#### 3.4.4 PKG_MEMBER_MGMT (279 lines) — Effort: B

| Item | Detail |
|---|---|
| **Spec lines** | 84 |
| **Body lines** | 195 |
| **Procedures** | `register_member`, `update_member_profile`, `update_miles_balance`, `change_member_status`, `merge_members` |
| **Functions** | `generate_membership_number`, `get_member`, `search_members` |

**Conversion Issues:**

| Line(s) | Issue | Severity | Resolution |
|---|---|---|---|
| 9–17 | `TYPE t_member_rec IS RECORD (... %TYPE)` | Medium | Use composite types or explicit column types in PG functions |
| 19 | `TYPE t_member_tab IS TABLE OF ... INDEX BY PLS_INTEGER` | Medium | → PG array or `RETURNS TABLE(...)` for set-returning functions |
| 93 | `TO_CHAR(SYSDATE, 'YY') \|\| LPAD(seq_member_id.NEXTVAL, 8, '0')` | Low | → `to_char(now(), 'YY') \|\| lpad(nextval('seq_member_id')::text, 8, '0')` |
| 118 | `seq_member_id.CURRVAL` | Low | → `currval('seq_member_id')` |
| 127 | `INITCAP(...)` | Low | Compatible — exists in PG |
| 158 | `NVL(p_first_name, first_name)` (×9 occurrences) | Low | → `COALESCE(...)` |
| 259 | `CHR(10)` | Low | Compatible — exists in PG |
| 115 | `RAISE_APPLICATION_ERROR(-20001, ...)` | Medium | → `RAISE EXCEPTION ... USING ERRCODE` |

#### 3.4.5 PKG_NOTIFICATION (172 lines) — Effort: B

| Item | Detail |
|---|---|
| **Spec lines** | 48 |
| **Body lines** | 124 |
| **Procedures** | `send_notification`, `process_pending`, `retry_failed`, `cancel_notification` |
| **Functions** | `get_member_notifications`, `get_notification_stats` |

**Conversion Issues:**

| Line(s) | Issue | Severity | Resolution |
|---|---|---|---|
| 95–96 | `TYPE ... IS TABLE OF` + `BULK COLLECT INTO` | High | Array or cursor pattern |
| 114 | `FORALL i IN ...` | High | → Loop or set-based approach |
| 87 | `DBMS_OUTPUT.PUT_LINE(...)` | Low | → `RAISE NOTICE` |
| 173 | `RAISE_APPLICATION_ERROR(-20130, ...)` | Medium | → `RAISE EXCEPTION` |
| 130 | `SQL%ROWCOUNT` | Low | → `GET DIAGNOSTICS` |

#### 3.4.6 PKG_PARTNER_INTEGRATION (215 lines) — Effort: B

| Item | Detail |
|---|---|
| **Spec lines** | 59 |
| **Body lines** | 156 |
| **Procedures** | `record_partner_earn`, `record_partner_redeem`, `transfer_miles`, `process_settlement` |
| **Functions** | `get_conversion_rate`, `get_partner_summary` |

**Conversion Issues:**

| Line(s) | Issue | Severity | Resolution |
|---|---|---|---|
| 75 | `RAISE_APPLICATION_ERROR(-20050, ...)` | Medium | → `RAISE EXCEPTION` |
| 214 | `NVL(SUM(...), 0)` | Low | → `COALESCE(SUM(...), 0)` |
| 241 | `NVL(p_start_date, DATE '2000-01-01')` | Low | → `COALESCE(...)` |
| 100 | `seq_partner_txn_id.NEXTVAL` | Low | → `nextval(...)` |

#### 3.4.7 PKG_REDEMPTION_MGMT (217 lines) — Effort: B

| Item | Detail |
|---|---|
| **Spec lines** | 48 |
| **Body lines** | 169 |
| **Procedures** | `redeem_reward`, `cancel_redemption`, `fulfill_redemption` |
| **Functions** | `generate_confirmation_code`, `check_reward_available`, `get_member_redemptions` |

**Conversion Issues:**

| Line(s) | Issue | Severity | Resolution |
|---|---|---|---|
| 56 | `DBMS_RANDOM.VALUE(100000, 999999)` | Medium | → `floor(random() * 899999 + 100000)` |
| 64 | `RETURN BOOLEAN` (in package function) | Low | PL/pgSQL supports `RETURNS boolean` natively |
| 115 | `RAISE_APPLICATION_ERROR(-20040, ...)` | Medium | → `RAISE EXCEPTION` |
| 136 | `ADD_MONTHS(SYSDATE, 12)` | Low | → `CURRENT_DATE + interval '12 months'` |
| 119 | `NVL(cash_copay, 0)` | Low | → `COALESCE(...)` |

#### 3.4.8 PKG_REPORTING (267 lines) — Effort: B

| Item | Detail |
|---|---|
| **Spec lines** | 62 |
| **Body lines** | 205 |
| **Procedures** | `generate_liability_report` |
| **Functions** | `get_dashboard_kpis`, `get_tier_distribution`, `get_monthly_accrual_trend`, `get_top_earners`, `get_partner_performance`, `get_redemption_analytics`, `generate_member_statement` |

**Conversion Issues:**

| Line(s) | Issue | Severity | Resolution |
|---|---|---|---|
| 116 | `DECODE(tier_status, 'DIAMOND', 1, ...)` | Medium | → `CASE tier_status WHEN 'DIAMOND' THEN 1 ...` |
| 136 | `TRUNC(SYSDATE, 'MM')` | Low | → `date_trunc('month', CURRENT_DATE)` |
| 165 | `FETCH FIRST p_top_n ROWS ONLY` | Low | → `LIMIT p_top_n` |
| 191 | `DESC NULLS LAST` | Low | Compatible — PG supports `NULLS LAST` |
| 250 | `members%ROWTYPE` | Low | Compatible — PG supports `%ROWTYPE` in PL/pgSQL |
| 261 | `TO_CHAR(v_member.available_miles, '999,999,999')` | Low | Compatible |
| 9–15 | `TYPE t_summary_rec IS RECORD (...)` | Medium | Convert to composite type or return `TABLE(...)` |

#### 3.4.9 PKG_TIER_CALCULATION (214 lines) — Effort: B

| Item | Detail |
|---|---|
| **Spec lines** | 53 |
| **Body lines** | 161 |
| **Procedures** | `recalculate_member_tier`, `recalculate_all_tiers` |
| **Functions** | `evaluate_tier`, `get_qualifying_miles`, `get_qualifying_segments`, `get_tier_hierarchy`, `check_upgrade_eligibility` |

**Conversion Issues:**

| Line(s) | Issue | Severity | Resolution |
|---|---|---|---|
| 212–228 | `START WITH ... CONNECT BY PRIOR` (hierarchical query) | High | → Rewrite using PostgreSQL recursive CTE: `WITH RECURSIVE tier_cte AS (...)`. In this case, a simpler `ORDER BY min_miles` suffices since the hierarchy is flat. |
| 9–15 | `TYPE t_tier_info IS RECORD (... %TYPE)` | Medium | Explicit composite type |
| 17 | `TYPE t_tier_tab IS TABLE OF ... INDEX BY PLS_INTEGER` | Medium | → PG array or `RETURNS SETOF` |
| 128 | `p_changed OUT BOOLEAN` | Low | PG supports `OUT boolean` |
| 191 | `DBMS_OUTPUT.PUT_LINE(...)` | Low | → `RAISE NOTICE` |
| 154 | `RAISE_APPLICATION_ERROR(-20002, ...)` | Medium | → `RAISE EXCEPTION` |

#### 3.4.10 PKG_VALIDATION (148 lines) — Effort: B

| Item | Detail |
|---|---|
| **Spec lines** | 39 |
| **Body lines** | 109 |
| **Procedures** | `validate_member_active`, `validate_redemption`, `validate_partner_active` |
| **Functions** | `is_valid_email`, `is_valid_airport_code`, `is_valid_flight_date`, `is_valid_miles_amount`, `is_valid_tier`, `is_valid_booking_class` |

**Conversion Issues:**

| Line(s) | Issue | Severity | Resolution |
|---|---|---|---|
| 64 | `REGEXP_LIKE(p_email, ...)` | Low | → `p_email ~ '^[A-Za-z0-9._%+-]+@...'` (PG `~` operator) |
| 82 | `SYSDATE + 1` (date arithmetic) | Low | → `CURRENT_DATE + 1` |
| 83 | `ADD_MONTHS(SYSDATE, -24)` | Low | → `CURRENT_DATE - interval '24 months'` |
| 51 | `RAISE_APPLICATION_ERROR(-20100, ...)` (×7 calls) | Medium | → `RAISE EXCEPTION '...' USING ERRCODE = 'P0001'` |
| 99 | `RETURN p_tier IN ('BLUE', ...)` (implicit boolean) | Low | Compatible in PG |

### 3.5 Standalone Functions (3 functions, 175 lines) — Effort: B

| Function | Lines | Issues |
|---|---|---|
| `fn_calculate_miles` | 50 | `DETERMINISTIC` → `IMMUTABLE`; `CASE` expressions compatible; `GREATEST()` compatible |
| `fn_get_tier_status` | 48 | `ADD_MONTHS` → interval; `NVL` → `COALESCE`; `TO_CHAR` compatible |
| `fn_validate_redemption` | 77 | Nested `FUNCTION tier_rank` (local function) → must be extracted as separate function in PG (PL/pgSQL does not support local functions); `NVL` → `COALESCE` |

### 3.6 Standalone Procedures (3 procedures, 302 lines) — Effort: B

| Procedure | Lines | Issues |
|---|---|---|
| `pr_expire_miles` | 87 | `TYPE ... IS TABLE OF ... INDEX BY PLS_INTEGER` → PG array; `.FIRST/.LAST` iteration; `DBMS_OUTPUT` → `RAISE NOTICE`; `MOD(x,1000)` → compatible; periodic `COMMIT` inside procedure → refactor (PG procedures support `COMMIT` since v11) |
| `pr_process_bulk_accrual` | 103 | **`BULK COLLECT INTO`** → cursor/array; **`FORALL ... SAVE EXCEPTIONS`** → loop with exception handling; **`PRAGMA EXCEPTION_INIT`** → manual `SQLSTATE` mapping; **`SQL%BULK_EXCEPTIONS`** → no equivalent, must use row-by-row error handling |
| `pr_recalculate_tiers` | 112 | Local `FUNCTION tier_rank()` → extract to standalone; `DBMS_OUTPUT` → `RAISE NOTICE`; `NVL` → `COALESCE`; `MOD()` → compatible |

### 3.7 Views (2 views, 133 lines) — Effort: B

| View | Lines | Issues |
|---|---|---|
| `vw_member_summary` | 64 | `MONTHS_BETWEEN()` → `EXTRACT(EPOCH FROM age(...)) / 2592000` or `date_part()`; **`DECODE(...)`** → `CASE WHEN`; `TRUNC(SYSDATE, 'YYYY')` → `date_trunc('year', ...)` |
| `vw_tier_status_report` | 69 | **`DECODE(...)`** (×2) → `CASE WHEN`; `TRUNC(SYSDATE, 'YYYY')` → `date_trunc('year', ...)`; `NULLIF(..., 0)` → compatible |

### 3.8 Materialized Views (2 MVs, 93 lines) — Effort: B

| Materialized View | Lines | Issues |
|---|---|---|
| `mvw_monthly_accruals` | 48 | **`BUILD IMMEDIATE`** → remove (PG default); **`REFRESH FAST ON DEMAND`** → `CREATE MATERIALIZED VIEW` (PG only supports complete refresh); **`ENABLE QUERY REWRITE`** → remove (not supported). `TO_NUMBER(TO_CHAR(...))` → `EXTRACT(YEAR FROM ...)`. Must set up `pg_cron` for scheduled refresh. |
| `mvw_partner_summary` | 45 | **`REFRESH COMPLETE ON DEMAND`** → standard in PG; **`ENABLE QUERY REWRITE`** → remove; `NVL` → `COALESCE`. Must set up `pg_cron` for scheduled refresh. |

### 3.9 Triggers (3 triggers, 174 lines) — Effort: B

| Trigger | Lines | Issues |
|---|---|---|
| `trg_flight_validation` | 67 | `:NEW.field` → `NEW.field`; `:OLD.field` → `OLD.field`; `INSERTING`/`UPDATING` → `TG_OP = 'INSERT'`/`TG_OP = 'UPDATE'`; `RAISE_APPLICATION_ERROR` → `RAISE EXCEPTION`; must split into trigger function + trigger declaration; `SYSDATE` → `CURRENT_TIMESTAMP` |
| `trg_member_audit` | 58 | Same `:NEW`/`:OLD` conversion; `INSERTING`/`UPDATING`/`DELETING` → `TG_OP` checks; `NVL` → `COALESCE`; calls `pkg_audit.log_change` → must call converted function |
| `trg_redemption_audit` | 49 | Same pattern; `NVL(TO_CHAR(...), 'null')` → `COALESCE(...)` |

**Note:** PostgreSQL requires triggers to be split into a trigger function (`CREATE FUNCTION ... RETURNS TRIGGER`) and a trigger declaration (`CREATE TRIGGER ... EXECUTE FUNCTION ...`).

### 3.10 Synonyms (50 synonyms, 44 lines) — Effort: A (Drop)

PostgreSQL does not support synonyms. Resolution options:
- **Public synonyms (31):** Replace with `SET search_path` or create views in `public` schema that reference the target tables
- **Private synonyms (19):** Replace with views or `search_path` configuration

All 50 synonyms can be dropped; application SQL should reference objects directly.

### 3.11 Oracle Advanced Queuing (1 queue, 160 lines) — Effort: C

| Component | Lines | Issue |
|---|---|---|
| `reward_fulfillment_msg_t` (Object Type) | 20 | → PG composite type or JSON payload |
| `DBMS_AQADM.CREATE_QUEUE_TABLE` | 12 | → Create regular table + `pg_notify` or use `pgmq` extension |
| `DBMS_AQADM.CREATE_QUEUE` / `START_QUEUE` | 12 | → No direct equivalent; use `pgmq`, `LISTEN/NOTIFY`, or external broker (Azure Service Bus) |
| `enqueue_fulfillment` procedure | 56 | → Rewrite: insert into queue table + `pg_notify('fulfillment_channel', ...)` |
| `dequeue_and_fulfill` procedure | 60 | → Rewrite: `SELECT ... FOR UPDATE SKIP LOCKED` pattern for competing consumers |
| `DBMS_AQ.ENQUEUE` / `DBMS_AQ.DEQUEUE` | — | → Complete replacement with PG-native or external queuing |

**Recommended approach:** Use the `pgmq` PostgreSQL extension (available on Azure) or implement a lightweight queue using `SKIP LOCKED`.

### 3.12 DBMS_SCHEDULER Jobs (3 jobs, 194 lines) — Effort: C

| Job | Lines | Schedule | Resolution |
|---|---|---|---|
| `JOB_EXPIRE_MILES` | 56 | Daily at 02:00 | → `pg_cron`: `SELECT cron.schedule('expire-miles', '0 2 * * *', $$CALL pr_expire_miles(...)$$)` |
| `JOB_TIER_RECALC` | 60 | Daily at 03:00 | → `pg_cron`: `SELECT cron.schedule('tier-recalc', '0 3 * * *', $$CALL pr_recalculate_tiers(...)$$)` |
| `JOB_MVW_REFRESH` | 78 | Daily at 04:00 | → `pg_cron`: `SELECT cron.schedule('mvw-refresh', '0 4 * * *', $$REFRESH MATERIALIZED VIEW CONCURRENTLY ...$$)` |

`DBMS_SCHEDULER` attributes (`max_failures`, `max_run_duration`, `logging_level`) have no direct `pg_cron` equivalent — implement monitoring in application layer or use Azure Automation.

---

## 4. Oracle-to-PostgreSQL Data Type Mapping

| Oracle Data Type | PostgreSQL Type | Notes |
|---|---|---|
| `NUMBER(10)` | `integer` or `bigint` | `integer` for ≤9 digits, `bigint` for 10+ |
| `NUMBER(12)` | `bigint` | Exceeds integer range |
| `NUMBER(15)` | `bigint` | Exceeds integer range |
| `NUMBER(10,2)` | `numeric(10,2)` | Exact decimal mapping |
| `NUMBER(5,2)` | `numeric(5,2)` | Exact decimal mapping |
| `NUMBER(3,1)` | `numeric(3,1)` | Exact decimal mapping |
| `NUMBER(8)` | `integer` | Within integer range |
| `NUMBER(5)` | `integer` | Within integer range |
| `NUMBER(3)` | `smallint` | Within smallint range |
| `NUMBER(1)` | `smallint` | Within smallint range |
| `VARCHAR2(n)` | `varchar(n)` | Direct mapping |
| `DATE` | `timestamp` | Oracle `DATE` includes time component |
| `CLOB` | `text` | Direct mapping |
| `RAW(16)` | `bytea` | Used in AQ message handles |
| `SYSDATE` | `CURRENT_TIMESTAMP` or `NOW()` | Function replacement |
| `USER` | `CURRENT_USER` | Function replacement |
| `SYSTIMESTAMP` | `CURRENT_TIMESTAMP` | Direct mapping |

---

## 5. PL/SQL Conversion Pattern Summary

### 5.1 High-Priority Patterns (require manual intervention)

| Pattern | Occurrences | Files | Conversion Strategy |
|---|---|---|---|
| **Packages → Functions/Procedures** | 10 packages | All `pkg_*.sql` | Split each package into individual functions/procedures. Use schema prefix or naming convention (e.g., `pkg_audit__log_change`) to maintain grouping. Package-level types → standalone composite types. |
| **BULK COLLECT INTO** | 5 | `pkg_batch_processing`, `pkg_flight_accrual`, `pkg_notification`, `pr_process_bulk_accrual`, `pr_expire_miles` | → Cursor-based loops or `ARRAY_AGG()` with set-based operations |
| **FORALL ... (SAVE EXCEPTIONS)** | 4 | `pkg_batch_processing`, `pkg_flight_accrual`, `pkg_notification`, `pr_process_bulk_accrual` | → `FOR` loop with individual error handling, or set-based `UPDATE ... WHERE id = ANY(array_var)` |
| **PRAGMA AUTONOMOUS_TRANSACTION** | 1 | `pkg_audit` (line 57) | → Use `dblink` connection to self, or `pg_background`, or refactor to use separate session. Critical for audit logging from triggers. |
| **CONNECT BY / START WITH** | 1 | `pkg_tier_calculation` (line 216) | → `WITH RECURSIVE cte AS (...)` or simplified `ORDER BY` for flat hierarchies |
| **PRAGMA EXCEPTION_INIT** | 1 | `pr_process_bulk_accrual` (line 31) | → Direct `SQLSTATE` error handling |
| **SQL%BULK_EXCEPTIONS** | 1 | `pr_process_bulk_accrual` (line 68) | → Row-level exception handling in loop |
| **DBMS_AQ.ENQUEUE/DEQUEUE** | 2 | `reward_fulfillment_queue.sql` | → Complete rewrite using `pgmq` or `SKIP LOCKED` pattern |
| **DBMS_SCHEDULER** | 3 | `job_*.sql` | → `pg_cron` extension |
| **DBMS_MVIEW.REFRESH** | 1 | `job_materialized_view_refresh.sql` | → `REFRESH MATERIALIZED VIEW CONCURRENTLY` |
| **DBMS_RANDOM.VALUE** | 1 | `pkg_redemption_mgmt` (line 56) | → `random()` |
| **Local/nested functions** | 2 | `fn_validate_redemption`, `pr_recalculate_tiers` | → Extract to standalone functions (PL/pgSQL does not support nested functions) |

### 5.2 Low-Priority Patterns (automatic or trivial conversion)

| Pattern | Occurrences | Conversion |
|---|---|---|
| `SYSDATE` | ~60 | → `CURRENT_TIMESTAMP` / `NOW()` |
| `NVL(a, b)` | ~30 | → `COALESCE(a, b)` |
| `DECODE(col, v1, r1, ...)` | 4 | → `CASE col WHEN v1 THEN r1 ...` |
| `RAISE_APPLICATION_ERROR(-xxxxx, msg)` | ~20 | → `RAISE EXCEPTION '%', msg USING ERRCODE = 'P0001'` |
| `DBMS_OUTPUT.PUT_LINE(...)` | ~12 | → `RAISE NOTICE '%', ...` |
| `seq_xxx.NEXTVAL` / `.CURRVAL` | ~15 | → `nextval('seq_xxx')` / `currval('seq_xxx')` |
| `SYS_REFCURSOR` | ~10 | → `REFCURSOR` |
| `ADD_MONTHS(d, n)` | ~8 | → `d + interval 'n months'` |
| `TRUNC(date, 'MM')` | ~5 | → `date_trunc('month', date)` |
| `MONTHS_BETWEEN(a, b)` | 1 | → `EXTRACT(EPOCH FROM (a - b)) / 2592000` |
| `REGEXP_LIKE(str, pattern)` | 2 | → `str ~ 'pattern'` |
| `DETERMINISTIC` | 1 | → `IMMUTABLE` |
| `FETCH FIRST n ROWS ONLY` | 4 | → `LIMIT n` |
| `INITCAP(...)` | 1 | Compatible — exists in PG |
| `:NEW.col` / `:OLD.col` in triggers | ~30 | → `NEW.col` / `OLD.col` |
| `INSERTING` / `UPDATING` / `DELETING` | 6 | → `TG_OP = 'INSERT'` / `'UPDATE'` / `'DELETE'` |

---

## 6. Prioritized Migration Plan

### Phase 1: Schema & Static Objects (Days 1–3)

| Task | Effort | Priority |
|---|---|---|
| Convert data types in table DDL (NUMBER → integer/bigint/numeric, VARCHAR2 → varchar, DATE → timestamp, CLOB → text) | 0.5d | P1 |
| Convert sequences (syntax is largely compatible) | 0.25d | P1 |
| Convert B-tree indexes (drop bitmap, convert to standard) | 0.5d | P1 |
| Convert Oracle Text index to `tsvector`/GIN | 0.5d | P1 |
| Convert constraints and comments | 0.25d | P1 |
| Drop synonyms (update application references) | 0.25d | P1 |

### Phase 2: Core PL/SQL Packages (Days 4–10)

| Task | Effort | Priority |
|---|---|---|
| Convert `pkg_validation` → standalone functions | 1d | P1 |
| Convert `pkg_audit` → functions (resolve AUTONOMOUS_TRANSACTION) | 1.5d | P1 |
| Convert `pkg_member_mgmt` → functions/procedures | 1.5d | P1 |
| Convert `pkg_notification` → functions/procedures | 1d | P1 |
| Convert `pkg_flight_accrual` → functions/procedures | 1.5d | P2 |
| Convert `pkg_tier_calculation` → functions (resolve CONNECT BY) | 1d | P2 |
| Convert `pkg_redemption_mgmt` → functions/procedures | 1d | P2 |
| Convert `pkg_partner_integration` → functions/procedures | 1d | P2 |

### Phase 3: Batch Processing & Reporting (Days 11–14)

| Task | Effort | Priority |
|---|---|---|
| Convert `pkg_batch_processing` (BULK COLLECT/FORALL rewrite) | 1.5d | P2 |
| Convert `pkg_reporting` → functions | 1d | P2 |
| Convert standalone functions (`fn_*`) | 0.5d | P2 |
| Convert standalone procedures (`pr_*`) — BULK COLLECT rewrite | 1.5d | P2 |

### Phase 4: Views, Triggers & Advanced Objects (Days 15–19)

| Task | Effort | Priority |
|---|---|---|
| Convert views (DECODE → CASE, MONTHS_BETWEEN, TRUNC) | 0.5d | P2 |
| Convert materialized views (remove Oracle-specific refresh options) | 1d | P2 |
| Convert triggers (split into function + trigger, :NEW/:OLD) | 1d | P2 |
| Rewrite Oracle AQ → `pgmq` or SKIP LOCKED pattern | 2d | P3 |
| Convert DBMS_SCHEDULER → pg_cron | 1.5d | P3 |

### Phase 5: Data Migration & Validation (Days 20–25)

| Task | Effort | Priority |
|---|---|---|
| Migrate reference data (tier rules, rewards, partners) | 0.5d | P1 |
| Migrate transactional data (members, flights, redemptions) | 1d | P1 |
| Validate row counts and data integrity | 1d | P1 |
| Functional regression testing | 2d | P1 |
| Performance testing and index tuning | 1d | P2 |

---

## 7. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| AUTONOMOUS_TRANSACTION in audit logging causes deadlocks | Medium | High | Use `dblink` to self or deferred trigger approach |
| BULK COLLECT/FORALL performance loss in PG | Medium | Medium | Use set-based operations where possible; benchmark with production data volumes |
| Oracle AQ replacement lacks feature parity | Low | High | Evaluate `pgmq` extension on Azure; fall back to Azure Service Bus if needed |
| Oracle Text search quality differs from PG `tsvector` | Low | Medium | Test full-text search behavior with actual reward descriptions |
| Materialized view refresh without FAST REFRESH | Low | Low | PG only supports COMPLETE refresh; schedule during low-traffic windows |
| CONNECT BY query complexity | Low | Low | Tier hierarchy is flat — simple ORDER BY suffices |

---

## 8. Files Analyzed

| Directory | Files | Total Lines |
|---|---|---|
| `oracle/schema/` | 4 files | 610 |
| `oracle/packages/` | 10 files | 2,208 |
| `oracle/functions/` | 3 files | 175 |
| `oracle/procedures/` | 3 files | 302 |
| `oracle/views/` | 4 files | 226 |
| `oracle/triggers/` | 3 files | 174 |
| `oracle/synonyms/` | 1 file | 44 |
| `oracle/queues/` | 1 file | 160 |
| `oracle/scheduler/` | 3 files | 194 |
| `oracle/data/` | 6 files | 506 |
| `oracle/setup.sql` | 1 file | 109 |
| **Total** | **39 files** | **4,708** |

---

*Report generated by ora2pg assessment simulation for SkyReward Airlines Oracle-to-PostgreSQL migration planning.*
