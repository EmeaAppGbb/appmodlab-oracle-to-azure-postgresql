-- ========================================
-- Package: Member Management (PKG_MEMBER_MGMT)
-- ========================================
-- Handles member registration, profile updates, and account management

CREATE OR REPLACE PACKAGE pkg_member_mgmt AS

  -- Custom types
  TYPE t_member_rec IS RECORD (
    member_id         members.member_id%TYPE,
    membership_number members.membership_number%TYPE,
    first_name        members.first_name%TYPE,
    last_name         members.last_name%TYPE,
    email             members.email%TYPE,
    tier_status       members.tier_status%TYPE,
    available_miles   members.available_miles%TYPE
  );

  TYPE t_member_tab IS TABLE OF t_member_rec INDEX BY PLS_INTEGER;

  -- Constants
  c_default_tier     CONSTANT VARCHAR2(20) := 'BLUE';
  c_max_search_rows  CONSTANT NUMBER := 100;

  -- Member registration
  PROCEDURE register_member(
    p_first_name      IN  VARCHAR2,
    p_last_name       IN  VARCHAR2,
    p_email           IN  VARCHAR2,
    p_phone           IN  VARCHAR2 DEFAULT NULL,
    p_date_of_birth   IN  DATE DEFAULT NULL,
    p_country         IN  VARCHAR2 DEFAULT 'US',
    p_member_id       OUT NUMBER,
    p_membership_num  OUT VARCHAR2
  );

  -- Update member profile
  PROCEDURE update_member_profile(
    p_member_id       IN  NUMBER,
    p_first_name      IN  VARCHAR2 DEFAULT NULL,
    p_last_name       IN  VARCHAR2 DEFAULT NULL,
    p_email           IN  VARCHAR2 DEFAULT NULL,
    p_phone           IN  VARCHAR2 DEFAULT NULL,
    p_address_line1   IN  VARCHAR2 DEFAULT NULL,
    p_city            IN  VARCHAR2 DEFAULT NULL,
    p_state_province  IN  VARCHAR2 DEFAULT NULL,
    p_postal_code     IN  VARCHAR2 DEFAULT NULL,
    p_country         IN  VARCHAR2 DEFAULT NULL
  );

  -- Get member details
  FUNCTION get_member(p_member_id IN NUMBER) RETURN t_member_rec;

  -- Search members by name
  FUNCTION search_members(
    p_last_name       IN  VARCHAR2,
    p_first_name      IN  VARCHAR2 DEFAULT NULL
  ) RETURN t_member_tab;

  -- Generate membership number
  FUNCTION generate_membership_number RETURN VARCHAR2;

  -- Update member miles balance
  PROCEDURE update_miles_balance(
    p_member_id       IN  NUMBER,
    p_miles_delta     IN  NUMBER,
    p_transaction_type IN VARCHAR2
  );

  -- Suspend/reactivate member
  PROCEDURE change_member_status(
    p_member_id       IN  NUMBER,
    p_new_status      IN  VARCHAR2,
    p_reason          IN  VARCHAR2 DEFAULT NULL
  );

  -- Merge duplicate member accounts
  PROCEDURE merge_members(
    p_keep_member_id   IN  NUMBER,
    p_merge_member_id  IN  NUMBER,
    p_merged_by        IN  VARCHAR2 DEFAULT USER
  );

END pkg_member_mgmt;
/

CREATE OR REPLACE PACKAGE BODY pkg_member_mgmt AS

  -- Generate membership number: SR + year + sequence
  FUNCTION generate_membership_number RETURN VARCHAR2 IS
    v_num VARCHAR2(20);
  BEGIN
    v_num := 'SR' || TO_CHAR(SYSDATE, 'YY') || LPAD(seq_member_id.NEXTVAL, 8, '0');
    RETURN v_num;
  END generate_membership_number;

  -- Register new member
  PROCEDURE register_member(
    p_first_name      IN  VARCHAR2,
    p_last_name       IN  VARCHAR2,
    p_email           IN  VARCHAR2,
    p_phone           IN  VARCHAR2 DEFAULT NULL,
    p_date_of_birth   IN  DATE DEFAULT NULL,
    p_country         IN  VARCHAR2 DEFAULT 'US',
    p_member_id       OUT NUMBER,
    p_membership_num  OUT VARCHAR2
  ) IS
    v_email_count NUMBER;
  BEGIN
    -- Validate email uniqueness
    SELECT COUNT(*) INTO v_email_count
    FROM members WHERE email = LOWER(p_email);

    IF v_email_count > 0 THEN
      RAISE_APPLICATION_ERROR(-20001, 'Email address already registered: ' || p_email);
    END IF;

    p_member_id := seq_member_id.CURRVAL;
    p_membership_num := generate_membership_number();

    INSERT INTO members (
      member_id, membership_number, first_name, last_name, email,
      phone, date_of_birth, country, tier_status, enrollment_date,
      tier_expiry_date, status
    ) VALUES (
      p_member_id, p_membership_num, INITCAP(p_first_name), INITCAP(p_last_name),
      LOWER(p_email), p_phone, p_date_of_birth, UPPER(p_country),
      c_default_tier, SYSDATE, ADD_MONTHS(SYSDATE, 12), 'ACTIVE'
    );

    -- Log audit
    pkg_audit.log_change('MEMBERS', 'INSERT', p_member_id, p_member_id, NULL,
      '{"membership_number":"' || p_membership_num || '","email":"' || LOWER(p_email) || '"}');

    COMMIT;

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      RAISE;
  END register_member;

  -- Update member profile
  PROCEDURE update_member_profile(
    p_member_id       IN  NUMBER,
    p_first_name      IN  VARCHAR2 DEFAULT NULL,
    p_last_name       IN  VARCHAR2 DEFAULT NULL,
    p_email           IN  VARCHAR2 DEFAULT NULL,
    p_phone           IN  VARCHAR2 DEFAULT NULL,
    p_address_line1   IN  VARCHAR2 DEFAULT NULL,
    p_city            IN  VARCHAR2 DEFAULT NULL,
    p_state_province  IN  VARCHAR2 DEFAULT NULL,
    p_postal_code     IN  VARCHAR2 DEFAULT NULL,
    p_country         IN  VARCHAR2 DEFAULT NULL
  ) IS
  BEGIN
    UPDATE members SET
      first_name     = NVL(p_first_name, first_name),
      last_name      = NVL(p_last_name, last_name),
      email          = NVL(LOWER(p_email), email),
      phone          = NVL(p_phone, phone),
      address_line1  = NVL(p_address_line1, address_line1),
      city           = NVL(p_city, city),
      state_province = NVL(p_state_province, state_province),
      postal_code    = NVL(p_postal_code, postal_code),
      country        = NVL(UPPER(p_country), country),
      updated_date   = SYSDATE,
      updated_by     = USER
    WHERE member_id = p_member_id;

    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20002, 'Member not found: ' || p_member_id);
    END IF;

    COMMIT;
  END update_member_profile;

  -- Get member details
  FUNCTION get_member(p_member_id IN NUMBER) RETURN t_member_rec IS
    v_rec t_member_rec;
  BEGIN
    SELECT member_id, membership_number, first_name, last_name,
           email, tier_status, available_miles
    INTO v_rec
    FROM members
    WHERE member_id = p_member_id;

    RETURN v_rec;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20002, 'Member not found: ' || p_member_id);
  END get_member;

  -- Search members by name
  FUNCTION search_members(
    p_last_name       IN  VARCHAR2,
    p_first_name      IN  VARCHAR2 DEFAULT NULL
  ) RETURN t_member_tab IS
    v_tab t_member_tab;
    v_idx PLS_INTEGER := 0;
  BEGIN
    FOR rec IN (
      SELECT member_id, membership_number, first_name, last_name,
             email, tier_status, available_miles
      FROM members
      WHERE UPPER(last_name) LIKE UPPER(p_last_name) || '%'
        AND (p_first_name IS NULL OR UPPER(first_name) LIKE UPPER(p_first_name) || '%')
        AND status = 'ACTIVE'
      ORDER BY last_name, first_name
      FETCH FIRST c_max_search_rows ROWS ONLY
    ) LOOP
      v_idx := v_idx + 1;
      v_tab(v_idx) := rec;
    END LOOP;

    RETURN v_tab;
  END search_members;

  -- Update miles balance
  PROCEDURE update_miles_balance(
    p_member_id       IN  NUMBER,
    p_miles_delta     IN  NUMBER,
    p_transaction_type IN VARCHAR2
  ) IS
    v_current_miles NUMBER;
  BEGIN
    SELECT available_miles INTO v_current_miles
    FROM members WHERE member_id = p_member_id FOR UPDATE;

    IF p_transaction_type = 'REDEEM' AND v_current_miles + p_miles_delta < 0 THEN
      RAISE_APPLICATION_ERROR(-20010, 'Insufficient miles balance. Available: ' || v_current_miles);
    END IF;

    UPDATE members SET
      available_miles    = available_miles + p_miles_delta,
      total_miles        = CASE WHEN p_miles_delta > 0 THEN total_miles + p_miles_delta ELSE total_miles END,
      ytd_miles          = CASE WHEN p_miles_delta > 0 THEN ytd_miles + p_miles_delta ELSE ytd_miles END,
      lifetime_miles     = CASE WHEN p_miles_delta > 0 THEN lifetime_miles + p_miles_delta ELSE lifetime_miles END,
      last_activity_date = SYSDATE,
      updated_date       = SYSDATE
    WHERE member_id = p_member_id;

    COMMIT;
  END update_miles_balance;

  -- Change member status
  PROCEDURE change_member_status(
    p_member_id       IN  NUMBER,
    p_new_status      IN  VARCHAR2,
    p_reason          IN  VARCHAR2 DEFAULT NULL
  ) IS
    v_old_status VARCHAR2(20);
  BEGIN
    SELECT status INTO v_old_status
    FROM members WHERE member_id = p_member_id;

    UPDATE members SET
      status       = p_new_status,
      notes        = notes || CHR(10) || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') ||
                     ' Status changed from ' || v_old_status || ' to ' || p_new_status ||
                     CASE WHEN p_reason IS NOT NULL THEN ': ' || p_reason ELSE '' END,
      updated_date = SYSDATE,
      updated_by   = USER
    WHERE member_id = p_member_id;

    pkg_notification.send_notification(
      p_member_id, 'ALERT',
      'Account Status Update',
      'Your SkyReward account status has been changed to ' || p_new_status
    );

    COMMIT;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20002, 'Member not found: ' || p_member_id);
  END change_member_status;

  -- Merge duplicate member accounts
  PROCEDURE merge_members(
    p_keep_member_id   IN  NUMBER,
    p_merge_member_id  IN  NUMBER,
    p_merged_by        IN  VARCHAR2 DEFAULT USER
  ) IS
    v_merge_miles NUMBER;
  BEGIN
    -- Get miles from account being merged
    SELECT available_miles INTO v_merge_miles
    FROM members WHERE member_id = p_merge_member_id;

    -- Transfer flights
    UPDATE flights SET member_id = p_keep_member_id, updated_date = SYSDATE
    WHERE member_id = p_merge_member_id;

    -- Transfer redemptions
    UPDATE redemptions SET member_id = p_keep_member_id, updated_date = SYSDATE
    WHERE member_id = p_merge_member_id;

    -- Transfer partner transactions
    UPDATE partner_transactions SET member_id = p_keep_member_id, updated_date = SYSDATE
    WHERE member_id = p_merge_member_id;

    -- Add miles to kept account
    UPDATE members SET
      available_miles = available_miles + v_merge_miles,
      updated_date    = SYSDATE,
      updated_by      = p_merged_by
    WHERE member_id = p_keep_member_id;

    -- Close merged account
    UPDATE members SET
      status       = 'CLOSED',
      notes        = 'Merged into member ' || p_keep_member_id || ' by ' || p_merged_by ||
                     ' on ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD'),
      updated_date = SYSDATE,
      updated_by   = p_merged_by
    WHERE member_id = p_merge_member_id;

    pkg_audit.log_change('MEMBERS', 'UPDATE', p_keep_member_id, p_keep_member_id, NULL,
      '{"action":"merge","merged_from":' || p_merge_member_id || '}');

    COMMIT;
  END merge_members;

END pkg_member_mgmt;
/
