-- ============================================================================
-- Materialized View: Partner Summary (MVW_PARTNER_SUMMARY)
-- Converted from Oracle materialized view MVW_PARTNER_SUMMARY to PostgreSQL.
--
-- Conversion notes:
--   - BUILD IMMEDIATE, REFRESH COMPLETE ON DEMAND, ENABLE QUERY REWRITE removed
--     (PostgreSQL does not support these clauses; use REFRESH MATERIALIZED VIEW
--      manually or via pg_cron)
--   - NVL replaced with COALESCE
--   - TO_CHAR(date, 'YYYY-MM') kept as-is (valid in PostgreSQL)
-- ============================================================================

CREATE MATERIALIZED VIEW mvw_partner_summary AS
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
    COALESCE(SUM(pt.miles_earned), 0) AS total_miles_earned,
    COALESCE(SUM(pt.miles_redeemed), 0) AS total_miles_redeemed,
    COALESCE(SUM(pt.amount), 0) AS total_amount,
    COALESCE(SUM(pt.miles_earned), 0) - COALESCE(SUM(pt.miles_redeemed), 0) AS net_miles,
    ROUND(AVG(pt.amount), 2) AS avg_transaction_amount,
    MIN(pt.transaction_date) AS first_txn_date,
    MAX(pt.transaction_date) AS last_txn_date,
    -- Settlement calculation (miles at $0.012 per mile)
    ROUND(
        (COALESCE(SUM(pt.miles_earned), 0) - COALESCE(SUM(pt.miles_redeemed), 0)) * 0.012,
        2
    ) AS estimated_settlement_usd
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
CREATE INDEX idx_mvw_partner_code  ON mvw_partner_summary(partner_code);
CREATE INDEX idx_mvw_partner_month ON mvw_partner_summary(txn_month);
CREATE INDEX idx_mvw_partner_type  ON mvw_partner_summary(partner_type);

COMMENT ON MATERIALIZED VIEW mvw_partner_summary IS
    'Pre-aggregated partner transaction summary by month and transaction type. Used for settlement processing and partner performance dashboards. Refresh with: REFRESH MATERIALIZED VIEW mvw_partner_summary;';
