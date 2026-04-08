-- ========================================
-- View: Tier Status Report (VW_TIER_STATUS_REPORT)
-- ========================================
-- Provides tier distribution and analytics for management reporting

CREATE OR REPLACE VIEW vw_tier_status_report AS
SELECT
  tr.tier_name,
  tr.min_miles,
  tr.min_segments,
  tr.miles_multiplier,
  tr.bonus_miles_pct,
  -- Oracle DECODE for tier ordering
  DECODE(tr.tier_name,
    'BLUE', 1, 'SILVER', 2, 'GOLD', 3, 'PLATINUM', 4, 'DIAMOND', 5
  ) AS tier_order,
  -- Member counts
  NVL(ms.member_count, 0) AS member_count,
  NVL(ms.active_count, 0) AS active_members,
  -- Miles statistics using Oracle analytics
  NVL(ms.total_available_miles, 0) AS total_available_miles,
  NVL(ms.avg_available_miles, 0) AS avg_available_miles,
  NVL(ms.total_lifetime_miles, 0) AS total_lifetime_miles,
  -- Flight activity
  NVL(fa.total_flights_ytd, 0) AS total_flights_ytd,
  NVL(fa.total_miles_ytd, 0) AS total_miles_ytd,
  -- Redemption activity
  NVL(ra.total_redemptions_ytd, 0) AS total_redemptions_ytd,
  NVL(ra.total_miles_redeemed_ytd, 0) AS total_miles_redeemed_ytd,
  -- Tier benefits
  tr.lounge_access,
  tr.priority_boarding,
  tr.free_upgrades,
  tr.bag_allowance,
  -- Percentage distribution (Oracle analytic)
  ROUND(NVL(ms.member_count, 0) * 100.0 /
    NULLIF(SUM(NVL(ms.member_count, 0)) OVER (), 0), 2) AS pct_of_total
FROM tier_rules tr
LEFT JOIN (
  SELECT tier_status,
         COUNT(*) AS member_count,
         SUM(CASE WHEN status = 'ACTIVE' THEN 1 ELSE 0 END) AS active_count,
         SUM(available_miles) AS total_available_miles,
         ROUND(AVG(available_miles)) AS avg_available_miles,
         SUM(lifetime_miles) AS total_lifetime_miles
  FROM members
  GROUP BY tier_status
) ms ON tr.tier_name = ms.tier_status
LEFT JOIN (
  SELECT m.tier_status,
         COUNT(f.flight_id) AS total_flights_ytd,
         NVL(SUM(f.total_miles), 0) AS total_miles_ytd
  FROM members m
  JOIN flights f ON m.member_id = f.member_id
  WHERE f.flight_date >= TRUNC(SYSDATE, 'YYYY')
    AND f.accrual_status = 'PROCESSED'
  GROUP BY m.tier_status
) fa ON tr.tier_name = fa.tier_status
LEFT JOIN (
  SELECT m.tier_status,
         COUNT(r.redemption_id) AS total_redemptions_ytd,
         NVL(SUM(r.miles_used), 0) AS total_miles_redeemed_ytd
  FROM members m
  JOIN redemptions r ON m.member_id = r.member_id
  WHERE r.redemption_date >= TRUNC(SYSDATE, 'YYYY')
    AND r.status IN ('CONFIRMED', 'FULFILLED')
  GROUP BY m.tier_status
) ra ON tr.tier_name = ra.tier_status
WHERE tr.status = 'ACTIVE'
ORDER BY tier_order;
