-- ============================================================================
-- PostgreSQL conversion of Oracle package PKG_MEMBER_MGMT
-- Each package procedure/function becomes a standalone function/procedure
-- prefixed with member_mgmt_
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Constants (replicate Oracle package constants as session/local values)
-- ----------------------------------------------------------------------------
-- c_default_tier   = 'BLUE'
-- c_max_search_rows = 100

-- ============================================================================
-- Function: member_mgmt_generate_membership_number
-- Generates a new membership number in the format SR<YY><8-digit seq>
-- Oracle: generate_membership_number RETURN VARCHAR2
-- ============================================================================
CREATE OR REPLACE FUNCTION member_mgmt_generate_membership_number()
RETURNS VARCHAR(20)
LANGUAGE plpgsql
AS $$
DECLARE
    v_num VARCHAR(20);
BEGIN
    v_num := 'SR' || TO_CHAR(CURRENT_DATE, 'YY') || LPAD(nextval('seq_member_id')::TEXT, 8, '0');
    RETURN v_num;
END;
$$;

-- ============================================================================
-- Function: member_mgmt_register_member
-- Registers a new member and returns the new member_id and membership_number.
-- Oracle: procedure with OUT params → PostgreSQL function returning a record.
-- ============================================================================
CREATE OR REPLACE FUNCTION member_mgmt_register_member(
    p_first_name    VARCHAR,
    p_last_name     VARCHAR,
    p_email         VARCHAR,
    p_phone         VARCHAR DEFAULT NULL,
    p_date_of_birth DATE    DEFAULT NULL,
    p_country       VARCHAR DEFAULT 'US'
)
RETURNS TABLE(member_id BIGINT, membership_num VARCHAR)
LANGUAGE plpgsql
AS $$
DECLARE
    v_email_count   INTEGER;
    v_member_id     BIGINT;
    v_membership_num VARCHAR(20);
BEGIN
    SELECT COUNT(*) INTO v_email_count
      FROM members m
     WHERE m.email = LOWER(p_email);

    IF v_email_count > 0 THEN
        RAISE EXCEPTION 'Email address already registered: %', p_email;
    END IF;

    -- Generate membership number (also advances the sequence)
    v_membership_num := member_mgmt_generate_membership_number();
    -- Use currval since generate_membership_number already called nextval
    v_member_id := currval('seq_member_id');

    INSERT INTO members (
        member_id, membership_number, first_name, last_name, email,
        phone, date_of_birth, country, tier_status,
        enrollment_date, tier_expiry_date, status
    ) VALUES (
        v_member_id, v_membership_num,
        INITCAP(p_first_name), INITCAP(p_last_name), LOWER(p_email),
        p_phone, p_date_of_birth, UPPER(p_country),
        'BLUE',
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP + INTERVAL '12 months',
        'ACTIVE'
    );

    PERFORM audit_log_change(
        'MEMBERS', 'INSERT', v_member_id, v_member_id, NULL,
        '{"membership_number":"' || v_membership_num || '","email":"' || LOWER(p_email) || '"}'
    );

    member_id      := v_member_id;
    membership_num := v_membership_num;
    RETURN NEXT;
END;
$$;

-- ============================================================================
-- Procedure: member_mgmt_update_member_profile
-- Updates member profile fields; only non-NULL parameters are applied.
-- Oracle: procedure → PostgreSQL procedure (RETURNS void).
-- ============================================================================
CREATE OR REPLACE FUNCTION member_mgmt_update_member_profile(
    p_member_id      BIGINT,
    p_first_name     VARCHAR DEFAULT NULL,
    p_last_name      VARCHAR DEFAULT NULL,
    p_email          VARCHAR DEFAULT NULL,
    p_phone          VARCHAR DEFAULT NULL,
    p_address_line1  VARCHAR DEFAULT NULL,
    p_city           VARCHAR DEFAULT NULL,
    p_state_province VARCHAR DEFAULT NULL,
    p_postal_code    VARCHAR DEFAULT NULL,
    p_country        VARCHAR DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE members
       SET first_name     = COALESCE(p_first_name, first_name),
           last_name      = COALESCE(p_last_name, last_name),
           email          = COALESCE(LOWER(p_email), email),
           phone          = COALESCE(p_phone, phone),
           address_line1  = COALESCE(p_address_line1, address_line1),
           city           = COALESCE(p_city, city),
           state_province = COALESCE(p_state_province, state_province),
           postal_code    = COALESCE(p_postal_code, postal_code),
           country        = COALESCE(UPPER(p_country), country),
           updated_date   = CURRENT_TIMESTAMP,
           updated_by     = current_user
     WHERE member_id = p_member_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Member not found: %', p_member_id;
    END IF;
END;
$$;

-- ============================================================================
-- Function: member_mgmt_get_member
-- Returns a single member record by member_id.
-- Oracle: function returning t_member_rec → PostgreSQL RETURNS TABLE.
-- ============================================================================
CREATE OR REPLACE FUNCTION member_mgmt_get_member(
    p_member_id BIGINT
)
RETURNS TABLE(
    member_id         BIGINT,
    membership_number VARCHAR,
    first_name        VARCHAR,
    last_name         VARCHAR,
    email             VARCHAR,
    tier_status       VARCHAR,
    available_miles   NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT m.member_id, m.membership_number, m.first_name, m.last_name,
           m.email, m.tier_status, m.available_miles
      FROM members m
     WHERE m.member_id = p_member_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Member not found: %', p_member_id;
    END IF;
END;
$$;

-- ============================================================================
-- Function: member_mgmt_search_members
-- Searches active members by last name (and optionally first name).
-- Oracle: function returning t_member_tab (INDEX BY table) → RETURNS TABLE.
-- ============================================================================
CREATE OR REPLACE FUNCTION member_mgmt_search_members(
    p_last_name  VARCHAR,
    p_first_name VARCHAR DEFAULT NULL
)
RETURNS TABLE(
    member_id         BIGINT,
    membership_number VARCHAR,
    first_name        VARCHAR,
    last_name         VARCHAR,
    email             VARCHAR,
    tier_status       VARCHAR,
    available_miles   NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT m.member_id, m.membership_number, m.first_name, m.last_name,
           m.email, m.tier_status, m.available_miles
      FROM members m
     WHERE UPPER(m.last_name) LIKE UPPER(p_last_name) || '%'
       AND (p_first_name IS NULL OR UPPER(m.first_name) LIKE UPPER(p_first_name) || '%')
       AND m.status = 'ACTIVE'
     ORDER BY m.last_name, m.first_name
     LIMIT 100;
END;
$$;

-- ============================================================================
-- Procedure: member_mgmt_update_miles_balance
-- Adjusts a member's miles balance. Prevents redemption below zero.
-- Oracle: procedure → PostgreSQL RETURNS void.
-- ============================================================================
CREATE OR REPLACE FUNCTION member_mgmt_update_miles_balance(
    p_member_id        BIGINT,
    p_miles_delta      NUMERIC,
    p_transaction_type VARCHAR
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_miles NUMERIC;
BEGIN
    SELECT m.available_miles INTO v_current_miles
      FROM members m
     WHERE m.member_id = p_member_id
       FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Member not found: %', p_member_id;
    END IF;

    IF p_transaction_type = 'REDEEM' AND v_current_miles + p_miles_delta < 0 THEN
        RAISE EXCEPTION 'Insufficient miles balance. Available: %', v_current_miles;
    END IF;

    UPDATE members
       SET available_miles   = available_miles + p_miles_delta,
           total_miles       = CASE WHEN p_miles_delta > 0 THEN total_miles + p_miles_delta ELSE total_miles END,
           ytd_miles         = CASE WHEN p_miles_delta > 0 THEN ytd_miles + p_miles_delta ELSE ytd_miles END,
           lifetime_miles    = CASE WHEN p_miles_delta > 0 THEN lifetime_miles + p_miles_delta ELSE lifetime_miles END,
           last_activity_date = CURRENT_TIMESTAMP,
           updated_date       = CURRENT_TIMESTAMP
     WHERE member_id = p_member_id;
END;
$$;

-- ============================================================================
-- Procedure: member_mgmt_change_member_status
-- Changes a member's status and appends a timestamped note.
-- Oracle: procedure → PostgreSQL RETURNS void.
-- ============================================================================
CREATE OR REPLACE FUNCTION member_mgmt_change_member_status(
    p_member_id   BIGINT,
    p_new_status  VARCHAR,
    p_reason      VARCHAR DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_old_status VARCHAR(20);
BEGIN
    SELECT m.status INTO v_old_status
      FROM members m
     WHERE m.member_id = p_member_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Member not found: %', p_member_id;
    END IF;

    UPDATE members
       SET status       = p_new_status,
           notes        = notes || CHR(10) || TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD HH24:MI:SS')
                          || ' Status changed from ' || v_old_status || ' to ' || p_new_status
                          || CASE WHEN p_reason IS NOT NULL THEN ': ' || p_reason ELSE '' END,
           updated_date = CURRENT_TIMESTAMP,
           updated_by   = current_user
     WHERE member_id = p_member_id;

    PERFORM notification_send_notification(
        p_member_id,
        'ALERT',
        'Account Status Update',
        'Your SkyReward account status has been changed to ' || p_new_status
    );
END;
$$;

-- ============================================================================
-- Procedure: member_mgmt_merge_members
-- Merges one member into another: moves transactions, combines miles, closes
-- the source member.
-- Oracle: procedure → PostgreSQL RETURNS void.
-- ============================================================================
CREATE OR REPLACE FUNCTION member_mgmt_merge_members(
    p_keep_member_id  BIGINT,
    p_merge_member_id BIGINT,
    p_merged_by       VARCHAR DEFAULT current_user
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_merge_miles NUMERIC;
BEGIN
    SELECT m.available_miles INTO v_merge_miles
      FROM members m
     WHERE m.member_id = p_merge_member_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Source member not found: %', p_merge_member_id;
    END IF;

    -- Reassign related records to the kept member
    UPDATE flights
       SET member_id    = p_keep_member_id,
           updated_date = CURRENT_TIMESTAMP
     WHERE member_id = p_merge_member_id;

    UPDATE redemptions
       SET member_id    = p_keep_member_id,
           updated_date = CURRENT_TIMESTAMP
     WHERE member_id = p_merge_member_id;

    UPDATE partner_transactions
       SET member_id    = p_keep_member_id,
           updated_date = CURRENT_TIMESTAMP
     WHERE member_id = p_merge_member_id;

    -- Add merged miles to the kept member
    UPDATE members
       SET available_miles = available_miles + v_merge_miles,
           updated_date    = CURRENT_TIMESTAMP,
           updated_by      = p_merged_by
     WHERE member_id = p_keep_member_id;

    -- Close the merged member
    UPDATE members
       SET status       = 'CLOSED',
           notes        = 'Merged into member ' || p_keep_member_id || ' by ' || p_merged_by
                          || ' on ' || TO_CHAR(CURRENT_TIMESTAMP, 'YYYY-MM-DD'),
           updated_date = CURRENT_TIMESTAMP,
           updated_by   = p_merged_by
     WHERE member_id = p_merge_member_id;

    PERFORM audit_log_change(
        'MEMBERS', 'UPDATE', p_keep_member_id, p_keep_member_id, NULL,
        '{"action":"merge","merged_from":' || p_merge_member_id || '}'
    );
END;
$$;
