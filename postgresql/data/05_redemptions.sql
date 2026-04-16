-- ========================================
-- Redemptions Data (PostgreSQL)
-- ========================================
-- Converted from Oracle PL/SQL:
--   ROWNUM = 1       -> LIMIT 1
--   DBMS_RANDOM      -> random()
--   EXCEPTION WHEN NO_DATA_FOUND -> handled via COUNT check
--   seq.NEXTVAL      -> nextval('seq')
-- Column mapping: miles_redeemed->miles_used, booking_ref->confirmation_code,
--   status values: AVAILABLE->ACTIVE (rewards), added redemption_channel

DO $$
DECLARE
  v_reward_id INTEGER;
  v_redemption_count INTEGER;
  v_reward_miles INTEGER;
  v_redemption_date DATE;
  v_reward_count INTEGER;
  member_rec RECORD;
BEGIN
  FOR member_rec IN (
    SELECT member_id, total_miles, tier_status
    FROM members
    WHERE status = 'ACTIVE' AND total_miles > 10000
    ORDER BY member_id
  ) LOOP
    v_redemption_count := CASE member_rec.tier_status
                           WHEN 'DIAMOND'  THEN floor(random() * 10 + 5)::int
                           WHEN 'PLATINUM' THEN floor(random() *  7 + 3)::int
                           WHEN 'GOLD'     THEN floor(random() *  5 + 2)::int
                           WHEN 'SILVER'   THEN floor(random() *  4 + 1)::int
                           ELSE floor(random() * 3)::int
                         END;

    FOR i IN 1..v_redemption_count LOOP
      -- Check if an affordable reward exists
      SELECT COUNT(*) INTO v_reward_count
      FROM rewards
      WHERE status = 'ACTIVE'
        AND miles_required <= member_rec.total_miles
        AND (quantity_available IS NULL OR quantity_available > 0);

      IF v_reward_count > 0 THEN
        -- Select a random affordable reward
        SELECT reward_id, miles_required INTO v_reward_id, v_reward_miles
        FROM rewards
        WHERE status = 'ACTIVE'
          AND miles_required <= member_rec.total_miles
          AND (quantity_available IS NULL OR quantity_available > 0)
        ORDER BY random()
        LIMIT 1;

        v_redemption_date := CURRENT_DATE - floor(random() * 365)::int;

        INSERT INTO redemptions (
          redemption_id, member_id, reward_id,
          miles_used, redemption_date, status,
          confirmation_code, fulfillment_date, redemption_channel
        ) VALUES (
          nextval('seq_redemption_id'),
          member_rec.member_id,
          v_reward_id,
          v_reward_miles,
          v_redemption_date,
          CASE
            WHEN random() < 0.9  THEN 'FULFILLED'
            WHEN random() < 0.95 THEN 'CONFIRMED'
            ELSE 'PENDING'
          END,
          'RD' || floor(random() * 899999 + 100000)::int,
          CASE
            WHEN random() < 0.9 THEN v_redemption_date + floor(random() * 29 + 1)::int
            ELSE NULL
          END,
          (ARRAY['WEB','MOBILE','CALL_CENTER','AIRPORT'])[floor(random() * 4 + 1)::int]
        );
      END IF;
    END LOOP;
  END LOOP;

  RAISE NOTICE 'Created redemption records';
END $$;

SELECT
  r.category,
  COUNT(rd.redemption_id) AS redemption_count,
  SUM(rd.miles_used) AS total_miles_redeemed
FROM redemptions rd
JOIN rewards r ON rd.reward_id = r.reward_id
GROUP BY r.category
ORDER BY total_miles_redeemed DESC;
