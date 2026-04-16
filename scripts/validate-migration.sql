-- ========================================
-- Migration Validation Script
-- ========================================
-- Compares row counts, checks referential integrity,
-- validates constraints, and verifies key aggregates.
--
-- Usage:
--   psql -U <username> -d <database> -f scripts/validate-migration.sql
--
-- Expected: All checks should return 'PASS'. Any 'FAIL' indicates
-- a data migration issue that must be investigated.

\echo ''
\echo '========================================'
\echo '  DATA MIGRATION VALIDATION REPORT'
\echo '========================================'
\echo ''

-- ----------------------------------------
-- 1. Row Count Validation
-- ----------------------------------------
\echo '--- 1. Row Counts ---'

SELECT
  table_name,
  row_count,
  CASE
    WHEN row_count > 0 THEN 'PASS'
    ELSE 'FAIL - table is empty'
  END AS status
FROM (
  SELECT 'tier_rules'            AS table_name, COUNT(*) AS row_count FROM tier_rules
  UNION ALL
  SELECT 'rewards',              COUNT(*) FROM rewards
  UNION ALL
  SELECT 'members',              COUNT(*) FROM members
  UNION ALL
  SELECT 'partners',             COUNT(*) FROM partners
  UNION ALL
  SELECT 'flights',              COUNT(*) FROM flights
  UNION ALL
  SELECT 'redemptions',          COUNT(*) FROM redemptions
  UNION ALL
  SELECT 'partner_transactions', COUNT(*) FROM partner_transactions
) counts
ORDER BY table_name;

-- Expected row counts (approximate for procedurally-generated data)
\echo ''
\echo '--- Expected Row Counts ---'
SELECT 'tier_rules'   AS table_name, 5     AS expected_rows, COUNT(*) AS actual_rows,
  CASE WHEN COUNT(*) = 5 THEN 'PASS' ELSE 'FAIL' END AS status FROM tier_rules
UNION ALL
SELECT 'rewards',      15,   COUNT(*),
  CASE WHEN COUNT(*) = 15 THEN 'PASS' ELSE 'FAIL' END FROM rewards
UNION ALL
SELECT 'members',      100,  COUNT(*),
  CASE WHEN COUNT(*) = 100 THEN 'PASS' ELSE 'FAIL' END FROM members
UNION ALL
SELECT 'partners',     5,    COUNT(*),
  CASE WHEN COUNT(*) = 5 THEN 'PASS' ELSE 'FAIL' END FROM partners
ORDER BY table_name;

-- ----------------------------------------
-- 2. Referential Integrity Checks
-- ----------------------------------------
\echo ''
\echo '--- 2. Referential Integrity ---'

-- Flights: all member_ids must exist in members
SELECT 'flights -> members' AS fk_check,
  COUNT(*) AS orphan_count,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL - orphan records' END AS status
FROM flights f
WHERE NOT EXISTS (SELECT 1 FROM members m WHERE m.member_id = f.member_id);

-- Redemptions: all member_ids must exist in members
SELECT 'redemptions -> members' AS fk_check,
  COUNT(*) AS orphan_count,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL - orphan records' END AS status
FROM redemptions rd
WHERE NOT EXISTS (SELECT 1 FROM members m WHERE m.member_id = rd.member_id);

-- Redemptions: all reward_ids must exist in rewards
SELECT 'redemptions -> rewards' AS fk_check,
  COUNT(*) AS orphan_count,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL - orphan records' END AS status
FROM redemptions rd
WHERE NOT EXISTS (SELECT 1 FROM rewards r WHERE r.reward_id = rd.reward_id);

-- Partner transactions: all member_ids must exist in members
SELECT 'partner_txn -> members' AS fk_check,
  COUNT(*) AS orphan_count,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL - orphan records' END AS status
FROM partner_transactions pt
WHERE NOT EXISTS (SELECT 1 FROM members m WHERE m.member_id = pt.member_id);

-- Partner transactions: all partner_ids must exist in partners
SELECT 'partner_txn -> partners' AS fk_check,
  COUNT(*) AS orphan_count,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL - orphan records' END AS status
FROM partner_transactions pt
WHERE NOT EXISTS (SELECT 1 FROM partners p WHERE p.partner_id = pt.partner_id);

-- ----------------------------------------
-- 3. Check Constraint Validation
-- ----------------------------------------
\echo ''
\echo '--- 3. Constraint Validation ---'

-- Tier rules: valid tier names
SELECT 'tier_rules.tier_name' AS constraint_check,
  COUNT(*) AS violations,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM tier_rules
WHERE tier_name NOT IN ('BLUE','SILVER','GOLD','PLATINUM','DIAMOND');

-- Members: valid tier status
SELECT 'members.tier_status' AS constraint_check,
  COUNT(*) AS violations,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM members
WHERE tier_status NOT IN ('BLUE','SILVER','GOLD','PLATINUM','DIAMOND');

-- Members: valid status
SELECT 'members.status' AS constraint_check,
  COUNT(*) AS violations,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM members
WHERE status NOT IN ('ACTIVE','INACTIVE','SUSPENDED','CLOSED');

-- Rewards: valid category
SELECT 'rewards.category' AS constraint_check,
  COUNT(*) AS violations,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM rewards
WHERE category NOT IN ('FLIGHT','UPGRADE','LOUNGE','HOTEL','CAR_RENTAL','MERCHANDISE','GIFT_CARD','EXPERIENCE');

-- Flights: valid cabin class
SELECT 'flights.cabin_class' AS constraint_check,
  COUNT(*) AS violations,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM flights
WHERE cabin_class NOT IN ('ECONOMY','PREMIUM_ECONOMY','BUSINESS','FIRST');

-- Flights: valid accrual status
SELECT 'flights.accrual_status' AS constraint_check,
  COUNT(*) AS violations,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM flights
WHERE accrual_status NOT IN ('PENDING','PROCESSED','REJECTED','REVERSED');

-- Redemptions: valid status
SELECT 'redemptions.status' AS constraint_check,
  COUNT(*) AS violations,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM redemptions
WHERE status NOT IN ('PENDING','CONFIRMED','FULFILLED','CANCELLED','EXPIRED');

-- Partner transactions: valid type
SELECT 'partner_txn.type' AS constraint_check,
  COUNT(*) AS violations,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM partner_transactions
WHERE transaction_type NOT IN ('EARN','REDEEM','TRANSFER','ADJUSTMENT');

-- ----------------------------------------
-- 4. Key Aggregate Validation
-- ----------------------------------------
\echo ''
\echo '--- 4. Key Aggregates ---'

-- Total miles across all members
SELECT 'Total member miles' AS metric,
  SUM(total_miles) AS value,
  CASE WHEN SUM(total_miles) > 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM members;

-- Member counts by tier
SELECT 'Members by tier' AS metric,
  tier_status,
  COUNT(*) AS member_count,
  CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM members
GROUP BY tier_status
ORDER BY CASE tier_status
           WHEN 'DIAMOND'  THEN 5
           WHEN 'PLATINUM' THEN 4
           WHEN 'GOLD'     THEN 3
           WHEN 'SILVER'   THEN 2
           WHEN 'BLUE'     THEN 1
         END;

-- Total flight miles earned
SELECT 'Total flight miles' AS metric,
  SUM(total_miles) AS value,
  CASE WHEN SUM(total_miles) > 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM flights;

-- Average miles per booking class
SELECT 'Avg miles by class' AS metric,
  booking_class,
  floor(AVG(total_miles)) AS avg_miles,
  COUNT(*) AS flight_count
FROM flights
GROUP BY booking_class
ORDER BY booking_class;

-- Total redemption miles
SELECT 'Total redeemed miles' AS metric,
  SUM(miles_used) AS value,
  CASE WHEN SUM(miles_used) > 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM redemptions;

-- Redemptions by reward category
SELECT 'Redemptions by category' AS metric,
  r.category,
  COUNT(*) AS redemption_count,
  SUM(rd.miles_used) AS total_miles
FROM redemptions rd
JOIN rewards r ON rd.reward_id = r.reward_id
GROUP BY r.category
ORDER BY total_miles DESC;

-- Partner transaction totals
SELECT 'Partner txn totals' AS metric,
  p.partner_name,
  SUM(pt.miles_earned) AS earned,
  SUM(pt.miles_redeemed) AS redeemed
FROM partner_transactions pt
JOIN partners p ON pt.partner_id = p.partner_id
GROUP BY p.partner_name
ORDER BY earned DESC;

-- ----------------------------------------
-- 5. Data Quality Checks
-- ----------------------------------------
\echo ''
\echo '--- 5. Data Quality ---'

-- Members: no NULL emails
SELECT 'members.email NOT NULL' AS quality_check,
  COUNT(*) AS violations,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM members WHERE email IS NULL;

-- Members: unique emails
SELECT 'members.email unique' AS quality_check,
  COUNT(*) - COUNT(DISTINCT email) AS duplicates,
  CASE WHEN COUNT(*) = COUNT(DISTINCT email) THEN 'PASS' ELSE 'FAIL' END AS status
FROM members;

-- Tier rules: exactly 5 tiers
SELECT 'tier_rules count = 5' AS quality_check,
  COUNT(*) AS actual,
  CASE WHEN COUNT(*) = 5 THEN 'PASS' ELSE 'FAIL' END AS status
FROM tier_rules;

-- Flights: positive distance
SELECT 'flights.distance > 0' AS quality_check,
  COUNT(*) AS violations,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM flights WHERE distance_miles <= 0;

-- Redemptions: positive miles
SELECT 'redemptions.miles > 0' AS quality_check,
  COUNT(*) AS violations,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM redemptions WHERE miles_used <= 0;

\echo ''
\echo '========================================'
\echo '  VALIDATION COMPLETE'
\echo '========================================'
