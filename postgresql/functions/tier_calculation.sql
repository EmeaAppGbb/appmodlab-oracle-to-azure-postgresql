-- ============================================================================
-- PostgreSQL conversion of Oracle package PKG_TIER_CALCULATION
-- Each package procedure/function becomes a standalone function
-- prefixed with tier_calculation_
-- ============================================================================

-- ============================================================================
-- Function: tier_calculation_get_qualifying_miles
-- Returns total qualifying miles for a member within a lookback period.
-- Oracle: used ADD_MONTHS(SYSDATE, -n), TRUNC(SYSDATE)
-- ============================================================================
CREATE OR REPLACE FUNCTION tier_calculation_get_qualifying_miles(
    p_member_id    BIGINT,
    p_months_back  INT DEFAULT 12
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_miles NUMERIC;
BEGIN
    SELECT COALESCE(SUM(miles_earned), 0)
      INTO v_total_miles
      FROM miles_transactions
     WHERE member_id = p_member_id
       AND transaction_type = 'EARN'
       AND qualifying = TRUE
       AND transaction_date >= CURRENT_DATE - (p_months_back || ' months')::INTERVAL;

    RETURN v_total_miles;
END;
$$;

-- ============================================================================
-- Function: tier_calculation_get_qualifying_segments
-- Returns total qualifying flight segments for a member within a lookback period.
-- Oracle: used ADD_MONTHS(SYSDATE, -n)
-- ============================================================================
CREATE OR REPLACE FUNCTION tier_calculation_get_qualifying_segments(
    p_member_id    BIGINT,
    p_months_back  INT DEFAULT 12
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_segments INT;
BEGIN
    SELECT COALESCE(COUNT(*), 0)::INT
      INTO v_total_segments
      FROM flight_activities
     WHERE member_id = p_member_id
       AND activity_date >= CURRENT_DATE - (p_months_back || ' months')::INTERVAL
       AND status = 'COMPLETED';

    RETURN v_total_segments;
END;
$$;

-- ============================================================================
-- Function: tier_calculation_evaluate_tier
-- Evaluates which tier a member qualifies for based on miles and segments.
-- Oracle: looped tier_rules ordered by min_miles DESC
-- ============================================================================
CREATE OR REPLACE FUNCTION tier_calculation_evaluate_tier(
    p_member_id  BIGINT
)
RETURNS VARCHAR
LANGUAGE plpgsql
AS $$
DECLARE
    v_qualifying_miles    NUMERIC;
    v_qualifying_segments INT;
    v_tier_name           VARCHAR;
    rec                   RECORD;
BEGIN
    v_qualifying_miles    := tier_calculation_get_qualifying_miles(p_member_id);
    v_qualifying_segments := tier_calculation_get_qualifying_segments(p_member_id);

    -- Loop from highest tier down; first match wins
    FOR rec IN
        SELECT tr.tier_name, tr.min_miles, tr.min_segments
          FROM tier_rules tr
         ORDER BY tr.min_miles DESC
    LOOP
        IF v_qualifying_miles >= rec.min_miles
           OR v_qualifying_segments >= rec.min_segments THEN
            RETURN rec.tier_name;
        END IF;
    END LOOP;

    -- Default to lowest tier if no rule matched
    RETURN 'BLUE';
END;
$$;

-- ============================================================================
-- Function: tier_calculation_recalculate_member_tier
-- Recalculates a single member's tier and updates if changed.
-- Oracle: procedure with OUT params → RETURNS TABLE
-- ============================================================================
CREATE OR REPLACE FUNCTION tier_calculation_recalculate_member_tier(
    p_member_id  BIGINT
)
RETURNS TABLE(new_tier VARCHAR, changed BOOLEAN)
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_tier  VARCHAR;
    v_new_tier      VARCHAR;
    v_changed       BOOLEAN := FALSE;
BEGIN
    -- Get current tier
    SELECT m.current_tier INTO v_current_tier
      FROM members m
     WHERE m.member_id = p_member_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Member % not found', p_member_id;
    END IF;

    -- Evaluate new tier
    v_new_tier := tier_calculation_evaluate_tier(p_member_id);

    -- Update if tier has changed
    IF v_new_tier IS DISTINCT FROM v_current_tier THEN
        UPDATE members
           SET current_tier = v_new_tier,
               tier_update_date = CURRENT_TIMESTAMP,
               updated_date = CURRENT_TIMESTAMP,
               updated_by = current_user
         WHERE member_id = p_member_id;

        -- Log tier change in history
        INSERT INTO tier_history (
            member_id, old_tier, new_tier, change_date, change_reason
        ) VALUES (
            p_member_id, v_current_tier, v_new_tier, CURRENT_TIMESTAMP, 'RECALCULATION'
        );

        v_changed := TRUE;
    END IF;

    RETURN QUERY SELECT v_new_tier, v_changed;
END;
$$;

-- ============================================================================
-- Function: tier_calculation_recalculate_all_tiers
-- Batch recalculates tiers for all active members.
-- Oracle: used cursor loop, pkg_audit.log_batch calls
-- ============================================================================
CREATE OR REPLACE FUNCTION tier_calculation_recalculate_all_tiers()
RETURNS TABLE(processed_count INT, changed_count INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_processed   INT := 0;
    v_changed     INT := 0;
    v_batch_id    BIGINT;
    rec           RECORD;
    tier_rec      RECORD;
BEGIN
    -- Start batch
    v_batch_id := batch_processing_start_batch('TIER_RECALCULATION');

    -- Loop through all active members
    FOR rec IN
        SELECT m.member_id
          FROM members m
         WHERE m.status = 'ACTIVE'
         ORDER BY m.member_id
    LOOP
        BEGIN
            SELECT * INTO tier_rec
              FROM tier_calculation_recalculate_member_tier(rec.member_id);

            v_processed := v_processed + 1;

            IF tier_rec.changed THEN
                v_changed := v_changed + 1;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Error recalculating tier for member %: %', rec.member_id, SQLERRM;
        END;
    END LOOP;

    -- Complete batch
    PERFORM batch_processing_complete_batch(v_batch_id, v_processed, v_changed);

    RETURN QUERY SELECT v_processed, v_changed;
END;
$$;

-- ============================================================================
-- Function: tier_calculation_get_tier_hierarchy
-- Returns all tier rules ordered by minimum miles ascending.
-- Oracle: used CONNECT BY → replaced with simple ORDER BY
-- ============================================================================
CREATE OR REPLACE FUNCTION tier_calculation_get_tier_hierarchy()
RETURNS TABLE(
    tier_name        VARCHAR,
    min_miles        NUMERIC,
    min_segments     INT,
    miles_multiplier NUMERIC,
    bonus_miles_pct  NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT tr.tier_name,
           tr.min_miles,
           tr.min_segments,
           tr.miles_multiplier,
           tr.bonus_miles_pct
      FROM tier_rules tr
     ORDER BY tr.min_miles ASC;
END;
$$;

-- ============================================================================
-- Function: tier_calculation_check_upgrade_eligibility
-- Checks if a member is eligible for an upgrade to the next tier.
-- Returns the next tier name if eligible, NULL otherwise.
-- ============================================================================
CREATE OR REPLACE FUNCTION tier_calculation_check_upgrade_eligibility(
    p_member_id  BIGINT
)
RETURNS VARCHAR
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_tier        VARCHAR;
    v_current_min_miles   NUMERIC;
    v_qualifying_miles    NUMERIC;
    v_qualifying_segments INT;
    v_next_tier           VARCHAR;
BEGIN
    -- Get current tier
    SELECT m.current_tier INTO v_current_tier
      FROM members m
     WHERE m.member_id = p_member_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Member % not found', p_member_id;
    END IF;

    -- Get current tier minimum miles
    SELECT tr.min_miles INTO v_current_min_miles
      FROM tier_rules tr
     WHERE tr.tier_name = v_current_tier;

    -- Get qualifying activity
    v_qualifying_miles    := tier_calculation_get_qualifying_miles(p_member_id);
    v_qualifying_segments := tier_calculation_get_qualifying_segments(p_member_id);

    -- Find the next tier above current that the member qualifies for
    SELECT tr.tier_name INTO v_next_tier
      FROM tier_rules tr
     WHERE tr.min_miles > COALESCE(v_current_min_miles, 0)
       AND (v_qualifying_miles >= tr.min_miles OR v_qualifying_segments >= tr.min_segments)
     ORDER BY tr.min_miles ASC
     LIMIT 1;

    RETURN v_next_tier;  -- NULL if no upgrade available
END;
$$;
