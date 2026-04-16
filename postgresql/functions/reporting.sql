-- ============================================================================
-- PostgreSQL conversion of Oracle package PKG_REPORTING
-- Each package procedure/function becomes a standalone function
-- prefixed with reporting_
--
-- Conversion notes:
--   - SYS_REFCURSOR replaced with RETURNS TABLE + RETURN QUERY
--   - TRUNC(SYSDATE,'MM') replaced with DATE_TRUNC('month', CURRENT_DATE)
--   - TRUNC(SYSDATE,'YYYY') replaced with DATE_TRUNC('year', CURRENT_DATE)
--   - NVL replaced with COALESCE
--   - ADD_MONTHS(x, n) replaced with INTERVAL arithmetic
--   - DECODE replaced with CASE expression
--   - CLOB replaced with TEXT
--   - members%ROWTYPE replaced with explicit column variables
--   - FETCH FIRST n ROWS ONLY replaced with LIMIT n
--   - SYSDATE replaced with CURRENT_TIMESTAMP / CURRENT_DATE
--   - CHR(10) replaced with E'\n' (or kept as chr(10))
-- ============================================================================

-- ============================================================================
-- Function: reporting_get_dashboard_kpis
-- Returns executive dashboard KPI metrics.
-- Oracle: SYS_REFCURSOR with UNION ALL
-- ============================================================================
CREATE OR REPLACE FUNCTION reporting_get_dashboard_kpis()
RETURNS TABLE(kpi_name VARCHAR, kpi_value NUMERIC, kpi_detail NUMERIC)
LANGUAGE plpgsql STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT 'Total Active Members'::VARCHAR AS kpi_name,
           COUNT(*)::NUMERIC AS kpi_value,
           NULL::NUMERIC AS kpi_detail
      FROM members WHERE status = 'ACTIVE'
    UNION ALL
    SELECT 'Total Miles Outstanding'::VARCHAR,
           SUM(available_miles)::NUMERIC,
           NULL::NUMERIC
      FROM members WHERE status = 'ACTIVE'
    UNION ALL
    SELECT 'Flights This Month'::VARCHAR,
           COUNT(*)::NUMERIC,
           NULL::NUMERIC
      FROM flights
     WHERE flight_date >= DATE_TRUNC('month', CURRENT_DATE)
    UNION ALL
    SELECT 'Redemptions This Month'::VARCHAR,
           COUNT(*)::NUMERIC,
           SUM(miles_used)::NUMERIC
      FROM redemptions
     WHERE redemption_date >= DATE_TRUNC('month', CURRENT_DATE)
       AND status IN ('CONFIRMED', 'FULFILLED')
    UNION ALL
    SELECT 'New Members This Month'::VARCHAR,
           COUNT(*)::NUMERIC,
           NULL::NUMERIC
      FROM members
     WHERE enrollment_date >= DATE_TRUNC('month', CURRENT_DATE);
END;
$$;

-- ============================================================================
-- Function: reporting_get_tier_distribution
-- Returns member counts and miles aggregates by tier.
-- Oracle: DECODE for ordering replaced with CASE WHEN
-- ============================================================================
CREATE OR REPLACE FUNCTION reporting_get_tier_distribution()
RETURNS TABLE(
    tier_status  VARCHAR,
    member_count BIGINT,
    percentage   NUMERIC,
    total_miles  NUMERIC,
    avg_miles    NUMERIC
)
LANGUAGE plpgsql STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT m.tier_status,
           COUNT(*)::BIGINT AS member_count,
           ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage,
           SUM(m.available_miles) AS total_miles,
           ROUND(AVG(m.available_miles)) AS avg_miles
      FROM members m
     WHERE m.status = 'ACTIVE'
     GROUP BY m.tier_status
     ORDER BY CASE m.tier_status
                  WHEN 'DIAMOND'  THEN 1
                  WHEN 'PLATINUM' THEN 2
                  WHEN 'GOLD'     THEN 3
                  WHEN 'SILVER'   THEN 4
                  WHEN 'BLUE'     THEN 5
              END;
END;
$$;

-- ============================================================================
-- Function: reporting_get_monthly_accrual_trend
-- Returns monthly flight accrual aggregates for the past N months.
-- Oracle: ADD_MONTHS(TRUNC(SYSDATE,'MM'), -n) → DATE_TRUNC - INTERVAL
-- ============================================================================
CREATE OR REPLACE FUNCTION reporting_get_monthly_accrual_trend(
    p_months_back INT DEFAULT 12
)
RETURNS TABLE(
    accrual_month  VARCHAR,
    flight_count   BIGINT,
    total_base_miles  NUMERIC,
    total_bonus_miles NUMERIC,
    total_miles       NUMERIC,
    unique_members    BIGINT
)
LANGUAGE plpgsql STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT TO_CHAR(f.flight_date, 'YYYY-MM')   AS accrual_month,
           COUNT(*)::BIGINT                     AS flight_count,
           SUM(f.base_miles)                    AS total_base_miles,
           SUM(f.bonus_miles)                   AS total_bonus_miles,
           SUM(f.total_miles)                   AS total_miles,
           COUNT(DISTINCT f.member_id)::BIGINT  AS unique_members
      FROM flights f
     WHERE f.accrual_status = 'PROCESSED'
       AND f.flight_date >= DATE_TRUNC('month', CURRENT_DATE) - (p_months_back || ' months')::INTERVAL
     GROUP BY TO_CHAR(f.flight_date, 'YYYY-MM')
     ORDER BY accrual_month;
END;
$$;

-- ============================================================================
-- Function: reporting_get_top_earners
-- Returns top N earning members within a date range.
-- Oracle: FETCH FIRST p_top_n ROWS ONLY → LIMIT p_top_n
-- ============================================================================
CREATE OR REPLACE FUNCTION reporting_get_top_earners(
    p_top_n      INT  DEFAULT 20,
    p_start_date DATE DEFAULT NULL,
    p_end_date   DATE DEFAULT NULL
)
RETURNS TABLE(
    member_id         BIGINT,
    membership_number VARCHAR,
    member_name       TEXT,
    tier_status       VARCHAR,
    earned_miles      NUMERIC,
    flight_count      BIGINT
)
LANGUAGE plpgsql STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT m.member_id,
           m.membership_number,
           (m.first_name || ' ' || m.last_name)::TEXT AS member_name,
           m.tier_status,
           SUM(f.total_miles)                         AS earned_miles,
           COUNT(*)::BIGINT                           AS flight_count
      FROM members m
      JOIN flights f ON m.member_id = f.member_id
     WHERE f.accrual_status = 'PROCESSED'
       AND f.flight_date >= COALESCE(p_start_date, (CURRENT_DATE - INTERVAL '12 months')::DATE)
       AND f.flight_date <= COALESCE(p_end_date, CURRENT_DATE)
     GROUP BY m.member_id, m.membership_number,
              m.first_name || ' ' || m.last_name, m.tier_status
     ORDER BY earned_miles DESC
     LIMIT p_top_n;
END;
$$;

-- ============================================================================
-- Function: reporting_get_partner_performance
-- Returns partner transaction performance metrics.
-- Oracle: NVL → COALESCE, NULLS LAST is supported natively in PG
-- ============================================================================
CREATE OR REPLACE FUNCTION reporting_get_partner_performance(
    p_start_date DATE DEFAULT NULL,
    p_end_date   DATE DEFAULT NULL
)
RETURNS TABLE(
    partner_code   VARCHAR,
    partner_name   VARCHAR,
    partner_type   VARCHAR,
    txn_count      BIGINT,
    total_earned   NUMERIC,
    total_redeemed NUMERIC,
    total_revenue  NUMERIC,
    unique_members BIGINT
)
LANGUAGE plpgsql STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT p.partner_code,
           p.partner_name,
           p.partner_type,
           COUNT(pt.txn_id)::BIGINT            AS txn_count,
           SUM(pt.miles_earned)                 AS total_earned,
           SUM(pt.miles_redeemed)               AS total_redeemed,
           SUM(pt.amount)                       AS total_revenue,
           COUNT(DISTINCT pt.member_id)::BIGINT AS unique_members
      FROM partners p
      LEFT JOIN partner_transactions pt ON p.partner_id = pt.partner_id
        AND pt.status = 'PROCESSED'
        AND pt.transaction_date >= COALESCE(p_start_date, DATE '2000-01-01')
        AND pt.transaction_date <= COALESCE(p_end_date, CURRENT_TIMESTAMP)
     WHERE p.status = 'ACTIVE'
     GROUP BY p.partner_code, p.partner_name, p.partner_type
     ORDER BY total_earned DESC NULLS LAST;
END;
$$;

-- ============================================================================
-- Function: reporting_get_redemption_analytics
-- Returns redemption metrics grouped by reward category.
-- ============================================================================
CREATE OR REPLACE FUNCTION reporting_get_redemption_analytics(
    p_start_date DATE DEFAULT NULL,
    p_end_date   DATE DEFAULT NULL
)
RETURNS TABLE(
    category                VARCHAR,
    redemption_count        BIGINT,
    total_miles_used        NUMERIC,
    avg_miles_per_redemption NUMERIC,
    total_cash_revenue      NUMERIC,
    unique_members          BIGINT
)
LANGUAGE plpgsql STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT rw.category,
           COUNT(*)::BIGINT                     AS redemption_count,
           SUM(r.miles_used)                    AS total_miles_used,
           ROUND(AVG(r.miles_used))             AS avg_miles_per_redemption,
           SUM(r.cash_paid)                     AS total_cash_revenue,
           COUNT(DISTINCT r.member_id)::BIGINT  AS unique_members
      FROM redemptions r
      JOIN rewards rw ON r.reward_id = rw.reward_id
     WHERE r.status IN ('CONFIRMED', 'FULFILLED')
       AND r.redemption_date >= COALESCE(p_start_date, DATE '2000-01-01')
       AND r.redemption_date <= COALESCE(p_end_date, CURRENT_TIMESTAMP)
     GROUP BY rw.category
     ORDER BY total_miles_used DESC;
END;
$$;

-- ============================================================================
-- Function: reporting_generate_liability_report
-- Calculates total outstanding miles, estimated liability, and breakage.
-- Oracle: procedure with OUT params → RETURNS TABLE
-- ============================================================================
CREATE OR REPLACE FUNCTION reporting_generate_liability_report()
RETURNS TABLE(
    total_outstanding_miles NUMERIC,
    estimated_liability_usd NUMERIC,
    breakage_estimate_pct   NUMERIC
)
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_total_miles   NUMERIC;
    v_liability     NUMERIC;
    v_breakage_pct  NUMERIC;
BEGIN
    SELECT COALESCE(SUM(available_miles), 0)
      INTO v_total_miles
      FROM members
     WHERE status = 'ACTIVE';

    -- Estimated cost per mile: $0.012
    v_liability := v_total_miles * 0.012;

    -- Calculate breakage (historically expired as % of earned)
    SELECT CASE WHEN SUM(miles_amount) > 0
                THEN ROUND(SUM(expired_miles) * 100.0 / SUM(miles_amount), 2)
                ELSE 0
           END
      INTO v_breakage_pct
      FROM miles_expiry;

    total_outstanding_miles := v_total_miles;
    estimated_liability_usd := v_liability;
    breakage_estimate_pct   := v_breakage_pct;
    RETURN NEXT;
END;
$$;

-- ============================================================================
-- Function: reporting_generate_member_statement
-- Generates a text statement for a member over a date range.
-- Oracle: CLOB → TEXT, members%ROWTYPE → explicit column variables
-- ============================================================================
CREATE OR REPLACE FUNCTION reporting_generate_member_statement(
    p_member_id  BIGINT,
    p_start_date DATE,
    p_end_date   DATE
)
RETURNS TEXT
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_stmt             TEXT;
    v_first_name       VARCHAR;
    v_last_name        VARCHAR;
    v_membership_number VARCHAR;
    v_tier_status      VARCHAR;
    v_available_miles  NUMERIC;
    rec                RECORD;
BEGIN
    -- Use explicit column selections instead of members%ROWTYPE
    SELECT m.first_name, m.last_name, m.membership_number,
           m.tier_status, m.available_miles
      INTO STRICT v_first_name, v_last_name, v_membership_number,
                  v_tier_status, v_available_miles
      FROM members m
     WHERE m.member_id = p_member_id;

    v_stmt := '================================================' || chr(10);
    v_stmt := v_stmt || 'SKYREWARD AIRLINES - MEMBER STATEMENT' || chr(10);
    v_stmt := v_stmt || '================================================' || chr(10);
    v_stmt := v_stmt || 'Member: ' || v_first_name || ' ' || v_last_name || chr(10);
    v_stmt := v_stmt || 'Membership #: ' || v_membership_number || chr(10);
    v_stmt := v_stmt || 'Tier: ' || v_tier_status || chr(10);
    v_stmt := v_stmt || 'Available Miles: ' || TO_CHAR(v_available_miles, '999,999,999') || chr(10);
    v_stmt := v_stmt || 'Period: ' || TO_CHAR(p_start_date, 'DD-Mon-YYYY') ||
              ' to ' || TO_CHAR(p_end_date, 'DD-Mon-YYYY') || chr(10);
    v_stmt := v_stmt || '------------------------------------------------' || chr(10);
    v_stmt := v_stmt || 'FLIGHT ACTIVITY' || chr(10);

    FOR rec IN (
        SELECT flight_date, flight_number,
               departure_airport || '-' || arrival_airport AS route,
               total_miles, accrual_status
          FROM flights
         WHERE member_id = p_member_id
           AND flight_date BETWEEN p_start_date AND p_end_date
         ORDER BY flight_date
    ) LOOP
        v_stmt := v_stmt || TO_CHAR(rec.flight_date, 'DD-Mon-YY') || '  ' ||
                  RPAD(rec.flight_number, 8) || '  ' || RPAD(rec.route, 10) || '  ' ||
                  LPAD(TO_CHAR(rec.total_miles, '999,999'), 10) || '  ' ||
                  rec.accrual_status || chr(10);
    END LOOP;

    v_stmt := v_stmt || '------------------------------------------------' || chr(10);
    v_stmt := v_stmt || 'REDEMPTIONS' || chr(10);

    FOR rec IN (
        SELECT r.redemption_date, rw.reward_name, r.miles_used, r.status
          FROM redemptions r
          JOIN rewards rw ON r.reward_id = rw.reward_id
         WHERE r.member_id = p_member_id
           AND r.redemption_date BETWEEN p_start_date AND p_end_date
         ORDER BY r.redemption_date
    ) LOOP
        v_stmt := v_stmt || TO_CHAR(rec.redemption_date, 'DD-Mon-YY') || '  ' ||
                  RPAD(rec.reward_name, 30) || '  ' ||
                  LPAD(TO_CHAR(-rec.miles_used, '999,999'), 10) || '  ' ||
                  rec.status || chr(10);
    END LOOP;

    v_stmt := v_stmt || '================================================' || chr(10);

    RETURN v_stmt;
END;
$$;
