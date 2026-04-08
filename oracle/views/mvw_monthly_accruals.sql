-- ========================================
-- Materialized View: Monthly Accruals (MVW_MONTHLY_ACCRUALS)
-- ========================================
-- Pre-aggregated monthly accrual data for reporting dashboards

CREATE MATERIALIZED VIEW mvw_monthly_accruals
  BUILD IMMEDIATE
  REFRESH FAST ON DEMAND
  ENABLE QUERY REWRITE
AS
SELECT
  TO_CHAR(f.flight_date, 'YYYY-MM') AS accrual_month,
  TO_NUMBER(TO_CHAR(f.flight_date, 'YYYY')) AS accrual_year,
  TO_NUMBER(TO_CHAR(f.flight_date, 'MM')) AS accrual_month_num,
  f.airline_code,
  f.cabin_class,
  m.tier_status,
  m.country AS member_country,
  -- Aggregations
  COUNT(*) AS flight_count,
  COUNT(DISTINCT f.member_id) AS unique_members,
  SUM(f.distance_miles) AS total_distance,
  SUM(f.base_miles) AS total_base_miles,
  SUM(f.bonus_miles) AS total_bonus_miles,
  SUM(f.tier_miles) AS total_tier_miles,
  SUM(f.total_miles) AS total_miles_earned,
  SUM(f.fare_amount) AS total_fare_revenue,
  ROUND(AVG(f.total_miles)) AS avg_miles_per_flight,
  ROUND(AVG(f.distance_miles)) AS avg_distance,
  MIN(f.flight_date) AS first_flight_date,
  MAX(f.flight_date) AS last_flight_date
FROM flights f
JOIN members m ON f.member_id = m.member_id
WHERE f.accrual_status = 'PROCESSED'
  AND f.status = 'ACTIVE'
GROUP BY
  TO_CHAR(f.flight_date, 'YYYY-MM'),
  TO_NUMBER(TO_CHAR(f.flight_date, 'YYYY')),
  TO_NUMBER(TO_CHAR(f.flight_date, 'MM')),
  f.airline_code,
  f.cabin_class,
  m.tier_status,
  m.country;

-- Create indexes on the materialized view
CREATE INDEX idx_mvw_accruals_month ON mvw_monthly_accruals(accrual_month);
CREATE INDEX idx_mvw_accruals_airline ON mvw_monthly_accruals(airline_code);
CREATE INDEX idx_mvw_accruals_tier ON mvw_monthly_accruals(tier_status);
CREATE INDEX idx_mvw_accruals_country ON mvw_monthly_accruals(member_country);

COMMENT ON MATERIALIZED VIEW mvw_monthly_accruals IS 'Pre-aggregated monthly flight accrual data by airline, cabin class, tier, and country. Refreshed nightly by DBMS_SCHEDULER job.';
