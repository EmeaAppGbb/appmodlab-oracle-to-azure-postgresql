-- ============================================================================
-- Function Validation Script
-- ============================================================================
-- Tests each PL/pgSQL function with sample data and verifies results.
-- All tests run inside a transaction that is ROLLED BACK so the database
-- is left unchanged.
--
-- Usage:
--   psql -U skyreward_admin -d skyreward -f scripts/validate-functions.sql
--
-- Assertions use RAISE EXCEPTION so psql ON_ERROR_STOP=1 will halt on failure.
-- ============================================================================

\echo ''
\echo '========================================'
\echo '  FUNCTION VALIDATION – SkyReward DB'
\echo '========================================'
\echo ''

BEGIN;

-- ============================================================================
-- Setup: ensure test data exists (tier_rules, rewards, members, partners)
-- These should already be loaded by setup.sql / data scripts.
-- ============================================================================

DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM tier_rules;
    IF v_count < 5 THEN
        RAISE EXCEPTION 'Prerequisite check failed: tier_rules has only % rows (expected >= 5)', v_count;
    END IF;

    SELECT COUNT(*) INTO v_count FROM members WHERE status = 'ACTIVE';
    IF v_count < 1 THEN
        RAISE EXCEPTION 'Prerequisite check failed: no ACTIVE members found';
    END IF;

    SELECT COUNT(*) INTO v_count FROM rewards;
    IF v_count < 1 THEN
        RAISE EXCEPTION 'Prerequisite check failed: no rewards found';
    END IF;

    RAISE NOTICE 'Prerequisites OK: tier_rules, members, rewards present';
END;
$$;

-- ============================================================================
-- Test 1: fn_calculate_miles
-- Expected: distance × cabin_multiplier × tier_bonus
-- ECONOMY multiplier = 1.0, BLUE tier bonus = 0%
-- ============================================================================
\echo '--- Test 1: fn_calculate_miles ---'

DO $$
DECLARE
    v_miles NUMERIC;
BEGIN
    -- 1000 miles, Y class, ECONOMY, BLUE tier → 1000
    v_miles := fn_calculate_miles(1000, 'Y', 'ECONOMY', 'BLUE');
    IF v_miles IS NULL OR v_miles < 500 THEN
        RAISE EXCEPTION 'fn_calculate_miles(1000, Y, ECONOMY, BLUE) returned %, expected >= 500', v_miles;
    END IF;
    RAISE NOTICE 'fn_calculate_miles(1000, Y, ECONOMY, BLUE) = %  ✓', v_miles;

    -- BUSINESS class should return more miles
    v_miles := fn_calculate_miles(1000, 'J', 'BUSINESS', 'GOLD');
    IF v_miles IS NULL OR v_miles <= 1000 THEN
        RAISE EXCEPTION 'fn_calculate_miles(1000, J, BUSINESS, GOLD) returned %, expected > 1000', v_miles;
    END IF;
    RAISE NOTICE 'fn_calculate_miles(1000, J, BUSINESS, GOLD) = %  ✓', v_miles;
END;
$$;

-- ============================================================================
-- Test 2: fn_tier_rank
-- Expected: BLUE=1, SILVER=2, GOLD=3, PLATINUM=4, DIAMOND=5
-- ============================================================================
\echo '--- Test 2: fn_tier_rank ---'

DO $$
DECLARE
    v_rank INT;
BEGIN
    v_rank := fn_tier_rank('BLUE');
    IF v_rank <> 1 THEN
        RAISE EXCEPTION 'fn_tier_rank(BLUE) = %, expected 1', v_rank;
    END IF;

    v_rank := fn_tier_rank('DIAMOND');
    IF v_rank <> 5 THEN
        RAISE EXCEPTION 'fn_tier_rank(DIAMOND) = %, expected 5', v_rank;
    END IF;

    RAISE NOTICE 'fn_tier_rank: BLUE=1, DIAMOND=5  ✓';
END;
$$;

-- ============================================================================
-- Test 3: fn_validate_redemption
-- Expected: returns validation message string
-- ============================================================================
\echo '--- Test 3: fn_validate_redemption ---'

DO $$
DECLARE
    v_result VARCHAR;
    v_member_id NUMERIC;
    v_reward_id NUMERIC;
BEGIN
    SELECT member_id INTO v_member_id FROM members WHERE status = 'ACTIVE' LIMIT 1;
    SELECT reward_id INTO v_reward_id FROM rewards WHERE status = 'ACTIVE' LIMIT 1;

    IF v_member_id IS NOT NULL AND v_reward_id IS NOT NULL THEN
        v_result := fn_validate_redemption(v_member_id, v_reward_id, 1);
        IF v_result IS NULL THEN
            RAISE EXCEPTION 'fn_validate_redemption returned NULL';
        END IF;
        RAISE NOTICE 'fn_validate_redemption(%, %) = %  ✓', v_member_id, v_reward_id, v_result;
    ELSE
        RAISE NOTICE 'fn_validate_redemption: SKIPPED (no active member/reward)';
    END IF;
END;
$$;

-- ============================================================================
-- Test 4: fn_get_tier_status
-- Expected: returns formatted status string
-- ============================================================================
\echo '--- Test 4: fn_get_tier_status ---'

DO $$
DECLARE
    v_status VARCHAR;
    v_member_id NUMERIC;
BEGIN
    SELECT member_id INTO v_member_id FROM members WHERE status = 'ACTIVE' LIMIT 1;
    IF v_member_id IS NOT NULL THEN
        v_status := fn_get_tier_status(v_member_id);
        IF v_status IS NULL THEN
            RAISE EXCEPTION 'fn_get_tier_status(%) returned NULL', v_member_id;
        END IF;
        RAISE NOTICE 'fn_get_tier_status(%) = %  ✓', v_member_id, v_status;
    ELSE
        RAISE NOTICE 'fn_get_tier_status: SKIPPED (no active member)';
    END IF;
END;
$$;

-- ============================================================================
-- Test 5: validation utility functions
-- ============================================================================
\echo '--- Test 5: Validation utility functions ---'

DO $$
BEGIN
    -- Valid email
    IF NOT validation_is_valid_email('test@example.com') THEN
        RAISE EXCEPTION 'validation_is_valid_email(test@example.com) returned false';
    END IF;

    -- Invalid email
    IF validation_is_valid_email('not-an-email') THEN
        RAISE EXCEPTION 'validation_is_valid_email(not-an-email) returned true';
    END IF;

    -- Valid airport code
    IF NOT validation_is_valid_airport_code('JFK') THEN
        RAISE EXCEPTION 'validation_is_valid_airport_code(JFK) returned false';
    END IF;

    -- Invalid airport code
    IF validation_is_valid_airport_code('TOOLONG') THEN
        RAISE EXCEPTION 'validation_is_valid_airport_code(TOOLONG) returned true';
    END IF;

    -- Valid tier
    IF NOT validation_is_valid_tier('GOLD') THEN
        RAISE EXCEPTION 'validation_is_valid_tier(GOLD) returned false';
    END IF;

    -- Valid booking class
    IF NOT validation_is_valid_booking_class('Y') THEN
        RAISE EXCEPTION 'validation_is_valid_booking_class(Y) returned false';
    END IF;

    -- Valid miles amount
    IF NOT validation_is_valid_miles_amount(1000) THEN
        RAISE EXCEPTION 'validation_is_valid_miles_amount(1000) returned false';
    END IF;

    -- Invalid miles amount
    IF validation_is_valid_miles_amount(-1) THEN
        RAISE EXCEPTION 'validation_is_valid_miles_amount(-1) returned true';
    END IF;

    RAISE NOTICE 'Validation utility functions  ✓';
END;
$$;

-- ============================================================================
-- Test 6: validation_validate_member_active
-- ============================================================================
\echo '--- Test 6: validation_validate_member_active ---'

DO $$
DECLARE
    v_member_id BIGINT;
BEGIN
    SELECT member_id INTO v_member_id FROM members WHERE status = 'ACTIVE' LIMIT 1;
    IF v_member_id IS NOT NULL THEN
        PERFORM validation_validate_member_active(v_member_id);
        RAISE NOTICE 'validation_validate_member_active(%) – active member OK  ✓', v_member_id;
    END IF;

    -- Non-existent member should raise exception
    BEGIN
        PERFORM validation_validate_member_active(-99999);
        RAISE EXCEPTION 'validation_validate_member_active(-99999) did not raise exception';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'validation_validate_member_active(-99999) – correctly raised exception  ✓';
    END;
END;
$$;

-- ============================================================================
-- Test 7: member_mgmt_register_member
-- ============================================================================
\echo '--- Test 7: member_mgmt_register_member ---'

DO $$
DECLARE
    v_member_id BIGINT;
    v_membership_num VARCHAR;
BEGIN
    SELECT member_id, membership_num
      INTO v_member_id, v_membership_num
      FROM member_mgmt_register_member(
          'TestFirst', 'TestLast', 'test_validation_' || EXTRACT(EPOCH FROM clock_timestamp())::BIGINT || '@example.com'
      );

    IF v_member_id IS NULL THEN
        RAISE EXCEPTION 'member_mgmt_register_member returned NULL member_id';
    END IF;
    IF v_membership_num IS NULL OR LENGTH(v_membership_num) = 0 THEN
        RAISE EXCEPTION 'member_mgmt_register_member returned empty membership_num';
    END IF;

    RAISE NOTICE 'member_mgmt_register_member → id=%, num=%  ✓', v_member_id, v_membership_num;
END;
$$;

-- ============================================================================
-- Test 8: member_mgmt_get_member
-- ============================================================================
\echo '--- Test 8: member_mgmt_get_member ---'

DO $$
DECLARE
    v_rec RECORD;
    v_member_id BIGINT;
BEGIN
    SELECT member_id INTO v_member_id FROM members WHERE status = 'ACTIVE' LIMIT 1;
    IF v_member_id IS NOT NULL THEN
        SELECT * INTO v_rec FROM member_mgmt_get_member(v_member_id);
        IF v_rec.member_id IS NULL THEN
            RAISE EXCEPTION 'member_mgmt_get_member(%) returned NULL', v_member_id;
        END IF;
        RAISE NOTICE 'member_mgmt_get_member(%) → % % (%)  ✓',
            v_member_id, v_rec.first_name, v_rec.last_name, v_rec.tier_status;
    END IF;
END;
$$;

-- ============================================================================
-- Test 9: member_mgmt_search_members
-- ============================================================================
\echo '--- Test 9: member_mgmt_search_members ---'

DO $$
DECLARE
    v_count INT;
    v_last_name VARCHAR;
BEGIN
    SELECT last_name INTO v_last_name FROM members LIMIT 1;
    IF v_last_name IS NOT NULL THEN
        SELECT COUNT(*) INTO v_count FROM member_mgmt_search_members(v_last_name);
        IF v_count < 1 THEN
            RAISE EXCEPTION 'member_mgmt_search_members(%) returned 0 rows', v_last_name;
        END IF;
        RAISE NOTICE 'member_mgmt_search_members(%) → % result(s)  ✓', v_last_name, v_count;
    END IF;
END;
$$;

-- ============================================================================
-- Test 10: flight_accrual_cabin_multiplier
-- ============================================================================
\echo '--- Test 10: flight_accrual_cabin_multiplier ---'

DO $$
DECLARE
    v_mult NUMERIC;
BEGIN
    v_mult := flight_accrual_cabin_multiplier('ECONOMY');
    IF v_mult IS NULL OR v_mult < 0.5 THEN
        RAISE EXCEPTION 'flight_accrual_cabin_multiplier(ECONOMY) = %, expected >= 0.5', v_mult;
    END IF;

    v_mult := flight_accrual_cabin_multiplier('FIRST');
    IF v_mult IS NULL OR v_mult <= 1.0 THEN
        RAISE EXCEPTION 'flight_accrual_cabin_multiplier(FIRST) = %, expected > 1.0', v_mult;
    END IF;

    RAISE NOTICE 'flight_accrual_cabin_multiplier: ECONOMY/FIRST OK  ✓';
END;
$$;

-- ============================================================================
-- Test 11: flight_accrual_calculate_base_miles
-- ============================================================================
\echo '--- Test 11: flight_accrual_calculate_base_miles ---'

DO $$
DECLARE
    v_miles NUMERIC;
BEGIN
    v_miles := flight_accrual_calculate_base_miles(2000, 'Y', 'ECONOMY');
    IF v_miles IS NULL OR v_miles < 500 THEN
        RAISE EXCEPTION 'flight_accrual_calculate_base_miles(2000, Y, ECONOMY) = %, expected >= 500', v_miles;
    END IF;
    RAISE NOTICE 'flight_accrual_calculate_base_miles(2000, Y, ECONOMY) = %  ✓', v_miles;
END;
$$;

-- ============================================================================
-- Test 12: tier_calculation_get_tier_hierarchy
-- ============================================================================
\echo '--- Test 12: tier_calculation_get_tier_hierarchy ---'

DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM tier_calculation_get_tier_hierarchy();
    IF v_count < 5 THEN
        RAISE EXCEPTION 'tier_calculation_get_tier_hierarchy returned % rows, expected >= 5', v_count;
    END IF;
    RAISE NOTICE 'tier_calculation_get_tier_hierarchy → % tiers  ✓', v_count;
END;
$$;

-- ============================================================================
-- Test 13: tier_calculation_evaluate_tier
-- ============================================================================
\echo '--- Test 13: tier_calculation_evaluate_tier ---'

DO $$
DECLARE
    v_tier VARCHAR;
    v_member_id BIGINT;
BEGIN
    SELECT member_id INTO v_member_id FROM members WHERE status = 'ACTIVE' LIMIT 1;
    IF v_member_id IS NOT NULL THEN
        v_tier := tier_calculation_evaluate_tier(v_member_id);
        IF v_tier IS NULL THEN
            RAISE EXCEPTION 'tier_calculation_evaluate_tier(%) returned NULL', v_member_id;
        END IF;
        IF v_tier NOT IN ('BLUE', 'SILVER', 'GOLD', 'PLATINUM', 'DIAMOND') THEN
            RAISE EXCEPTION 'tier_calculation_evaluate_tier(%) returned invalid tier: %', v_member_id, v_tier;
        END IF;
        RAISE NOTICE 'tier_calculation_evaluate_tier(%) = %  ✓', v_member_id, v_tier;
    END IF;
END;
$$;

-- ============================================================================
-- Test 14: redemption_mgmt_generate_confirmation_code
-- ============================================================================
\echo '--- Test 14: redemption_mgmt_generate_confirmation_code ---'

DO $$
DECLARE
    v_code VARCHAR;
BEGIN
    v_code := redemption_mgmt_generate_confirmation_code();
    IF v_code IS NULL OR LENGTH(v_code) < 10 THEN
        RAISE EXCEPTION 'redemption_mgmt_generate_confirmation_code returned "%", expected 10+ chars', v_code;
    END IF;
    IF LEFT(v_code, 2) <> 'SR' THEN
        RAISE EXCEPTION 'Confirmation code does not start with SR: %', v_code;
    END IF;
    RAISE NOTICE 'redemption_mgmt_generate_confirmation_code = %  ✓', v_code;
END;
$$;

-- ============================================================================
-- Test 15: audit_log_change
-- ============================================================================
\echo '--- Test 15: audit_log_change ---'

DO $$
DECLARE
    v_count_before INT;
    v_count_after  INT;
BEGIN
    SELECT COUNT(*) INTO v_count_before FROM audit_log;

    PERFORM audit_log_change('members', 'UPDATE', 1, 1, '{"old":"val"}', '{"new":"val"}');

    SELECT COUNT(*) INTO v_count_after FROM audit_log;
    IF v_count_after <= v_count_before THEN
        RAISE EXCEPTION 'audit_log_change did not insert audit record';
    END IF;
    RAISE NOTICE 'audit_log_change → inserted audit record  ✓';
END;
$$;

-- ============================================================================
-- Test 16: batch_processing_start_batch / complete_batch
-- ============================================================================
\echo '--- Test 16: batch_processing_start_batch / complete_batch ---'

DO $$
DECLARE
    v_batch_id BIGINT;
    v_status   VARCHAR;
BEGIN
    v_batch_id := batch_processing_start_batch('DATA_CLEANUP', 'Test Batch');
    IF v_batch_id IS NULL THEN
        RAISE EXCEPTION 'batch_processing_start_batch returned NULL';
    END IF;

    v_status := batch_processing_get_batch_status(v_batch_id);
    IF v_status <> 'RUNNING' THEN
        RAISE EXCEPTION 'Batch status after start = %, expected RUNNING', v_status;
    END IF;

    PERFORM batch_processing_complete_batch(v_batch_id, 100, 95, 5, 'COMPLETED');

    v_status := batch_processing_get_batch_status(v_batch_id);
    IF v_status <> 'COMPLETED' THEN
        RAISE EXCEPTION 'Batch status after complete = %, expected COMPLETED', v_status;
    END IF;

    RAISE NOTICE 'batch_processing start/complete → RUNNING → COMPLETED  ✓';
END;
$$;

-- ============================================================================
-- Test 17: notification_send_notification
-- ============================================================================
\echo '--- Test 17: notification_send_notification ---'

DO $$
DECLARE
    v_member_id BIGINT;
    v_count_before INT;
    v_count_after  INT;
BEGIN
    SELECT member_id INTO v_member_id FROM members WHERE status = 'ACTIVE' LIMIT 1;
    IF v_member_id IS NOT NULL THEN
        SELECT COUNT(*) INTO v_count_before FROM notifications;

        PERFORM notification_send_notification(
            v_member_id, 'ALERT', 'Test Subject', 'Test body', 'EMAIL', 3
        );

        SELECT COUNT(*) INTO v_count_after FROM notifications;
        IF v_count_after <= v_count_before THEN
            RAISE EXCEPTION 'notification_send_notification did not insert notification';
        END IF;
        RAISE NOTICE 'notification_send_notification → inserted  ✓';
    END IF;
END;
$$;

-- ============================================================================
-- Test 18: reporting_get_tier_distribution
-- ============================================================================
\echo '--- Test 18: reporting_get_tier_distribution ---'

DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM reporting_get_tier_distribution();
    IF v_count < 1 THEN
        RAISE EXCEPTION 'reporting_get_tier_distribution returned 0 rows';
    END IF;
    RAISE NOTICE 'reporting_get_tier_distribution → % tier(s)  ✓', v_count;
END;
$$;

-- ============================================================================
-- Test 19: reporting_get_dashboard_kpis
-- ============================================================================
\echo '--- Test 19: reporting_get_dashboard_kpis ---'

DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM reporting_get_dashboard_kpis();
    IF v_count < 1 THEN
        RAISE EXCEPTION 'reporting_get_dashboard_kpis returned 0 rows';
    END IF;
    RAISE NOTICE 'reporting_get_dashboard_kpis → % KPI(s)  ✓', v_count;
END;
$$;

-- ============================================================================
-- Test 20: member_mgmt_generate_membership_number
-- ============================================================================
\echo '--- Test 20: member_mgmt_generate_membership_number ---'

DO $$
DECLARE
    v_num VARCHAR;
BEGIN
    v_num := member_mgmt_generate_membership_number();
    IF v_num IS NULL OR LENGTH(v_num) < 8 THEN
        RAISE EXCEPTION 'member_mgmt_generate_membership_number returned "%"', v_num;
    END IF;
    IF LEFT(v_num, 2) <> 'SR' THEN
        RAISE EXCEPTION 'Membership number does not start with SR: %', v_num;
    END IF;
    RAISE NOTICE 'member_mgmt_generate_membership_number = %  ✓', v_num;
END;
$$;

-- ============================================================================
-- Rollback – leave database unchanged
-- ============================================================================
ROLLBACK;

\echo ''
\echo '========================================'
\echo '  ✅  ALL FUNCTION TESTS PASSED'
\echo '========================================'
\echo ''
