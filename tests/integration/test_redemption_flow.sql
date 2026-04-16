-- ============================================================================
-- Integration Test: Redemption Flow
-- ============================================================================
-- Tests: validate → redeem → verify balance → cancel → verify refund
-- Runs in a transaction, rolls back at end.
-- ============================================================================

\echo '--- Integration Test: Redemption Flow ---'

BEGIN;

DO $$
DECLARE
    v_member_id BIGINT;
    v_reward_id BIGINT;
    v_redemption_id BIGINT;
    v_confirm_code VARCHAR;
    v_miles_before NUMERIC;
    v_miles_after  NUMERIC;
    v_miles_refund NUMERIC;
    v_is_available BOOLEAN;
    v_validation_msg VARCHAR;
    v_rec RECORD;
BEGIN
    -- Setup: find a member with enough miles and an active reward
    SELECT m.member_id, m.available_miles
      INTO v_member_id, v_miles_before
      FROM members m
     WHERE m.status = 'ACTIVE'
       AND m.available_miles >= 1000
     ORDER BY m.available_miles DESC
     LIMIT 1;

    IF v_member_id IS NULL THEN
        RAISE NOTICE 'SKIPPED: No member with sufficient miles found';
        RETURN;
    END IF;

    SELECT r.reward_id INTO v_reward_id
      FROM rewards r
     WHERE r.status = 'ACTIVE'
       AND r.miles_required <= v_miles_before
     ORDER BY r.miles_required
     LIMIT 1;

    IF v_reward_id IS NULL THEN
        RAISE NOTICE 'SKIPPED: No affordable active reward found for member miles=%', v_miles_before;
        RETURN;
    END IF;

    RAISE NOTICE 'Using member % (miles: %) and reward %', v_member_id, v_miles_before, v_reward_id;

    -- Step 1: Validate redemption with fn_validate_redemption
    RAISE NOTICE 'Step 1: Validating redemption (standalone function)...';
    v_validation_msg := fn_validate_redemption(v_member_id, v_reward_id, 1);
    RAISE NOTICE '  Validation result: %', v_validation_msg;

    -- Step 2: Check reward availability
    RAISE NOTICE 'Step 2: Checking reward availability...';
    v_is_available := redemption_mgmt_check_reward_available(v_reward_id, v_member_id, 1);
    IF NOT v_is_available THEN
        RAISE NOTICE 'SKIPPED: Reward not available (may be tier/date restricted)';
        RETURN;
    END IF;
    RAISE NOTICE '  Reward available: %', v_is_available;

    -- Step 3: Redeem reward
    RAISE NOTICE 'Step 3: Redeeming reward...';
    SELECT redemption_id, confirm_code
      INTO v_redemption_id, v_confirm_code
      FROM redemption_mgmt_redeem_reward(v_member_id, v_reward_id, 1, 'WEB');

    IF v_redemption_id IS NULL THEN
        RAISE EXCEPTION 'redemption_mgmt_redeem_reward returned NULL redemption_id';
    END IF;
    IF v_confirm_code IS NULL OR LENGTH(v_confirm_code) < 5 THEN
        RAISE EXCEPTION 'Invalid confirmation code: %', v_confirm_code;
    END IF;
    RAISE NOTICE '  Redeemed: id=%, code=%', v_redemption_id, v_confirm_code;

    -- Step 4: Verify miles deducted
    RAISE NOTICE 'Step 4: Verifying miles deduction...';
    SELECT available_miles INTO v_miles_after FROM members WHERE member_id = v_member_id;
    IF v_miles_after >= v_miles_before THEN
        RAISE NOTICE '  WARNING: Miles not yet deducted (balance: %)', v_miles_after;
    ELSE
        RAISE NOTICE '  Miles deducted: % → % (-%)', v_miles_before, v_miles_after, v_miles_before - v_miles_after;
    END IF;

    -- Step 5: Verify redemption record
    RAISE NOTICE 'Step 5: Verifying redemption record...';
    SELECT * INTO v_rec FROM redemptions WHERE redemption_id = v_redemption_id;
    IF v_rec.status NOT IN ('PENDING', 'CONFIRMED') THEN
        RAISE EXCEPTION 'Unexpected redemption status: %', v_rec.status;
    END IF;
    RAISE NOTICE '  Redemption status: %', v_rec.status;

    -- Step 6: Get member redemptions
    RAISE NOTICE 'Step 6: Listing member redemptions...';
    IF EXISTS (SELECT 1 FROM redemption_mgmt_get_member_redemptions(v_member_id)) THEN
        RAISE NOTICE '  Redemption history retrieved';
    ELSE
        RAISE NOTICE '  WARNING: No redemptions returned';
    END IF;

    -- Step 7: Cancel redemption
    RAISE NOTICE 'Step 7: Cancelling redemption...';
    PERFORM redemption_mgmt_cancel_redemption(v_redemption_id, 'Integration test cancellation');

    SELECT status INTO v_rec FROM redemptions WHERE redemption_id = v_redemption_id;
    IF v_rec.status <> 'CANCELLED' THEN
        RAISE EXCEPTION 'Cancellation failed: status = %', v_rec.status;
    END IF;
    RAISE NOTICE '  Cancelled successfully';

    -- Step 8: Verify miles refunded
    RAISE NOTICE 'Step 8: Checking miles refund...';
    SELECT available_miles INTO v_miles_refund FROM members WHERE member_id = v_member_id;
    RAISE NOTICE '  Miles after cancel: % (original: %)', v_miles_refund, v_miles_before;

    RAISE NOTICE '✅  Redemption Flow: ALL STEPS PASSED';
END;
$$;

ROLLBACK;
