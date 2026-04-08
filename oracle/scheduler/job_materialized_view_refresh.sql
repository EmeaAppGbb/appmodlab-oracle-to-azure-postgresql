-- ========================================
-- Scheduler Job: Materialized View Refresh (JOB_MATERIALIZED_VIEW_REFRESH)
-- ========================================
-- DBMS_SCHEDULER job to refresh materialized views nightly

BEGIN
  -- Drop job if it already exists
  BEGIN
    DBMS_SCHEDULER.DROP_JOB(job_name => 'JOB_MVW_REFRESH', force => TRUE);
  EXCEPTION
    WHEN OTHERS THEN NULL;
  END;

  DBMS_SCHEDULER.CREATE_JOB(
    job_name        => 'JOB_MVW_REFRESH',
    job_type        => 'PLSQL_BLOCK',
    job_action      => '
      BEGIN
        -- Refresh monthly accruals materialized view
        DBMS_MVIEW.REFRESH(
          list         => ''MVW_MONTHLY_ACCRUALS'',
          method       => ''C'',  -- Complete refresh
          atomic_refresh => TRUE
        );
        DBMS_OUTPUT.PUT_LINE(''MVW_MONTHLY_ACCRUALS refreshed at '' || TO_CHAR(SYSDATE, ''YYYY-MM-DD HH24:MI:SS''));

        -- Refresh partner summary materialized view
        DBMS_MVIEW.REFRESH(
          list         => ''MVW_PARTNER_SUMMARY'',
          method       => ''C'',  -- Complete refresh
          atomic_refresh => TRUE
        );
        DBMS_OUTPUT.PUT_LINE(''MVW_PARTNER_SUMMARY refreshed at '' || TO_CHAR(SYSDATE, ''YYYY-MM-DD HH24:MI:SS''));

        -- Log completion
        INSERT INTO batch_processing_log (
          batch_id, batch_type, batch_name, start_time, end_time,
          records_processed, records_succeeded, status
        ) VALUES (
          seq_expiry_batch_id.NEXTVAL, ''DATA_CLEANUP'', ''Materialized View Refresh'',
          SYSDATE, SYSDATE, 2, 2, ''COMPLETED''
        );
        COMMIT;

      EXCEPTION
        WHEN OTHERS THEN
          DBMS_OUTPUT.PUT_LINE(''Error refreshing materialized views: '' || SQLERRM);
          INSERT INTO batch_processing_log (
            batch_id, batch_type, batch_name, start_time, end_time,
            status, error_message
          ) VALUES (
            seq_expiry_batch_id.NEXTVAL, ''DATA_CLEANUP'', ''Materialized View Refresh'',
            SYSDATE, SYSDATE, ''FAILED'', SQLERRM
          );
          COMMIT;
          RAISE;
      END;
    ',
    start_date      => SYSTIMESTAMP,
    repeat_interval => 'FREQ=DAILY;BYHOUR=4;BYMINUTE=0;BYSECOND=0',
    end_date        => NULL,
    enabled         => TRUE,
    auto_drop       => FALSE,
    comments        => 'Nightly job to refresh all materialized views. Runs at 4:00 AM daily, after tier recalculation.'
  );

  -- Set job attributes
  DBMS_SCHEDULER.SET_ATTRIBUTE(
    name      => 'JOB_MVW_REFRESH',
    attribute => 'max_failures',
    value     => 3
  );

  DBMS_SCHEDULER.SET_ATTRIBUTE(
    name      => 'JOB_MVW_REFRESH',
    attribute => 'max_run_duration',
    value     => INTERVAL '1' HOUR
  );

  DBMS_SCHEDULER.SET_ATTRIBUTE(
    name      => 'JOB_MVW_REFRESH',
    attribute => 'logging_level',
    value     => DBMS_SCHEDULER.LOGGING_FULL
  );

END;
/
