# APPMODLAB: Oracle to Azure PostgreSQL Migration

**Business Domain:** Airline Loyalty Program (SkyReward Airlines)

## Overview
This lab demonstrates migrating a complex Oracle 19c database to Azure Database for PostgreSQL Flexible Server. The legacy system uses extensive Oracle-specific features including PL/SQL packages, sequences, materialized views, Oracle Advanced Queuing, DBMS_SCHEDULER, and Oracle Text search.

## Oracle Features Demonstrated
- **50+ PL/SQL Packages** - Business logic in package specifications and bodies
- **Sequences** - Oracle sequences for ID generation (convert to SERIAL/BIGSERIAL)
- **Materialized Views** - Pre-aggregated reporting data with scheduled refresh
- **Oracle Advanced Queuing** - Async message processing for reward fulfillment
- **DBMS_SCHEDULER** - Scheduled jobs for batch processing
- **Oracle Text** - Full-text search on rewards catalog
- **Synonyms** - Public and private synonyms for schema abstraction
- **CONNECT BY** - Hierarchical queries for referral chains
- **BULK COLLECT/FORALL** - High-performance bulk operations
- **Ref Cursors** - Dynamic result sets
- **Autonomous Transactions** - Independent transaction control
- **Oracle-specific Data Types** - NUMBER, VARCHAR2, CLOB, DATE
- **Oracle-specific Functions** - ADD_MONTHS, MONTHS_BETWEEN, TRUNC, DECODE

## Database Schema
- **members** - 100+ member records with tier status
- **flights** - 1000+ flight accrual transactions
- **redemptions** - Reward redemption history
- **rewards** - Catalog of redeemable rewards
- **partner_transactions** - Partner earn/burn transactions
- **tier_rules** - Tier qualification rules (5 tiers)
- **partners** - Partner organizations
- **miles_expiry** - Miles expiration tracking
- **audit_log** - Comprehensive audit trail
- **notifications** - Member notification queue

## Quick Start

### 1. Start Oracle Database
```bash
docker-compose up -d
docker logs -f skyreward-oracle
```

### 2. Run Setup
```bash
# Wait for Oracle to be ready (check logs)
docker exec -it skyreward-oracle sqlplus system/OraclePass123@XEPDB1

-- Run setup script
@/docker-entrypoint-initdb.d/setup/setup.sql
```

### 3. Test PL/SQL Packages
```sql
-- Connect as application user
CONNECT skyreward/SkyReward123@XEPDB1

-- Test member management
DECLARE
  v_member_id NUMBER;
BEGIN
  v_member_id := pkg_member_mgmt.create_member(
    p_first_name => 'John',
    p_last_name  => 'Doe',
    p_email      => 'john.doe@example.com',
    p_phone      => '+15551234567'
  );
  DBMS_OUTPUT.PUT_LINE('Created member: ' || v_member_id);
END;
/

-- Test flight accrual
DECLARE
  v_flight_id NUMBER;
BEGIN
  v_flight_id := pkg_flight_accrual.post_flight_miles(
    p_member_id      => 1000000,
    p_flight_number  => 'SR123',
    p_origin         => 'JFK',
    p_destination    => 'LAX',
    p_travel_date    => SYSDATE,
    p_booking_class  => 'J',
    p_distance_miles => 2500
  );
  DBMS_OUTPUT.PUT_LINE('Posted flight: ' || v_flight_id);
END;
/

-- Query member summary
SELECT * FROM vw_member_summary WHERE member_id = 1000000;

-- Test reporting
SELECT * FROM TABLE(pkg_reporting.get_tier_distribution());
```

## Migration Tools

### ora2pg Assessment
```bash
# Generate assessment report
ora2pg -t SHOW_VERSION -c ora2pg.conf
ora2pg -t SHOW_REPORT -c ora2pg.conf > assessment_report.html
```

### Schema Conversion
```bash
# Export DDL
ora2pg -t TABLE,VIEW,SEQUENCE,TRIGGER -c ora2pg.conf -o schema.sql

# Export PL/SQL
ora2pg -t PACKAGE,PROCEDURE,FUNCTION -c ora2pg.conf -o plsql.sql
```

## Key Migration Challenges
1. **PL/SQL Packages → PL/pgSQL Functions** - Rewrite packages as grouped functions
2. **Sequences** - Convert to SERIAL/BIGSERIAL or explicit sequences
3. **Materialized Views** - Map to PostgreSQL materialized views + pg_cron
4. **Oracle AQ → pgmq/Service Bus** - Replace queuing mechanism
5. **DBMS_SCHEDULER → pg_cron** - Replace scheduling mechanism
6. **Oracle Text → Full-Text Search** - Convert to tsvector/tsquery
7. **CONNECT BY → Recursive CTEs** - Rewrite hierarchical queries
8. **FORALL/BULK COLLECT** - Optimize with batch operations
9. **Synonyms** - Use schemas or remove
10. **Oracle-specific Functions** - Replace with PostgreSQL equivalents

## File Structure
```
oracle/
├── setup.sql                  # Master setup script
├── schema/                    # DDL scripts
│   ├── 01_sequences.sql
│   ├── 02_tables.sql
│   ├── 03_indexes.sql
│   └── 04_constraints.sql
├── packages/                  # 10 PL/SQL packages
│   ├── pkg_member_mgmt.sql
│   ├── pkg_flight_accrual.sql
│   ├── pkg_tier_calculation.sql
│   ├── pkg_redemption_mgmt.sql
│   ├── pkg_partner_integration.sql
│   ├── pkg_reporting.sql
│   ├── pkg_batch_processing.sql
│   ├── pkg_validation.sql
│   ├── pkg_audit.sql
│   └── pkg_notification.sql
├── functions/                 # Standalone functions
│   ├── fn_calculate_miles.sql
│   ├── fn_get_tier_status.sql
│   └── fn_validate_redemption.sql
├── procedures/                # Standalone procedures
│   ├── pr_expire_miles.sql
│   ├── pr_recalculate_tiers.sql
│   └── pr_process_bulk_accrual.sql
├── views/                     # Views and materialized views
│   ├── vw_member_summary.sql
│   ├── vw_tier_status_report.sql
│   ├── mvw_monthly_accruals.sql
│   └── mvw_partner_summary.sql
├── synonyms/                  # Public/private synonyms
│   └── synonyms.sql
├── triggers/                  # Database triggers
│   ├── trg_member_audit.sql
│   ├── trg_flight_validation.sql
│   └── trg_redemption_audit.sql
├── queues/                    # Oracle AQ setup
│   └── reward_fulfillment_queue.sql
├── scheduler/                 # DBMS_SCHEDULER jobs
│   ├── job_expire_miles.sql
│   ├── job_tier_recalc.sql
│   └── job_materialized_view_refresh.sql
└── data/                      # Sample data
    ├── 01_tier_rules.sql
    ├── 02_rewards.sql
    ├── 03_members.sql
    ├── 04_flights.sql
    ├── 05_redemptions.sql
    └── 06_partner_transactions.sql
```

## Database Statistics
- **Tables:** 11 core tables
- **Sequences:** 10 sequences
- **Packages:** 10 PL/SQL packages (spec + body)
- **Functions:** 3 standalone functions
- **Procedures:** 3 standalone procedures
- **Views:** 2 views + 2 materialized views
- **Triggers:** 3 triggers
- **Indexes:** 25+ indexes (including bitmap and Oracle Text)
- **Synonyms:** 15+ synonyms
- **Scheduler Jobs:** 3 scheduled jobs
- **Sample Data:** 100+ members, 1000+ flights, rewards catalog, partner transactions

## Next Steps
1. Review Oracle database structure and PL/SQL code
2. Run ora2pg assessment to identify migration complexity
3. Convert schema and PL/SQL to PostgreSQL
4. Set up Azure Database for PostgreSQL Flexible Server
5. Migrate data using Azure DMS
6. Test and validate migrated application

## License
Internal use for Microsoft GBB App Modernization Labs
