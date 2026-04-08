-- ========================================
-- Procedure: Process Bulk Accrual (PR_PROCESS_BULK_ACCRUAL)
-- ========================================
-- Bulk processes pending flight accruals using FORALL and BULK COLLECT

CREATE OR REPLACE PROCEDURE pr_process_bulk_accrual(
  p_batch_size     IN  NUMBER DEFAULT 5000,
  p_batch_id       OUT NUMBER,
  p_processed      OUT NUMBER,
  p_failed         OUT NUMBER
)
IS
  -- Collection types for BULK COLLECT
  TYPE t_flight_id_tab  IS TABLE OF flights.flight_id%TYPE;
  TYPE t_member_id_tab  IS TABLE OF flights.member_id%TYPE;
  TYPE t_miles_tab      IS TABLE OF flights.total_miles%TYPE;
  TYPE t_tier_miles_tab IS TABLE OF flights.tier_miles%TYPE;
  TYPE t_flight_date_tab IS TABLE OF flights.flight_date%TYPE;

  v_flight_ids   t_flight_id_tab;
  v_member_ids   t_member_id_tab;
  v_total_miles  t_miles_tab;
  v_tier_miles   t_tier_miles_tab;
  v_flight_dates t_flight_date_tab;

  v_errors NUMBER := 0;

  -- DML error logging
  ex_dml_errors EXCEPTION;
  PRAGMA EXCEPTION_INIT(ex_dml_errors, -24381);

BEGIN
  p_batch_id := pkg_batch_processing.start_batch(
    'BULK_ACCRUAL', 'Bulk Flight Accrual Processing',
    '{"batch_size":' || p_batch_size || '}'
  );
  p_processed := 0;
  p_failed := 0;

  -- BULK COLLECT pending flights
  SELECT flight_id, member_id, total_miles, tier_miles, flight_date
  BULK COLLECT INTO v_flight_ids, v_member_ids, v_total_miles, v_tier_miles, v_flight_dates
  FROM flights
  WHERE accrual_status = 'PENDING'
    AND status = 'ACTIVE'
  ORDER BY flight_date ASC
  FETCH FIRST p_batch_size ROWS ONLY;

  IF v_flight_ids.COUNT = 0 THEN
    pkg_batch_processing.complete_batch(p_batch_id, 0, 0, 0);
    DBMS_OUTPUT.PUT_LINE('No pending accruals to process.');
    RETURN;
  END IF;

  DBMS_OUTPUT.PUT_LINE('Processing ' || v_flight_ids.COUNT || ' pending accruals...');

  -- FORALL bulk update flights to PROCESSED (Oracle bulk DML)
  BEGIN
    FORALL i IN v_flight_ids.FIRST .. v_flight_ids.LAST SAVE EXCEPTIONS
      UPDATE flights SET
        accrual_status = 'PROCESSED',
        processed_date = SYSDATE,
        updated_date   = SYSDATE
      WHERE flight_id = v_flight_ids(i)
        AND accrual_status = 'PENDING';
  EXCEPTION
    WHEN ex_dml_errors THEN
      v_errors := SQL%BULK_EXCEPTIONS.COUNT;
      FOR i IN 1 .. v_errors LOOP
        DBMS_OUTPUT.PUT_LINE('Error at index ' || SQL%BULK_EXCEPTIONS(i).ERROR_INDEX ||
                             ': ' || SQLERRM(-SQL%BULK_EXCEPTIONS(i).ERROR_CODE));
      END LOOP;
  END;

  -- Update member balances - row-by-row (needs individual member logic)
  FOR i IN v_member_ids.FIRST .. v_member_ids.LAST LOOP
    BEGIN
      -- Update available miles, total miles, YTD, and lifetime
      UPDATE members SET
        available_miles    = available_miles + v_total_miles(i),
        total_miles        = total_miles + v_total_miles(i),
        ytd_miles          = ytd_miles + v_tier_miles(i),
        lifetime_miles     = lifetime_miles + v_total_miles(i),
        last_activity_date = GREATEST(NVL(last_activity_date, v_flight_dates(i)), v_flight_dates(i)),
        updated_date       = SYSDATE
      WHERE member_id = v_member_ids(i);

      -- Insert miles expiry record (miles expire after 36 months)
      INSERT INTO miles_expiry (
        expiry_id, member_id, source_type, source_id,
        miles_amount, earned_date, expiry_date, status
      ) VALUES (
        seq_expiry_batch_id.NEXTVAL, v_member_ids(i), 'FLIGHT', v_flight_ids(i),
        v_total_miles(i), v_flight_dates(i), ADD_MONTHS(v_flight_dates(i), 36), 'ACTIVE'
      );

      p_processed := p_processed + 1;
    EXCEPTION
      WHEN OTHERS THEN
        p_failed := p_failed + 1;
        DBMS_OUTPUT.PUT_LINE('Error processing member ' || v_member_ids(i) ||
                             ', flight ' || v_flight_ids(i) || ': ' || SQLERRM);
    END;
  END LOOP;

  pkg_batch_processing.complete_batch(p_batch_id, v_flight_ids.COUNT, p_processed, p_failed);

  COMMIT;

  DBMS_OUTPUT.PUT_LINE('Bulk accrual complete. Processed: ' || p_processed ||
                       ', Failed: ' || p_failed);

EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    pkg_batch_processing.complete_batch(p_batch_id, 0, 0, v_flight_ids.COUNT, 'FAILED', SQLERRM);
    RAISE;
END pr_process_bulk_accrual;
/
