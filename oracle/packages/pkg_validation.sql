-- ========================================
-- Package: Validation (PKG_VALIDATION)
-- ========================================
-- Centralized validation routines for data integrity

CREATE OR REPLACE PACKAGE pkg_validation AS

  -- Validate member exists and is active
  PROCEDURE validate_member_active(p_member_id IN NUMBER);

  -- Validate email format
  FUNCTION is_valid_email(p_email IN VARCHAR2) RETURN BOOLEAN;

  -- Validate IATA airport code
  FUNCTION is_valid_airport_code(p_code IN VARCHAR2) RETURN BOOLEAN;

  -- Validate flight date (not in future, not too old)
  FUNCTION is_valid_flight_date(p_flight_date IN DATE) RETURN BOOLEAN;

  -- Validate miles amount (positive, within reasonable range)
  FUNCTION is_valid_miles_amount(p_miles IN NUMBER) RETURN BOOLEAN;

  -- Validate tier status value
  FUNCTION is_valid_tier(p_tier IN VARCHAR2) RETURN BOOLEAN;

  -- Validate booking class
  FUNCTION is_valid_booking_class(p_class IN VARCHAR2) RETURN BOOLEAN;

  -- Validate redemption eligibility
  PROCEDURE validate_redemption(
    p_member_id   IN  NUMBER,
    p_reward_id   IN  NUMBER,
    p_quantity    IN  NUMBER DEFAULT 1
  );

  -- Validate partner is active
  PROCEDURE validate_partner_active(p_partner_code IN VARCHAR2);

END pkg_validation;
/

CREATE OR REPLACE PACKAGE BODY pkg_validation AS

  -- Validate member exists and is active
  PROCEDURE validate_member_active(p_member_id IN NUMBER) IS
    v_status VARCHAR2(20);
  BEGIN
    SELECT status INTO v_status
    FROM members WHERE member_id = p_member_id;

    IF v_status != 'ACTIVE' THEN
      RAISE_APPLICATION_ERROR(-20100, 'Member account is not active. Status: ' || v_status);
    END IF;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20101, 'Member not found: ' || p_member_id);
  END validate_member_active;

  -- Validate email format
  FUNCTION is_valid_email(p_email IN VARCHAR2) RETURN BOOLEAN IS
  BEGIN
    IF p_email IS NULL THEN RETURN FALSE; END IF;
    -- Oracle regex for basic email validation
    IF REGEXP_LIKE(p_email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$') THEN
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END IF;
  END is_valid_email;

  -- Validate IATA airport code (3 alpha characters)
  FUNCTION is_valid_airport_code(p_code IN VARCHAR2) RETURN BOOLEAN IS
  BEGIN
    IF p_code IS NULL THEN RETURN FALSE; END IF;
    RETURN REGEXP_LIKE(p_code, '^[A-Z]{3}$');
  END is_valid_airport_code;

  -- Validate flight date
  FUNCTION is_valid_flight_date(p_flight_date IN DATE) RETURN BOOLEAN IS
  BEGIN
    IF p_flight_date IS NULL THEN RETURN FALSE; END IF;
    IF p_flight_date > SYSDATE + 1 THEN RETURN FALSE; END IF;          -- Not in future
    IF p_flight_date < ADD_MONTHS(SYSDATE, -24) THEN RETURN FALSE; END IF; -- Not older than 2 years
    RETURN TRUE;
  END is_valid_flight_date;

  -- Validate miles amount
  FUNCTION is_valid_miles_amount(p_miles IN NUMBER) RETURN BOOLEAN IS
  BEGIN
    IF p_miles IS NULL THEN RETURN FALSE; END IF;
    IF p_miles <= 0 THEN RETURN FALSE; END IF;
    IF p_miles > 10000000 THEN RETURN FALSE; END IF; -- Max 10M miles per transaction
    RETURN TRUE;
  END is_valid_miles_amount;

  -- Validate tier status
  FUNCTION is_valid_tier(p_tier IN VARCHAR2) RETURN BOOLEAN IS
  BEGIN
    RETURN p_tier IN ('BLUE', 'SILVER', 'GOLD', 'PLATINUM', 'DIAMOND');
  END is_valid_tier;

  -- Validate booking class
  FUNCTION is_valid_booking_class(p_class IN VARCHAR2) RETURN BOOLEAN IS
  BEGIN
    IF p_class IS NULL OR LENGTH(p_class) > 2 THEN RETURN FALSE; END IF;
    RETURN REGEXP_LIKE(p_class, '^[A-Z]{1,2}$');
  END is_valid_booking_class;

  -- Validate redemption eligibility
  PROCEDURE validate_redemption(
    p_member_id   IN  NUMBER,
    p_reward_id   IN  NUMBER,
    p_quantity    IN  NUMBER DEFAULT 1
  ) IS
    v_member_status  VARCHAR2(20);
    v_member_tier    VARCHAR2(20);
    v_member_miles   NUMBER;
    v_reward_status  VARCHAR2(20);
    v_min_tier       VARCHAR2(20);
    v_miles_required NUMBER;
    v_qty_available  NUMBER;
    v_valid_from     DATE;
    v_valid_until    DATE;
  BEGIN
    -- Check member
    SELECT status, tier_status, available_miles
    INTO v_member_status, v_member_tier, v_member_miles
    FROM members WHERE member_id = p_member_id;

    IF v_member_status != 'ACTIVE' THEN
      RAISE_APPLICATION_ERROR(-20110, 'Member account is not active');
    END IF;

    -- Check reward
    SELECT status, min_tier_required, miles_required,
           NVL(quantity_available, 999999), valid_from, NVL(valid_until, SYSDATE + 1)
    INTO v_reward_status, v_min_tier, v_miles_required,
         v_qty_available, v_valid_from, v_valid_until
    FROM rewards WHERE reward_id = p_reward_id;

    IF v_reward_status != 'ACTIVE' THEN
      RAISE_APPLICATION_ERROR(-20111, 'Reward is not active');
    END IF;

    IF SYSDATE NOT BETWEEN v_valid_from AND v_valid_until THEN
      RAISE_APPLICATION_ERROR(-20112, 'Reward is not within valid date range');
    END IF;

    IF v_qty_available < p_quantity THEN
      RAISE_APPLICATION_ERROR(-20113, 'Insufficient reward quantity. Available: ' || v_qty_available);
    END IF;

    IF v_member_miles < v_miles_required * p_quantity THEN
      RAISE_APPLICATION_ERROR(-20114, 'Insufficient miles. Required: ' ||
        (v_miles_required * p_quantity) || ', Available: ' || v_member_miles);
    END IF;

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20115, 'Member or reward not found');
  END validate_redemption;

  -- Validate partner is active
  PROCEDURE validate_partner_active(p_partner_code IN VARCHAR2) IS
    v_status VARCHAR2(20);
  BEGIN
    SELECT status INTO v_status
    FROM partners WHERE partner_code = UPPER(p_partner_code);

    IF v_status != 'ACTIVE' THEN
      RAISE_APPLICATION_ERROR(-20120, 'Partner is not active: ' || p_partner_code);
    END IF;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20121, 'Partner not found: ' || p_partner_code);
  END validate_partner_active;

END pkg_validation;
/
