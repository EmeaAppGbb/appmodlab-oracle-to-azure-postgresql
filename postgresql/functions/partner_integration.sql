-- ============================================================================
-- PostgreSQL conversion of Oracle package PKG_PARTNER_INTEGRATION
-- Each package procedure/function becomes a standalone function
-- prefixed with partner_integration_
--
-- Conversion notes:
--   - %TYPE replaced with explicit PostgreSQL data types
--   - RAISE_APPLICATION_ERROR replaced with RAISE EXCEPTION
--   - NVL replaced with COALESCE
--   - SYSDATE replaced with CURRENT_TIMESTAMP
--   - seq_xxx.NEXTVAL replaced with nextval('seq_xxx')
--   - COMMIT/ROLLBACK removed (transaction control is external)
--   - SYS_REFCURSOR replaced with RETURNS TABLE + RETURN QUERY
--   - Cross-package calls use flattened naming convention
-- ============================================================================

-- ============================================================================
-- Function: partner_integration_get_conversion_rate
-- Returns the conversion rate for a given partner code.
-- Oracle: get_conversion_rate RETURN NUMBER
-- ============================================================================
CREATE OR REPLACE FUNCTION partner_integration_get_conversion_rate(
    p_partner_code VARCHAR
)
RETURNS NUMERIC
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_rate NUMERIC;
BEGIN
    SELECT conversion_rate INTO STRICT v_rate
      FROM partners
     WHERE partner_code = UPPER(p_partner_code)
       AND status = 'ACTIVE';

    RETURN v_rate;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE EXCEPTION 'Partner not found or inactive: %', p_partner_code;
END;
$$;

-- ============================================================================
-- Function: partner_integration_record_partner_earn
-- Records a partner earn transaction and credits miles to the member.
-- Oracle: procedure with OUT p_txn_id → PostgreSQL function returning BIGINT
-- ============================================================================
CREATE OR REPLACE FUNCTION partner_integration_record_partner_earn(
    p_member_id        BIGINT,
    p_partner_code     VARCHAR,
    p_transaction_date DATE,
    p_amount           NUMERIC,
    p_currency         VARCHAR DEFAULT 'USD',
    p_partner_ref      VARCHAR DEFAULT NULL,
    p_description      VARCHAR DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_partner_id   BIGINT;
    v_conv_rate    NUMERIC;
    v_miles_earned NUMERIC;
    v_txn_id       BIGINT;
BEGIN
    -- Validate member is active
    PERFORM validation_validate_member_active(p_member_id);

    SELECT partner_id, conversion_rate
      INTO STRICT v_partner_id, v_conv_rate
      FROM partners
     WHERE partner_code = UPPER(p_partner_code)
       AND status = 'ACTIVE';

    v_miles_earned := ROUND(p_amount * v_conv_rate);
    v_txn_id := nextval('seq_partner_txn_id');

    INSERT INTO partner_transactions (
        txn_id, member_id, partner_id, transaction_date, transaction_type,
        partner_ref, description, amount, currency, miles_earned,
        conversion_rate, status, processed_date
    ) VALUES (
        v_txn_id, p_member_id, v_partner_id, p_transaction_date, 'EARN',
        p_partner_ref, p_description, p_amount, p_currency, v_miles_earned,
        v_conv_rate, 'PROCESSED', CURRENT_TIMESTAMP
    );

    -- Credit miles to member
    PERFORM member_mgmt_update_miles_balance(p_member_id, v_miles_earned, 'EARN');

    RETURN v_txn_id;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE EXCEPTION 'Partner not found or inactive: %', p_partner_code;
END;
$$;

-- ============================================================================
-- Function: partner_integration_record_partner_redeem
-- Records a partner redeem transaction and debits miles from the member.
-- Oracle: procedure with OUT p_txn_id → PostgreSQL function returning BIGINT
-- ============================================================================
CREATE OR REPLACE FUNCTION partner_integration_record_partner_redeem(
    p_member_id    BIGINT,
    p_partner_code VARCHAR,
    p_miles_amount NUMERIC,
    p_partner_ref  VARCHAR DEFAULT NULL,
    p_description  VARCHAR DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_partner_id BIGINT;
    v_conv_rate  NUMERIC;
    v_txn_id     BIGINT;
BEGIN
    -- Validate member is active
    PERFORM validation_validate_member_active(p_member_id);

    SELECT partner_id, conversion_rate
      INTO STRICT v_partner_id, v_conv_rate
      FROM partners
     WHERE partner_code = UPPER(p_partner_code)
       AND status = 'ACTIVE';

    v_txn_id := nextval('seq_partner_txn_id');

    INSERT INTO partner_transactions (
        txn_id, member_id, partner_id, transaction_date, transaction_type,
        partner_ref, description, miles_redeemed, conversion_rate, status, processed_date
    ) VALUES (
        v_txn_id, p_member_id, v_partner_id, CURRENT_TIMESTAMP, 'REDEEM',
        p_partner_ref, p_description, p_miles_amount, v_conv_rate, 'PROCESSED', CURRENT_TIMESTAMP
    );

    -- Debit miles from member
    PERFORM member_mgmt_update_miles_balance(p_member_id, -p_miles_amount, 'REDEEM');

    RETURN v_txn_id;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE EXCEPTION 'Partner not found or inactive: %', p_partner_code;
END;
$$;

-- ============================================================================
-- Function: partner_integration_transfer_miles
-- Transfers miles between two partners for a given member.
-- Oracle: procedure with OUT p_txn_id → PostgreSQL function returning BIGINT
-- ============================================================================
CREATE OR REPLACE FUNCTION partner_integration_transfer_miles(
    p_member_id    BIGINT,
    p_from_partner VARCHAR,
    p_to_partner   VARCHAR,
    p_miles_amount NUMERIC
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_from_partner_id BIGINT;
    v_to_partner_id   BIGINT;
    v_from_rate       NUMERIC;
    v_to_rate         NUMERIC;
    v_converted_miles NUMERIC;
    v_txn_id          BIGINT;
BEGIN
    -- Validate member is active
    PERFORM validation_validate_member_active(p_member_id);

    SELECT partner_id, conversion_rate
      INTO STRICT v_from_partner_id, v_from_rate
      FROM partners
     WHERE partner_code = UPPER(p_from_partner)
       AND status = 'ACTIVE';

    SELECT partner_id, conversion_rate
      INTO STRICT v_to_partner_id, v_to_rate
      FROM partners
     WHERE partner_code = UPPER(p_to_partner)
       AND status = 'ACTIVE';

    v_converted_miles := ROUND(p_miles_amount * v_from_rate / v_to_rate);
    v_txn_id := nextval('seq_partner_txn_id');

    INSERT INTO partner_transactions (
        txn_id, member_id, partner_id, transaction_date, transaction_type,
        description, miles_redeemed, miles_earned, conversion_rate, status, processed_date
    ) VALUES (
        v_txn_id, p_member_id, v_to_partner_id, CURRENT_TIMESTAMP, 'TRANSFER',
        'Transfer from ' || p_from_partner || ' to ' || p_to_partner,
        p_miles_amount, v_converted_miles, v_from_rate / v_to_rate, 'PROCESSED', CURRENT_TIMESTAMP
    );

    RETURN v_txn_id;
END;
$$;

-- ============================================================================
-- Function: partner_integration_process_settlement
-- Calculates settlement totals for a partner over a date range.
-- Oracle: procedure with OUT params → PostgreSQL RETURNS TABLE
-- ============================================================================
CREATE OR REPLACE FUNCTION partner_integration_process_settlement(
    p_partner_code VARCHAR,
    p_start_date   DATE,
    p_end_date     DATE
)
RETURNS TABLE(total_earned NUMERIC, total_redeemed NUMERIC, net_settlement NUMERIC)
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_partner_id    BIGINT;
    v_total_earned  NUMERIC;
    v_total_redeemed NUMERIC;
BEGIN
    SELECT p.partner_id INTO STRICT v_partner_id
      FROM partners p
     WHERE p.partner_code = UPPER(p_partner_code);

    SELECT COALESCE(SUM(pt.miles_earned), 0),
           COALESCE(SUM(pt.miles_redeemed), 0)
      INTO v_total_earned, v_total_redeemed
      FROM partner_transactions pt
     WHERE pt.partner_id = v_partner_id
       AND pt.status = 'PROCESSED'
       AND pt.transaction_date BETWEEN p_start_date AND p_end_date;

    total_earned   := v_total_earned;
    total_redeemed := v_total_redeemed;
    net_settlement := v_total_earned - v_total_redeemed;
    RETURN NEXT;
END;
$$;

-- ============================================================================
-- Function: partner_integration_get_partner_summary
-- Returns transaction summary grouped by type for a partner.
-- Oracle: SYS_REFCURSOR → RETURNS TABLE with RETURN QUERY
-- ============================================================================
CREATE OR REPLACE FUNCTION partner_integration_get_partner_summary(
    p_partner_code VARCHAR,
    p_start_date   DATE DEFAULT NULL,
    p_end_date     DATE DEFAULT NULL
)
RETURNS TABLE(
    transaction_type VARCHAR,
    txn_count        BIGINT,
    total_earned     NUMERIC,
    total_redeemed   NUMERIC,
    total_amount     NUMERIC
)
LANGUAGE plpgsql STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT pt.transaction_type,
           COUNT(*)::BIGINT            AS txn_count,
           SUM(pt.miles_earned)        AS total_earned,
           SUM(pt.miles_redeemed)      AS total_redeemed,
           SUM(pt.amount)              AS total_amount
      FROM partner_transactions pt
      JOIN partners p ON pt.partner_id = p.partner_id
     WHERE p.partner_code = UPPER(p_partner_code)
       AND pt.transaction_date >= COALESCE(p_start_date, DATE '2000-01-01')
       AND pt.transaction_date <= COALESCE(p_end_date, CURRENT_TIMESTAMP)
       AND pt.status = 'PROCESSED'
     GROUP BY pt.transaction_type;
END;
$$;
