-- ========================================
-- Package: Audit (PKG_AUDIT)
-- ========================================
-- Audit logging and trail management

CREATE OR REPLACE PACKAGE pkg_audit AS

  -- Log a change
  PROCEDURE log_change(
    p_table_name  IN VARCHAR2,
    p_operation   IN VARCHAR2,
    p_record_id   IN NUMBER,
    p_member_id   IN NUMBER DEFAULT NULL,
    p_old_values  IN CLOB DEFAULT NULL,
    p_new_values  IN CLOB DEFAULT NULL
  );

  -- Get audit trail for a record
  FUNCTION get_audit_trail(
    p_table_name  IN VARCHAR2,
    p_record_id   IN NUMBER
  ) RETURN SYS_REFCURSOR;

  -- Get audit trail for a member
  FUNCTION get_member_audit_trail(
    p_member_id   IN NUMBER,
    p_start_date  IN DATE DEFAULT NULL,
    p_end_date    IN DATE DEFAULT NULL
  ) RETURN SYS_REFCURSOR;

  -- Purge old audit records
  PROCEDURE purge_audit_records(
    p_retention_days IN NUMBER DEFAULT 365,
    p_deleted_count  OUT NUMBER
  );

  -- Get audit summary statistics
  FUNCTION get_audit_summary(
    p_start_date  IN DATE DEFAULT TRUNC(SYSDATE),
    p_end_date    IN DATE DEFAULT SYSDATE
  ) RETURN SYS_REFCURSOR;

END pkg_audit;
/

CREATE OR REPLACE PACKAGE BODY pkg_audit AS

  -- Log a change
  PROCEDURE log_change(
    p_table_name  IN VARCHAR2,
    p_operation   IN VARCHAR2,
    p_record_id   IN NUMBER,
    p_member_id   IN NUMBER DEFAULT NULL,
    p_old_values  IN CLOB DEFAULT NULL,
    p_new_values  IN CLOB DEFAULT NULL
  ) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    INSERT INTO audit_log (
      audit_id, table_name, operation, record_id, member_id,
      old_values, new_values, changed_by, changed_date,
      session_id
    ) VALUES (
      seq_audit_id.NEXTVAL, UPPER(p_table_name), UPPER(p_operation),
      p_record_id, p_member_id, p_old_values, p_new_values,
      USER, SYSDATE,
      SYS_CONTEXT('USERENV', 'SESSIONID')
    );

    COMMIT;
  END log_change;

  -- Get audit trail for a record
  FUNCTION get_audit_trail(
    p_table_name  IN VARCHAR2,
    p_record_id   IN NUMBER
  ) RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
  BEGIN
    OPEN v_cursor FOR
      SELECT audit_id, operation, old_values, new_values,
             changed_by, changed_date
      FROM audit_log
      WHERE table_name = UPPER(p_table_name)
        AND record_id = p_record_id
      ORDER BY changed_date DESC;

    RETURN v_cursor;
  END get_audit_trail;

  -- Get member audit trail
  FUNCTION get_member_audit_trail(
    p_member_id   IN NUMBER,
    p_start_date  IN DATE DEFAULT NULL,
    p_end_date    IN DATE DEFAULT NULL
  ) RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
  BEGIN
    OPEN v_cursor FOR
      SELECT audit_id, table_name, operation, record_id,
             old_values, new_values, changed_by, changed_date
      FROM audit_log
      WHERE member_id = p_member_id
        AND changed_date >= NVL(p_start_date, DATE '2000-01-01')
        AND changed_date <= NVL(p_end_date, SYSDATE)
      ORDER BY changed_date DESC;

    RETURN v_cursor;
  END get_member_audit_trail;

  -- Purge old audit records
  PROCEDURE purge_audit_records(
    p_retention_days IN NUMBER DEFAULT 365,
    p_deleted_count  OUT NUMBER
  ) IS
  BEGIN
    DELETE FROM audit_log
    WHERE changed_date < SYSDATE - p_retention_days;

    p_deleted_count := SQL%ROWCOUNT;
    COMMIT;
  END purge_audit_records;

  -- Get audit summary statistics
  FUNCTION get_audit_summary(
    p_start_date  IN DATE DEFAULT TRUNC(SYSDATE),
    p_end_date    IN DATE DEFAULT SYSDATE
  ) RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
  BEGIN
    OPEN v_cursor FOR
      SELECT table_name, operation,
             COUNT(*) AS change_count,
             COUNT(DISTINCT member_id) AS affected_members,
             MIN(changed_date) AS first_change,
             MAX(changed_date) AS last_change
      FROM audit_log
      WHERE changed_date BETWEEN p_start_date AND p_end_date
      GROUP BY table_name, operation
      ORDER BY table_name, operation;

    RETURN v_cursor;
  END get_audit_summary;

END pkg_audit;
/
