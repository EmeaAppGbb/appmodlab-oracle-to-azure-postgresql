-- ========================================
-- Redemptions Data
-- ========================================
-- Sample redemption transactions

DECLARE
  v_member_id NUMBER;
  v_reward_id NUMBER;
  v_redemption_count NUMBER;
  v_member_miles NUMBER;
  v_reward_miles NUMBER;
  v_redemption_date DATE;
BEGIN
  -- Create redemptions for active members with sufficient miles
  FOR member_rec IN (
    SELECT member_id, total_miles, tier_status 
    FROM members 
    WHERE status = 'ACTIVE' AND total_miles > 10000
    ORDER BY member_id
  ) LOOP
    -- More redemptions for higher tier members
    v_redemption_count := CASE member_rec.tier_status
                           WHEN 'DIAMOND' THEN TRUNC(DBMS_RANDOM.VALUE(5, 15))
                           WHEN 'PLATINUM' THEN TRUNC(DBMS_RANDOM.VALUE(3, 10))
                           WHEN 'GOLD' THEN TRUNC(DBMS_RANDOM.VALUE(2, 7))
                           WHEN 'SILVER' THEN TRUNC(DBMS_RANDOM.VALUE(1, 5))
                           ELSE TRUNC(DBMS_RANDOM.VALUE(0, 3))
                         END;
    
    FOR i IN 1..v_redemption_count LOOP
      -- Select random reward that member can afford
      BEGIN
        SELECT reward_id, miles_required INTO v_reward_id, v_reward_miles
        FROM (
          SELECT reward_id, miles_required
          FROM rewards
          WHERE status = 'AVAILABLE' 
            AND miles_required <= member_rec.total_miles
            AND availability > 0
          ORDER BY DBMS_RANDOM.VALUE
        )
        WHERE ROWNUM = 1;
        
        -- Redemption date in past year
        v_redemption_date := TRUNC(SYSDATE) - TRUNC(DBMS_RANDOM.VALUE(0, 365));
        
        INSERT INTO redemptions (
          redemption_id, member_id, reward_id,
          miles_redeemed, redemption_date, status,
          booking_ref, fulfillment_date
        ) VALUES (
          seq_redemption_id.NEXTVAL,
          member_rec.member_id,
          v_reward_id,
          v_reward_miles,
          v_redemption_date,
          CASE 
            WHEN DBMS_RANDOM.VALUE < 0.9 THEN 'FULFILLED'
            WHEN DBMS_RANDOM.VALUE < 0.95 THEN 'CONFIRMED'
            ELSE 'PENDING'
          END,
          'RD' || TRUNC(DBMS_RANDOM.VALUE(100000, 999999)),
          CASE 
            WHEN DBMS_RANDOM.VALUE < 0.9 THEN v_redemption_date + TRUNC(DBMS_RANDOM.VALUE(1, 30))
            ELSE NULL
          END
        );
        
        -- Update member miles would normally happen via trigger/package
        -- but we'll skip here to keep data generation simple
        
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          NULL; -- No affordable rewards, skip
      END;
    END LOOP;
    
    IF MOD(member_rec.member_id, 1000000) = 10 THEN
      COMMIT;
    END IF;
  END LOOP;
  
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Created redemption records');
END;
/

SELECT 
  r.category,
  COUNT(rd.redemption_id) AS redemption_count,
  SUM(rd.miles_redeemed) AS total_miles_redeemed
FROM redemptions rd
JOIN rewards r ON rd.reward_id = r.reward_id
GROUP BY r.category
ORDER BY total_miles_redeemed DESC;
