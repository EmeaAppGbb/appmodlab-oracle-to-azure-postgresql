-- ============================================================================
-- View: Member Summary (VW_MEMBER_SUMMARY)
-- Converted from Oracle view VW_MEMBER_SUMMARY to PostgreSQL.
--
-- Conversion notes:
--   - MONTHS_BETWEEN(SYSDATE, date) replaced with
--     EXTRACT(YEAR FROM age(...)) * 12 + EXTRACT(MONTH FROM age(...))
--   - DECODE replaced with CASE expression
--   - NVL replaced with COALESCE
--   - TRUNC(SYSDATE, 'YYYY') replaced with DATE_TRUNC('year', CURRENT_DATE)
--   - TRUNC(tier_expiry_date - SYSDATE) replaced with integer subtraction
--   - SYSDATE replaced with CURRENT_DATE
-- ============================================================================

CREATE OR REPLACE VIEW vw_member_summary AS
SELECT
    m.member_id,
    m.membership_number,
    m.first_name || ' ' || m.last_name AS member_name,
    m.email,
    m.tier_status,
    m.available_miles,
    m.total_miles,
    m.ytd_miles,
    m.lifetime_miles,
    m.enrollment_date,
    m.tier_expiry_date,
    m.last_activity_date,
    m.preferred_airport,
    m.status,
    -- Membership duration in months
    ROUND(
        EXTRACT(YEAR FROM age(CURRENT_DATE, m.enrollment_date)) * 12 +
        EXTRACT(MONTH FROM age(CURRENT_DATE, m.enrollment_date))
    )::INT AS membership_months,
    -- Flight statistics
    COALESCE(f.total_flights, 0) AS total_flights,
    COALESCE(f.ytd_flights, 0) AS ytd_flights,
    COALESCE(f.total_flight_miles, 0) AS total_flight_miles,
    f.last_flight_date,
    -- Redemption statistics
    COALESCE(r.total_redemptions, 0) AS total_redemptions,
    COALESCE(r.total_miles_redeemed, 0) AS total_miles_redeemed,
    r.last_redemption_date,
    -- Tier stars display
    CASE m.tier_status
        WHEN 'DIAMOND'  THEN '★★★★★'
        WHEN 'PLATINUM' THEN '★★★★'
        WHEN 'GOLD'     THEN '★★★'
        WHEN 'SILVER'   THEN '★★'
        WHEN 'BLUE'     THEN '★'
    END AS tier_stars,
    -- Days until tier expiry
    (m.tier_expiry_date - CURRENT_DATE) AS days_until_tier_expiry,
    -- Rank within tier
    RANK() OVER (PARTITION BY m.tier_status ORDER BY m.lifetime_miles DESC) AS tier_rank
FROM members m
LEFT JOIN (
    SELECT member_id,
           COUNT(*) AS total_flights,
           SUM(CASE WHEN flight_date >= DATE_TRUNC('year', CURRENT_DATE) THEN 1 ELSE 0 END) AS ytd_flights,
           SUM(total_miles) AS total_flight_miles,
           MAX(flight_date) AS last_flight_date
    FROM   flights
    WHERE  accrual_status = 'PROCESSED'
    GROUP  BY member_id
) f ON m.member_id = f.member_id
LEFT JOIN (
    SELECT member_id,
           COUNT(*) AS total_redemptions,
           SUM(miles_used) AS total_miles_redeemed,
           MAX(redemption_date) AS last_redemption_date
    FROM   redemptions
    WHERE  status IN ('CONFIRMED', 'FULFILLED')
    GROUP  BY member_id
) r ON m.member_id = r.member_id
WHERE m.status != 'CLOSED';
