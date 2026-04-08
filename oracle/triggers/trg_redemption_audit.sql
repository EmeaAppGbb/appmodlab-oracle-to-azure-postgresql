-- ========================================
-- Trigger: Redemption Audit (TRG_REDEMPTION_AUDIT)
-- ========================================
-- Tracks redemption changes and enforces redemption business rules

CREATE OR REPLACE TRIGGER trg_redemption_audit
  AFTER INSERT OR UPDATE ON redemptions
  FOR EACH ROW
DECLARE
  v_old_vals CLOB;
  v_new_vals CLOB;
BEGIN
  IF INSERTING THEN
    -- Audit the new redemption
    v_new_vals := '{"redemption_id":' || :NEW.redemption_id ||
                  ',"reward_id":' || :NEW.reward_id ||
                  ',"miles_used":' || :NEW.miles_used ||
                  ',"quantity":' || :NEW.quantity ||
                  ',"confirmation_code":"' || :NEW.confirmation_code ||
                  '","channel":"' || :NEW.redemption_channel ||
                  '","status":"' || :NEW.status || '"}';

    pkg_audit.log_change(
      p_table_name => 'REDEMPTIONS',
      p_operation  => 'INSERT',
      p_record_id  => :NEW.redemption_id,
      p_member_id  => :NEW.member_id,
      p_old_values => NULL,
      p_new_values => v_new_vals
    );

  ELSIF UPDATING THEN
    -- Only audit if status changed
    IF :OLD.status != :NEW.status THEN
      v_old_vals := '{"status":"' || :OLD.status ||
                    '","miles_used":' || :OLD.miles_used || '}';
      v_new_vals := '{"status":"' || :NEW.status ||
                    '","miles_used":' || :NEW.miles_used ||
                    '","fulfillment_date":"' ||
                    NVL(TO_CHAR(:NEW.fulfillment_date, 'YYYY-MM-DD'), 'null') || '"}';

      pkg_audit.log_change(
        p_table_name => 'REDEMPTIONS',
        p_operation  => 'UPDATE',
        p_record_id  => :NEW.redemption_id,
        p_member_id  => :NEW.member_id,
        p_old_values => v_old_vals,
        p_new_values => v_new_vals
      );
    END IF;
  END IF;

END trg_redemption_audit;
/
