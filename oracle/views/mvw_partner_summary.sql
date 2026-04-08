-- ========================================
-- Materialized View: Partner Summary (MVW_PARTNER_SUMMARY)
-- ========================================
-- Pre-aggregated partner transaction data for settlement and reporting

CREATE MATERIALIZED VIEW mvw_partner_summary
  BUILD IMMEDIATE
  REFRESH COMPLETE ON DEMAND
  ENABLE QUERY REWRITE
AS
SELECT
  p.partner_id,
  p.partner_code,
  p.partner_name,
  p.partner_type,
  p.conversion_rate,
  TO_CHAR(pt.transaction_date, 'YYYY-MM') AS txn_month,
  pt.transaction_type,
  -- Aggregations
  COUNT(*) AS txn_count,
  COUNT(DISTINCT pt.member_id) AS unique_members,
  NVL(SUM(pt.miles_earned), 0) AS total_miles_earned,
  NVL(SUM(pt.miles_redeemed), 0) AS total_miles_redeemed,
  NVL(SUM(pt.amount), 0) AS total_amount,
  NVL(SUM(pt.miles_earned), 0) - NVL(SUM(pt.miles_redeemed), 0) AS net_miles,
  ROUND(AVG(pt.amount), 2) AS avg_transaction_amount,
  MIN(pt.transaction_date) AS first_txn_date,
  MAX(pt.transaction_date) AS last_txn_date,
  -- Settlement calculation (miles at $0.012 per mile)
  ROUND((NVL(SUM(pt.miles_earned), 0) - NVL(SUM(pt.miles_redeemed), 0)) * 0.012, 2) AS estimated_settlement_usd
FROM partners p
LEFT JOIN partner_transactions pt ON p.partner_id = pt.partner_id
  AND pt.status = 'PROCESSED'
GROUP BY
  p.partner_id,
  p.partner_code,
  p.partner_name,
  p.partner_type,
  p.conversion_rate,
  TO_CHAR(pt.transaction_date, 'YYYY-MM'),
  pt.transaction_type;

-- Indexes on materialized view
CREATE INDEX idx_mvw_partner_code ON mvw_partner_summary(partner_code);
CREATE INDEX idx_mvw_partner_month ON mvw_partner_summary(txn_month);
CREATE INDEX idx_mvw_partner_type ON mvw_partner_summary(partner_type);

COMMENT ON MATERIALIZED VIEW mvw_partner_summary IS 'Pre-aggregated partner transaction summary by month and transaction type. Used for settlement processing and partner performance dashboards.';
