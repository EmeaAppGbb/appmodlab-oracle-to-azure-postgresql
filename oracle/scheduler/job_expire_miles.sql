-- ========================================
-- Scheduler Job: Expire Miles (JOB_EXPIRE_MILES)
-- ========================================
-- DBMS_SCHEDULER job to run nightly miles expiration

BEGIN
  -- Drop job if it already exists
  BEGIN
    DBMS_SCHEDULER.DROP_JOB(job_name => 'JOB_EXPIRE_MILES', force => TRUE);
  EXCEPTION
    WHEN OTHERS THEN NULL;
  END;

  DBMS_SCHEDULER.CREATE_JOB(
    job_name        => 'JOB_EXPIRE_MILES',
    job_type        => 'PLSQL_BLOCK',
    job_action      => '
      DECLARE
        v_batch_id      NUMBER;
        v_expired_count NUMBER;
        v_total_miles   NUMBER;
      BEGIN
        pr_expire_miles(
          p_run_date      => SYSDATE,
          p_batch_id      => v_batch_id,
          p_expired_count => v_expired_count,
          p_total_miles   => v_total_miles
        );
        DBMS_OUTPUT.PUT_LINE(''Miles expiry job completed. Batch: '' || v_batch_id ||
                             '', Expired: '' || v_expired_count ||
                             '', Miles: '' || v_total_miles);
      END;
    ',
    start_date      => SYSTIMESTAMP,
    repeat_interval => 'FREQ=DAILY;BYHOUR=2;BYMINUTE=0;BYSECOND=0',
    end_date        => NULL,
    enabled         => TRUE,
    auto_drop       => FALSE,
    comments        => 'Nightly job to expire miles that have passed their expiry date. Runs at 2:00 AM daily.'
  );

  -- Set job attributes
  DBMS_SCHEDULER.SET_ATTRIBUTE(
    name      => 'JOB_EXPIRE_MILES',
    attribute => 'max_failures',
    value     => 3
  );

  DBMS_SCHEDULER.SET_ATTRIBUTE(
    name      => 'JOB_EXPIRE_MILES',
    attribute => 'max_run_duration',
    value     => INTERVAL '2' HOUR
  );

  DBMS_SCHEDULER.SET_ATTRIBUTE(
    name      => 'JOB_EXPIRE_MILES',
    attribute => 'logging_level',
    value     => DBMS_SCHEDULER.LOGGING_FULL
  );

END;
/
