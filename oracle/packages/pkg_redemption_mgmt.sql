-- ========================================
-- Package: Redemption Management (PKG_REDEMPTION_MGMT)
-- ========================================
-- Handles reward redemptions, cancellations, and fulfillment

CREATE OR REPLACE PACKAGE pkg_redemption_mgmt AS

  -- Redeem a reward
  PROCEDURE redeem_reward(
    p_member_id       IN  NUMBER,
    p_reward_id       IN  NUMBER,
    p_quantity        IN  NUMBER DEFAULT 1,
    p_channel         IN  VARCHAR2 DEFAULT 'WEB',
    p_redemption_id   OUT NUMBER,
    p_confirm_code    OUT VARCHAR2
  );

  -- Cancel a redemption
  PROCEDURE cancel_redemption(
    p_redemption_id   IN  NUMBER,
    p_reason          IN  VARCHAR2
  );

  -- Fulfill a redemption (mark as delivered)
  PROCEDURE fulfill_redemption(
    p_redemption_id   IN  NUMBER,
    p_fulfillment_notes IN VARCHAR2 DEFAULT NULL
  );

  -- Get redemption history for a member
  FUNCTION get_member_redemptions(
    p_member_id       IN  NUMBER,
    p_start_date      IN  DATE DEFAULT NULL,
    p_end_date        IN  DATE DEFAULT NULL
  ) RETURN SYS_REFCURSOR;

  -- Generate confirmation code
  FUNCTION generate_confirmation_code RETURN VARCHAR2;

  -- Check reward availability
  FUNCTION check_reward_available(
    p_reward_id       IN  NUMBER,
    p_member_id       IN  NUMBER,
    p_quantity        IN  NUMBER DEFAULT 1
  ) RETURN BOOLEAN;

END pkg_redemption_mgmt;
/

CREATE OR REPLACE PACKAGE BODY pkg_redemption_mgmt AS

  -- Generate confirmation code
  FUNCTION generate_confirmation_code RETURN VARCHAR2 IS
  BEGIN
    RETURN 'SR' || TO_CHAR(SYSDATE, 'YYYYMMDD') ||
           LPAD(TRUNC(DBMS_RANDOM.VALUE(100000, 999999)), 6, '0');
  END generate_confirmation_code;

  -- Check reward availability
  FUNCTION check_reward_available(
    p_reward_id       IN  NUMBER,
    p_member_id       IN  NUMBER,
    p_quantity        IN  NUMBER DEFAULT 1
  ) RETURN BOOLEAN IS
    v_reward_status    VARCHAR2(20);
    v_qty_available    NUMBER;
    v_min_tier         VARCHAR2(20);
    v_member_tier      VARCHAR2(20);
    v_miles_required   NUMBER;
    v_member_miles     NUMBER;
    v_valid_from       DATE;
    v_valid_until      DATE;
  BEGIN
    SELECT status, NVL(quantity_available, 999999), min_tier_required,
           miles_required, valid_from, NVL(valid_until, SYSDATE + 1)
    INTO v_reward_status, v_qty_available, v_min_tier,
         v_miles_required, v_valid_from, v_valid_until
    FROM rewards WHERE reward_id = p_reward_id;

    SELECT tier_status, available_miles
    INTO v_member_tier, v_member_miles
    FROM members WHERE member_id = p_member_id;

    -- Check all conditions
    IF v_reward_status != 'ACTIVE' THEN RETURN FALSE; END IF;
    IF SYSDATE NOT BETWEEN v_valid_from AND v_valid_until THEN RETURN FALSE; END IF;
    IF v_qty_available < p_quantity THEN RETURN FALSE; END IF;
    IF v_member_miles < v_miles_required * p_quantity THEN RETURN FALSE; END IF;

    RETURN TRUE;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN FALSE;
  END check_reward_available;

  -- Redeem a reward
  PROCEDURE redeem_reward(
    p_member_id       IN  NUMBER,
    p_reward_id       IN  NUMBER,
    p_quantity        IN  NUMBER DEFAULT 1,
    p_channel         IN  VARCHAR2 DEFAULT 'WEB',
    p_redemption_id   OUT NUMBER,
    p_confirm_code    OUT VARCHAR2
  ) IS
    v_miles_required  NUMBER;
    v_cash_copay      NUMBER;
    v_total_miles     NUMBER;
    v_reward_name     VARCHAR2(200);
  BEGIN
    -- Validate member
    pkg_validation.validate_member_active(p_member_id);

    -- Check availability
    IF NOT check_reward_available(p_reward_id, p_member_id, p_quantity) THEN
      RAISE_APPLICATION_ERROR(-20040, 'Reward not available for redemption');
    END IF;

    -- Get reward details
    SELECT miles_required, NVL(cash_copay, 0), reward_name
    INTO v_miles_required, v_cash_copay, v_reward_name
    FROM rewards WHERE reward_id = p_reward_id;

    v_total_miles  := v_miles_required * p_quantity;
    p_redemption_id := seq_redemption_id.NEXTVAL;
    p_confirm_code  := generate_confirmation_code();

    -- Insert redemption
    INSERT INTO redemptions (
      redemption_id, member_id, reward_id, redemption_date,
      miles_used, cash_paid, quantity, confirmation_code,
      redemption_channel, status, expiry_date
    ) VALUES (
      p_redemption_id, p_member_id, p_reward_id, SYSDATE,
      v_total_miles, v_cash_copay * p_quantity, p_quantity,
      p_confirm_code, p_channel, 'CONFIRMED',
      ADD_MONTHS(SYSDATE, 12)
    );

    -- Deduct miles from member
    pkg_member_mgmt.update_miles_balance(p_member_id, -v_total_miles, 'REDEEM');

    -- Decrease reward quantity
    UPDATE rewards SET
      quantity_available = quantity_available - p_quantity,
      updated_date       = SYSDATE
    WHERE reward_id = p_reward_id
      AND quantity_available IS NOT NULL;

    -- Send confirmation notification
    pkg_notification.send_notification(
      p_member_id, 'REDEMPTION_CONFIRM',
      'Redemption Confirmed - ' || v_reward_name,
      'Your redemption has been confirmed. Confirmation code: ' || p_confirm_code ||
      '. Miles used: ' || v_total_miles
    );

    COMMIT;

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE;
  END redeem_reward;

  -- Cancel redemption
  PROCEDURE cancel_redemption(
    p_redemption_id   IN  NUMBER,
    p_reason          IN  VARCHAR2
  ) IS
    v_member_id    NUMBER;
    v_miles_used   NUMBER;
    v_reward_id    NUMBER;
    v_quantity     NUMBER;
    v_status       VARCHAR2(20);
  BEGIN
    SELECT member_id, miles_used, reward_id, quantity, status
    INTO v_member_id, v_miles_used, v_reward_id, v_quantity, v_status
    FROM redemptions WHERE redemption_id = p_redemption_id;

    IF v_status NOT IN ('PENDING', 'CONFIRMED') THEN
      RAISE_APPLICATION_ERROR(-20041, 'Cannot cancel redemption in status: ' || v_status);
    END IF;

    UPDATE redemptions SET
      status       = 'CANCELLED',
      notes        = p_reason,
      updated_date = SYSDATE
    WHERE redemption_id = p_redemption_id;

    -- Refund miles to member
    pkg_member_mgmt.update_miles_balance(v_member_id, v_miles_used, 'REFUND');

    -- Restore reward quantity
    UPDATE rewards SET
      quantity_available = quantity_available + v_quantity,
      updated_date       = SYSDATE
    WHERE reward_id = v_reward_id
      AND quantity_available IS NOT NULL;

    pkg_audit.log_change('REDEMPTIONS', 'UPDATE', p_redemption_id, v_member_id,
      '{"status":"' || v_status || '"}',
      '{"status":"CANCELLED","reason":"' || p_reason || '"}');

    COMMIT;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20042, 'Redemption not found: ' || p_redemption_id);
  END cancel_redemption;

  -- Fulfill redemption
  PROCEDURE fulfill_redemption(
    p_redemption_id   IN  NUMBER,
    p_fulfillment_notes IN VARCHAR2 DEFAULT NULL
  ) IS
  BEGIN
    UPDATE redemptions SET
      status           = 'FULFILLED',
      fulfillment_date = SYSDATE,
      notes            = p_fulfillment_notes,
      updated_date     = SYSDATE
    WHERE redemption_id = p_redemption_id
      AND status = 'CONFIRMED';

    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20043, 'Redemption not found or not in CONFIRMED status');
    END IF;

    COMMIT;
  END fulfill_redemption;

  -- Get member redemption history
  FUNCTION get_member_redemptions(
    p_member_id       IN  NUMBER,
    p_start_date      IN  DATE DEFAULT NULL,
    p_end_date        IN  DATE DEFAULT NULL
  ) RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
  BEGIN
    OPEN v_cursor FOR
      SELECT r.redemption_id, r.redemption_date, r.miles_used,
             r.confirmation_code, r.status, r.quantity,
             rw.reward_name, rw.category
      FROM redemptions r
      JOIN rewards rw ON r.reward_id = rw.reward_id
      WHERE r.member_id = p_member_id
        AND r.redemption_date >= NVL(p_start_date, DATE '2000-01-01')
        AND r.redemption_date <= NVL(p_end_date, SYSDATE)
      ORDER BY r.redemption_date DESC;

    RETURN v_cursor;
  END get_member_redemptions;

END pkg_redemption_mgmt;
/
