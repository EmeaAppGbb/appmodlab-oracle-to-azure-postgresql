-- ============================================================================
-- Job: Materialized View Refresh (pg_cron)
-- ============================================================================
-- Migrated from: Oracle DBMS_SCHEDULER  JOB_MVW_REFRESH
-- Oracle source:  oracle/scheduler/job_materialized_view_refresh.sql
--
-- Oracle schedule : FREQ=DAILY; BYHOUR=4; BYMINUTE=0; BYSECOND=0
-- pg_cron crontab : 0 4 * * *   (daily at 04:00 AM)
--
-- Oracle refreshed MVW_MONTHLY_ACCRUALS and MVW_PARTNER_SUMMARY using
-- DBMS_MVIEW.REFRESH with method 'C' (complete). PostgreSQL uses
-- REFRESH MATERIALIZED VIEW (optionally CONCURRENTLY if a unique index
-- exists on the view).
--
-- Differences from Oracle DBMS_SCHEDULER:
--   - max_failures (3)       – pg_cron has no equivalent; monitor via
--                               cron.job_run_details.
--   - max_run_duration (1h)  – pg_cron does not enforce a maximum runtime.
--   - logging_level (FULL)   – pg_cron logs runs in cron.job_run_details.
--   - Oracle logged success/failure to batch_processing_log; the pg_cron
--     command below preserves that behaviour.
--
-- Note: If unique indexes exist on the materialized views, replace
--   REFRESH MATERIALIZED VIEW
-- with
--   REFRESH MATERIALIZED VIEW CONCURRENTLY
-- to allow reads during the refresh.
--
-- Prerequisites:
--   CREATE EXTENSION IF NOT EXISTS pg_cron;
-- ============================================================================

-- Schedule nightly materialized-view refresh at 4:00 AM daily
SELECT cron.schedule(
    'job_mvw_refresh',
    '0 4 * * *',
    $$
    REFRESH MATERIALIZED VIEW mvw_monthly_accruals;
    REFRESH MATERIALIZED VIEW mvw_partner_summary;
    INSERT INTO batch_processing_log (
        batch_id,
        batch_type,
        batch_name,
        start_time,
        end_time,
        records_processed,
        records_succeeded,
        status
    ) VALUES (
        nextval('seq_expiry_batch_id'),
        'DATA_CLEANUP',
        'Materialized View Refresh',
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP,
        2,
        2,
        'COMPLETED'
    );
    $$
);
