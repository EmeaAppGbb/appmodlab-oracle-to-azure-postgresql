-- ============================================================================
-- Trigger: Redemption Audit (TRG_REDEMPTION_AUDIT)
-- Converted from Oracle trigger TRG_REDEMPTION_AUDIT to PostgreSQL PL/pgSQL.
--
-- Conversion notes:
--   - Oracle standalone trigger split into trigger function + CREATE TRIGGER
--   - :NEW / :OLD replaced with NEW / OLD
--   - INSERTING / UPDATING replaced with TG_OP checks
--   - NVL replaced with COALESCE
--   - CLOB replaced with TEXT
--   - pkg_audit.log_change replaced with audit_log_change
--   - AFTER trigger returns NULL in PostgreSQL
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_trg_redemption_audit()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_old_vals TEXT;
    v_new_vals TEXT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Audit the new redemption
        v_new_vals := '{"redemption_id":' || NEW.redemption_id ||
                      ',"reward_id":' || NEW.reward_id ||
                      ',"miles_used":' || NEW.miles_used ||
                      ',"quantity":' || NEW.quantity ||
                      ',"confirmation_code":"' || NEW.confirmation_code ||
                      '","channel":"' || NEW.redemption_channel ||
                      '","status":"' || NEW.status || '"}';

        PERFORM audit_log_change(
            p_table_name => 'REDEMPTIONS',
            p_operation  => 'INSERT',
            p_record_id  => NEW.redemption_id,
            p_member_id  => NEW.member_id,
            p_old_values => NULL,
            p_new_values => v_new_vals
        );

    ELSIF TG_OP = 'UPDATE' THEN
        -- Only audit if status changed
        IF OLD.status != NEW.status THEN
            v_old_vals := '{"status":"' || OLD.status ||
                          '","miles_used":' || OLD.miles_used || '}';
            v_new_vals := '{"status":"' || NEW.status ||
                          '","miles_used":' || NEW.miles_used ||
                          '","fulfillment_date":"' ||
                          COALESCE(TO_CHAR(NEW.fulfillment_date, 'YYYY-MM-DD'), 'null') ||
                          '"}';

            PERFORM audit_log_change(
                p_table_name => 'REDEMPTIONS',
                p_operation  => 'UPDATE',
                p_record_id  => NEW.redemption_id,
                p_member_id  => NEW.member_id,
                p_old_values => v_old_vals,
                p_new_values => v_new_vals
            );
        END IF;
    END IF;

    RETURN NULL;
END;
$$;

-- Create the trigger
CREATE TRIGGER trg_redemption_audit
    AFTER INSERT OR UPDATE ON redemptions
    FOR EACH ROW
    EXECUTE FUNCTION fn_trg_redemption_audit();
