-- ============================================================================
-- PostgreSQL conversion of Oracle package PKG_REDEMPTION_MGMT
-- Each package procedure/function becomes a standalone function
-- prefixed with redemption_mgmt_
-- ============================================================================

-- ============================================================================
-- Function: redemption_mgmt_generate_confirmation_code
-- Generates a unique confirmation code for a redemption.
-- Oracle: generate_confirmation_code RETURN VARCHAR2
-- ============================================================================
CREATE OR REPLACE FUNCTION redemption_mgmt_generate_confirmation_code()
RETURNS VARCHAR
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN 'SR' || TO_CHAR(CURRENT_TIMESTAMP, 'YYYYMMDD')
        || LPAD(TRUNC(random() * 899999 + 100000)::TEXT, 6, '0');
END;
$$;

-- ============================================================================
-- Function: redemption_mgmt_check_reward_available
-- Checks whether a reward is available for a given member and quantity.
-- Oracle: check_reward_available RETURN BOOLEAN (used NVL, SYSDATE)
-- ============================================================================
CREATE OR REPLACE FUNCTION redemption_mgmt_check_reward_available(
    p_reward_id  BIGINT,
    p_member_id  BIGINT,
    p_quantity   INT DEFAULT 1
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_available_qty   INT;
    v_is_active       BOOLEAN;
    v_valid_from      DATE;
    v_valid_to        DATE;
    v_member_tier     VARCHAR;
    v_required_tier   VARCHAR;
BEGIN
    -- Get reward details
    SELECT quantity_available, is_active, valid_from, valid_to, required_tier
      INTO v_available_qty, v_is_active, v_valid_from, v_valid_to, v_required_tier
      FROM rewards
     WHERE reward_id = p_reward_id;

    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    -- Check active status
    IF NOT COALESCE(v_is_active, FALSE) THEN
        RETURN FALSE;
    END IF;

    -- Check date validity
    IF v_valid_from IS NOT NULL AND CURRENT_DATE < v_valid_from THEN
        RETURN FALSE;
    END IF;

    IF v_valid_to IS NOT NULL AND CURRENT_DATE > v_valid_to THEN
        RETURN FALSE;
    END IF;

    -- Check quantity
    IF COALESCE(v_available_qty, 0) < p_quantity THEN
        RETURN FALSE;
    END IF;

    -- Check member tier if required
    IF v_required_tier IS NOT NULL THEN
        SELECT current_tier INTO v_member_tier
          FROM members
         WHERE member_id = p_member_id;

        IF v_member_tier IS NULL OR v_member_tier <> v_required_tier THEN
            RETURN FALSE;
        END IF;
    END IF;

    RETURN TRUE;
END;
$$;

-- ============================================================================
-- Function: redemption_mgmt_redeem_reward
-- Redeems a reward for a member: validates, inserts, deducts miles, notifies.
-- Oracle: procedure with OUT params → PostgreSQL RETURNS TABLE
-- ============================================================================
CREATE OR REPLACE FUNCTION redemption_mgmt_redeem_reward(
    p_member_id  BIGINT,
    p_reward_id  BIGINT,
    p_quantity   INT     DEFAULT 1,
    p_channel    VARCHAR DEFAULT 'WEB'
)
RETURNS TABLE(redemption_id BIGINT, confirm_code VARCHAR)
LANGUAGE plpgsql
AS $$
DECLARE
    v_redemption_id   BIGINT;
    v_confirm_code    VARCHAR;
    v_miles_cost      NUMERIC;
    v_reward_name     VARCHAR;
    v_total_cost      NUMERIC;
BEGIN
    -- Validate member is active
    PERFORM validation_validate_member_active(p_member_id);

    -- Check reward availability
    IF NOT redemption_mgmt_check_reward_available(p_reward_id, p_member_id, p_quantity) THEN
        RAISE EXCEPTION 'Reward % is not available for the requested quantity', p_reward_id;
    END IF;

    -- Get reward details
    SELECT r.miles_required, r.reward_name
      INTO v_miles_cost, v_reward_name
      FROM rewards r
     WHERE r.reward_id = p_reward_id;

    v_total_cost := v_miles_cost * p_quantity;

    -- Generate confirmation code
    v_confirm_code := redemption_mgmt_generate_confirmation_code();

    -- Insert redemption record
    v_redemption_id := nextval('seq_redemption_id');

    INSERT INTO redemptions (
        redemption_id, member_id, reward_id, quantity,
        miles_used, confirmation_code, status, channel,
        redemption_date, created_date, created_by
    ) VALUES (
        v_redemption_id, p_member_id, p_reward_id, p_quantity,
        v_total_cost, v_confirm_code, 'PENDING', p_channel,
        CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, current_user
    );

    -- Deduct miles from member balance
    PERFORM member_mgmt_update_miles_balance(p_member_id, -v_total_cost);

    -- Decrease reward quantity
    UPDATE rewards
       SET quantity_available = quantity_available - p_quantity,
           updated_date = CURRENT_TIMESTAMP
     WHERE reward_id = p_reward_id;

    -- Send confirmation notification
    PERFORM notification_send_notification(
        p_member_id  := p_member_id,
        p_type       := 'REDEMPTION_CONFIRM',
        p_subject    := 'Reward Redemption Confirmation',
        p_body       := 'Your redemption for ' || v_reward_name
                        || ' (Qty: ' || p_quantity || ') has been confirmed.'
                        || ' Confirmation code: ' || v_confirm_code
    );

    RETURN QUERY SELECT v_redemption_id, v_confirm_code;
END;
$$;

-- ============================================================================
-- Function: redemption_mgmt_cancel_redemption
-- Cancels a pending or confirmed redemption: refunds miles, restores qty.
-- Oracle: cancel_redemption procedure
-- ============================================================================
CREATE OR REPLACE FUNCTION redemption_mgmt_cancel_redemption(
    p_redemption_id  BIGINT,
    p_reason         VARCHAR
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_member_id    BIGINT;
    v_reward_id    BIGINT;
    v_quantity     INT;
    v_miles_used   NUMERIC;
    v_status       VARCHAR;
BEGIN
    -- Get redemption details
    SELECT member_id, reward_id, quantity, miles_used, status
      INTO v_member_id, v_reward_id, v_quantity, v_miles_used, v_status
      FROM redemptions
     WHERE redemption_id = p_redemption_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Redemption % not found', p_redemption_id;
    END IF;

    -- Validate status allows cancellation
    IF v_status NOT IN ('PENDING', 'CONFIRMED') THEN
        RAISE EXCEPTION 'Cannot cancel redemption with status %', v_status;
    END IF;

    -- Update redemption status
    UPDATE redemptions
       SET status = 'CANCELLED',
           cancel_reason = p_reason,
           cancelled_date = CURRENT_TIMESTAMP,
           updated_date = CURRENT_TIMESTAMP,
           updated_by = current_user
     WHERE redemption_id = p_redemption_id;

    -- Refund miles to member
    PERFORM member_mgmt_update_miles_balance(v_member_id, v_miles_used);

    -- Restore reward quantity
    UPDATE rewards
       SET quantity_available = quantity_available + v_quantity,
           updated_date = CURRENT_TIMESTAMP
     WHERE reward_id = v_reward_id;

    -- Log audit trail
    PERFORM audit_log_change(
        p_table_name  := 'redemptions',
        p_record_id   := p_redemption_id,
        p_action       := 'CANCEL',
        p_old_value    := v_status,
        p_new_value    := 'CANCELLED',
        p_change_reason := p_reason
    );
END;
$$;

-- ============================================================================
-- Function: redemption_mgmt_fulfill_redemption
-- Marks a confirmed redemption as fulfilled.
-- Oracle: fulfill_redemption procedure (used SQL%ROWCOUNT)
-- ============================================================================
CREATE OR REPLACE FUNCTION redemption_mgmt_fulfill_redemption(
    p_redemption_id     BIGINT,
    p_fulfillment_notes VARCHAR DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_rowcount INT;
BEGIN
    UPDATE redemptions
       SET status = 'FULFILLED',
           fulfillment_date = CURRENT_TIMESTAMP,
           fulfillment_notes = p_fulfillment_notes,
           updated_date = CURRENT_TIMESTAMP,
           updated_by = current_user
     WHERE redemption_id = p_redemption_id
       AND status = 'CONFIRMED';

    GET DIAGNOSTICS v_rowcount = ROW_COUNT;

    IF v_rowcount = 0 THEN
        RAISE EXCEPTION 'Redemption % not found or not in CONFIRMED status', p_redemption_id;
    END IF;
END;
$$;

-- ============================================================================
-- Function: redemption_mgmt_get_member_redemptions
-- Returns redemption history for a member within an optional date range.
-- Oracle: SYS_REFCURSOR → RETURNS TABLE with RETURN QUERY
-- ============================================================================
CREATE OR REPLACE FUNCTION redemption_mgmt_get_member_redemptions(
    p_member_id   BIGINT,
    p_start_date  DATE DEFAULT NULL,
    p_end_date    DATE DEFAULT NULL
)
RETURNS TABLE(
    redemption_id       BIGINT,
    reward_id           BIGINT,
    reward_name         VARCHAR,
    quantity            INT,
    miles_used          NUMERIC,
    confirmation_code   VARCHAR,
    status              VARCHAR,
    channel             VARCHAR,
    redemption_date     TIMESTAMP,
    fulfillment_date    TIMESTAMP,
    cancelled_date      TIMESTAMP
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT rd.redemption_id,
           rd.reward_id,
           rw.reward_name,
           rd.quantity,
           rd.miles_used,
           rd.confirmation_code,
           rd.status,
           rd.channel,
           rd.redemption_date,
           rd.fulfillment_date,
           rd.cancelled_date
      FROM redemptions rd
      JOIN rewards rw ON rw.reward_id = rd.reward_id
     WHERE rd.member_id = p_member_id
       AND (p_start_date IS NULL OR rd.redemption_date >= p_start_date)
       AND (p_end_date   IS NULL OR rd.redemption_date <= p_end_date)
     ORDER BY rd.redemption_date DESC;
END;
$$;
