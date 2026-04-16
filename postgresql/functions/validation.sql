-- ============================================================================
-- PostgreSQL conversion of Oracle package PKG_VALIDATION
-- Each package procedure/function becomes a standalone function
-- prefixed with validation_
-- ============================================================================

-- ============================================================================
-- Function: validation_validate_member_active
-- Raises exception if member does not exist or is not active.
-- Oracle: RAISE_APPLICATION_ERROR → RAISE EXCEPTION
-- ============================================================================
CREATE OR REPLACE FUNCTION validation_validate_member_active(
    p_member_id  BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR;
BEGIN
    SELECT status INTO v_status
      FROM members
     WHERE member_id = p_member_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Member % not found', p_member_id;
    END IF;

    IF v_status <> 'ACTIVE' THEN
        RAISE EXCEPTION 'Member % is not active (status: %)', p_member_id, v_status;
    END IF;
END;
$$;

-- ============================================================================
-- Function: validation_is_valid_email
-- Validates an email address using PostgreSQL regex.
-- Oracle: REGEXP_LIKE → PostgreSQL ~ operator
-- ============================================================================
CREATE OR REPLACE FUNCTION validation_is_valid_email(
    p_email  VARCHAR
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_email IS NULL THEN
        RETURN FALSE;
    END IF;

    RETURN p_email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$';
END;
$$;

-- ============================================================================
-- Function: validation_is_valid_airport_code
-- Validates a 3-letter uppercase IATA airport code.
-- ============================================================================
CREATE OR REPLACE FUNCTION validation_is_valid_airport_code(
    p_code  VARCHAR
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_code IS NULL THEN
        RETURN FALSE;
    END IF;

    RETURN p_code ~ '^[A-Z]{3}$';
END;
$$;

-- ============================================================================
-- Function: validation_is_valid_flight_date
-- Validates that a flight date is not in the future and within a reasonable
-- historical range.
-- ============================================================================
CREATE OR REPLACE FUNCTION validation_is_valid_flight_date(
    p_flight_date  DATE
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_flight_date IS NULL THEN
        RETURN FALSE;
    END IF;

    -- Date must not be in the future
    IF p_flight_date > CURRENT_DATE THEN
        RETURN FALSE;
    END IF;

    -- Date must be within the last 2 years
    IF p_flight_date < CURRENT_DATE - INTERVAL '2 years' THEN
        RETURN FALSE;
    END IF;

    RETURN TRUE;
END;
$$;

-- ============================================================================
-- Function: validation_is_valid_miles_amount
-- Validates that miles amount is positive and within allowed limits.
-- ============================================================================
CREATE OR REPLACE FUNCTION validation_is_valid_miles_amount(
    p_miles  NUMERIC
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_miles IS NULL THEN
        RETURN FALSE;
    END IF;

    IF p_miles <= 0 THEN
        RETURN FALSE;
    END IF;

    -- Upper limit sanity check
    IF p_miles > 10000000 THEN
        RETURN FALSE;
    END IF;

    RETURN TRUE;
END;
$$;

-- ============================================================================
-- Function: validation_is_valid_tier
-- Validates that the tier name is a recognized tier.
-- ============================================================================
CREATE OR REPLACE FUNCTION validation_is_valid_tier(
    p_tier  VARCHAR
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_count INT;
BEGIN
    IF p_tier IS NULL THEN
        RETURN FALSE;
    END IF;

    SELECT COUNT(*) INTO v_count
      FROM tier_rules
     WHERE tier_name = p_tier;

    RETURN v_count > 0;
END;
$$;

-- ============================================================================
-- Function: validation_is_valid_booking_class
-- Validates that the booking class code is recognized.
-- ============================================================================
CREATE OR REPLACE FUNCTION validation_is_valid_booking_class(
    p_class  VARCHAR
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_count INT;
BEGIN
    IF p_class IS NULL THEN
        RETURN FALSE;
    END IF;

    SELECT COUNT(*) INTO v_count
      FROM booking_classes
     WHERE class_code = p_class
       AND is_active = TRUE;

    RETURN v_count > 0;
END;
$$;

-- ============================================================================
-- Function: validation_validate_redemption
-- Validates that a member can redeem a specific reward.
-- Oracle: RAISE_APPLICATION_ERROR → RAISE EXCEPTION, NVL → COALESCE
-- ============================================================================
CREATE OR REPLACE FUNCTION validation_validate_redemption(
    p_member_id  BIGINT,
    p_reward_id  BIGINT,
    p_quantity   INT DEFAULT 1
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_member_status    VARCHAR;
    v_miles_balance    NUMERIC;
    v_reward_active    BOOLEAN;
    v_miles_required   NUMERIC;
    v_quantity_avail   INT;
    v_valid_from       DATE;
    v_valid_to         DATE;
BEGIN
    -- Validate member exists and is active
    PERFORM validation_validate_member_active(p_member_id);

    -- Get member miles balance
    SELECT COALESCE(miles_balance, 0) INTO v_miles_balance
      FROM members
     WHERE member_id = p_member_id;

    -- Get reward details
    SELECT is_active, miles_required, quantity_available, valid_from, valid_to
      INTO v_reward_active, v_miles_required, v_quantity_avail, v_valid_from, v_valid_to
      FROM rewards
     WHERE reward_id = p_reward_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reward % not found', p_reward_id;
    END IF;

    IF NOT COALESCE(v_reward_active, FALSE) THEN
        RAISE EXCEPTION 'Reward % is not active', p_reward_id;
    END IF;

    -- Check date validity
    IF v_valid_from IS NOT NULL AND CURRENT_DATE < v_valid_from THEN
        RAISE EXCEPTION 'Reward % is not yet available (valid from %)', p_reward_id, v_valid_from;
    END IF;

    IF v_valid_to IS NOT NULL AND CURRENT_DATE > v_valid_to THEN
        RAISE EXCEPTION 'Reward % has expired (valid to %)', p_reward_id, v_valid_to;
    END IF;

    -- Check quantity availability
    IF COALESCE(v_quantity_avail, 0) < p_quantity THEN
        RAISE EXCEPTION 'Insufficient reward quantity (available: %, requested: %)',
            COALESCE(v_quantity_avail, 0), p_quantity;
    END IF;

    -- Check miles balance
    IF v_miles_balance < (v_miles_required * p_quantity) THEN
        RAISE EXCEPTION 'Insufficient miles balance (balance: %, required: %)',
            v_miles_balance, v_miles_required * p_quantity;
    END IF;
END;
$$;

-- ============================================================================
-- Function: validation_validate_partner_active
-- Raises exception if partner does not exist or is not active.
-- Oracle: RAISE_APPLICATION_ERROR → RAISE EXCEPTION
-- ============================================================================
CREATE OR REPLACE FUNCTION validation_validate_partner_active(
    p_partner_code  VARCHAR
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR;
BEGIN
    SELECT status INTO v_status
      FROM partners
     WHERE partner_code = p_partner_code;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Partner % not found', p_partner_code;
    END IF;

    IF v_status <> 'ACTIVE' THEN
        RAISE EXCEPTION 'Partner % is not active (status: %)', p_partner_code, v_status;
    END IF;
END;
$$;
