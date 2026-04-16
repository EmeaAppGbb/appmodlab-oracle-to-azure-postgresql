CREATE OR REPLACE FUNCTION fn_get_tier_status(p_member_id NUMERIC)
RETURNS VARCHAR
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_tier   VARCHAR(20);
    v_qual_miles     NUMERIC;
    v_qual_segments  NUMERIC;
    v_projected_tier VARCHAR(20) := 'BLUE';
    v_result         VARCHAR(200);
    rec              RECORD;
BEGIN
    SELECT tier_status INTO STRICT v_current_tier
    FROM members
    WHERE member_id = p_member_id;

    SELECT COALESCE(SUM(tier_miles), 0), COUNT(*)
    INTO v_qual_miles, v_qual_segments
    FROM flights
    WHERE member_id = p_member_id
      AND accrual_status = 'PROCESSED'
      AND flight_date >= CURRENT_DATE - INTERVAL '12 months';

    FOR rec IN (
        SELECT tier_name, min_miles, min_segments
        FROM tier_rules
        WHERE status = 'ACTIVE'
          AND CURRENT_TIMESTAMP BETWEEN effective_date
              AND COALESCE(expiry_date, CURRENT_TIMESTAMP + INTERVAL '1 day')
        ORDER BY min_miles DESC
    ) LOOP
        IF v_qual_miles >= rec.min_miles OR v_qual_segments >= rec.min_segments THEN
            v_projected_tier := rec.tier_name;
            EXIT;
        END IF;
    END LOOP;

    v_result := 'Current: ' || v_current_tier
             || ' | Projected: ' || v_projected_tier
             || ' | QualMiles: ' || TO_CHAR(v_qual_miles, '999,999')
             || ' | Segments: ' || v_qual_segments;

    RETURN v_result;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 'ERROR: Member not found';
END;
$$;
