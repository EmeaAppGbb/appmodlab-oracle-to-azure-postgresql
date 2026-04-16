-- ========================================
-- Members Data (PostgreSQL)
-- ========================================
-- Converted from Oracle PL/SQL:
--   DECLARE/BEGIN/END  -> DO $$ / END $$
--   DBMS_RANDOM.VALUE  -> random()
--   TRUNC()            -> floor()
--   LPAD()             -> lpad()  (same syntax)
--   ADD_MONTHS(SYSDATE, -n) -> CURRENT_TIMESTAMP - (n || ' months')::interval
--   SYSDATE            -> CURRENT_TIMESTAMP
--   DBMS_OUTPUT.PUT_LINE -> RAISE NOTICE
--   seq.NEXTVAL        -> nextval('seq')
-- Column mapping: join_date->enrollment_date, state->state_province,
--   qualifying_miles->ytd_miles, added membership_number

DO $$
DECLARE
  v_member_id INTEGER;
  v_tier VARCHAR(50);
  v_cities TEXT[] := ARRAY['New York','Los Angeles','Chicago','Houston','Phoenix',
                           'Seattle','Miami','Boston','San Francisco','Atlanta'];
BEGIN
  FOR i IN 1..100 LOOP
    v_tier := CASE
                WHEN i % 20 = 0 THEN 'DIAMOND'
                WHEN i % 10 = 0 THEN 'PLATINUM'
                WHEN i % 5 = 0 THEN 'GOLD'
                WHEN i % 3 = 0 THEN 'SILVER'
                ELSE 'BLUE'
              END;

    v_member_id := nextval('seq_member_id');

    INSERT INTO members (
      member_id, membership_number, first_name, last_name, email, phone,
      tier_status, total_miles, available_miles, ytd_miles,
      lifetime_miles, enrollment_date, status, city, state_province, country
    ) VALUES (
      v_member_id,
      'SR' || lpad(v_member_id::text, 8, '0'),
      'FirstName' || i,
      'LastName' || i,
      'member' || i || '@skyreward.com',
      '+1555000' || lpad(i::text, 4, '0'),
      v_tier,
      CASE v_tier
        WHEN 'DIAMOND'  THEN 150000 + floor(random() * 50000)::int
        WHEN 'PLATINUM' THEN 100000 + floor(random() * 25000)::int
        WHEN 'GOLD'     THEN  75000 + floor(random() * 15000)::int
        WHEN 'SILVER'   THEN  50000 + floor(random() * 10000)::int
        ELSE floor(random() * 25000)::int
      END,
      CASE v_tier
        WHEN 'DIAMOND'  THEN 100000 + floor(random() * 25000)::int
        WHEN 'PLATINUM' THEN  75000 + floor(random() * 15000)::int
        WHEN 'GOLD'     THEN  50000 + floor(random() * 10000)::int
        WHEN 'SILVER'   THEN  25000 + floor(random() * 10000)::int
        ELSE floor(random() * 10000)::int
      END,
      CASE v_tier
        WHEN 'DIAMOND'  THEN 100000 + floor(random() * 25000)::int
        WHEN 'PLATINUM' THEN  75000 + floor(random() * 15000)::int
        WHEN 'GOLD'     THEN  50000 + floor(random() * 10000)::int
        WHEN 'SILVER'   THEN  25000 + floor(random() * 10000)::int
        ELSE floor(random() * 10000)::int
      END,
      CASE v_tier
        WHEN 'DIAMOND'  THEN 500000 + floor(random() * 500000)::int
        WHEN 'PLATINUM' THEN 300000 + floor(random() * 200000)::int
        WHEN 'GOLD'     THEN 150000 + floor(random() * 100000)::int
        WHEN 'SILVER'   THEN  75000 + floor(random() *  50000)::int
        ELSE floor(random() * 50000)::int
      END,
      CURRENT_TIMESTAMP - ((12 + floor(random() * 108))::int || ' months')::interval,
      'ACTIVE',
      v_cities[(i % 10) + 1],
      'XX',
      'US'
    );

    IF i % 100 = 0 THEN
      -- PostgreSQL auto-commits in DO blocks; this is a logical checkpoint
      RAISE NOTICE 'Inserted % members', i;
    END IF;
  END LOOP;

  RAISE NOTICE 'Created 100 member records';
END $$;

-- Create partners for testing
INSERT INTO partners (partner_id, partner_code, partner_name, partner_type, conversion_rate, status, agreement_start)
VALUES (nextval('seq_partner_id'), 'PHI', 'Premium Hotels International', 'HOTEL', 2.0, 'ACTIVE', CURRENT_TIMESTAMP);

INSERT INTO partners (partner_id, partner_code, partner_name, partner_type, conversion_rate, status, agreement_start)
VALUES (nextval('seq_partner_id'), 'GCR', 'Global Car Rentals', 'CAR_RENTAL', 1.5, 'ACTIVE', CURRENT_TIMESTAMP);

INSERT INTO partners (partner_id, partner_code, partner_name, partner_type, conversion_rate, status, agreement_start)
VALUES (nextval('seq_partner_id'), 'ECC', 'Elite Credit Card', 'FINANCIAL', 1.0, 'ACTIVE', CURRENT_TIMESTAMP);

INSERT INTO partners (partner_id, partner_code, partner_name, partner_type, conversion_rate, status, agreement_start)
VALUES (nextval('seq_partner_id'), 'RRN', 'Restaurant Rewards Network', 'DINING', 1.25, 'ACTIVE', CURRENT_TIMESTAMP);

INSERT INTO partners (partner_id, partner_code, partner_name, partner_type, conversion_rate, status, agreement_start)
VALUES (nextval('seq_partner_id'), 'OSM', 'Online Shopping Mall', 'RETAIL', 0.5, 'ACTIVE', CURRENT_TIMESTAMP);

SELECT tier_status, COUNT(*) AS member_count,
       floor(AVG(total_miles)) AS avg_miles,
       floor(AVG(lifetime_miles)) AS avg_lifetime_miles
FROM members
GROUP BY tier_status
ORDER BY CASE tier_status
           WHEN 'DIAMOND'  THEN 5
           WHEN 'PLATINUM' THEN 4
           WHEN 'GOLD'     THEN 3
           WHEN 'SILVER'   THEN 2
           WHEN 'BLUE'     THEN 1
         END;
