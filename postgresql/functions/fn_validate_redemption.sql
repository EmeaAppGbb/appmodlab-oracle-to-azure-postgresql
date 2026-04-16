-- Helper function: extracted from the nested function in the Oracle source.
-- Must be defined before fn_validate_redemption since it depends on this.
CREATE OR REPLACE FUNCTION fn_tier_rank(p_tier VARCHAR)
RETURNS INT
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    RETURN CASE p_tier
        WHEN 'BLUE'     THEN 1
        WHEN 'SILVER'   THEN 2
        WHEN 'GOLD'     THEN 3
        WHEN 'PLATINUM' THEN 4
        WHEN 'DIAMOND'  THEN 5
        ELSE 0
    END;
END;
$$;

CREATE OR REPLACE FUNCTION fn_validate_redemption(
    p_member_id NUMERIC,
    p_reward_id NUMERIC,
    p_quantity   NUMERIC DEFAULT 1
)
RETURNS VARCHAR
LANGUAGE plpgsql
AS $$
DECLARE
    v_member_status VARCHAR(20);
    v_member_tier   VARCHAR(20);
    v_member_miles  NUMERIC;
    v_reward_status VARCHAR(20);
    v_min_tier      VARCHAR(20);
    v_miles_required NUMERIC;
    v_qty_available NUMERIC;
    v_valid_from    DATE;
    v_valid_until   DATE;
BEGIN
    -- Look up member
    BEGIN
        SELECT status, tier_status, available_miles
        INTO STRICT v_member_status, v_member_tier, v_member_miles
        FROM members
        WHERE member_id = p_member_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 'INVALID: Member not found';
    END;

    IF v_member_status != 'ACTIVE' THEN
        RETURN 'INVALID: Member account is ' || v_member_status;
    END IF;

    -- Look up reward
    BEGIN
        SELECT status,
               min_tier_required,
               miles_required,
               COALESCE(quantity_available, 999999),
               valid_from,
               COALESCE(valid_until, CURRENT_DATE + 1)
        INTO STRICT v_reward_status, v_min_tier, v_miles_required,
                    v_qty_available, v_valid_from, v_valid_until
        FROM rewards
        WHERE reward_id = p_reward_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 'INVALID: Reward not found';
    END;

    IF v_reward_status != 'ACTIVE' THEN
        RETURN 'INVALID: Reward is ' || v_reward_status;
    END IF;

    IF CURRENT_DATE NOT BETWEEN v_valid_from AND v_valid_until THEN
        RETURN 'INVALID: Reward is outside valid date range';
    END IF;

    IF fn_tier_rank(v_member_tier) < fn_tier_rank(v_min_tier) THEN
        RETURN 'INVALID: Requires minimum tier ' || v_min_tier || ', member is ' || v_member_tier;
    END IF;

    IF v_qty_available < p_quantity THEN
        RETURN 'INVALID: Insufficient quantity. Available: ' || v_qty_available;
    END IF;

    IF v_member_miles < v_miles_required * p_quantity THEN
        RETURN 'INVALID: Insufficient miles. Required: ' || (v_miles_required * p_quantity)
            || ', Available: ' || v_member_miles;
    END IF;

    RETURN 'VALID: Redemption eligible. Miles cost: ' || (v_miles_required * p_quantity);
END;
$$;
