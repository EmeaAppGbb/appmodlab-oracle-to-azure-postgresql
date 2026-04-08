-- ========================================
-- Package: Batch Processing (PKG_BATCH_PROCESSING)
-- ========================================
-- Manages batch jobs for miles expiry, tier recalculation, and data maintenance

CREATE OR REPLACE PACKAGE pkg_batch_processing AS

  -- Start a batch job
  FUNCTION start_batch(
    p_batch_type  IN VARCHAR2,
    p_batch_name  IN VARCHAR2,
    p_parameters  IN CLOB DEFAULT NULL
  ) RETURN NUMBER;

  -- Complete a batch job
  PROCEDURE complete_batch(
    p_batch_id    IN NUMBER,
    p_records_processed IN NUMBER,
    p_records_succeeded IN NUMBER,
    p_records_failed    IN NUMBER,
    p_status      IN VARCHAR2 DEFAULT 'COMPLETED',
    p_error_msg   IN CLOB DEFAULT NULL
  );

  -- Expire miles batch job
  PROCEDURE run_miles_expiry(
    p_expiry_date IN DATE DEFAULT SYSDATE,
    p_batch_id    OUT NUMBER,
    p_expired_count OUT NUMBER
  );

  -- Tier recalculation batch
  PROCEDURE run_tier_recalculation(
    p_batch_id    OUT NUMBER,
    p_processed   OUT NUMBER,
    p_changed     OUT NUMBER
  );

  -- Data cleanup batch (remove old audit logs, processed notifications)
  PROCEDURE run_data_cleanup(
    p_retention_days IN NUMBER DEFAULT 365,
    p_batch_id       OUT NUMBER,
    p_deleted_count  OUT NUMBER
  );

  -- Year-end miles reset
  PROCEDURE run_ytd_miles_reset(
    p_batch_id    OUT NUMBER,
    p_reset_count OUT NUMBER
  );

  -- Generate monthly statements batch
  PROCEDURE run_statement_generation(
    p_statement_month IN DATE DEFAULT ADD_MONTHS(SYSDATE, -1),
    p_batch_id        OUT NUMBER,
    p_generated_count OUT NUMBER
  );

  -- Get batch job status
  FUNCTION get_batch_status(p_batch_id IN NUMBER) RETURN VARCHAR2;

  -- Get recent batch history
  FUNCTION get_batch_history(
    p_batch_type IN VARCHAR2 DEFAULT NULL,
    p_days_back  IN NUMBER DEFAULT 30
  ) RETURN SYS_REFCURSOR;

END pkg_batch_processing;
/

CREATE OR REPLACE PACKAGE BODY pkg_batch_processing AS

  -- Start a batch job
  FUNCTION start_batch(
    p_batch_type  IN VARCHAR2,
    p_batch_name  IN VARCHAR2,
    p_parameters  IN CLOB DEFAULT NULL
  ) RETURN NUMBER IS
    v_batch_id NUMBER;
  BEGIN
    v_batch_id := seq_expiry_batch_id.NEXTVAL;

    INSERT INTO batch_processing_log (
      batch_id, batch_type, batch_name, start_time, status, parameters
    ) VALUES (
      v_batch_id, p_batch_type, p_batch_name, SYSDATE, 'RUNNING', p_parameters
    );

    COMMIT;
    RETURN v_batch_id;
  END start_batch;

  -- Complete a batch job
  PROCEDURE complete_batch(
    p_batch_id    IN NUMBER,
    p_records_processed IN NUMBER,
    p_records_succeeded IN NUMBER,
    p_records_failed    IN NUMBER,
    p_status      IN VARCHAR2 DEFAULT 'COMPLETED',
    p_error_msg   IN CLOB DEFAULT NULL
  ) IS
  BEGIN
    UPDATE batch_processing_log SET
      end_time          = SYSDATE,
      records_processed = p_records_processed,
      records_succeeded = p_records_succeeded,
      records_failed    = p_records_failed,
      status            = p_status,
      error_message     = p_error_msg
    WHERE batch_id = p_batch_id;

    COMMIT;
  END complete_batch;

  -- Run miles expiry
  PROCEDURE run_miles_expiry(
    p_expiry_date IN DATE DEFAULT SYSDATE,
    p_batch_id    OUT NUMBER,
    p_expired_count OUT NUMBER
  ) IS
    TYPE t_expiry_ids IS TABLE OF miles_expiry.expiry_id%TYPE;
    TYPE t_member_ids IS TABLE OF miles_expiry.member_id%TYPE;
    TYPE t_miles_arr IS TABLE OF miles_expiry.miles_amount%TYPE;

    v_expiry_ids t_expiry_ids;
    v_member_ids t_member_ids;
    v_miles_arr  t_miles_arr;
  BEGIN
    p_batch_id := start_batch('MILES_EXPIRY', 'Nightly Miles Expiry Run');
    p_expired_count := 0;

    -- Find expiring miles
    SELECT expiry_id, member_id, miles_amount - expired_miles
    BULK COLLECT INTO v_expiry_ids, v_member_ids, v_miles_arr
    FROM miles_expiry
    WHERE status = 'ACTIVE'
      AND expiry_date <= p_expiry_date
      AND miles_amount > expired_miles;

    IF v_expiry_ids.COUNT = 0 THEN
      complete_batch(p_batch_id, 0, 0, 0);
      RETURN;
    END IF;

    -- Bulk expire miles
    FORALL i IN v_expiry_ids.FIRST .. v_expiry_ids.LAST
      UPDATE miles_expiry SET
        expired_miles  = miles_amount,
        status         = 'EXPIRED',
        batch_id       = p_batch_id,
        processed_date = SYSDATE
      WHERE expiry_id = v_expiry_ids(i);

    -- Deduct expired miles from member balances
    FOR i IN v_member_ids.FIRST .. v_member_ids.LAST LOOP
      BEGIN
        UPDATE members SET
          available_miles = GREATEST(available_miles - v_miles_arr(i), 0),
          updated_date    = SYSDATE
        WHERE member_id = v_member_ids(i);

        -- Send expiry notification
        pkg_notification.send_notification(
          v_member_ids(i), 'MILES_EXPIRY',
          'Miles Expiration Notice',
          TO_CHAR(v_miles_arr(i), '999,999') || ' miles have expired from your account.'
        );
      EXCEPTION
        WHEN OTHERS THEN
          DBMS_OUTPUT.PUT_LINE('Error expiring miles for member ' || v_member_ids(i) || ': ' || SQLERRM);
      END;
    END LOOP;

    p_expired_count := v_expiry_ids.COUNT;
    complete_batch(p_batch_id, p_expired_count, p_expired_count, 0);

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      complete_batch(p_batch_id, 0, 0, 0, 'FAILED', SQLERRM);
      RAISE;
  END run_miles_expiry;

  -- Run tier recalculation
  PROCEDURE run_tier_recalculation(
    p_batch_id    OUT NUMBER,
    p_processed   OUT NUMBER,
    p_changed     OUT NUMBER
  ) IS
  BEGIN
    p_batch_id := start_batch('TIER_RECALC', 'Nightly Tier Recalculation');

    pkg_tier_calculation.recalculate_all_tiers(p_processed, p_changed);

    complete_batch(p_batch_id, p_processed, p_processed, 0);

  EXCEPTION
    WHEN OTHERS THEN
      complete_batch(p_batch_id, 0, 0, 0, 'FAILED', SQLERRM);
      RAISE;
  END run_tier_recalculation;

  -- Data cleanup
  PROCEDURE run_data_cleanup(
    p_retention_days IN NUMBER DEFAULT 365,
    p_batch_id       OUT NUMBER,
    p_deleted_count  OUT NUMBER
  ) IS
    v_audit_deleted  NUMBER;
    v_notif_deleted  NUMBER;
    v_cutoff_date    DATE;
  BEGIN
    p_batch_id := start_batch('DATA_CLEANUP', 'Periodic Data Cleanup',
      '{"retention_days":' || p_retention_days || '}');
    v_cutoff_date := SYSDATE - p_retention_days;

    -- Clean old audit logs
    DELETE FROM audit_log WHERE changed_date < v_cutoff_date;
    v_audit_deleted := SQL%ROWCOUNT;

    -- Clean sent/cancelled notifications
    DELETE FROM notifications
    WHERE status IN ('SENT', 'CANCELLED')
      AND created_date < v_cutoff_date;
    v_notif_deleted := SQL%ROWCOUNT;

    p_deleted_count := v_audit_deleted + v_notif_deleted;
    complete_batch(p_batch_id, p_deleted_count, p_deleted_count, 0);

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      complete_batch(p_batch_id, 0, 0, 0, 'FAILED', SQLERRM);
      RAISE;
  END run_data_cleanup;

  -- Year-end YTD miles reset
  PROCEDURE run_ytd_miles_reset(
    p_batch_id    OUT NUMBER,
    p_reset_count OUT NUMBER
  ) IS
  BEGIN
    p_batch_id := start_batch('DATA_CLEANUP', 'Year-End YTD Miles Reset');

    UPDATE members SET
      ytd_miles    = 0,
      updated_date = SYSDATE
    WHERE status = 'ACTIVE';

    p_reset_count := SQL%ROWCOUNT;
    complete_batch(p_batch_id, p_reset_count, p_reset_count, 0);

    COMMIT;
  END run_ytd_miles_reset;

  -- Statement generation
  PROCEDURE run_statement_generation(
    p_statement_month IN DATE DEFAULT ADD_MONTHS(SYSDATE, -1),
    p_batch_id        OUT NUMBER,
    p_generated_count OUT NUMBER
  ) IS
    v_start_date DATE := TRUNC(p_statement_month, 'MM');
    v_end_date   DATE := LAST_DAY(p_statement_month);
    v_statement  CLOB;
  BEGIN
    p_batch_id := start_batch('STATEMENT_GEN', 'Monthly Statement Generation');
    p_generated_count := 0;

    FOR rec IN (
      SELECT member_id, email FROM members
      WHERE status = 'ACTIVE'
        AND communication_pref IN ('EMAIL', 'MAIL')
    ) LOOP
      BEGIN
        v_statement := pkg_reporting.generate_member_statement(rec.member_id, v_start_date, v_end_date);

        pkg_notification.send_notification(
          rec.member_id, 'STATEMENT',
          'Your SkyReward Monthly Statement - ' || TO_CHAR(p_statement_month, 'MON YYYY'),
          v_statement
        );

        p_generated_count := p_generated_count + 1;
      EXCEPTION
        WHEN OTHERS THEN
          DBMS_OUTPUT.PUT_LINE('Statement error for member ' || rec.member_id || ': ' || SQLERRM);
      END;
    END LOOP;

    complete_batch(p_batch_id, p_generated_count, p_generated_count, 0);
    COMMIT;
  END run_statement_generation;

  -- Get batch status
  FUNCTION get_batch_status(p_batch_id IN NUMBER) RETURN VARCHAR2 IS
    v_status VARCHAR2(20);
  BEGIN
    SELECT status INTO v_status
    FROM batch_processing_log WHERE batch_id = p_batch_id;
    RETURN v_status;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN 'NOT_FOUND';
  END get_batch_status;

  -- Get batch history
  FUNCTION get_batch_history(
    p_batch_type IN VARCHAR2 DEFAULT NULL,
    p_days_back  IN NUMBER DEFAULT 30
  ) RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
  BEGIN
    OPEN v_cursor FOR
      SELECT batch_id, batch_type, batch_name, start_time, end_time,
             records_processed, records_succeeded, records_failed,
             status, run_by
      FROM batch_processing_log
      WHERE (p_batch_type IS NULL OR batch_type = p_batch_type)
        AND start_time >= SYSDATE - p_days_back
      ORDER BY start_time DESC;

    RETURN v_cursor;
  END get_batch_history;

END pkg_batch_processing;
/
