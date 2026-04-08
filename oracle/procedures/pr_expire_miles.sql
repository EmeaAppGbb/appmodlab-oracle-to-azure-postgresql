-- ========================================
-- Procedure: Expire Miles (PR_EXPIRE_MILES)
-- ========================================
-- Processes miles expiration for members with inactive miles batches

CREATE OR REPLACE PROCEDURE pr_expire_miles(
  p_run_date       IN DATE DEFAULT SYSDATE,
  p_batch_id       OUT NUMBER,
  p_expired_count  OUT NUMBER,
  p_total_miles    OUT NUMBER
)
IS
  TYPE t_expiry_rec IS RECORD (
    expiry_id   miles_expiry.expiry_id%TYPE,
    member_id   miles_expiry.member_id%TYPE,
    miles_to_expire NUMBER
  );

  TYPE t_expiry_tab IS TABLE OF t_expiry_rec INDEX BY PLS_INTEGER;
  v_expiry_data t_expiry_tab;

  v_idx PLS_INTEGER := 0;
BEGIN
  p_batch_id := pkg_batch_processing.start_batch('MILES_EXPIRY', 'Scheduled Miles Expiry - ' || TO_CHAR(p_run_date, 'YYYY-MM-DD'));
  p_expired_count := 0;
  p_total_miles := 0;

  -- Collect expiring records
  FOR rec IN (
    SELECT expiry_id, member_id, (miles_amount - expired_miles) AS miles_to_expire
    FROM miles_expiry
    WHERE status = 'ACTIVE'
      AND expiry_date <= p_run_date
      AND miles_amount > expired_miles
    ORDER BY member_id, expiry_date
  ) LOOP
    v_idx := v_idx + 1;
    v_expiry_data(v_idx).expiry_id := rec.expiry_id;
    v_expiry_data(v_idx).member_id := rec.member_id;
    v_expiry_data(v_idx).miles_to_expire := rec.miles_to_expire;
  END LOOP;

  IF v_idx = 0 THEN
    pkg_batch_processing.complete_batch(p_batch_id, 0, 0, 0);
    RETURN;
  END IF;

  -- Process each expiry record
  FOR i IN v_expiry_data.FIRST .. v_expiry_data.LAST LOOP
    BEGIN
      -- Mark miles as expired
      UPDATE miles_expiry SET
        expired_miles  = miles_amount,
        status         = 'EXPIRED',
        batch_id       = p_batch_id,
        processed_date = SYSDATE
      WHERE expiry_id = v_expiry_data(i).expiry_id;

      -- Deduct from member balance
      UPDATE members SET
        available_miles = GREATEST(available_miles - v_expiry_data(i).miles_to_expire, 0),
        updated_date    = SYSDATE
      WHERE member_id = v_expiry_data(i).member_id;

      -- Notify member
      pkg_notification.send_notification(
        v_expiry_data(i).member_id, 'MILES_EXPIRY',
        'Miles Expiration Notice',
        TO_CHAR(v_expiry_data(i).miles_to_expire, '999,999') ||
        ' miles have expired from your SkyReward account. ' ||
        'Keep earning to maintain your miles balance!'
      );

      p_expired_count := p_expired_count + 1;
      p_total_miles := p_total_miles + v_expiry_data(i).miles_to_expire;

      -- Commit every 1000 records
      IF MOD(p_expired_count, 1000) = 0 THEN
        COMMIT;
      END IF;

    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error expiring record ' || v_expiry_data(i).expiry_id ||
                             ': ' || SQLERRM);
    END;
  END LOOP;

  pkg_batch_processing.complete_batch(p_batch_id, p_expired_count, p_expired_count, 0);
  COMMIT;

  DBMS_OUTPUT.PUT_LINE('Miles expiry complete. Records: ' || p_expired_count ||
                       ', Total miles: ' || p_total_miles);

EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    pkg_batch_processing.complete_batch(p_batch_id, 0, 0, p_expired_count, 'FAILED', SQLERRM);
    RAISE;
END pr_expire_miles;
/
