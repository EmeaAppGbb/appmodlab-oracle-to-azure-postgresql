-- ============================================================================
-- Integration Test: Partner Transaction
-- ============================================================================
-- Tests: partner earn → partner redeem → settlement → summary
-- Runs in a transaction, rolls back at end.
-- ============================================================================

\echo '--- Integration Test: Partner Transaction ---'

BEGIN;

DO $$
DECLARE
    v_member_id BIGINT;
    v_partner_code VARCHAR;
    v_txn_id BIGINT;
    v_conv_rate NUMERIC;
    v_miles_before NUMERIC;
    v_miles_after  NUMERIC;
    v_rec RECORD;
BEGIN
    -- Setup: find active member and partner
    SELECT member_id, available_miles
      INTO v_member_id, v_miles_before
      FROM members
     WHERE status = 'ACTIVE'
       AND available_miles >= 500
     ORDER BY member_id
     LIMIT 1;

    IF v_member_id IS NULL THEN
        RAISE NOTICE 'SKIPPED: No active member with sufficient miles';
        RETURN;
    END IF;

    SELECT partner_code INTO v_partner_code
      FROM partners
     WHERE status = 'ACTIVE'
     LIMIT 1;

    IF v_partner_code IS NULL THEN
        RAISE NOTICE 'SKIPPED: No active partner found';
        RETURN;
    END IF;

    RAISE NOTICE 'Using member % (miles: %) and partner %', v_member_id, v_miles_before, v_partner_code;

    -- Step 1: Get conversion rate
    RAISE NOTICE 'Step 1: Getting conversion rate...';
    v_conv_rate := partner_integration_get_conversion_rate(v_partner_code);
    IF v_conv_rate IS NULL OR v_conv_rate <= 0 THEN
        RAISE EXCEPTION 'Invalid conversion rate for %: %', v_partner_code, v_conv_rate;
    END IF;
    RAISE NOTICE '  Conversion rate for %: %', v_partner_code, v_conv_rate;

    -- Step 2: Record partner earn
    RAISE NOTICE 'Step 2: Recording partner earn...';
    v_txn_id := partner_integration_record_partner_earn(
        v_member_id, v_partner_code, CURRENT_DATE,
        150.00, 'USD', 'INTTEST-EARN-001', 'Integration test hotel stay'
    );

    IF v_txn_id IS NULL THEN
        RAISE EXCEPTION 'partner_integration_record_partner_earn returned NULL';
    END IF;
    RAISE NOTICE '  Earn transaction: id=%', v_txn_id;

    -- Verify miles earned
    SELECT miles_earned INTO v_rec FROM partner_transactions WHERE txn_id = v_txn_id;
    IF v_rec.miles_earned IS NULL OR v_rec.miles_earned <= 0 THEN
        RAISE EXCEPTION 'No miles earned on partner transaction: %', v_rec.miles_earned;
    END IF;
    RAISE NOTICE '  Miles earned: %', v_rec.miles_earned;

    -- Step 3: Record partner redeem
    RAISE NOTICE 'Step 3: Recording partner redeem...';
    v_txn_id := partner_integration_record_partner_redeem(
        v_member_id, v_partner_code, 200,
        'INTTEST-REDM-001', 'Integration test partner redemption'
    );

    IF v_txn_id IS NULL THEN
        RAISE EXCEPTION 'partner_integration_record_partner_redeem returned NULL';
    END IF;
    RAISE NOTICE '  Redeem transaction: id=%', v_txn_id;

    -- Step 4: Get partner summary
    RAISE NOTICE 'Step 4: Getting partner summary...';
    IF EXISTS (SELECT 1 FROM partner_integration_get_partner_summary(v_partner_code)) THEN
        RAISE NOTICE '  Partner summary retrieved';
    ELSE
        RAISE NOTICE '  WARNING: Partner summary empty';
    END IF;

    -- Step 5: Process settlement
    RAISE NOTICE 'Step 5: Processing settlement...';
    SELECT * INTO v_rec
      FROM partner_integration_process_settlement(
          v_partner_code,
          CURRENT_DATE - INTERVAL '30 days',
          CURRENT_DATE + INTERVAL '1 day'
      );
    RAISE NOTICE '  Settlement: earned=%, redeemed=%, net=%',
        v_rec.total_earned, v_rec.total_redeemed, v_rec.net_settlement;

    RAISE NOTICE '✅  Partner Transaction Flow: ALL STEPS PASSED';
END;
$$;

ROLLBACK;
