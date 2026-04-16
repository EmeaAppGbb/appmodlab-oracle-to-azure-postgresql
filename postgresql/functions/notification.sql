-- ============================================================================
-- PostgreSQL conversion of Oracle package PKG_NOTIFICATION
-- Each package procedure/function becomes a standalone function
-- prefixed with notification_
-- ============================================================================

-- ============================================================================
-- Function: notification_send_notification
-- Inserts a notification record. On exception, logs via RAISE NOTICE instead
-- of propagating the error.
-- Oracle: DBMS_OUTPUT.PUT_LINE → RAISE NOTICE, SYSDATE → CURRENT_TIMESTAMP
-- ============================================================================
CREATE OR REPLACE FUNCTION notification_send_notification(
    p_member_id       BIGINT,
    p_type            VARCHAR,
    p_subject         VARCHAR,
    p_body            TEXT,
    p_channel         VARCHAR   DEFAULT NULL,
    p_priority        INT       DEFAULT 3,
    p_scheduled_date  TIMESTAMP DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_channel VARCHAR;
BEGIN
    -- Default channel based on notification type if not provided
    v_channel := COALESCE(p_channel, 'EMAIL');

    INSERT INTO notifications (
        notification_id, member_id, notification_type, subject,
        body, channel, priority, status,
        scheduled_date, created_date, created_by
    ) VALUES (
        nextval('seq_notification_id'), p_member_id, p_type, p_subject,
        p_body, v_channel, p_priority, 'PENDING',
        COALESCE(p_scheduled_date, CURRENT_TIMESTAMP), CURRENT_TIMESTAMP, current_user
    );

EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Failed to send notification to member %: %', p_member_id, SQLERRM;
END;
$$;

-- ============================================================================
-- Function: notification_process_pending
-- Processes pending notifications in batches.
-- Oracle: BULK COLLECT + FORALL → single UPDATE with subquery
-- ============================================================================
CREATE OR REPLACE FUNCTION notification_process_pending(
    p_batch_size  INT DEFAULT 500
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_count INT;
BEGIN
    UPDATE notifications
       SET status = 'SENT',
           sent_date = CURRENT_TIMESTAMP,
           updated_date = CURRENT_TIMESTAMP
     WHERE notification_id IN (
         SELECT notification_id
           FROM notifications
          WHERE status = 'PENDING'
            AND scheduled_date <= CURRENT_TIMESTAMP
          ORDER BY priority ASC, scheduled_date ASC
          LIMIT p_batch_size
     );

    GET DIAGNOSTICS v_count = ROW_COUNT;

    RAISE NOTICE 'Processed % pending notifications', v_count;

    RETURN v_count;
END;
$$;

-- ============================================================================
-- Function: notification_retry_failed
-- Retries failed notifications that have not exceeded max retry count.
-- Oracle: SQL%ROWCOUNT → GET DIAGNOSTICS
-- ============================================================================
CREATE OR REPLACE FUNCTION notification_retry_failed(
    p_max_retries  INT DEFAULT 3
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_count INT;
BEGIN
    UPDATE notifications
       SET status = 'PENDING',
           retry_count = COALESCE(retry_count, 0) + 1,
           updated_date = CURRENT_TIMESTAMP
     WHERE status = 'FAILED'
       AND COALESCE(retry_count, 0) < p_max_retries;

    GET DIAGNOSTICS v_count = ROW_COUNT;

    RAISE NOTICE 'Queued % failed notifications for retry', v_count;

    RETURN v_count;
END;
$$;

-- ============================================================================
-- Function: notification_get_member_notifications
-- Returns recent notifications for a member.
-- Oracle: SYS_REFCURSOR → RETURNS TABLE with RETURN QUERY
-- ============================================================================
CREATE OR REPLACE FUNCTION notification_get_member_notifications(
    p_member_id   BIGINT,
    p_days_back   INT DEFAULT 30
)
RETURNS TABLE(
    notification_id    BIGINT,
    notification_type  VARCHAR,
    subject            VARCHAR,
    body               TEXT,
    channel            VARCHAR,
    priority           INT,
    status             VARCHAR,
    scheduled_date     TIMESTAMP,
    sent_date          TIMESTAMP,
    created_date       TIMESTAMP
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT n.notification_id,
           n.notification_type,
           n.subject,
           n.body,
           n.channel,
           n.priority,
           n.status,
           n.scheduled_date,
           n.sent_date,
           n.created_date
      FROM notifications n
     WHERE n.member_id = p_member_id
       AND n.created_date >= CURRENT_TIMESTAMP - (p_days_back || ' days')::INTERVAL
     ORDER BY n.created_date DESC;
END;
$$;

-- ============================================================================
-- Function: notification_cancel_notification
-- Cancels a pending notification.
-- Oracle: SQL%ROWCOUNT check → GET DIAGNOSTICS
-- ============================================================================
CREATE OR REPLACE FUNCTION notification_cancel_notification(
    p_notification_id  BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount INT;
BEGIN
    UPDATE notifications
       SET status = 'CANCELLED',
           updated_date = CURRENT_TIMESTAMP
     WHERE notification_id = p_notification_id
       AND status = 'PENDING';

    GET DIAGNOSTICS v_rowcount = ROW_COUNT;

    IF v_rowcount = 0 THEN
        RAISE EXCEPTION 'Notification % not found or not in PENDING status', p_notification_id;
    END IF;
END;
$$;

-- ============================================================================
-- Function: notification_get_notification_stats
-- Returns notification statistics grouped by type and status.
-- Oracle: SYS_REFCURSOR → RETURNS TABLE, NVL → COALESCE,
--         TRUNC(SYSDATE, 'MM') → DATE_TRUNC('month', CURRENT_DATE)
-- ============================================================================
CREATE OR REPLACE FUNCTION notification_get_notification_stats(
    p_start_date  TIMESTAMP DEFAULT NULL,
    p_end_date    TIMESTAMP DEFAULT NULL
)
RETURNS TABLE(
    notification_type  VARCHAR,
    status             VARCHAR,
    total_count        BIGINT,
    earliest_date      TIMESTAMP,
    latest_date        TIMESTAMP
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_start TIMESTAMP;
    v_end   TIMESTAMP;
BEGIN
    -- Default to current month if no dates provided
    v_start := COALESCE(p_start_date, DATE_TRUNC('month', CURRENT_DATE));
    v_end   := COALESCE(p_end_date, CURRENT_TIMESTAMP);

    RETURN QUERY
    SELECT n.notification_type,
           n.status,
           COUNT(*)            AS total_count,
           MIN(n.created_date) AS earliest_date,
           MAX(n.created_date) AS latest_date
      FROM notifications n
     WHERE n.created_date >= v_start
       AND n.created_date <= v_end
     GROUP BY n.notification_type, n.status
     ORDER BY n.notification_type, n.status;
END;
$$;
