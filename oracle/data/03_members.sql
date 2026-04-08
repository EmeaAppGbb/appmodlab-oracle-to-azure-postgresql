-- ========================================
-- Members Data
-- ========================================
-- Sample member records with realistic data

DECLARE
  v_member_id NUMBER;
  v_tier VARCHAR2(50);
  v_referred_by NUMBER := NULL;
BEGIN
  -- Create founding members (no referrer)
  FOR i IN 1..100 LOOP
    v_tier := CASE 
                WHEN MOD(i, 20) = 0 THEN 'DIAMOND'
                WHEN MOD(i, 10) = 0 THEN 'PLATINUM'
                WHEN MOD(i, 5) = 0 THEN 'GOLD'
                WHEN MOD(i, 3) = 0 THEN 'SILVER'
                ELSE 'BLUE'
              END;
    
    v_member_id := seq_member_id.NEXTVAL;
    
    INSERT INTO members (
      member_id, first_name, last_name, email, phone,
      tier_status, total_miles, qualifying_miles, qualifying_segments,
      lifetime_miles, join_date, status, city, state, country
    ) VALUES (
      v_member_id,
      'FirstName' || i,
      'LastName' || i,
      'member' || i || '@skyreward.com',
      '+1555000' || LPAD(i, 4, '0'),
      v_tier,
      CASE v_tier
        WHEN 'DIAMOND' THEN 150000 + TRUNC(DBMS_RANDOM.VALUE(0, 50000))
        WHEN 'PLATINUM' THEN 100000 + TRUNC(DBMS_RANDOM.VALUE(0, 25000))
        WHEN 'GOLD' THEN 75000 + TRUNC(DBMS_RANDOM.VALUE(0, 15000))
        WHEN 'SILVER' THEN 50000 + TRUNC(DBMS_RANDOM.VALUE(0, 10000))
        ELSE TRUNC(DBMS_RANDOM.VALUE(0, 25000))
      END,
      CASE v_tier
        WHEN 'DIAMOND' THEN 100000 + TRUNC(DBMS_RANDOM.VALUE(0, 25000))
        WHEN 'PLATINUM' THEN 75000 + TRUNC(DBMS_RANDOM.VALUE(0, 15000))
        WHEN 'GOLD' THEN 50000 + TRUNC(DBMS_RANDOM.VALUE(0, 10000))
        WHEN 'SILVER' THEN 25000 + TRUNC(DBMS_RANDOM.VALUE(0, 10000))
        ELSE TRUNC(DBMS_RANDOM.VALUE(0, 10000))
      END,
      CASE v_tier
        WHEN 'DIAMOND' THEN 100 + TRUNC(DBMS_RANDOM.VALUE(0, 50))
        WHEN 'PLATINUM' THEN 75 + TRUNC(DBMS_RANDOM.VALUE(0, 25))
        WHEN 'GOLD' THEN 50 + TRUNC(DBMS_RANDOM.VALUE(0, 15))
        WHEN 'SILVER' THEN 25 + TRUNC(DBMS_RANDOM.VALUE(0, 15))
        ELSE TRUNC(DBMS_RANDOM.VALUE(0, 20))
      END,
      CASE v_tier
        WHEN 'DIAMOND' THEN 500000 + TRUNC(DBMS_RANDOM.VALUE(0, 500000))
        WHEN 'PLATINUM' THEN 300000 + TRUNC(DBMS_RANDOM.VALUE(0, 200000))
        WHEN 'GOLD' THEN 150000 + TRUNC(DBMS_RANDOM.VALUE(0, 100000))
        WHEN 'SILVER' THEN 75000 + TRUNC(DBMS_RANDOM.VALUE(0, 50000))
        ELSE TRUNC(DBMS_RANDOM.VALUE(0, 50000))
      END,
      ADD_MONTHS(SYSDATE, -TRUNC(DBMS_RANDOM.VALUE(12, 120))), -- Join date 1-10 years ago
      'ACTIVE',
      CASE MOD(i, 10)
        WHEN 0 THEN 'New York'
        WHEN 1 THEN 'Los Angeles'
        WHEN 2 THEN 'Chicago'
        WHEN 3 THEN 'Houston'
        WHEN 4 THEN 'Phoenix'
        WHEN 5 THEN 'Seattle'
        WHEN 6 THEN 'Miami'
        WHEN 7 THEN 'Boston'
        WHEN 8 THEN 'San Francisco'
        ELSE 'Atlanta'
      END,
      'XX',
      'USA'
    );
    
    IF MOD(i, 100) = 0 THEN
      COMMIT;
    END IF;
  END LOOP;
  
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Created 100 member records');
END;
/

-- Create partners for testing
INSERT INTO partners (partner_id, partner_name, partner_type, earn_rate, burn_rate, status, contract_start)
VALUES (seq_partner_id.NEXTVAL, 'Premium Hotels International', 'HOTEL', 2.0, 1.0, 'ACTIVE', SYSDATE);

INSERT INTO partners (partner_id, partner_name, partner_type, earn_rate, burn_rate, status, contract_start)
VALUES (seq_partner_id.NEXTVAL, 'Global Car Rentals', 'CAR_RENTAL', 1.5, 1.0, 'ACTIVE', SYSDATE);

INSERT INTO partners (partner_id, partner_name, partner_type, earn_rate, burn_rate, status, contract_start)
VALUES (seq_partner_id.NEXTVAL, 'Elite Credit Card', 'CREDIT_CARD', 1.0, 0.8, 'ACTIVE', SYSDATE);

INSERT INTO partners (partner_id, partner_name, partner_type, earn_rate, burn_rate, status, contract_start)
VALUES (seq_partner_id.NEXTVAL, 'Restaurant Rewards Network', 'DINING', 1.25, 1.0, 'ACTIVE', SYSDATE);

INSERT INTO partners (partner_id, partner_name, partner_type, earn_rate, burn_rate, status, contract_start)
VALUES (seq_partner_id.NEXTVAL, 'Online Shopping Mall', 'RETAIL', 0.5, 1.0, 'ACTIVE', SYSDATE);

COMMIT;

SELECT tier_status, COUNT(*) AS member_count, 
       TRUNC(AVG(total_miles)) AS avg_miles,
       TRUNC(AVG(lifetime_miles)) AS avg_lifetime_miles
FROM members 
GROUP BY tier_status 
ORDER BY DECODE(tier_status, 'DIAMOND', 5, 'PLATINUM', 4, 'GOLD', 3, 'SILVER', 2, 'BLUE', 1);
