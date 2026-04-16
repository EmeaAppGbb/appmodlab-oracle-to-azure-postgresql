-- ========================================
-- PostgreSQL Master Setup Script
-- ========================================
-- SkyReward Airlines Loyalty Program Database
-- Converted from Oracle to PostgreSQL
--
-- Usage:
--   psql -U <username> -d <database> -f setup.sql
--
-- Execution order:
--   1. Tables (with inline PK, FK, UNIQUE, CHECK constraints)
--   2. Sequences (with default value bindings to table columns)
--   3. Indexes (B-tree and GIN full-text)
--   4. Additional constraints (cross-table foreign keys)
--   5. Synonym replacements (views and search_path config)
--   6. Functions (standalone utilities first, then domain packages)
--   7. Procedures (depend on functions)
--   8. Triggers (depend on tables and functions)
--   9. Views and materialized views
--  10. Reference and seed data
--  11. Queues (pgmq - optional)
--  12. Scheduler jobs (pg_cron - optional)

-- ========================================
-- Phase 1: Schema (tables, sequences, indexes, constraints)
-- ========================================
\echo '=== Creating tables ==='
\i schema/01_tables.sql

\echo '=== Creating sequences ==='
\i schema/02_sequences.sql

\echo '=== Creating indexes ==='
\i schema/03_indexes.sql

\echo '=== Adding additional constraints ==='
\i schema/04_constraints.sql

\echo '=== Setting up synonym replacements (views & search_path) ==='
\i schema/05_synonyms_to_views.sql

-- ========================================
-- Phase 2: Functions (dependency order)
-- ========================================
\echo '=== Creating validation functions ==='
\i functions/validation.sql

\echo '=== Creating audit functions ==='
\i functions/audit.sql

\echo '=== Creating notification functions ==='
\i functions/notification.sql

\echo '=== Creating batch processing functions ==='
\i functions/batch_processing.sql

\echo '=== Creating standalone calculation functions ==='
\i functions/fn_calculate_miles.sql
\i functions/fn_get_tier_status.sql
\i functions/fn_validate_redemption.sql

\echo '=== Creating member management functions ==='
\i functions/member_mgmt.sql

\echo '=== Creating flight accrual functions ==='
\i functions/flight_accrual.sql

\echo '=== Creating tier calculation functions ==='
\i functions/tier_calculation.sql

\echo '=== Creating redemption management functions ==='
\i functions/redemption_mgmt.sql

\echo '=== Creating partner integration functions ==='
\i functions/partner_integration.sql

\echo '=== Creating reporting functions ==='
\i functions/reporting.sql

-- ========================================
-- Phase 3: Procedures
-- ========================================
\echo '=== Creating procedures ==='
\i procedures/pr_expire_miles.sql
\i procedures/pr_process_bulk_accrual.sql
\i procedures/pr_recalculate_tiers.sql

-- ========================================
-- Phase 4: Triggers
-- ========================================
\echo '=== Creating triggers ==='
\i triggers/trg_member_audit.sql
\i triggers/trg_flight_validation.sql
\i triggers/trg_redemption_audit.sql

-- ========================================
-- Phase 5: Views and materialized views
-- ========================================
\echo '=== Creating views ==='
\i views/vw_member_summary.sql
\i views/vw_tier_status_report.sql

\echo '=== Creating materialized views ==='
\i views/mvw_monthly_accruals.sql
\i views/mvw_partner_summary.sql

-- ========================================
-- Phase 6: Reference and seed data
-- ========================================
\echo '=== Loading data ==='
\i data/01_tier_rules.sql
\i data/02_rewards.sql
\i data/03_members.sql
\i data/04_flights.sql
\i data/05_redemptions.sql
\i data/06_partner_transactions.sql

-- ========================================
-- Phase 7: Optional extensions (pgmq, pg_cron)
-- ========================================
\echo '=== Setting up queues (requires pgmq extension) ==='
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'pgmq') THEN
        CREATE EXTENSION IF NOT EXISTS pgmq;
        RAISE NOTICE 'pgmq extension enabled – loading queue definitions';
    ELSE
        RAISE NOTICE 'pgmq extension not available – skipping queue setup';
    END IF;
END;
$$;
-- Only load queue script if pgmq is actually installed
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgmq') THEN
        RAISE NOTICE 'Loading reward_fulfillment_queue.sql';
    ELSE
        RAISE NOTICE 'Skipping reward_fulfillment_queue.sql (pgmq not installed)';
    END IF;
END;
$$;
\if `SELECT EXISTS(SELECT 1 FROM pg_extension WHERE extname = 'pgmq')::text`
\i queues/reward_fulfillment_queue.sql
\endif

\echo '=== Setting up scheduler jobs (requires pg_cron extension) ==='
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'pg_cron') THEN
        CREATE EXTENSION IF NOT EXISTS pg_cron;
        RAISE NOTICE 'pg_cron extension enabled – loading scheduler jobs';
    ELSE
        RAISE NOTICE 'pg_cron extension not available – skipping scheduler setup';
    END IF;
END;
$$;
\if `SELECT EXISTS(SELECT 1 FROM pg_extension WHERE extname = 'pg_cron')::text`
\i scheduler/job_expire_miles.sql
\i scheduler/job_materialized_view_refresh.sql
\i scheduler/job_tier_recalc.sql
\endif

\echo '=== PostgreSQL setup complete ==='
