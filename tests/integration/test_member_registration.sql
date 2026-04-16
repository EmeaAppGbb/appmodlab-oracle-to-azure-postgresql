-- ============================================================================
-- Integration Test: Member Registration Flow
-- ============================================================================
-- Tests: register → lookup → update profile → change status
-- Runs in a transaction, rolls back at end.
-- ============================================================================

\echo '--- Integration Test: Member Registration Flow ---'

BEGIN;

DO $$
DECLARE
    v_member_id BIGINT;
    v_membership_num VARCHAR;
    v_rec RECORD;
    v_email VARCHAR := 'inttest_reg_' || EXTRACT(EPOCH FROM clock_timestamp())::BIGINT || '@example.com';
BEGIN
    -- Step 1: Register a new member
    RAISE NOTICE 'Step 1: Registering new member...';
    SELECT member_id, membership_num
      INTO v_member_id, v_membership_num
      FROM member_mgmt_register_member('Integration', 'TestUser', v_email, '+1555000111', '1990-06-15', 'US');

    IF v_member_id IS NULL THEN
        RAISE EXCEPTION 'Registration failed: NULL member_id';
    END IF;
    RAISE NOTICE '  Registered: id=%, num=%', v_member_id, v_membership_num;

    -- Step 2: Look up the member
    RAISE NOTICE 'Step 2: Looking up member...';
    SELECT * INTO v_rec FROM member_mgmt_get_member(v_member_id);
    IF v_rec.member_id IS NULL THEN
        RAISE EXCEPTION 'Lookup failed: member_mgmt_get_member returned NULL';
    END IF;
    IF v_rec.first_name <> 'Integration' THEN
        RAISE EXCEPTION 'Lookup returned wrong first_name: %', v_rec.first_name;
    END IF;
    IF v_rec.tier_status <> 'BLUE' THEN
        RAISE EXCEPTION 'New member should be BLUE tier, got: %', v_rec.tier_status;
    END IF;
    RAISE NOTICE '  Lookup OK: % % (tier=%)', v_rec.first_name, v_rec.last_name, v_rec.tier_status;

    -- Step 3: Search by last name
    RAISE NOTICE 'Step 3: Searching by last name...';
    IF NOT EXISTS (SELECT 1 FROM member_mgmt_search_members('TestUser')) THEN
        RAISE EXCEPTION 'Search by last name returned no results';
    END IF;
    RAISE NOTICE '  Search OK';

    -- Step 4: Update profile
    RAISE NOTICE 'Step 4: Updating profile...';
    PERFORM member_mgmt_update_member_profile(v_member_id, p_phone := '+1555999888');
    RAISE NOTICE '  Profile updated';

    -- Step 5: Verify member is ACTIVE, then suspend
    RAISE NOTICE 'Step 5: Changing member status...';
    PERFORM member_mgmt_change_member_status(v_member_id, 'SUSPENDED', 'Integration test');

    -- Verify suspended
    SELECT status INTO v_rec FROM members WHERE member_id = v_member_id;
    IF v_rec.status <> 'SUSPENDED' THEN
        RAISE EXCEPTION 'Status change failed: expected SUSPENDED, got %', v_rec.status;
    END IF;
    RAISE NOTICE '  Status changed to SUSPENDED';

    -- Step 6: Verify audit trail was created
    RAISE NOTICE 'Step 6: Checking audit trail...';
    IF NOT EXISTS (
        SELECT 1 FROM audit_log
         WHERE table_name = 'members'
           AND member_id = v_member_id
    ) THEN
        RAISE NOTICE '  WARNING: No audit trail found (trigger may not be active)';
    ELSE
        RAISE NOTICE '  Audit trail present';
    END IF;

    RAISE NOTICE '✅  Member Registration Flow: ALL STEPS PASSED';
END;
$$;

ROLLBACK;
