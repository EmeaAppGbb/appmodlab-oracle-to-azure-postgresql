-- ============================================================================
-- Job: Tier Recalculation (pg_cron)
-- ============================================================================
-- Migrated from: Oracle DBMS_SCHEDULER  JOB_TIER_RECALC
-- Oracle source:  oracle/scheduler/job_tier_recalc.sql
--
-- Oracle schedule : FREQ=DAILY; BYHOUR=3; BYMINUTE=0; BYSECOND=0
-- pg_cron crontab : 0 3 * * *   (daily at 03:00 AM)
--
-- Differences from Oracle DBMS_SCHEDULER:
--   - max_failures (3)       – pg_cron has no equivalent; monitor failures
--                               via cron.job_run_details.
--   - max_run_duration (4h)  – pg_cron does not enforce a maximum runtime.
--                               Use statement_timeout if a hard limit is
--                               required.
--   - logging_level (FULL)   – pg_cron logs every run in
--                               cron.job_run_details automatically.
--   - Runs after job_expire_miles (Oracle dependency via schedule offset);
--     in pg_cron the 1-hour gap (02:00 → 03:00) preserves the intended
--     ordering. For strict chaining, call pr_recalculate_tiers() from
--     within pr_expire_miles or use pg_cron job chaining via
--     cron.job_run_details polling.
--
-- Prerequisites:
--   CREATE EXTENSION IF NOT EXISTS pg_cron;
-- ============================================================================

-- Schedule nightly tier recalculation at 3:00 AM daily
SELECT cron.schedule(
    'job_tier_recalc',
    '0 3 * * *',
    $$SELECT * FROM pr_recalculate_tiers()$$
);
