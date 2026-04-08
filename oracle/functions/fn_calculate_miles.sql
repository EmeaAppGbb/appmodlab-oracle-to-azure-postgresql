-- ========================================
-- Function: Calculate Miles (FN_CALCULATE_MILES)
-- ========================================
-- Standalone function for miles calculation with cabin/class multipliers

CREATE OR REPLACE FUNCTION fn_calculate_miles(
  p_distance_miles  IN NUMBER,
  p_booking_class   IN VARCHAR2,
  p_cabin_class     IN VARCHAR2,
  p_member_tier     IN VARCHAR2 DEFAULT 'BLUE'
) RETURN NUMBER
DETERMINISTIC
IS
  v_cabin_mult   NUMBER;
  v_class_factor NUMBER;
  v_tier_bonus   NUMBER;
  v_base_miles   NUMBER;
  v_total_miles  NUMBER;
BEGIN
  -- Cabin class multiplier
  v_cabin_mult := CASE p_cabin_class
    WHEN 'ECONOMY'         THEN 1.0
    WHEN 'PREMIUM_ECONOMY' THEN 1.5
    WHEN 'BUSINESS'        THEN 2.0
    WHEN 'FIRST'           THEN 3.0
    ELSE 1.0
  END;

  -- Booking class factor
  v_class_factor := CASE
    WHEN p_booking_class IN ('Y', 'J', 'F', 'C') THEN 1.5   -- Full fare
    WHEN p_booking_class IN ('B', 'M', 'H')      THEN 1.0   -- Standard
    WHEN p_booking_class IN ('Q', 'V', 'W')      THEN 0.75  -- Discount
    WHEN p_booking_class IN ('L', 'K', 'N')      THEN 0.5   -- Deep discount
    ELSE 0.5
  END;

  -- Tier bonus percentage
  v_tier_bonus := CASE p_member_tier
    WHEN 'BLUE'     THEN 0
    WHEN 'SILVER'   THEN 25
    WHEN 'GOLD'     THEN 50
    WHEN 'PLATINUM' THEN 75
    WHEN 'DIAMOND'  THEN 100
    ELSE 0
  END;

  -- Calculate base miles (minimum 500)
  v_base_miles := GREATEST(ROUND(p_distance_miles * v_cabin_mult * v_class_factor), 500);

  -- Apply tier bonus
  v_total_miles := ROUND(v_base_miles * (1 + v_tier_bonus / 100));

  RETURN v_total_miles;
END fn_calculate_miles;
/
