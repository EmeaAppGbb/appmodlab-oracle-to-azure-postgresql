-- ============================================================================
-- PostgreSQL conversion of Oracle package PKG_BATCH_PROCESSING
-- Each package procedure/function becomes a standalone function
-- prefixed with batch_processing_
--
-- Conversion notes:
--   - BULK COLLECT / FORALL replaced with cursor FOR loops
--   - SYSDATE replaced with CURRENT_TIMESTAMP / CURRENT_DATE
--   - ADD_MONTHS(x, n) replaced with INTERVAL arithmetic
--   - TRUNC(x, 'MM') replaced with DATE_TRUNC('month', x)
--   - LAST_DAY(x) replaced with (DATE_TRUNC('month',x)+INTERVAL '1 month'-INTERVAL '1 day')::DATE
--   - DBMS_OUTPUT.PUT_LINE replaced with RAISE NOTICE
--   - SQL%ROWCOUNT replaced with GET DIAGNOSTICS ... ROW_COUNT
--   - seq_xxx.NEXTVAL replaced with nextval('seq_xxx')
--   - CLOB replaced with TEXT
--   - COMMIT/ROLLBACK removed (transaction control is external)
--   - Cross-package calls use flattened naming convention
-- ============================================================================

-- ============================================================================
-- Function: batch_processing_start_batch
-- Creates a new batch processing log entry and returns the batch_id.
-- ============================================================================
CREATE OR REPLACE FUNCTION batch_processing_start_batch(
    p_batch_type VARCHAR,
    p_batch_name VARCHAR,
    p_parameters TEXT DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_batch_id BIGINT;
BEGIN
    v_batch_id := nextval('seq_expiry_batch_id');

    INSERT INTO batch_processing_log (
        batch_id, batch_type, batch_name, start_time, status, parameters
    ) VALUES (
        v_batch_id, p_batch_type, p_batch_name, CURRENT_TIMESTAMP, 'RUNNING', p_parameters
    );

    RETURN v_batch_id;
END;
$$;

-- ============================================================================
-- Function: batch_processing_complete_batch
-- Updates the batch processing log with completion details.
-- ============================================================================
CREATE OR REPLACE FUNCTION batch_processing_complete_batch(
    p_batch_id          BIGINT,
    p_records_processed INT,
    p_records_succeeded INT,
    p_records_failed    INT,
    p_status            VARCHAR DEFAULT 'COMPLETED',
    p_error_msg         TEXT    DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE batch_processing_log SET
        end_time          = CURRENT_TIMESTAMP,
        records_processed = p_records_processed,
        records_succeeded = p_records_succeeded,
        records_failed    = p_records_failed,
        status            = p_status,
        error_message     = p_error_msg
    WHERE batch_id = p_batch_id;
END;
$$;

-- ============================================================================
-- Function: batch_processing_run_miles_expiry
-- Expires active miles that have passed their expiry date.
-- Oracle: BULK COLLECT + FORALL → cursor FOR loop
-- ============================================================================
CREATE OR REPLACE FUNCTION batch_processing_run_miles_expiry(
    p_expiry_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE(batch_id BIGINT, expired_count INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_batch_id      BIGINT;
    v_expired_count INT := 0;
    v_rec           RECORD;
BEGIN
    v_batch_id := batch_processing_start_batch('MILES_EXPIRY', 'Nightly Miles Expiry Run');

    -- Process each expiring record via cursor loop (replaces BULK COLLECT + FORALL)
    FOR v_rec IN (
        SELECT me.expiry_id,
               me.member_id,
               me.miles_amount - me.expired_miles AS miles_to_expire
          FROM miles_expiry me
         WHERE me.status = 'ACTIVE'
           AND me.expiry_date <= p_expiry_date
           AND me.miles_amount > me.expired_miles
    ) LOOP
        BEGIN
            UPDATE miles_expiry SET
                expired_miles  = miles_amount,
                status         = 'EXPIRED',
                batch_id       = v_batch_id,
                processed_date = CURRENT_TIMESTAMP
            WHERE expiry_id = v_rec.expiry_id;

            UPDATE members SET
                available_miles = GREATEST(available_miles - v_rec.miles_to_expire, 0),
                updated_date    = CURRENT_TIMESTAMP
            WHERE member_id = v_rec.member_id;

            -- Send expiry notification
            PERFORM notification_send_notification(
                v_rec.member_id, 'MILES_EXPIRY',
                'Miles Expiration Notice',
                TO_CHAR(v_rec.miles_to_expire, '999,999') || ' miles have expired from your account.'
            );

            v_expired_count := v_expired_count + 1;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE 'Error expiring miles for member %: %', v_rec.member_id, SQLERRM;
        END;
    END LOOP;

    PERFORM batch_processing_complete_batch(v_batch_id, v_expired_count, v_expired_count, 0);

    batch_id      := v_batch_id;
    expired_count := v_expired_count;
    RETURN NEXT;
EXCEPTION
    WHEN OTHERS THEN
        PERFORM batch_processing_complete_batch(v_batch_id, 0, 0, 0, 'FAILED', SQLERRM);
        RAISE;
END;
$$;

-- ============================================================================
-- Function: batch_processing_run_tier_recalculation
-- Triggers tier recalculation for all active members.
-- Oracle: pkg_tier_calculation.recalculate_all_tiers → tier_calculation_recalculate_all_tiers
-- ============================================================================
CREATE OR REPLACE FUNCTION batch_processing_run_tier_recalculation()
RETURNS TABLE(batch_id BIGINT, processed INT, changed INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_batch_id  BIGINT;
    v_processed INT;
    v_changed   INT;
    v_result    RECORD;
BEGIN
    v_batch_id := batch_processing_start_batch('TIER_RECALC', 'Nightly Tier Recalculation');

    SELECT * INTO v_result FROM tier_calculation_recalculate_all_tiers();
    v_processed := v_result.processed;
    v_changed   := v_result.changed;

    PERFORM batch_processing_complete_batch(v_batch_id, v_processed, v_processed, 0);

    batch_id  := v_batch_id;
    processed := v_processed;
    changed   := v_changed;
    RETURN NEXT;
EXCEPTION
    WHEN OTHERS THEN
        PERFORM batch_processing_complete_batch(v_batch_id, 0, 0, 0, 'FAILED', SQLERRM);
        RAISE;
END;
$$;

-- ============================================================================
-- Function: batch_processing_run_data_cleanup
-- Removes old audit logs and processed notifications.
-- Oracle: SQL%ROWCOUNT → GET DIAGNOSTICS
-- ============================================================================
CREATE OR REPLACE FUNCTION batch_processing_run_data_cleanup(
    p_retention_days INT DEFAULT 365
)
RETURNS TABLE(batch_id BIGINT, deleted_count INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_batch_id       BIGINT;
    v_audit_deleted  INT;
    v_notif_deleted  INT;
    v_cutoff_date    TIMESTAMP;
BEGIN
    v_batch_id := batch_processing_start_batch('DATA_CLEANUP', 'Periodic Data Cleanup',
        '{"retention_days":' || p_retention_days || '}');
    v_cutoff_date := CURRENT_TIMESTAMP - (p_retention_days || ' days')::INTERVAL;

    -- Clean old audit logs
    DELETE FROM audit_log WHERE changed_date < v_cutoff_date;
    GET DIAGNOSTICS v_audit_deleted = ROW_COUNT;

    -- Clean sent/cancelled notifications
    DELETE FROM notifications
     WHERE status IN ('SENT', 'CANCELLED')
       AND created_date < v_cutoff_date;
    GET DIAGNOSTICS v_notif_deleted = ROW_COUNT;

    PERFORM batch_processing_complete_batch(
        v_batch_id,
        v_audit_deleted + v_notif_deleted,
        v_audit_deleted + v_notif_deleted,
        0
    );

    batch_id      := v_batch_id;
    deleted_count := v_audit_deleted + v_notif_deleted;
    RETURN NEXT;
EXCEPTION
    WHEN OTHERS THEN
        PERFORM batch_processing_complete_batch(v_batch_id, 0, 0, 0, 'FAILED', SQLERRM);
        RAISE;
END;
$$;

-- ============================================================================
-- Function: batch_processing_run_ytd_miles_reset
-- Resets year-to-date miles for all active members.
-- Oracle: SQL%ROWCOUNT → GET DIAGNOSTICS
-- ============================================================================
CREATE OR REPLACE FUNCTION batch_processing_run_ytd_miles_reset()
RETURNS TABLE(batch_id BIGINT, reset_count INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_batch_id    BIGINT;
    v_reset_count INT;
BEGIN
    v_batch_id := batch_processing_start_batch('DATA_CLEANUP', 'Year-End YTD Miles Reset');

    UPDATE members SET
        ytd_miles    = 0,
        updated_date = CURRENT_TIMESTAMP
    WHERE status = 'ACTIVE';

    GET DIAGNOSTICS v_reset_count = ROW_COUNT;

    PERFORM batch_processing_complete_batch(v_batch_id, v_reset_count, v_reset_count, 0);

    batch_id    := v_batch_id;
    reset_count := v_reset_count;
    RETURN NEXT;
END;
$$;

-- ============================================================================
-- Function: batch_processing_run_statement_generation
-- Generates monthly statements for all active members who opted in.
-- Oracle: ADD_MONTHS(SYSDATE,-1) → CURRENT_DATE - INTERVAL '1 month'
--         TRUNC(x,'MM') → DATE_TRUNC('month', x)
--         LAST_DAY(x) → (DATE_TRUNC('month',x) + INTERVAL '1 month' - INTERVAL '1 day')::DATE
--         pkg_reporting.generate_member_statement → reporting_generate_member_statement
--         pkg_notification.send_notification → notification_send_notification
--         DBMS_OUTPUT.PUT_LINE → RAISE NOTICE
-- ============================================================================
CREATE OR REPLACE FUNCTION batch_processing_run_statement_generation(
    p_statement_month DATE DEFAULT NULL
)
RETURNS TABLE(batch_id BIGINT, generated_count INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_batch_id        BIGINT;
    v_generated_count INT := 0;
    v_stmt_month      DATE;
    v_start_date      DATE;
    v_end_date        DATE;
    v_statement       TEXT;
    rec               RECORD;
BEGIN
    v_stmt_month := COALESCE(p_statement_month, (CURRENT_DATE - INTERVAL '1 month')::DATE);
    v_start_date := DATE_TRUNC('month', v_stmt_month)::DATE;
    v_end_date   := (DATE_TRUNC('month', v_stmt_month) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;

    v_batch_id := batch_processing_start_batch('STATEMENT_GEN', 'Monthly Statement Generation');

    FOR rec IN (
        SELECT m.member_id, m.email
          FROM members m
         WHERE m.status = 'ACTIVE'
           AND m.communication_pref IN ('EMAIL', 'MAIL')
    ) LOOP
        BEGIN
            v_statement := reporting_generate_member_statement(rec.member_id, v_start_date, v_end_date);

            PERFORM notification_send_notification(
                rec.member_id, 'STATEMENT',
                'Your SkyReward Monthly Statement - ' || TO_CHAR(v_stmt_month, 'Mon YYYY'),
                v_statement
            );

            v_generated_count := v_generated_count + 1;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE 'Statement error for member %: %', rec.member_id, SQLERRM;
        END;
    END LOOP;

    PERFORM batch_processing_complete_batch(v_batch_id, v_generated_count, v_generated_count, 0);

    batch_id        := v_batch_id;
    generated_count := v_generated_count;
    RETURN NEXT;
END;
$$;

-- ============================================================================
-- Function: batch_processing_get_batch_status
-- Returns the current status of a batch job.
-- ============================================================================
CREATE OR REPLACE FUNCTION batch_processing_get_batch_status(
    p_batch_id BIGINT
)
RETURNS VARCHAR
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_status VARCHAR;
BEGIN
    SELECT status INTO v_status
      FROM batch_processing_log
     WHERE batch_id = p_batch_id;

    IF NOT FOUND THEN
        RETURN 'NOT_FOUND';
    END IF;

    RETURN v_status;
END;
$$;

-- ============================================================================
-- Function: batch_processing_get_batch_history
-- Returns recent batch job history, optionally filtered by type.
-- Oracle: SYS_REFCURSOR → RETURNS TABLE with RETURN QUERY
--         SYSDATE - p_days_back → CURRENT_TIMESTAMP - INTERVAL
-- ============================================================================
CREATE OR REPLACE FUNCTION batch_processing_get_batch_history(
    p_batch_type VARCHAR DEFAULT NULL,
    p_days_back  INT     DEFAULT 30
)
RETURNS TABLE(
    batch_id          BIGINT,
    batch_type        VARCHAR,
    batch_name        VARCHAR,
    start_time        TIMESTAMP,
    end_time          TIMESTAMP,
    records_processed INT,
    records_succeeded INT,
    records_failed    INT,
    status            VARCHAR,
    run_by            VARCHAR
)
LANGUAGE plpgsql STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT bl.batch_id, bl.batch_type, bl.batch_name,
           bl.start_time, bl.end_time,
           bl.records_processed, bl.records_succeeded, bl.records_failed,
           bl.status, bl.run_by
      FROM batch_processing_log bl
     WHERE (p_batch_type IS NULL OR bl.batch_type = p_batch_type)
       AND bl.start_time >= CURRENT_TIMESTAMP - (p_days_back || ' days')::INTERVAL
     ORDER BY bl.start_time DESC;
END;
$$;
