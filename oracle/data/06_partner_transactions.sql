-- ========================================
-- Partner Transactions Data
-- ========================================
-- Sample partner earn/burn transactions

DECLARE
  v_member_id NUMBER;
  v_partner_id NUMBER;
  v_txn_count NUMBER;
  v_txn_type VARCHAR2(10);
  v_miles NUMBER;
  v_txn_date DATE;
BEGIN
  -- Create partner transactions for active members
  FOR member_rec IN (
    SELECT member_id, tier_status 
    FROM members 
    WHERE status = 'ACTIVE' 
    ORDER BY member_id
  ) LOOP
    -- Random number of partner transactions
    v_txn_count := TRUNC(DBMS_RANDOM.VALUE(0, 20));
    
    FOR i IN 1..v_txn_count LOOP
      -- Random partner
      SELECT partner_id INTO v_partner_id
      FROM (
        SELECT partner_id 
        FROM partners 
        WHERE status = 'ACTIVE'
        ORDER BY DBMS_RANDOM.VALUE
      )
      WHERE ROWNUM = 1;
      
      -- 80% earn, 20% burn
      v_txn_type := CASE WHEN DBMS_RANDOM.VALUE < 0.8 THEN 'EARN' ELSE 'BURN' END;
      
      -- Random miles/amount
      v_miles := TRUNC(DBMS_RANDOM.VALUE(100, 5000));
      
      -- Transaction date in past year
      v_txn_date := TRUNC(SYSDATE) - TRUNC(DBMS_RANDOM.VALUE(0, 365));
      
      INSERT INTO partner_transactions (
        txn_id, member_id, partner_id, txn_type, miles,
        transaction_date, transaction_amount, currency,
        reference_number, status, posted_date
      ) VALUES (
        seq_partner_txn_id.NEXTVAL,
        member_rec.member_id,
        v_partner_id,
        v_txn_type,
        v_miles,
        v_txn_date,
        CASE v_txn_type 
          WHEN 'EARN' THEN v_miles / 2 -- $0.50 per mile
          ELSE v_miles * 0.01 -- Burn value
        END,
        'USD',
        'PT' || TRUNC(DBMS_RANDOM.VALUE(1000000, 9999999)),
        'POSTED',
        v_txn_date + TRUNC(DBMS_RANDOM.VALUE(0, 5))
      );
    END LOOP;
    
    IF MOD(member_rec.member_id, 1000000) = 20 THEN
      COMMIT;
    END IF;
  END LOOP;
  
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Created partner transaction records');
END;
/

SELECT 
  p.partner_name,
  p.partner_type,
  COUNT(pt.txn_id) AS txn_count,
  SUM(CASE WHEN pt.txn_type = 'EARN' THEN pt.miles ELSE 0 END) AS miles_earned,
  SUM(CASE WHEN pt.txn_type = 'BURN' THEN pt.miles ELSE 0 END) AS miles_burned
FROM partners p
LEFT JOIN partner_transactions pt ON p.partner_id = pt.partner_id
GROUP BY p.partner_name, p.partner_type
ORDER BY miles_earned DESC;

PROMPT
PROMPT ========================================
PROMPT Data Loading Summary
PROMPT ========================================

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
