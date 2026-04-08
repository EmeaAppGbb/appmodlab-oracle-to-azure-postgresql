-- ========================================
-- Package: Reporting (PKG_REPORTING)
-- ========================================
-- Generates reports, analytics queries, and executive dashboards

CREATE OR REPLACE PACKAGE pkg_reporting AS

  -- Types for report results
  TYPE t_summary_rec IS RECORD (
    label   VARCHAR2(100),
    value   NUMBER,
    pct     NUMBER(5,2)
  );

  TYPE t_summary_tab IS TABLE OF t_summary_rec INDEX BY PLS_INTEGER;

  -- Executive dashboard KPIs
  FUNCTION get_dashboard_kpis RETURN SYS_REFCURSOR;

  -- Tier distribution report
  FUNCTION get_tier_distribution RETURN SYS_REFCURSOR;

  -- Monthly accrual trend
  FUNCTION get_monthly_accrual_trend(
    p_months_back IN NUMBER DEFAULT 12
  ) RETURN SYS_REFCURSOR;

  -- Top earning members
  FUNCTION get_top_earners(
    p_top_n       IN NUMBER DEFAULT 20,
    p_start_date  IN DATE DEFAULT NULL,
    p_end_date    IN DATE DEFAULT NULL
  ) RETURN SYS_REFCURSOR;

  -- Partner performance report
  FUNCTION get_partner_performance(
    p_start_date  IN DATE DEFAULT NULL,
    p_end_date    IN DATE DEFAULT NULL
  ) RETURN SYS_REFCURSOR;

  -- Redemption analytics
  FUNCTION get_redemption_analytics(
    p_start_date  IN DATE DEFAULT NULL,
    p_end_date    IN DATE DEFAULT NULL
  ) RETURN SYS_REFCURSOR;

  -- Revenue and liability report
  PROCEDURE generate_liability_report(
    p_total_outstanding_miles OUT NUMBER,
    p_estimated_liability_usd OUT NUMBER,
    p_breakage_estimate_pct   OUT NUMBER
  );

  -- Generate member statement (CLOB output)
  FUNCTION generate_member_statement(
    p_member_id   IN  NUMBER,
    p_start_date  IN  DATE,
    p_end_date    IN  DATE
  ) RETURN CLOB;

END pkg_reporting;
/

CREATE OR REPLACE PACKAGE BODY pkg_reporting AS

  -- Dashboard KPIs
  FUNCTION get_dashboard_kpis RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
  BEGIN
    OPEN v_cursor FOR
      SELECT 'Total Active Members' AS kpi_name,
             COUNT(*) AS kpi_value,
             NULL AS kpi_detail
      FROM members WHERE status = 'ACTIVE'
      UNION ALL
      SELECT 'Total Miles Outstanding',
             SUM(available_miles),
             NULL
      FROM members WHERE status = 'ACTIVE'
      UNION ALL
      SELECT 'Flights This Month',
             COUNT(*),
             NULL
      FROM flights
      WHERE flight_date >= TRUNC(SYSDATE, 'MM')
      UNION ALL
      SELECT 'Redemptions This Month',
             COUNT(*),
             SUM(miles_used)
      FROM redemptions
      WHERE redemption_date >= TRUNC(SYSDATE, 'MM')
        AND status IN ('CONFIRMED', 'FULFILLED')
      UNION ALL
      SELECT 'New Members This Month',
             COUNT(*),
             NULL
      FROM members
      WHERE enrollment_date >= TRUNC(SYSDATE, 'MM');

    RETURN v_cursor;
  END get_dashboard_kpis;

  -- Tier distribution
  FUNCTION get_tier_distribution RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
  BEGIN
    OPEN v_cursor FOR
      SELECT tier_status,
             COUNT(*) AS member_count,
             ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage,
             SUM(available_miles) AS total_miles,
             ROUND(AVG(available_miles)) AS avg_miles
      FROM members
      WHERE status = 'ACTIVE'
      GROUP BY tier_status
      ORDER BY DECODE(tier_status, 'DIAMOND', 1, 'PLATINUM', 2, 'GOLD', 3, 'SILVER', 4, 'BLUE', 5);

    RETURN v_cursor;
  END get_tier_distribution;

  -- Monthly accrual trend
  FUNCTION get_monthly_accrual_trend(
    p_months_back IN NUMBER DEFAULT 12
  ) RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
  BEGIN
    OPEN v_cursor FOR
      SELECT TO_CHAR(flight_date, 'YYYY-MM') AS accrual_month,
             COUNT(*) AS flight_count,
             SUM(base_miles) AS total_base_miles,
             SUM(bonus_miles) AS total_bonus_miles,
             SUM(total_miles) AS total_miles,
             COUNT(DISTINCT member_id) AS unique_members
      FROM flights
      WHERE accrual_status = 'PROCESSED'
        AND flight_date >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -p_months_back)
      GROUP BY TO_CHAR(flight_date, 'YYYY-MM')
      ORDER BY accrual_month;

    RETURN v_cursor;
  END get_monthly_accrual_trend;

  -- Top earners
  FUNCTION get_top_earners(
    p_top_n       IN NUMBER DEFAULT 20,
    p_start_date  IN DATE DEFAULT NULL,
    p_end_date    IN DATE DEFAULT NULL
  ) RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
  BEGIN
    OPEN v_cursor FOR
      SELECT m.member_id, m.membership_number,
             m.first_name || ' ' || m.last_name AS member_name,
             m.tier_status,
             SUM(f.total_miles) AS earned_miles,
             COUNT(*) AS flight_count
      FROM members m
      JOIN flights f ON m.member_id = f.member_id
      WHERE f.accrual_status = 'PROCESSED'
        AND f.flight_date >= NVL(p_start_date, ADD_MONTHS(SYSDATE, -12))
        AND f.flight_date <= NVL(p_end_date, SYSDATE)
      GROUP BY m.member_id, m.membership_number,
               m.first_name || ' ' || m.last_name, m.tier_status
      ORDER BY earned_miles DESC
      FETCH FIRST p_top_n ROWS ONLY;

    RETURN v_cursor;
  END get_top_earners;

  -- Partner performance
  FUNCTION get_partner_performance(
    p_start_date  IN DATE DEFAULT NULL,
    p_end_date    IN DATE DEFAULT NULL
  ) RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
  BEGIN
    OPEN v_cursor FOR
      SELECT p.partner_code, p.partner_name, p.partner_type,
             COUNT(pt.txn_id) AS txn_count,
             SUM(pt.miles_earned) AS total_earned,
             SUM(pt.miles_redeemed) AS total_redeemed,
             SUM(pt.amount) AS total_revenue,
             COUNT(DISTINCT pt.member_id) AS unique_members
      FROM partners p
      LEFT JOIN partner_transactions pt ON p.partner_id = pt.partner_id
        AND pt.status = 'PROCESSED'
        AND pt.transaction_date >= NVL(p_start_date, DATE '2000-01-01')
        AND pt.transaction_date <= NVL(p_end_date, SYSDATE)
      WHERE p.status = 'ACTIVE'
      GROUP BY p.partner_code, p.partner_name, p.partner_type
      ORDER BY total_earned DESC NULLS LAST;

    RETURN v_cursor;
  END get_partner_performance;

  -- Redemption analytics
  FUNCTION get_redemption_analytics(
    p_start_date  IN DATE DEFAULT NULL,
    p_end_date    IN DATE DEFAULT NULL
  ) RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
  BEGIN
    OPEN v_cursor FOR
      SELECT rw.category,
             COUNT(*) AS redemption_count,
             SUM(r.miles_used) AS total_miles_used,
             ROUND(AVG(r.miles_used)) AS avg_miles_per_redemption,
             SUM(r.cash_paid) AS total_cash_revenue,
             COUNT(DISTINCT r.member_id) AS unique_members
      FROM redemptions r
      JOIN rewards rw ON r.reward_id = rw.reward_id
      WHERE r.status IN ('CONFIRMED', 'FULFILLED')
        AND r.redemption_date >= NVL(p_start_date, DATE '2000-01-01')
        AND r.redemption_date <= NVL(p_end_date, SYSDATE)
      GROUP BY rw.category
      ORDER BY total_miles_used DESC;

    RETURN v_cursor;
  END get_redemption_analytics;

  -- Liability report
  PROCEDURE generate_liability_report(
    p_total_outstanding_miles OUT NUMBER,
    p_estimated_liability_usd OUT NUMBER,
    p_breakage_estimate_pct   OUT NUMBER
  ) IS
    v_expired_ratio NUMBER;
  BEGIN
    SELECT NVL(SUM(available_miles), 0) INTO p_total_outstanding_miles
    FROM members WHERE status = 'ACTIVE';

    -- Estimated cost per mile: $0.012
    p_estimated_liability_usd := p_total_outstanding_miles * 0.012;

    -- Calculate breakage (historically expired as % of earned)
    SELECT CASE WHEN SUM(miles_amount) > 0
                THEN ROUND(SUM(expired_miles) * 100.0 / SUM(miles_amount), 2)
                ELSE 0 END
    INTO p_breakage_estimate_pct
    FROM miles_expiry;
  END generate_liability_report;

  -- Generate member statement
  FUNCTION generate_member_statement(
    p_member_id   IN  NUMBER,
    p_start_date  IN  DATE,
    p_end_date    IN  DATE
  ) RETURN CLOB IS
    v_stmt CLOB;
    v_member members%ROWTYPE;
  BEGIN
    SELECT * INTO v_member FROM members WHERE member_id = p_member_id;

    v_stmt := '================================================' || CHR(10);
    v_stmt := v_stmt || 'SKYREWARD AIRLINES - MEMBER STATEMENT' || CHR(10);
    v_stmt := v_stmt || '================================================' || CHR(10);
    v_stmt := v_stmt || 'Member: ' || v_member.first_name || ' ' || v_member.last_name || CHR(10);
    v_stmt := v_stmt || 'Membership #: ' || v_member.membership_number || CHR(10);
    v_stmt := v_stmt || 'Tier: ' || v_member.tier_status || CHR(10);
    v_stmt := v_stmt || 'Available Miles: ' || TO_CHAR(v_member.available_miles, '999,999,999') || CHR(10);
    v_stmt := v_stmt || 'Period: ' || TO_CHAR(p_start_date, 'DD-MON-YYYY') ||
              ' to ' || TO_CHAR(p_end_date, 'DD-MON-YYYY') || CHR(10);
    v_stmt := v_stmt || '------------------------------------------------' || CHR(10);
    v_stmt := v_stmt || 'FLIGHT ACTIVITY' || CHR(10);

    FOR rec IN (
      SELECT flight_date, flight_number, departure_airport || '-' || arrival_airport AS route,
             total_miles, accrual_status
      FROM flights
      WHERE member_id = p_member_id
        AND flight_date BETWEEN p_start_date AND p_end_date
      ORDER BY flight_date
    ) LOOP
      v_stmt := v_stmt || TO_CHAR(rec.flight_date, 'DD-MON-YY') || '  ' ||
                RPAD(rec.flight_number, 8) || '  ' || RPAD(rec.route, 10) || '  ' ||
                LPAD(TO_CHAR(rec.total_miles, '999,999'), 10) || '  ' ||
                rec.accrual_status || CHR(10);
    END LOOP;

    v_stmt := v_stmt || '------------------------------------------------' || CHR(10);
    v_stmt := v_stmt || 'REDEMPTIONS' || CHR(10);

    FOR rec IN (
      SELECT r.redemption_date, rw.reward_name, r.miles_used, r.status
      FROM redemptions r
      JOIN rewards rw ON r.reward_id = rw.reward_id
      WHERE r.member_id = p_member_id
        AND r.redemption_date BETWEEN p_start_date AND p_end_date
      ORDER BY r.redemption_date
    ) LOOP
      v_stmt := v_stmt || TO_CHAR(rec.redemption_date, 'DD-MON-YY') || '  ' ||
                RPAD(rec.reward_name, 30) || '  ' ||
                LPAD(TO_CHAR(-rec.miles_used, '999,999'), 10) || '  ' ||
                rec.status || CHR(10);
    END LOOP;

    v_stmt := v_stmt || '================================================' || CHR(10);

    RETURN v_stmt;
  END generate_member_statement;

END pkg_reporting;
/
