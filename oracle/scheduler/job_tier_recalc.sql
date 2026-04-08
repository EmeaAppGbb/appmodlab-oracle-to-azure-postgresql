-- ========================================
-- Scheduler Job: Tier Recalculation (JOB_TIER_RECALC)
-- ========================================
-- DBMS_SCHEDULER job to run nightly tier status recalculation

BEGIN
  -- Drop job if it already exists
  BEGIN
    DBMS_SCHEDULER.DROP_JOB(job_name => 'JOB_TIER_RECALC', force => TRUE);
  EXCEPTION
    WHEN OTHERS THEN NULL;
  END;

  DBMS_SCHEDULER.CREATE_JOB(
    job_name        => 'JOB_TIER_RECALC',
    job_type        => 'PLSQL_BLOCK',
    job_action      => '
      DECLARE
        v_batch_id   NUMBER;
        v_processed  NUMBER;
        v_upgraded   NUMBER;
        v_downgraded NUMBER;
        v_unchanged  NUMBER;
      BEGIN
        pr_recalculate_tiers(
          p_batch_id   => v_batch_id,
          p_processed  => v_processed,
          p_upgraded   => v_upgraded,
          p_downgraded => v_downgraded,
          p_unchanged  => v_unchanged
        );
        DBMS_OUTPUT.PUT_LINE(''Tier recalculation completed. Batch: '' || v_batch_id ||
                             '', Processed: '' || v_processed ||
                             '', Upgraded: '' || v_upgraded ||
                             '', Downgraded: '' || v_downgraded);
      END;
    ',
    start_date      => SYSTIMESTAMP,
    repeat_interval => 'FREQ=DAILY;BYHOUR=3;BYMINUTE=0;BYSECOND=0',
    end_date        => NULL,
    enabled         => TRUE,
    auto_drop       => FALSE,
    comments        => 'Nightly job to recalculate all active member tier statuses. Runs at 3:00 AM daily, after miles expiry.'
  );

  -- Set job attributes
  DBMS_SCHEDULER.SET_ATTRIBUTE(
    name      => 'JOB_TIER_RECALC',
    attribute => 'max_failures',
    value     => 3
  );

  DBMS_SCHEDULER.SET_ATTRIBUTE(
    name      => 'JOB_TIER_RECALC',
    attribute => 'max_run_duration',
    value     => INTERVAL '4' HOUR
  );

  DBMS_SCHEDULER.SET_ATTRIBUTE(
    name      => 'JOB_TIER_RECALC',
    attribute => 'logging_level',
    value     => DBMS_SCHEDULER.LOGGING_FULL
  );

END;
/
