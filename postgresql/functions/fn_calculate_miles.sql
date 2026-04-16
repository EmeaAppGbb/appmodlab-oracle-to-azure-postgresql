CREATE OR REPLACE FUNCTION fn_calculate_miles(
    p_distance_miles NUMERIC,
    p_booking_class VARCHAR,
    p_cabin_class VARCHAR,
    p_member_tier VARCHAR DEFAULT 'BLUE'
)
RETURNS NUMERIC
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_cabin_mult   NUMERIC;
    v_class_factor NUMERIC;
    v_tier_bonus   NUMERIC;
    v_base_miles   NUMERIC;
    v_total_miles  NUMERIC;
BEGIN
    v_cabin_mult := CASE p_cabin_class
        WHEN 'ECONOMY'         THEN 1.0
        WHEN 'PREMIUM_ECONOMY' THEN 1.5
        WHEN 'BUSINESS'        THEN 2.0
        WHEN 'FIRST'           THEN 3.0
        ELSE 1.0
    END;

    v_class_factor := CASE
        WHEN p_booking_class IN ('Y','J','F','C') THEN 1.5
        WHEN p_booking_class IN ('B','M','H')     THEN 1.0
        WHEN p_booking_class IN ('Q','V','W')     THEN 0.75
        WHEN p_booking_class IN ('L','K','N')     THEN 0.5
        ELSE 0.5
    END;

    v_tier_bonus := CASE p_member_tier
        WHEN 'BLUE'     THEN 0
        WHEN 'SILVER'   THEN 25
        WHEN 'GOLD'     THEN 50
        WHEN 'PLATINUM' THEN 75
        WHEN 'DIAMOND'  THEN 100
        ELSE 0
    END;

    v_base_miles  := GREATEST(ROUND(p_distance_miles * v_cabin_mult * v_class_factor), 500);
    v_total_miles := ROUND(v_base_miles * (1 + v_tier_bonus / 100.0));

    RETURN v_total_miles;
END;
$$;
