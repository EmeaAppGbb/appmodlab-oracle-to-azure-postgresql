-- ============================================================================
-- Function: Process Bulk Accrual (PR_PROCESS_BULK_ACCRUAL)
-- Converted from Oracle procedure PR_PROCESS_BULK_ACCRUAL to PostgreSQL
-- PL/pgSQL.
--
-- Conversion notes:
--   - OUT parameters replaced with RETURNS TABLE
--   - BULK COLLECT + FORALL replaced with CTE-based UPDATE ... RETURNING
--   - SAVE EXCEPTIONS replaced with per-row BEGIN/EXCEPTION blocks
--   - seq_expiry_batch_id.NEXTVAL replaced with nextval('seq_expiry_batch_id')
--   - ADD_MONTHS(date, 36) replaced with date + INTERVAL '36 months'
--   - NVL replaced with COALESCE
--   - SYSDATE replaced with CURRENT_TIMESTAMP / CURRENT_DATE
--   - DBMS_OUTPUT.PUT_LINE replaced with RAISE NOTICE
--   - COMMIT / ROLLBACK removed (transaction control is external)
--   - pkg_batch_processing.xxx replaced with batch_processing_xxx
-- ============================================================================

CREATE OR REPLACE FUNCTION pr_process_bulk_accrual(
    p_batch_size INT DEFAULT 5000
)
RETURNS TABLE(batch_id BIGINT, processed INT, failed INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_batch_id    BIGINT;
    v_processed   INT := 0;
    v_failed      INT := 0;
    v_total_rows  INT := 0;
    v_rec         RECORD;
BEGIN
    -- Start batch
    v_batch_id := batch_processing_start_batch(
        'BULK_ACCRUAL',
        'Bulk Flight Accrual Processing',
        '{"batch_size":' || p_batch_size || '}'
    );

    -- Bulk-update pending flights to PROCESSED using a CTE with RETURNING,
    -- replacing Oracle FORALL + SAVE EXCEPTIONS
    CREATE TEMPORARY TABLE _accrual_batch ON COMMIT DROP AS
    WITH pending AS (
        SELECT flight_id
        FROM   flights
        WHERE  accrual_status = 'PENDING'
          AND  status = 'ACTIVE'
        ORDER  BY flight_date ASC
        LIMIT  p_batch_size
    )
    UPDATE flights f SET
        accrual_status = 'PROCESSED',
        processed_date = CURRENT_TIMESTAMP,
        updated_date   = CURRENT_TIMESTAMP
    FROM   pending p
    WHERE  f.flight_id = p.flight_id
      AND  f.accrual_status = 'PENDING'
    RETURNING f.flight_id, f.member_id, f.total_miles, f.tier_miles, f.flight_date;

    GET DIAGNOSTICS v_total_rows = ROW_COUNT;

    IF v_total_rows = 0 THEN
        PERFORM batch_processing_complete_batch(v_batch_id, 0, 0, 0);
        RAISE NOTICE 'No pending accruals to process.';
        batch_id  := v_batch_id;
        processed := 0;
        failed    := 0;
        RETURN NEXT;
        RETURN;
    END IF;

    RAISE NOTICE 'Processing % pending accruals...', v_total_rows;

    -- Update member balances row-by-row (needs individual member logic)
    FOR v_rec IN
        SELECT flight_id, member_id, total_miles, tier_miles, flight_date
        FROM   _accrual_batch
    LOOP
        BEGIN
            -- Update available miles, total miles, YTD, and lifetime
            UPDATE members SET
                available_miles    = available_miles + v_rec.total_miles,
                total_miles        = total_miles + v_rec.total_miles,
                ytd_miles          = ytd_miles + v_rec.tier_miles,
                lifetime_miles     = lifetime_miles + v_rec.total_miles,
                last_activity_date = GREATEST(
                    COALESCE(last_activity_date, v_rec.flight_date),
                    v_rec.flight_date
                ),
                updated_date       = CURRENT_TIMESTAMP
            WHERE member_id = v_rec.member_id;

            -- Insert miles expiry record (miles expire after 36 months)
            INSERT INTO miles_expiry (
                expiry_id, member_id, source_type, source_id,
                miles_amount, earned_date, expiry_date, status
            ) VALUES (
                nextval('seq_expiry_batch_id'),
                v_rec.member_id,
                'FLIGHT',
                v_rec.flight_id,
                v_rec.total_miles,
                v_rec.flight_date,
                v_rec.flight_date + INTERVAL '36 months',
                'ACTIVE'
            );

            v_processed := v_processed + 1;

        EXCEPTION
            WHEN OTHERS THEN
                v_failed := v_failed + 1;
                RAISE NOTICE 'Error processing member %, flight %: %',
                             v_rec.member_id, v_rec.flight_id, SQLERRM;
        END;
    END LOOP;

    -- Complete batch
    PERFORM batch_processing_complete_batch(v_batch_id, v_total_rows, v_processed, v_failed);

    RAISE NOTICE 'Bulk accrual complete. Processed: %, Failed: %', v_processed, v_failed;

    -- Return results
    batch_id  := v_batch_id;
    processed := v_processed;
    failed    := v_failed;
    RETURN NEXT;

EXCEPTION
    WHEN OTHERS THEN
        PERFORM batch_processing_complete_batch(
            v_batch_id, 0, 0, v_total_rows, 'FAILED', SQLERRM
        );
        RAISE;
END;
$$;
