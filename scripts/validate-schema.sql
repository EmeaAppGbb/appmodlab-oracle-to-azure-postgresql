-- ============================================================================
-- Schema Validation Script
-- ============================================================================
-- Validates that all expected schema objects exist in the PostgreSQL database
-- after migration from Oracle.
--
-- Usage:
--   psql -U skyreward_admin -d skyreward -f scripts/validate-schema.sql
--
-- Exit codes: psql returns non-zero if any RAISE EXCEPTION fires
-- ============================================================================

\echo ''
\echo '========================================'
\echo '  SCHEMA VALIDATION – SkyReward DB'
\echo '========================================'
\echo ''

-- ============================================================================
-- Helper: temporary table to collect validation results
-- ============================================================================
CREATE TEMPORARY TABLE _validation_results (
    category   TEXT,
    object_name TEXT,
    status     TEXT   -- PASS / FAIL
);

-- ============================================================================
-- 1. Tables
-- ============================================================================
\echo '--- Checking Tables ---'

DO $$
DECLARE
    expected_tables TEXT[] := ARRAY[
        'members', 'flights', 'rewards', 'redemptions', 'partners',
        'partner_transactions', 'tier_rules', 'miles_expiry', 'audit_log',
        'notifications', 'batch_processing_log'
    ];
    t TEXT;
BEGIN
    FOREACH t IN ARRAY expected_tables LOOP
        IF EXISTS (
            SELECT 1 FROM information_schema.tables
             WHERE table_schema = current_schema()
               AND table_type = 'BASE TABLE'
               AND table_name = t
        ) THEN
            INSERT INTO _validation_results VALUES ('TABLE', t, 'PASS');
        ELSE
            INSERT INTO _validation_results VALUES ('TABLE', t, 'FAIL');
        END IF;
    END LOOP;
END;
$$;

SELECT status, object_name FROM _validation_results WHERE category = 'TABLE' ORDER BY object_name;

-- ============================================================================
-- 2. Sequences
-- ============================================================================
\echo ''
\echo '--- Checking Sequences ---'

DO $$
DECLARE
    expected_seqs TEXT[] := ARRAY[
        'seq_member_id', 'seq_flight_id', 'seq_redemption_id', 'seq_reward_id',
        'seq_partner_txn_id', 'seq_tier_rule_id', 'seq_audit_id',
        'seq_notification_id', 'seq_partner_id', 'seq_expiry_id', 'seq_batch_id'
    ];
    s TEXT;
BEGIN
    FOREACH s IN ARRAY expected_seqs LOOP
        IF EXISTS (
            SELECT 1 FROM information_schema.sequences
             WHERE sequence_schema = current_schema()
               AND sequence_name = s
        ) THEN
            INSERT INTO _validation_results VALUES ('SEQUENCE', s, 'PASS');
        ELSE
            INSERT INTO _validation_results VALUES ('SEQUENCE', s, 'FAIL');
        END IF;
    END LOOP;
END;
$$;

SELECT status, object_name FROM _validation_results WHERE category = 'SEQUENCE' ORDER BY object_name;

-- ============================================================================
-- 3. Indexes (spot-check key indexes)
-- ============================================================================
\echo ''
\echo '--- Checking Indexes ---'

DO $$
DECLARE
    expected_indexes TEXT[] := ARRAY[
        'idx_members_name', 'idx_members_tier', 'idx_members_status',
        'idx_flights_member', 'idx_flights_date', 'idx_flights_member_date',
        'idx_flights_accrual_status',
        'idx_redemptions_member', 'idx_redemptions_status',
        'idx_rewards_category', 'idx_rewards_miles', 'idx_rewards_desc_text',
        'idx_partner_txn_member', 'idx_partner_txn_date',
        'idx_tier_rules_name',
        'idx_miles_expiry_member', 'idx_miles_expiry_date',
        'idx_audit_table', 'idx_audit_date',
        'idx_notif_status', 'idx_notif_scheduled',
        'idx_batch_type', 'idx_batch_status'
    ];
    i TEXT;
BEGIN
    FOREACH i IN ARRAY expected_indexes LOOP
        IF EXISTS (
            SELECT 1 FROM pg_indexes
             WHERE schemaname = current_schema()
               AND indexname = i
        ) THEN
            INSERT INTO _validation_results VALUES ('INDEX', i, 'PASS');
        ELSE
            INSERT INTO _validation_results VALUES ('INDEX', i, 'FAIL');
        END IF;
    END LOOP;
END;
$$;

SELECT status, object_name FROM _validation_results WHERE category = 'INDEX' ORDER BY object_name;

-- ============================================================================
-- 4. Views (business + synonym alias views)
-- ============================================================================
\echo ''
\echo '--- Checking Views ---'

DO $$
DECLARE
    expected_views TEXT[] := ARRAY[
        -- Business views
        'vw_member_summary', 'vw_tier_status_report',
        -- Synonym alias views
        'mem', 'flt', 'rdm', 'rwd', 'ptr', 'ptr_txn',
        'tr', 'aud', 'notif', 'batch_log', 'mexp'
    ];
    v TEXT;
BEGIN
    FOREACH v IN ARRAY expected_views LOOP
        IF EXISTS (
            SELECT 1 FROM information_schema.views
             WHERE table_schema = current_schema()
               AND table_name = v
        ) THEN
            INSERT INTO _validation_results VALUES ('VIEW', v, 'PASS');
        ELSE
            INSERT INTO _validation_results VALUES ('VIEW', v, 'FAIL');
        END IF;
    END LOOP;
END;
$$;

SELECT status, object_name FROM _validation_results WHERE category = 'VIEW' ORDER BY object_name;

-- ============================================================================
-- 5. Materialized Views
-- ============================================================================
\echo ''
\echo '--- Checking Materialized Views ---'

DO $$
DECLARE
    expected_matviews TEXT[] := ARRAY[
        'mvw_monthly_accruals', 'mvw_partner_summary'
    ];
    mv TEXT;
BEGIN
    FOREACH mv IN ARRAY expected_matviews LOOP
        IF EXISTS (
            SELECT 1 FROM pg_matviews
             WHERE schemaname = current_schema()
               AND matviewname = mv
        ) THEN
            INSERT INTO _validation_results VALUES ('MATVIEW', mv, 'PASS');
        ELSE
            INSERT INTO _validation_results VALUES ('MATVIEW', mv, 'FAIL');
        END IF;
    END LOOP;
END;
$$;

SELECT status, object_name FROM _validation_results WHERE category = 'MATVIEW' ORDER BY object_name;

-- ============================================================================
-- 6. Functions / Procedures
-- ============================================================================
\echo ''
\echo '--- Checking Functions ---'

DO $$
DECLARE
    expected_functions TEXT[] := ARRAY[
        -- member_mgmt
        'member_mgmt_generate_membership_number',
        'member_mgmt_register_member',
        'member_mgmt_update_member_profile',
        'member_mgmt_get_member',
        'member_mgmt_search_members',
        'member_mgmt_update_miles_balance',
        'member_mgmt_change_member_status',
        'member_mgmt_merge_members',
        -- flight_accrual
        'flight_accrual_cabin_multiplier',
        'flight_accrual_calculate_base_miles',
        'flight_accrual_calculate_bonus_miles',
        'flight_accrual_record_flight',
        'flight_accrual_process_pending_accruals',
        'flight_accrual_reverse_accrual',
        'flight_accrual_retroactive_accrual',
        -- tier_calculation
        'tier_calculation_get_qualifying_miles',
        'tier_calculation_get_qualifying_segments',
        'tier_calculation_evaluate_tier',
        'tier_calculation_recalculate_member_tier',
        'tier_calculation_recalculate_all_tiers',
        'tier_calculation_get_tier_hierarchy',
        'tier_calculation_check_upgrade_eligibility',
        -- redemption_mgmt
        'redemption_mgmt_generate_confirmation_code',
        'redemption_mgmt_check_reward_available',
        'redemption_mgmt_redeem_reward',
        'redemption_mgmt_cancel_redemption',
        'redemption_mgmt_fulfill_redemption',
        'redemption_mgmt_get_member_redemptions',
        -- standalone functions
        'fn_calculate_miles',
        'fn_get_tier_status',
        'fn_validate_redemption',
        'fn_tier_rank',
        -- partner_integration
        'partner_integration_get_conversion_rate',
        'partner_integration_record_partner_earn',
        'partner_integration_record_partner_redeem',
        'partner_integration_transfer_miles',
        'partner_integration_process_settlement',
        'partner_integration_get_partner_summary',
        -- audit
        'audit_log_change',
        'audit_get_audit_trail',
        'audit_get_member_audit_trail',
        'audit_purge_audit_records',
        'audit_get_audit_summary',
        -- batch_processing
        'batch_processing_start_batch',
        'batch_processing_complete_batch',
        'batch_processing_run_miles_expiry',
        'batch_processing_run_tier_recalculation',
        'batch_processing_run_data_cleanup',
        'batch_processing_run_ytd_miles_reset',
        'batch_processing_run_statement_generation',
        'batch_processing_get_batch_status',
        'batch_processing_get_batch_history',
        -- notification
        'notification_send_notification',
        'notification_process_pending',
        'notification_retry_failed',
        'notification_get_member_notifications',
        'notification_cancel_notification',
        'notification_get_notification_stats',
        -- reporting
        'reporting_get_dashboard_kpis',
        'reporting_get_tier_distribution',
        'reporting_get_monthly_accrual_trend',
        'reporting_get_top_earners',
        'reporting_get_partner_performance',
        'reporting_get_redemption_analytics',
        'reporting_generate_liability_report',
        'reporting_generate_member_statement',
        -- validation
        'validation_validate_member_active',
        'validation_is_valid_email',
        'validation_is_valid_airport_code',
        'validation_is_valid_flight_date',
        'validation_is_valid_miles_amount',
        'validation_is_valid_tier',
        'validation_is_valid_booking_class',
        'validation_validate_redemption',
        'validation_validate_partner_active',
        -- procedures (implemented as functions)
        'pr_expire_miles',
        'pr_process_bulk_accrual',
        'pr_recalculate_tiers',
        -- trigger functions
        'fn_trg_flight_validation',
        'fn_trg_member_audit',
        'fn_trg_redemption_audit'
    ];
    f TEXT;
BEGIN
    FOREACH f IN ARRAY expected_functions LOOP
        IF EXISTS (
            SELECT 1 FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = current_schema()
              AND p.proname = f
        ) THEN
            INSERT INTO _validation_results VALUES ('FUNCTION', f, 'PASS');
        ELSE
            INSERT INTO _validation_results VALUES ('FUNCTION', f, 'FAIL');
        END IF;
    END LOOP;
END;
$$;

SELECT status, object_name FROM _validation_results WHERE category = 'FUNCTION' ORDER BY object_name;

-- ============================================================================
-- 7. Triggers
-- ============================================================================
\echo ''
\echo '--- Checking Triggers ---'

DO $$
DECLARE
    expected_triggers TEXT[] := ARRAY[
        'trg_flight_validation',
        'trg_member_audit',
        'trg_redemption_audit'
    ];
    t TEXT;
BEGIN
    FOREACH t IN ARRAY expected_triggers LOOP
        IF EXISTS (
            SELECT 1 FROM information_schema.triggers
             WHERE trigger_schema = current_schema()
               AND trigger_name = t
        ) THEN
            INSERT INTO _validation_results VALUES ('TRIGGER', t, 'PASS');
        ELSE
            INSERT INTO _validation_results VALUES ('TRIGGER', t, 'FAIL');
        END IF;
    END LOOP;
END;
$$;

SELECT status, object_name FROM _validation_results WHERE category = 'TRIGGER' ORDER BY object_name;

-- ============================================================================
-- 8. Foreign Key Constraints
-- ============================================================================
\echo ''
\echo '--- Checking Foreign Key Constraints ---'

DO $$
DECLARE
    expected_fks TEXT[] := ARRAY[
        'fk_rewards_partner',
        'fk_miles_expiry_batch'
    ];
    fk TEXT;
BEGIN
    FOREACH fk IN ARRAY expected_fks LOOP
        IF EXISTS (
            SELECT 1 FROM information_schema.table_constraints
             WHERE constraint_schema = current_schema()
               AND constraint_type = 'FOREIGN KEY'
               AND constraint_name = fk
        ) THEN
            INSERT INTO _validation_results VALUES ('FK_CONSTRAINT', fk, 'PASS');
        ELSE
            INSERT INTO _validation_results VALUES ('FK_CONSTRAINT', fk, 'FAIL');
        END IF;
    END LOOP;
END;
$$;

SELECT status, object_name FROM _validation_results WHERE category = 'FK_CONSTRAINT' ORDER BY object_name;

-- ============================================================================
-- 9. Optional extensions (informational – not failures)
-- ============================================================================
\echo ''
\echo '--- Optional Extensions ---'

SELECT
    CASE WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgmq')
         THEN 'INSTALLED' ELSE 'NOT INSTALLED' END AS pgmq_status,
    CASE WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron')
         THEN 'INSTALLED' ELSE 'NOT INSTALLED' END AS pg_cron_status;

-- ============================================================================
-- SUMMARY
-- ============================================================================
\echo ''
\echo '========================================'
\echo '  VALIDATION SUMMARY'
\echo '========================================'
\echo ''

SELECT
    category,
    COUNT(*) FILTER (WHERE status = 'PASS') AS passed,
    COUNT(*) FILTER (WHERE status = 'FAIL') AS failed,
    COUNT(*) AS total
FROM _validation_results
GROUP BY category
ORDER BY category;

\echo ''

-- Report overall pass/fail
DO $$
DECLARE
    fail_count INT;
BEGIN
    SELECT COUNT(*) INTO fail_count FROM _validation_results WHERE status = 'FAIL';

    IF fail_count = 0 THEN
        RAISE NOTICE '✅  ALL SCHEMA OBJECTS VALIDATED SUCCESSFULLY';
    ELSE
        RAISE NOTICE '❌  SCHEMA VALIDATION FAILED – % object(s) missing:', fail_count;
        -- List failures
        PERFORM (
            SELECT string_agg(category || ': ' || object_name, E'\n')
              FROM _validation_results WHERE status = 'FAIL'
        );
        -- Show failures in output
        RAISE EXCEPTION '% schema object(s) missing. Run with -a flag to see details.', fail_count;
    END IF;
END;
$$;

-- Show failures for review (if any, this won't be reached after exception above)
SELECT category, object_name FROM _validation_results WHERE status = 'FAIL' ORDER BY category, object_name;

DROP TABLE IF EXISTS _validation_results;
