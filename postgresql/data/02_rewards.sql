-- ========================================
-- Rewards Catalog Data (PostgreSQL)
-- ========================================
-- Converted from Oracle: seq.NEXTVAL -> nextval(), PL/SQL block -> plain SQL
-- Oracle columns: reward_id, name, description, category, miles_required, availability, status
-- PG columns:    reward_id, reward_code, reward_name, description, category, miles_required, quantity_available, status

-- Flight rewards
INSERT INTO rewards (reward_id, reward_code, reward_name, description, category, miles_required, quantity_available, status)
VALUES (nextval('seq_reward_id'), 'FLT-DOM-SHORT',
  'Economy Flight - Domestic Short Haul',
  'Redeem miles for a one-way economy class ticket on domestic routes under 500 miles',
  'FLIGHT', 12500, 100, 'ACTIVE');

INSERT INTO rewards (reward_id, reward_code, reward_name, description, category, miles_required, quantity_available, status)
VALUES (nextval('seq_reward_id'), 'FLT-DOM-LONG',
  'Economy Flight - Domestic Long Haul',
  'Redeem miles for a one-way economy class ticket on domestic routes over 500 miles',
  'FLIGHT', 25000, 100, 'ACTIVE');

INSERT INTO rewards (reward_id, reward_code, reward_name, description, category, miles_required, quantity_available, status)
VALUES (nextval('seq_reward_id'), 'FLT-BIZ-INTL',
  'Business Class Flight - International',
  'Redeem miles for a one-way business class ticket on international routes',
  'FLIGHT', 75000, 50, 'ACTIVE');

INSERT INTO rewards (reward_id, reward_code, reward_name, description, category, miles_required, quantity_available, status)
VALUES (nextval('seq_reward_id'), 'FLT-FIRST-INTL',
  'First Class Flight - International',
  'Redeem miles for a one-way first class ticket on long-haul international routes',
  'FLIGHT', 150000, 20, 'ACTIVE');

-- Upgrade rewards
INSERT INTO rewards (reward_id, reward_code, reward_name, description, category, miles_required, quantity_available, status)
VALUES (nextval('seq_reward_id'), 'UPG-PREM-ECON',
  'Economy to Premium Economy Upgrade',
  'Upgrade your economy ticket to premium economy on the same flight',
  'UPGRADE', 8000, 200, 'ACTIVE');

INSERT INTO rewards (reward_id, reward_code, reward_name, description, category, miles_required, quantity_available, status)
VALUES (nextval('seq_reward_id'), 'UPG-BIZ',
  'Economy to Business Class Upgrade',
  'Upgrade your economy ticket to business class on the same flight',
  'UPGRADE', 25000, 100, 'ACTIVE');

-- Hotel rewards
INSERT INTO rewards (reward_id, reward_code, reward_name, description, category, miles_required, quantity_available, status)
VALUES (nextval('seq_reward_id'), 'HTL-PREM-1N',
  'Premium Hotel Stay - 1 Night',
  'One night stay at a premium hotel at select destinations worldwide',
  'HOTEL', 20000, 500, 'ACTIVE');

INSERT INTO rewards (reward_id, reward_code, reward_name, description, category, miles_required, quantity_available, status)
VALUES (nextval('seq_reward_id'), 'HTL-LUX-3N',
  'Luxury Resort - 3 Nights',
  'Three nights at a luxury resort with breakfast included',
  'HOTEL', 50000, 100, 'ACTIVE');

-- Car rental
INSERT INTO rewards (reward_id, reward_code, reward_name, description, category, miles_required, quantity_available, status)
VALUES (nextval('seq_reward_id'), 'CAR-RENT-1W',
  'Car Rental - 1 Week',
  'One week car rental from premium car rental partners',
  'CAR_RENTAL', 15000, 300, 'ACTIVE');

-- Merchandise
INSERT INTO rewards (reward_id, reward_code, reward_name, description, category, miles_required, quantity_available, status)
VALUES (nextval('seq_reward_id'), 'MERCH-HEADPHONES',
  'Noise Cancelling Headphones',
  'Premium wireless noise cancelling headphones',
  'MERCHANDISE', 35000, 50, 'ACTIVE');

INSERT INTO rewards (reward_id, reward_code, reward_name, description, category, miles_required, quantity_available, status)
VALUES (nextval('seq_reward_id'), 'MERCH-LUGGAGE',
  'Travel Luggage Set',
  'Premium hardshell luggage set (carry-on + checked bag)',
  'MERCHANDISE', 45000, 75, 'ACTIVE');

INSERT INTO rewards (reward_id, reward_code, reward_name, description, category, miles_required, quantity_available, status)
VALUES (nextval('seq_reward_id'), 'MERCH-WATCH',
  'Smartwatch',
  'Latest model smartwatch with fitness tracking',
  'MERCHANDISE', 50000, 30, 'ACTIVE');

-- Gift cards
INSERT INTO rewards (reward_id, reward_code, reward_name, description, category, miles_required, quantity_available, status)
VALUES (nextval('seq_reward_id'), 'GC-AMZN-50',
  'Amazon Gift Card - $50',
  '$50 Amazon gift card for online shopping',
  'GIFT_CARD', 7500, 1000, 'ACTIVE');

INSERT INTO rewards (reward_id, reward_code, reward_name, description, category, miles_required, quantity_available, status)
VALUES (nextval('seq_reward_id'), 'GC-REST-100',
  'Restaurant Gift Card - $100',
  '$100 gift card for participating restaurants',
  'GIFT_CARD', 15000, 500, 'ACTIVE');

-- Experiences (mapped from Oracle 'DONATION' to PG 'EXPERIENCE')
INSERT INTO rewards (reward_id, reward_code, reward_name, description, category, miles_required, quantity_available, status)
VALUES (nextval('seq_reward_id'), 'EXP-CHARITY-100',
  'Charity Donation - $100',
  'Donate miles equivalent to $100 to participating charities',
  'EXPERIENCE', 10000, 9999, 'ACTIVE');

SELECT category, COUNT(*) AS reward_count FROM rewards GROUP BY category ORDER BY category;
