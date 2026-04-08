-- ========================================
-- Tier Rules Data
-- ========================================
-- Define tier structure and qualification requirements

INSERT INTO tier_rules (rule_id, tier_name, tier_level, min_qualifying_miles, min_qualifying_segments, benefits, bonus_multiplier)
VALUES (seq_tier_rule_id.NEXTVAL, 'BLUE', 1, 0, 0, 
  'Base tier benefits: Standard mileage accrual, No upgrade priority, No lounge access', 1.0);

INSERT INTO tier_rules (rule_id, tier_name, tier_level, min_qualifying_miles, min_qualifying_segments, benefits, bonus_multiplier)
VALUES (seq_tier_rule_id.NEXTVAL, 'SILVER', 2, 25000, 25, 
  'Silver tier benefits: 25% bonus miles, Priority check-in, 1 free checked bag, Partner lounge access', 1.25);

INSERT INTO tier_rules (rule_id, tier_name, tier_level, min_qualifying_miles, min_qualifying_segments, benefits, bonus_multiplier)
VALUES (seq_tier_rule_id.NEXTVAL, 'GOLD', 3, 50000, 50, 
  'Gold tier benefits: 50% bonus miles, Priority boarding, 2 free checked bags, SkyReward lounge access, Complimentary upgrades (subject to availability)', 1.5);

INSERT INTO tier_rules (rule_id, tier_name, tier_level, min_qualifying_miles, min_qualifying_segments, benefits, bonus_multiplier)
VALUES (seq_tier_rule_id.NEXTVAL, 'PLATINUM', 4, 75000, 75, 
  'Platinum tier benefits: 75% bonus miles, Dedicated check-in, 3 free checked bags, Premium lounge access, Guaranteed upgrades (economy to premium economy), Bonus award availability', 1.75);

INSERT INTO tier_rules (rule_id, tier_name, tier_level, min_qualifying_miles, min_qualifying_segments, benefits, bonus_multiplier)
VALUES (seq_tier_rule_id.NEXTVAL, 'DIAMOND', 5, 100000, 100, 
  'Diamond tier benefits: 100% bonus miles, Concierge service, Unlimited free checked bags, First class lounge access, Confirmed upgrades to business class, Priority award redemption, Global Services hotline', 2.0);

COMMIT;

SELECT tier_name, min_qualifying_miles, bonus_multiplier FROM tier_rules ORDER BY tier_level;
