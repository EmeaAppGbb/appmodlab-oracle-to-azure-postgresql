-- ============================================================================
-- Integration Test: Tier Upgrade
-- ============================================================================
-- Tests: evaluate tier → check upgrade eligibility → recalculate
-- Runs in a transaction, rolls back at end.
-- ============================================================================

\echo '--- Integration Test: Tier Upgrade ---'

BEGIN;

DO $$
DECLARE
    v_member_id BIGINT;
    v_current_tier VARCHAR;
    v_evaluated_tier VARCHAR;
    v_next_tier VARCHAR;
    v_hierarchy_count INT;
    v_qualifying_miles NUMERIC;
    v_qualifying_segments INT;
    v_rec RECORD;
BEGIN
    -- Step 1: Verify tier hierarchy is loaded
    RAISE NOTICE 'Step 1: Checking tier hierarchy...';
    SELECT COUNT(*) INTO v_hierarchy_count FROM tier_calculation_get_tier_hierarchy();
    IF v_hierarchy_count < 5 THEN
        RAISE EXCEPTION 'Tier hierarchy has only % entries, expected 5', v_hierarchy_count;
    END IF;
    RAISE NOTICE '  Tier hierarchy: % tiers loaded', v_hierarchy_count;

    -- Step 2: Get an active member
    SELECT member_id, tier_status
      INTO v_member_id, v_current_tier
      FROM members
     WHERE status = 'ACTIVE'
     ORDER BY member_id
     LIMIT 1;

    IF v_member_id IS NULL THEN
        RAISE EXCEPTION 'No active member found';
    END IF;
    RAISE NOTICE 'Step 2: Using member % (current tier: %)', v_member_id, v_current_tier;

    -- Step 3: Get qualifying miles and segments
    RAISE NOTICE 'Step 3: Calculating qualifying activity...';
    v_qualifying_miles := tier_calculation_get_qualifying_miles(v_member_id);
    v_qualifying_segments := tier_calculation_get_qualifying_segments(v_member_id);
    RAISE NOTICE '  Qualifying miles: %, segments: %', v_qualifying_miles, v_qualifying_segments;

    -- Step 4: Evaluate tier
    RAISE NOTICE 'Step 4: Evaluating tier...';
    v_evaluated_tier := tier_calculation_evaluate_tier(v_member_id);
    IF v_evaluated_tier IS NULL THEN
        RAISE EXCEPTION 'tier_calculation_evaluate_tier returned NULL';
    END IF;
    IF v_evaluated_tier NOT IN ('BLUE', 'SILVER', 'GOLD', 'PLATINUM', 'DIAMOND') THEN
        RAISE EXCEPTION 'Invalid tier returned: %', v_evaluated_tier;
    END IF;
    RAISE NOTICE '  Evaluated tier: %', v_evaluated_tier;

    -- Step 5: Check upgrade eligibility
    RAISE NOTICE 'Step 5: Checking upgrade eligibility...';
    v_next_tier := tier_calculation_check_upgrade_eligibility(v_member_id);
    IF v_next_tier IS NOT NULL THEN
        RAISE NOTICE '  Eligible for upgrade to: %', v_next_tier;
    ELSE
        RAISE NOTICE '  No upgrade available at this time';
    END IF;

    -- Step 6: Recalculate tier for this member
    RAISE NOTICE 'Step 6: Recalculating member tier...';
    SELECT * INTO v_rec FROM tier_calculation_recalculate_member_tier(v_member_id);
    RAISE NOTICE '  New tier: %, changed: %', v_rec.new_tier, v_rec.changed;

    -- Step 7: Verify fn_get_tier_status
    RAISE NOTICE 'Step 7: Getting tier status string...';
    DECLARE
        v_status_str VARCHAR;
    BEGIN
        v_status_str := fn_get_tier_status(v_member_id);
        IF v_status_str IS NULL THEN
            RAISE EXCEPTION 'fn_get_tier_status returned NULL';
        END IF;
        RAISE NOTICE '  Status: %', v_status_str;
    END;

    RAISE NOTICE '✅  Tier Upgrade Flow: ALL STEPS PASSED';
END;
$$;

ROLLBACK;
