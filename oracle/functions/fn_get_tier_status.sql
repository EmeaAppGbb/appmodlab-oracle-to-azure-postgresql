-- ========================================
-- Function: Get Tier Status (FN_GET_TIER_STATUS)
-- ========================================
-- Returns current and projected tier status for a member

CREATE OR REPLACE FUNCTION fn_get_tier_status(
  p_member_id IN NUMBER
) RETURN VARCHAR2
IS
  v_current_tier  VARCHAR2(20);
  v_qual_miles    NUMBER;
  v_qual_segments NUMBER;
  v_projected_tier VARCHAR2(20) := 'BLUE';
  v_result        VARCHAR2(200);
BEGIN
  -- Get current tier
  SELECT tier_status INTO v_current_tier
  FROM members WHERE member_id = p_member_id;

  -- Calculate qualifying activity in rolling 12 months
  SELECT NVL(SUM(tier_miles), 0), COUNT(*)
  INTO v_qual_miles, v_qual_segments
  FROM flights
  WHERE member_id = p_member_id
    AND accrual_status = 'PROCESSED'
    AND flight_date >= ADD_MONTHS(TRUNC(SYSDATE), -12);

  -- Determine projected tier (highest to lowest)
  FOR rec IN (
    SELECT tier_name, min_miles, min_segments
    FROM tier_rules
    WHERE status = 'ACTIVE'
      AND SYSDATE BETWEEN effective_date AND NVL(expiry_date, SYSDATE + 1)
    ORDER BY min_miles DESC
  ) LOOP
    IF v_qual_miles >= rec.min_miles OR v_qual_segments >= rec.min_segments THEN
      v_projected_tier := rec.tier_name;
      EXIT;
    END IF;
  END LOOP;

  -- Build result string
  v_result := 'Current: ' || v_current_tier ||
              ' | Projected: ' || v_projected_tier ||
              ' | QualMiles: ' || TO_CHAR(v_qual_miles, '999,999') ||
              ' | Segments: ' || v_qual_segments;

  RETURN v_result;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN 'ERROR: Member not found';
END fn_get_tier_status;
/
