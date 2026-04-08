-- ========================================
-- Package: Partner Integration (PKG_PARTNER_INTEGRATION)
-- ========================================
-- Manages partner transactions, miles conversion, and settlement

CREATE OR REPLACE PACKAGE pkg_partner_integration AS

  -- Record partner earn transaction
  PROCEDURE record_partner_earn(
    p_member_id       IN  NUMBER,
    p_partner_code    IN  VARCHAR2,
    p_transaction_date IN DATE,
    p_amount          IN  NUMBER,
    p_currency        IN  VARCHAR2 DEFAULT 'USD',
    p_partner_ref     IN  VARCHAR2 DEFAULT NULL,
    p_description     IN  VARCHAR2 DEFAULT NULL,
    p_txn_id          OUT NUMBER
  );

  -- Record partner redeem transaction
  PROCEDURE record_partner_redeem(
    p_member_id       IN  NUMBER,
    p_partner_code    IN  VARCHAR2,
    p_miles_amount    IN  NUMBER,
    p_partner_ref     IN  VARCHAR2 DEFAULT NULL,
    p_description     IN  VARCHAR2 DEFAULT NULL,
    p_txn_id          OUT NUMBER
  );

  -- Transfer miles between partners
  PROCEDURE transfer_miles(
    p_member_id       IN  NUMBER,
    p_from_partner    IN  VARCHAR2,
    p_to_partner      IN  VARCHAR2,
    p_miles_amount    IN  NUMBER,
    p_txn_id          OUT NUMBER
  );

  -- Process partner settlement
  PROCEDURE process_settlement(
    p_partner_code    IN  VARCHAR2,
    p_start_date      IN  DATE,
    p_end_date        IN  DATE,
    p_total_earned    OUT NUMBER,
    p_total_redeemed  OUT NUMBER,
    p_net_settlement  OUT NUMBER
  );

  -- Get partner conversion rate
  FUNCTION get_conversion_rate(p_partner_code IN VARCHAR2) RETURN NUMBER;

  -- Get partner transaction summary
  FUNCTION get_partner_summary(
    p_partner_code    IN  VARCHAR2,
    p_start_date      IN  DATE DEFAULT NULL,
    p_end_date        IN  DATE DEFAULT NULL
  ) RETURN SYS_REFCURSOR;

END pkg_partner_integration;
/

CREATE OR REPLACE PACKAGE BODY pkg_partner_integration AS

  -- Get conversion rate
  FUNCTION get_conversion_rate(p_partner_code IN VARCHAR2) RETURN NUMBER IS
    v_rate NUMBER;
  BEGIN
    SELECT conversion_rate INTO v_rate
    FROM partners
    WHERE partner_code = UPPER(p_partner_code) AND status = 'ACTIVE';

    RETURN v_rate;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20050, 'Partner not found or inactive: ' || p_partner_code);
  END get_conversion_rate;

  -- Record partner earn
  PROCEDURE record_partner_earn(
    p_member_id       IN  NUMBER,
    p_partner_code    IN  VARCHAR2,
    p_transaction_date IN DATE,
    p_amount          IN  NUMBER,
    p_currency        IN  VARCHAR2 DEFAULT 'USD',
    p_partner_ref     IN  VARCHAR2 DEFAULT NULL,
    p_description     IN  VARCHAR2 DEFAULT NULL,
    p_txn_id          OUT NUMBER
  ) IS
    v_partner_id    NUMBER;
    v_conv_rate     NUMBER;
    v_miles_earned  NUMBER;
  BEGIN
    pkg_validation.validate_member_active(p_member_id);

    SELECT partner_id, conversion_rate INTO v_partner_id, v_conv_rate
    FROM partners
    WHERE partner_code = UPPER(p_partner_code) AND status = 'ACTIVE';

    v_miles_earned := ROUND(p_amount * v_conv_rate);
    p_txn_id := seq_partner_txn_id.NEXTVAL;

    INSERT INTO partner_transactions (
      txn_id, member_id, partner_id, transaction_date, transaction_type,
      partner_ref, description, amount, currency, miles_earned,
      conversion_rate, status, processed_date
    ) VALUES (
      p_txn_id, p_member_id, v_partner_id, p_transaction_date, 'EARN',
      p_partner_ref, p_description, p_amount, p_currency, v_miles_earned,
      v_conv_rate, 'PROCESSED', SYSDATE
    );

    -- Credit miles to member
    pkg_member_mgmt.update_miles_balance(p_member_id, v_miles_earned, 'EARN');

    COMMIT;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20050, 'Partner not found or inactive: ' || p_partner_code);
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE;
  END record_partner_earn;

  -- Record partner redeem
  PROCEDURE record_partner_redeem(
    p_member_id       IN  NUMBER,
    p_partner_code    IN  VARCHAR2,
    p_miles_amount    IN  NUMBER,
    p_partner_ref     IN  VARCHAR2 DEFAULT NULL,
    p_description     IN  VARCHAR2 DEFAULT NULL,
    p_txn_id          OUT NUMBER
  ) IS
    v_partner_id    NUMBER;
    v_conv_rate     NUMBER;
  BEGIN
    pkg_validation.validate_member_active(p_member_id);

    SELECT partner_id, conversion_rate INTO v_partner_id, v_conv_rate
    FROM partners
    WHERE partner_code = UPPER(p_partner_code) AND status = 'ACTIVE';

    p_txn_id := seq_partner_txn_id.NEXTVAL;

    INSERT INTO partner_transactions (
      txn_id, member_id, partner_id, transaction_date, transaction_type,
      partner_ref, description, miles_redeemed, conversion_rate, status, processed_date
    ) VALUES (
      p_txn_id, p_member_id, v_partner_id, SYSDATE, 'REDEEM',
      p_partner_ref, p_description, p_miles_amount, v_conv_rate, 'PROCESSED', SYSDATE
    );

    pkg_member_mgmt.update_miles_balance(p_member_id, -p_miles_amount, 'REDEEM');

    COMMIT;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20050, 'Partner not found or inactive: ' || p_partner_code);
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE;
  END record_partner_redeem;

  -- Transfer miles between partners
  PROCEDURE transfer_miles(
    p_member_id       IN  NUMBER,
    p_from_partner    IN  VARCHAR2,
    p_to_partner      IN  VARCHAR2,
    p_miles_amount    IN  NUMBER,
    p_txn_id          OUT NUMBER
  ) IS
    v_from_partner_id NUMBER;
    v_to_partner_id   NUMBER;
    v_from_rate       NUMBER;
    v_to_rate         NUMBER;
    v_converted_miles NUMBER;
  BEGIN
    pkg_validation.validate_member_active(p_member_id);

    SELECT partner_id, conversion_rate INTO v_from_partner_id, v_from_rate
    FROM partners WHERE partner_code = UPPER(p_from_partner) AND status = 'ACTIVE';

    SELECT partner_id, conversion_rate INTO v_to_partner_id, v_to_rate
    FROM partners WHERE partner_code = UPPER(p_to_partner) AND status = 'ACTIVE';

    v_converted_miles := ROUND(p_miles_amount * v_from_rate / v_to_rate);
    p_txn_id := seq_partner_txn_id.NEXTVAL;

    INSERT INTO partner_transactions (
      txn_id, member_id, partner_id, transaction_date, transaction_type,
      description, miles_redeemed, miles_earned, conversion_rate, status, processed_date
    ) VALUES (
      p_txn_id, p_member_id, v_to_partner_id, SYSDATE, 'TRANSFER',
      'Transfer from ' || p_from_partner || ' to ' || p_to_partner,
      p_miles_amount, v_converted_miles, v_from_rate / v_to_rate, 'PROCESSED', SYSDATE
    );

    COMMIT;
  END transfer_miles;

  -- Process settlement
  PROCEDURE process_settlement(
    p_partner_code    IN  VARCHAR2,
    p_start_date      IN  DATE,
    p_end_date        IN  DATE,
    p_total_earned    OUT NUMBER,
    p_total_redeemed  OUT NUMBER,
    p_net_settlement  OUT NUMBER
  ) IS
    v_partner_id NUMBER;
  BEGIN
    SELECT partner_id INTO v_partner_id
    FROM partners WHERE partner_code = UPPER(p_partner_code);

    SELECT NVL(SUM(miles_earned), 0), NVL(SUM(miles_redeemed), 0)
    INTO p_total_earned, p_total_redeemed
    FROM partner_transactions
    WHERE partner_id = v_partner_id
      AND status = 'PROCESSED'
      AND transaction_date BETWEEN p_start_date AND p_end_date;

    p_net_settlement := p_total_earned - p_total_redeemed;
  END process_settlement;

  -- Get partner summary
  FUNCTION get_partner_summary(
    p_partner_code    IN  VARCHAR2,
    p_start_date      IN  DATE DEFAULT NULL,
    p_end_date        IN  DATE DEFAULT NULL
  ) RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
  BEGIN
    OPEN v_cursor FOR
      SELECT transaction_type,
             COUNT(*) AS txn_count,
             SUM(miles_earned) AS total_earned,
             SUM(miles_redeemed) AS total_redeemed,
             SUM(amount) AS total_amount
      FROM partner_transactions pt
      JOIN partners p ON pt.partner_id = p.partner_id
      WHERE p.partner_code = UPPER(p_partner_code)
        AND pt.transaction_date >= NVL(p_start_date, DATE '2000-01-01')
        AND pt.transaction_date <= NVL(p_end_date, SYSDATE)
        AND pt.status = 'PROCESSED'
      GROUP BY transaction_type;

    RETURN v_cursor;
  END get_partner_summary;

END pkg_partner_integration;
/
