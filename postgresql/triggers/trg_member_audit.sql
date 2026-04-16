-- ============================================================================
-- Trigger: Member Audit (TRG_MEMBER_AUDIT)
-- Converted from Oracle trigger TRG_MEMBER_AUDIT to PostgreSQL PL/pgSQL.
--
-- Conversion notes:
--   - Oracle standalone trigger split into trigger function + CREATE TRIGGER
--   - :NEW / :OLD replaced with NEW / OLD
--   - INSERTING / UPDATING / DELETING replaced with TG_OP checks
--   - NVL replaced with COALESCE
--   - CLOB replaced with TEXT
--   - pkg_audit.log_change replaced with audit_log_change
--   - AFTER trigger returns NULL in PostgreSQL
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_trg_member_audit()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_operation VARCHAR(10);
    v_old_vals  TEXT;
    v_new_vals  TEXT;
    v_member_id BIGINT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_operation := 'INSERT';
        v_member_id := NEW.member_id;
        v_new_vals := '{"membership_number":"' || NEW.membership_number ||
                      '","first_name":"' || NEW.first_name ||
                      '","last_name":"' || NEW.last_name ||
                      '","email":"' || NEW.email ||
                      '","tier_status":"' || NEW.tier_status ||
                      '","available_miles":' || COALESCE(NEW.available_miles, 0) ||
                      ',"status":"' || NEW.status || '"}';

    ELSIF TG_OP = 'UPDATE' THEN
        v_operation := 'UPDATE';
        v_member_id := NEW.member_id;
        v_old_vals := '{"first_name":"' || OLD.first_name ||
                      '","last_name":"' || OLD.last_name ||
                      '","email":"' || OLD.email ||
                      '","tier_status":"' || OLD.tier_status ||
                      '","available_miles":' || COALESCE(OLD.available_miles, 0) ||
                      ',"status":"' || OLD.status || '"}';
        v_new_vals := '{"first_name":"' || NEW.first_name ||
                      '","last_name":"' || NEW.last_name ||
                      '","email":"' || NEW.email ||
                      '","tier_status":"' || NEW.tier_status ||
                      '","available_miles":' || COALESCE(NEW.available_miles, 0) ||
                      ',"status":"' || NEW.status || '"}';

    ELSIF TG_OP = 'DELETE' THEN
        v_operation := 'DELETE';
        v_member_id := OLD.member_id;
        v_old_vals := '{"membership_number":"' || OLD.membership_number ||
                      '","first_name":"' || OLD.first_name ||
                      '","last_name":"' || OLD.last_name ||
                      '","email":"' || OLD.email ||
                      '","status":"' || OLD.status || '"}';
    END IF;

    -- Log the change via audit function
    PERFORM audit_log_change(
        p_table_name => 'MEMBERS',
        p_operation  => v_operation,
        p_record_id  => v_member_id,
        p_member_id  => v_member_id,
        p_old_values => v_old_vals,
        p_new_values => v_new_vals
    );

    RETURN NULL;
END;
$$;

-- Create the trigger
CREATE TRIGGER trg_member_audit
    AFTER INSERT OR UPDATE OR DELETE ON members
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_member_audit();
