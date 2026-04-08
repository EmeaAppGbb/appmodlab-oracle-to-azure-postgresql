-- ========================================
-- View: Member Summary (VW_MEMBER_SUMMARY)
-- ========================================
-- Comprehensive member view with aggregated flight and redemption stats

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
  -- Oracle-specific: MONTHS_BETWEEN for membership duration
  ROUND(MONTHS_BETWEEN(SYSDATE, m.enrollment_date)) AS membership_months,
  -- Flight statistics
  NVL(f.total_flights, 0) AS total_flights,
  NVL(f.ytd_flights, 0) AS ytd_flights,
  NVL(f.total_flight_miles, 0) AS total_flight_miles,
  f.last_flight_date,
  -- Redemption statistics
  NVL(r.total_redemptions, 0) AS total_redemptions,
  NVL(r.total_miles_redeemed, 0) AS total_miles_redeemed,
  r.last_redemption_date,
  -- Oracle-specific: DECODE for tier display
  DECODE(m.tier_status,
    'DIAMOND',  '★★★★★',
    'PLATINUM', '★★★★',
    'GOLD',     '★★★',
    'SILVER',   '★★',
    'BLUE',     '★'
  ) AS tier_stars,
  -- Days until tier expiry
  TRUNC(m.tier_expiry_date - SYSDATE) AS days_until_tier_expiry,
  -- Oracle analytic: rank within tier
  RANK() OVER (PARTITION BY m.tier_status ORDER BY m.lifetime_miles DESC) AS tier_rank
FROM members m
LEFT JOIN (
  SELECT member_id,
         COUNT(*) AS total_flights,
         SUM(CASE WHEN flight_date >= TRUNC(SYSDATE, 'YYYY') THEN 1 ELSE 0 END) AS ytd_flights,
         SUM(total_miles) AS total_flight_miles,
         MAX(flight_date) AS last_flight_date
  FROM flights
  WHERE accrual_status = 'PROCESSED'
  GROUP BY member_id
) f ON m.member_id = f.member_id
LEFT JOIN (
  SELECT member_id,
         COUNT(*) AS total_redemptions,
         SUM(miles_used) AS total_miles_redeemed,
         MAX(redemption_date) AS last_redemption_date
  FROM redemptions
  WHERE status IN ('CONFIRMED', 'FULFILLED')
  GROUP BY member_id
) r ON m.member_id = r.member_id
WHERE m.status != 'CLOSED';
