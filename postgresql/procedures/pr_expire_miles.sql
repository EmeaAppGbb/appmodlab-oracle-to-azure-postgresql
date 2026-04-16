-- ============================================================================
-- Function: Expire Miles (PR_EXPIRE_MILES)
-- Converted from Oracle procedure PR_EXPIRE_MILES to PostgreSQL PL/pgSQL.
--
-- Conversion notes:
--   - OUT parameters replaced with RETURNS TABLE
--   - INDEX BY associative array replaced with cursor FOR loop
--   - SYSDATE replaced with CURRENT_TIMESTAMP / CURRENT_DATE
--   - pkg_batch_processing.xxx replaced with batch_processing_xxx
--   - pkg_notification.send_notification replaced with notification_send_notification
--   - DBMS_OUTPUT.PUT_LINE replaced with RAISE NOTICE
--   - COMMIT / ROLLBACK removed (transaction control is external)
--   - SQLERRM replaced with SQLERRM (same in PostgreSQL)
-- ============================================================================

CREATE OR REPLACE FUNCTION pr_expire_miles(
    p_run_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE(batch_id BIGINT, expired_count INT, total_miles NUMERIC)
LANGUAGE plpgsql
AS $$
DECLARE
    v_batch_id       BIGINT;
    v_expired_count  INT := 0;
    v_total_miles    NUMERIC := 0;
    v_rec            RECORD;
BEGIN
    -- Start a new batch
    v_batch_id := batch_processing_start_batch(
        'MILES_EXPIRY',
        'Scheduled Miles Expiry - ' || TO_CHAR(p_run_date, 'YYYY-MM-DD')
    );

    -- Process each expiring record via cursor FOR loop
    FOR v_rec IN
        SELECT e.expiry_id,
               e.member_id,
               (e.miles_amount - e.expired_miles) AS miles_to_expire
        FROM   miles_expiry e
        WHERE  e.status = 'ACTIVE'
          AND  e.expiry_date <= p_run_date
          AND  e.miles_amount > e.expired_miles
        ORDER  BY e.member_id, e.expiry_date
    LOOP
        BEGIN
            -- Mark miles as expired
            UPDATE miles_expiry SET
                expired_miles  = miles_amount,
                status         = 'EXPIRED',
                batch_id       = v_batch_id,
                processed_date = CURRENT_TIMESTAMP
            WHERE expiry_id = v_rec.expiry_id;

            -- Deduct from member balance
            UPDATE members SET
                available_miles = GREATEST(available_miles - v_rec.miles_to_expire, 0),
                updated_date    = CURRENT_TIMESTAMP
            WHERE member_id = v_rec.member_id;

            -- Notify member
            PERFORM notification_send_notification(
                v_rec.member_id,
                'MILES_EXPIRY',
                'Miles Expiration Notice',
                TO_CHAR(v_rec.miles_to_expire, '999,999') ||
                ' miles have expired from your SkyReward account. ' ||
                'Keep earning to maintain your miles balance!'
            );

            v_expired_count := v_expired_count + 1;
            v_total_miles   := v_total_miles + v_rec.miles_to_expire;

        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE 'Error expiring record %: %', v_rec.expiry_id, SQLERRM;
        END;
    END LOOP;

    -- Complete the batch
    IF v_expired_count = 0 THEN
        PERFORM batch_processing_complete_batch(v_batch_id, 0, 0, 0);
    ELSE
        PERFORM batch_processing_complete_batch(v_batch_id, v_expired_count, v_expired_count, 0);
    END IF;

    RAISE NOTICE 'Miles expiry complete. Records: %, Total miles: %',
                 v_expired_count, v_total_miles;

    -- Return results
    batch_id      := v_batch_id;
    expired_count := v_expired_count;
    total_miles   := v_total_miles;
    RETURN NEXT;

EXCEPTION
    WHEN OTHERS THEN
        PERFORM batch_processing_complete_batch(
            v_batch_id, 0, 0, v_expired_count, 'FAILED', SQLERRM
        );
        RAISE;
END;
$$;
