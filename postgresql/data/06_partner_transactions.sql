-- ========================================
-- Partner Transactions Data (PostgreSQL)
-- ========================================
-- Converted from Oracle PL/SQL:
--   ROWNUM = 1       -> LIMIT 1
--   DBMS_RANDOM      -> random()
--   seq.NEXTVAL      -> nextval('seq')
-- Column mapping: txn_type->transaction_type, miles->miles_earned/miles_redeemed,
--   transaction_amount->amount, reference_number->partner_ref,
--   posted_date->processed_date, EARN/BURN->EARN/REDEEM

DO $$
DECLARE
  v_partner_id INTEGER;
  v_txn_count INTEGER;
  v_txn_type VARCHAR(10);
  v_miles INTEGER;
  v_txn_date DATE;
  member_rec RECORD;
BEGIN
  FOR member_rec IN (
    SELECT member_id, tier_status
    FROM members
    WHERE status = 'ACTIVE'
    ORDER BY member_id
  ) LOOP
    v_txn_count := floor(random() * 20)::int;

    FOR i IN 1..v_txn_count LOOP
      -- Random active partner
      SELECT partner_id INTO v_partner_id
      FROM partners
      WHERE status = 'ACTIVE'
      ORDER BY random()
      LIMIT 1;

      -- 80% earn, 20% redeem
      v_txn_type := CASE WHEN random() < 0.8 THEN 'EARN' ELSE 'REDEEM' END;

      v_miles := floor(random() * 4900 + 100)::int;

      v_txn_date := CURRENT_DATE - floor(random() * 365)::int;

      INSERT INTO partner_transactions (
        txn_id, member_id, partner_id, transaction_type,
        miles_earned, miles_redeemed,
        transaction_date, amount, currency,
        partner_ref, status, processed_date
      ) VALUES (
        nextval('seq_partner_txn_id'),
        member_rec.member_id,
        v_partner_id,
        v_txn_type,
        CASE WHEN v_txn_type = 'EARN' THEN v_miles ELSE 0 END,
        CASE WHEN v_txn_type = 'REDEEM' THEN v_miles ELSE 0 END,
        v_txn_date,
        CASE v_txn_type
          WHEN 'EARN' THEN v_miles / 2.0
          ELSE v_miles * 0.01
        END,
        'USD',
        'PT' || floor(random() * 8999999 + 1000000)::int,
        'PROCESSED',
        v_txn_date + floor(random() * 5)::int
      );
    END LOOP;
  END LOOP;

  RAISE NOTICE 'Created partner transaction records';
END $$;

SELECT
  p.partner_name,
  p.partner_type,
  COUNT(pt.txn_id) AS txn_count,
  SUM(pt.miles_earned) AS miles_earned,
  SUM(pt.miles_redeemed) AS miles_redeemed
FROM partners p
LEFT JOIN partner_transactions pt ON p.partner_id = pt.partner_id
GROUP BY p.partner_name, p.partner_type
ORDER BY miles_earned DESC;

\echo ''
\echo '========================================'
\echo 'Data Loading Summary'
\echo '========================================'

SELECT 'Tier Rules' AS table_name, COUNT(*) AS row_count FROM tier_rules
UNION ALL
SELECT 'Rewards', COUNT(*) FROM rewards
UNION ALL
SELECT 'Members', COUNT(*) FROM members
UNION ALL
SELECT 'Partners', COUNT(*) FROM partners
UNION ALL
SELECT 'Flights', COUNT(*) FROM flights
UNION ALL
SELECT 'Redemptions', COUNT(*) FROM redemptions
UNION ALL
SELECT 'Partner Transactions', COUNT(*) FROM partner_transactions
ORDER BY row_count DESC;
