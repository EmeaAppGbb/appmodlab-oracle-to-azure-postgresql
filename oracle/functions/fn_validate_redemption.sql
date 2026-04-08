-- ========================================
-- Function: Validate Redemption (FN_VALIDATE_REDEMPTION)
-- ========================================
-- Returns validation result for a redemption attempt

CREATE OR REPLACE FUNCTION fn_validate_redemption(
  p_member_id   IN NUMBER,
  p_reward_id   IN NUMBER,
  p_quantity    IN NUMBER DEFAULT 1
) RETURN VARCHAR2
IS
  v_member_status  VARCHAR2(20);
  v_member_tier    VARCHAR2(20);
  v_member_miles   NUMBER;
  v_reward_status  VARCHAR2(20);
  v_min_tier       VARCHAR2(20);
  v_miles_required NUMBER;
  v_qty_available  NUMBER;
  v_valid_from     DATE;
  v_valid_until    DATE;

  -- Tier rank function
  FUNCTION tier_rank(p_tier VARCHAR2) RETURN NUMBER IS
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

BEGIN
  -- Check member
  BEGIN
    SELECT status, tier_status, available_miles
    INTO v_member_status, v_member_tier, v_member_miles
    FROM members WHERE member_id = p_member_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN 'INVALID: Member not found';
  END;

  IF v_member_status != 'ACTIVE' THEN
    RETURN 'INVALID: Member account is ' || v_member_status;
  END IF;

  -- Check reward
  BEGIN
    SELECT status, min_tier_required, miles_required,
           NVL(quantity_available, 999999), valid_from, NVL(valid_until, SYSDATE + 1)
    INTO v_reward_status, v_min_tier, v_miles_required,
         v_qty_available, v_valid_from, v_valid_until
    FROM rewards WHERE reward_id = p_reward_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN 'INVALID: Reward not found';
  END;

  IF v_reward_status != 'ACTIVE' THEN
    RETURN 'INVALID: Reward is ' || v_reward_status;
  END IF;

  IF SYSDATE NOT BETWEEN v_valid_from AND v_valid_until THEN
    RETURN 'INVALID: Reward is outside valid date range';
  END IF;

  -- Check tier eligibility
  IF tier_rank(v_member_tier) < tier_rank(v_min_tier) THEN
    RETURN 'INVALID: Requires minimum tier ' || v_min_tier || ', member is ' || v_member_tier;
  END IF;

  -- Check quantity
  IF v_qty_available < p_quantity THEN
    RETURN 'INVALID: Insufficient quantity. Available: ' || v_qty_available;
  END IF;

  -- Check miles
  IF v_member_miles < v_miles_required * p_quantity THEN
    RETURN 'INVALID: Insufficient miles. Required: ' ||
           (v_miles_required * p_quantity) || ', Available: ' || v_member_miles;
  END IF;

  RETURN 'VALID: Redemption eligible. Miles cost: ' || (v_miles_required * p_quantity);
END fn_validate_redemption;
/
