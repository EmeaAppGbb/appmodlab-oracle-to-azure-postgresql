-- ========================================
-- Trigger: Member Audit (TRG_MEMBER_AUDIT)
-- ========================================
-- Captures all changes to the members table in the audit log

CREATE OR REPLACE TRIGGER trg_member_audit
  AFTER INSERT OR UPDATE OR DELETE ON members
  FOR EACH ROW
DECLARE
  v_operation VARCHAR2(10);
  v_old_vals  CLOB;
  v_new_vals  CLOB;
  v_member_id NUMBER;
BEGIN
  IF INSERTING THEN
    v_operation := 'INSERT';
    v_member_id := :NEW.member_id;
    v_new_vals := '{"membership_number":"' || :NEW.membership_number ||
                  '","first_name":"' || :NEW.first_name ||
                  '","last_name":"' || :NEW.last_name ||
                  '","email":"' || :NEW.email ||
                  '","tier_status":"' || :NEW.tier_status ||
                  '","available_miles":' || NVL(:NEW.available_miles, 0) ||
                  ',"status":"' || :NEW.status || '"}';
  ELSIF UPDATING THEN
    v_operation := 'UPDATE';
    v_member_id := :NEW.member_id;
    v_old_vals := '{"first_name":"' || :OLD.first_name ||
                  '","last_name":"' || :OLD.last_name ||
                  '","email":"' || :OLD.email ||
                  '","tier_status":"' || :OLD.tier_status ||
                  '","available_miles":' || NVL(:OLD.available_miles, 0) ||
                  ',"status":"' || :OLD.status || '"}';
    v_new_vals := '{"first_name":"' || :NEW.first_name ||
                  '","last_name":"' || :NEW.last_name ||
                  '","email":"' || :NEW.email ||
                  '","tier_status":"' || :NEW.tier_status ||
                  '","available_miles":' || NVL(:NEW.available_miles, 0) ||
                  ',"status":"' || :NEW.status || '"}';
  ELSIF DELETING THEN
    v_operation := 'DELETE';
    v_member_id := :OLD.member_id;
    v_old_vals := '{"membership_number":"' || :OLD.membership_number ||
                  '","first_name":"' || :OLD.first_name ||
                  '","last_name":"' || :OLD.last_name ||
                  '","email":"' || :OLD.email ||
                  '","status":"' || :OLD.status || '"}';
  END IF;

  -- Use autonomous transaction via pkg_audit
  pkg_audit.log_change(
    p_table_name => 'MEMBERS',
    p_operation  => v_operation,
    p_record_id  => v_member_id,
    p_member_id  => v_member_id,
    p_old_values => v_old_vals,
    p_new_values => v_new_vals
  );
END trg_member_audit;
/
