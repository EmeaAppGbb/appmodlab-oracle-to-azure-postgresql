-- ============================================================================
-- PostgreSQL conversion of Oracle package PKG_AUDIT
-- Each package procedure/function becomes a standalone function
-- prefixed with audit_
--
-- Conversion notes:
--   - PRAGMA AUTONOMOUS_TRANSACTION removed (see comment in log_change)
--   - SYS_CONTEXT('USERENV','SESSIONID') replaced with pg_backend_pid()::TEXT
--   - USER replaced with current_user
--   - SYSDATE replaced with CURRENT_TIMESTAMP / CURRENT_DATE
--   - TRUNC(SYSDATE) replaced with CURRENT_DATE
--   - NVL replaced with COALESCE
--   - seq_xxx.NEXTVAL replaced with nextval('seq_xxx')
--   - CLOB replaced with TEXT
--   - SQL%ROWCOUNT replaced with GET DIAGNOSTICS ... ROW_COUNT
--   - SYS_REFCURSOR replaced with RETURNS TABLE + RETURN QUERY
--   - COMMIT/ROLLBACK removed (transaction control is external)
-- ============================================================================

-- ============================================================================
-- Function: audit_log_change
-- Inserts a record into the audit_log table.
-- NOTE: Oracle used PRAGMA AUTONOMOUS_TRANSACTION to allow the audit insert
-- to commit independently. PostgreSQL does not support autonomous transactions
-- natively. The caller should manage transaction boundaries. If independent
-- commit is required, consider using dblink or pg_background extensions.
-- ============================================================================
CREATE OR REPLACE FUNCTION audit_log_change(
    p_table_name VARCHAR,
    p_operation  VARCHAR,
    p_record_id  BIGINT,
    p_member_id  BIGINT   DEFAULT NULL,
    p_old_values TEXT     DEFAULT NULL,
    p_new_values TEXT     DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO audit_log (
        audit_id, table_name, operation, record_id, member_id,
        old_values, new_values, changed_by, changed_date,
        session_id
    ) VALUES (
        nextval('seq_audit_id'), UPPER(p_table_name), UPPER(p_operation),
        p_record_id, p_member_id, p_old_values, p_new_values,
        current_user, CURRENT_TIMESTAMP,
        pg_backend_pid()::TEXT
    );
END;
$$;

-- ============================================================================
-- Function: audit_get_audit_trail
-- Returns the audit trail for a specific table/record combination.
-- Oracle: SYS_REFCURSOR → RETURNS TABLE with RETURN QUERY
-- ============================================================================
CREATE OR REPLACE FUNCTION audit_get_audit_trail(
    p_table_name VARCHAR,
    p_record_id  BIGINT
)
RETURNS TABLE(
    audit_id     BIGINT,
    operation    VARCHAR,
    old_values   TEXT,
    new_values   TEXT,
    changed_by   VARCHAR,
    changed_date TIMESTAMP
)
LANGUAGE plpgsql STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT al.audit_id, al.operation, al.old_values, al.new_values,
           al.changed_by, al.changed_date
      FROM audit_log al
     WHERE al.table_name = UPPER(p_table_name)
       AND al.record_id = p_record_id
     ORDER BY al.changed_date DESC;
END;
$$;

-- ============================================================================
-- Function: audit_get_member_audit_trail
-- Returns the audit trail for a specific member, optionally filtered by date.
-- Oracle: NVL → COALESCE, SYSDATE → CURRENT_TIMESTAMP
-- ============================================================================
CREATE OR REPLACE FUNCTION audit_get_member_audit_trail(
    p_member_id  BIGINT,
    p_start_date DATE DEFAULT NULL,
    p_end_date   DATE DEFAULT NULL
)
RETURNS TABLE(
    audit_id     BIGINT,
    table_name   VARCHAR,
    operation    VARCHAR,
    record_id    BIGINT,
    old_values   TEXT,
    new_values   TEXT,
    changed_by   VARCHAR,
    changed_date TIMESTAMP
)
LANGUAGE plpgsql STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT al.audit_id, al.table_name, al.operation, al.record_id,
           al.old_values, al.new_values, al.changed_by, al.changed_date
      FROM audit_log al
     WHERE al.member_id = p_member_id
       AND al.changed_date >= COALESCE(p_start_date, DATE '2000-01-01')
       AND al.changed_date <= COALESCE(p_end_date, CURRENT_TIMESTAMP)
     ORDER BY al.changed_date DESC;
END;
$$;

-- ============================================================================
-- Function: audit_purge_audit_records
-- Deletes audit records older than the specified retention period.
-- Oracle: SQL%ROWCOUNT → GET DIAGNOSTICS
-- Returns the number of deleted rows.
-- ============================================================================
CREATE OR REPLACE FUNCTION audit_purge_audit_records(
    p_retention_days INT DEFAULT 365
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_deleted_count INT;
BEGIN
    DELETE FROM audit_log
     WHERE changed_date < CURRENT_TIMESTAMP - (p_retention_days || ' days')::INTERVAL;

    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

    RETURN v_deleted_count;
END;
$$;

-- ============================================================================
-- Function: audit_get_audit_summary
-- Returns aggregate audit statistics grouped by table and operation.
-- Oracle: TRUNC(SYSDATE) → CURRENT_DATE, SYSDATE → CURRENT_TIMESTAMP
-- ============================================================================
CREATE OR REPLACE FUNCTION audit_get_audit_summary(
    p_start_date TIMESTAMP DEFAULT NULL,
    p_end_date   TIMESTAMP DEFAULT NULL
)
RETURNS TABLE(
    table_name       VARCHAR,
    operation        VARCHAR,
    change_count     BIGINT,
    affected_members BIGINT,
    first_change     TIMESTAMP,
    last_change      TIMESTAMP
)
LANGUAGE plpgsql STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT al.table_name, al.operation,
           COUNT(*)::BIGINT                      AS change_count,
           COUNT(DISTINCT al.member_id)::BIGINT  AS affected_members,
           MIN(al.changed_date)                  AS first_change,
           MAX(al.changed_date)                  AS last_change
      FROM audit_log al
     WHERE al.changed_date BETWEEN COALESCE(p_start_date, CURRENT_DATE::TIMESTAMP)
                                AND COALESCE(p_end_date, CURRENT_TIMESTAMP)
     GROUP BY al.table_name, al.operation
     ORDER BY al.table_name, al.operation;
END;
$$;
