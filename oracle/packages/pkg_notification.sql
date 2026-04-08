-- ========================================
-- Package: Notification (PKG_NOTIFICATION)
-- ========================================
-- Manages member notifications across channels

CREATE OR REPLACE PACKAGE pkg_notification AS

  -- Send a notification
  PROCEDURE send_notification(
    p_member_id       IN  NUMBER,
    p_type            IN  VARCHAR2,
    p_subject         IN  VARCHAR2,
    p_body            IN  CLOB,
    p_channel         IN  VARCHAR2 DEFAULT NULL,
    p_priority        IN  NUMBER DEFAULT 3,
    p_scheduled_date  IN  DATE DEFAULT NULL
  );

  -- Process pending notifications (send them out)
  PROCEDURE process_pending(
    p_batch_size      IN  NUMBER DEFAULT 500,
    p_processed_count OUT NUMBER
  );

  -- Retry failed notifications
  PROCEDURE retry_failed(
    p_max_retries     IN  NUMBER DEFAULT 3,
    p_retried_count   OUT NUMBER
  );

  -- Get notification history for a member
  FUNCTION get_member_notifications(
    p_member_id       IN  NUMBER,
    p_days_back       IN  NUMBER DEFAULT 30
  ) RETURN SYS_REFCURSOR;

  -- Cancel scheduled notifications
  PROCEDURE cancel_notification(
    p_notification_id IN  NUMBER
  );

  -- Get notification statistics
  FUNCTION get_notification_stats(
    p_start_date      IN  DATE DEFAULT TRUNC(SYSDATE),
    p_end_date        IN  DATE DEFAULT SYSDATE
  ) RETURN SYS_REFCURSOR;

END pkg_notification;
/

CREATE OR REPLACE PACKAGE BODY pkg_notification AS

  -- Send a notification
  PROCEDURE send_notification(
    p_member_id       IN  NUMBER,
    p_type            IN  VARCHAR2,
    p_subject         IN  VARCHAR2,
    p_body            IN  CLOB,
    p_channel         IN  VARCHAR2 DEFAULT NULL,
    p_priority        IN  NUMBER DEFAULT 3,
    p_scheduled_date  IN  DATE DEFAULT NULL
  ) IS
    v_channel VARCHAR2(20);
  BEGIN
    -- Determine channel from member preference if not specified
    IF p_channel IS NULL THEN
      SELECT communication_pref INTO v_channel
      FROM members WHERE member_id = p_member_id;
    ELSE
      v_channel := p_channel;
    END IF;

    INSERT INTO notifications (
      notification_id, member_id, notification_type, channel,
      subject, body, priority, status, scheduled_date
    ) VALUES (
      seq_notification_id.NEXTVAL, p_member_id, p_type, v_channel,
      p_subject, p_body, p_priority,
      CASE WHEN p_scheduled_date IS NOT NULL THEN 'PENDING' ELSE 'PENDING' END,
      NVL(p_scheduled_date, SYSDATE)
    );

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      -- Don't let notification failures break the calling process
      DBMS_OUTPUT.PUT_LINE('Notification error for member ' || p_member_id || ': ' || SQLERRM);
  END send_notification;

  -- Process pending notifications
  PROCEDURE process_pending(
    p_batch_size      IN  NUMBER DEFAULT 500,
    p_processed_count OUT NUMBER
  ) IS
    TYPE t_notif_ids IS TABLE OF notifications.notification_id%TYPE;
    v_notif_ids t_notif_ids;
  BEGIN
    p_processed_count := 0;

    SELECT notification_id
    BULK COLLECT INTO v_notif_ids
    FROM notifications
    WHERE status = 'PENDING'
      AND scheduled_date <= SYSDATE
    ORDER BY priority ASC, scheduled_date ASC
    FETCH FIRST p_batch_size ROWS ONLY;

    IF v_notif_ids.COUNT = 0 THEN
      RETURN;
    END IF;

    -- In production this would integrate with email/SMS/push services
    -- Here we simulate successful send
    FORALL i IN v_notif_ids.FIRST .. v_notif_ids.LAST
      UPDATE notifications SET
        status       = 'SENT',
        sent_date    = SYSDATE,
        updated_date = SYSDATE
      WHERE notification_id = v_notif_ids(i);

    p_processed_count := v_notif_ids.COUNT;
    COMMIT;
  END process_pending;

  -- Retry failed notifications
  PROCEDURE retry_failed(
    p_max_retries     IN  NUMBER DEFAULT 3,
    p_retried_count   OUT NUMBER
  ) IS
  BEGIN
    UPDATE notifications SET
      status       = 'PENDING',
      retry_count  = retry_count + 1,
      error_message = NULL,
      updated_date = SYSDATE
    WHERE status = 'FAILED'
      AND retry_count < p_max_retries;

    p_retried_count := SQL%ROWCOUNT;
    COMMIT;
  END retry_failed;

  -- Get member notifications
  FUNCTION get_member_notifications(
    p_member_id       IN  NUMBER,
    p_days_back       IN  NUMBER DEFAULT 30
  ) RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
  BEGIN
    OPEN v_cursor FOR
      SELECT notification_id, notification_type, channel,
             subject, status, sent_date, created_date
      FROM notifications
      WHERE member_id = p_member_id
        AND created_date >= SYSDATE - p_days_back
      ORDER BY created_date DESC;

    RETURN v_cursor;
  END get_member_notifications;

  -- Cancel notification
  PROCEDURE cancel_notification(
    p_notification_id IN  NUMBER
  ) IS
  BEGIN
    UPDATE notifications SET
      status       = 'CANCELLED',
      updated_date = SYSDATE
    WHERE notification_id = p_notification_id
      AND status = 'PENDING';

    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20130, 'Notification not found or not in PENDING status');
    END IF;

    COMMIT;
  END cancel_notification;

  -- Notification statistics
  FUNCTION get_notification_stats(
    p_start_date      IN  DATE DEFAULT TRUNC(SYSDATE),
    p_end_date        IN  DATE DEFAULT SYSDATE
  ) RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
  BEGIN
    OPEN v_cursor FOR
      SELECT notification_type, channel, status,
             COUNT(*) AS notification_count,
             ROUND(AVG(retry_count), 1) AS avg_retries
      FROM notifications
      WHERE created_date BETWEEN p_start_date AND p_end_date
      GROUP BY notification_type, channel, status
      ORDER BY notification_type, channel;

    RETURN v_cursor;
  END get_notification_stats;

END pkg_notification;
/
