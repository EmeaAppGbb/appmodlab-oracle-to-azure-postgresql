-- ========================================
-- Tier Rules Data (PostgreSQL)
-- ========================================
-- Converted from Oracle: seq.NEXTVAL -> nextval(), column mapping to PG schema
-- Oracle columns: rule_id, tier_name, tier_level, min_qualifying_miles, min_qualifying_segments, benefits, bonus_multiplier
-- PG columns:    rule_id, tier_name, min_miles, min_segments, miles_multiplier, lounge_access, priority_boarding, free_upgrades, bonus_miles_pct, bag_allowance

INSERT INTO tier_rules (rule_id, tier_name, min_miles, min_segments, miles_multiplier, lounge_access, priority_boarding, free_upgrades, bonus_miles_pct, bag_allowance)
VALUES (nextval('seq_tier_rule_id'), 'BLUE', 0, 0, 1.0, 'N', 'N', 0, 0.00, 1);

INSERT INTO tier_rules (rule_id, tier_name, min_miles, min_segments, miles_multiplier, lounge_access, priority_boarding, free_upgrades, bonus_miles_pct, bag_allowance)
VALUES (nextval('seq_tier_rule_id'), 'SILVER', 25000, 25, 1.25, 'N', 'Y', 0, 25.00, 1);

INSERT INTO tier_rules (rule_id, tier_name, min_miles, min_segments, miles_multiplier, lounge_access, priority_boarding, free_upgrades, bonus_miles_pct, bag_allowance)
VALUES (nextval('seq_tier_rule_id'), 'GOLD', 50000, 50, 1.5, 'Y', 'Y', 1, 50.00, 2);

INSERT INTO tier_rules (rule_id, tier_name, min_miles, min_segments, miles_multiplier, lounge_access, priority_boarding, free_upgrades, bonus_miles_pct, bag_allowance)
VALUES (nextval('seq_tier_rule_id'), 'PLATINUM', 75000, 75, 1.75, 'Y', 'Y', 2, 75.00, 3);

INSERT INTO tier_rules (rule_id, tier_name, min_miles, min_segments, miles_multiplier, lounge_access, priority_boarding, free_upgrades, bonus_miles_pct, bag_allowance)
VALUES (nextval('seq_tier_rule_id'), 'DIAMOND', 100000, 100, 2.0, 'Y', 'Y', 5, 100.00, 99);

SELECT tier_name, min_miles, miles_multiplier FROM tier_rules ORDER BY min_miles;
