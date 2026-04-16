-- ============================================================================
-- Job: Expire Miles (pg_cron)
-- ============================================================================
-- Migrated from: Oracle DBMS_SCHEDULER  JOB_EXPIRE_MILES
-- Oracle source:  oracle/scheduler/job_expire_miles.sql
--
-- Oracle schedule : FREQ=DAILY; BYHOUR=2; BYMINUTE=0; BYSECOND=0
-- pg_cron crontab : 0 2 * * *   (daily at 02:00 AM)
--
-- Differences from Oracle DBMS_SCHEDULER:
--   - max_failures (3)       – pg_cron has no equivalent; failed runs are
--                               logged in cron.job_run_details but the job
--                               keeps running on schedule. Monitor externally.
--   - max_run_duration (2h)  – pg_cron does not enforce a maximum runtime.
--                               Use statement_timeout inside the called
--                               function if a hard limit is required.
--   - logging_level (FULL)   – pg_cron automatically logs every run in
--                               cron.job_run_details (start, end, status,
--                               return_message).
--
-- Prerequisites:
--   CREATE EXTENSION IF NOT EXISTS pg_cron;
-- ============================================================================

-- Schedule nightly miles expiry at 2:00 AM daily
SELECT cron.schedule(
    'job_expire_miles',
    '0 2 * * *',
    $$SELECT * FROM pr_expire_miles(CURRENT_DATE)$$
);
