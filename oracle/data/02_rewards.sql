-- ========================================
-- Rewards Catalog Data
-- ========================================
-- Sample rewards for redemption

BEGIN
  -- Flight rewards
  INSERT INTO rewards (reward_id, name, description, category, miles_required, availability, status)
  VALUES (seq_reward_id.NEXTVAL, 'Economy Flight - Domestic Short Haul', 
    'Redeem miles for a one-way economy class ticket on domestic routes under 500 miles', 
    'FLIGHT', 12500, 100, 'AVAILABLE');
  
  INSERT INTO rewards (reward_id, name, description, category, miles_required, availability, status)
  VALUES (seq_reward_id.NEXTVAL, 'Economy Flight - Domestic Long Haul', 
    'Redeem miles for a one-way economy class ticket on domestic routes over 500 miles', 
    'FLIGHT', 25000, 100, 'AVAILABLE');
  
  INSERT INTO rewards (reward_id, name, description, category, miles_required, availability, status)
  VALUES (seq_reward_id.NEXTVAL, 'Business Class Flight - International', 
    'Redeem miles for a one-way business class ticket on international routes', 
    'FLIGHT', 75000, 50, 'AVAILABLE');
  
  INSERT INTO rewards (reward_id, name, description, category, miles_required, availability, status)
  VALUES (seq_reward_id.NEXTVAL, 'First Class Flight - International', 
    'Redeem miles for a one-way first class ticket on long-haul international routes', 
    'FLIGHT', 150000, 20, 'LIMITED');
  
  -- Upgrade rewards
  INSERT INTO rewards (reward_id, name, description, category, miles_required, availability, status)
  VALUES (seq_reward_id.NEXTVAL, 'Economy to Premium Economy Upgrade', 
    'Upgrade your economy ticket to premium economy on the same flight', 
    'UPGRADE', 8000, 200, 'AVAILABLE');
  
  INSERT INTO rewards (reward_id, name, description, category, miles_required, availability, status)
  VALUES (seq_reward_id.NEXTVAL, 'Economy to Business Class Upgrade', 
    'Upgrade your economy ticket to business class on the same flight', 
    'UPGRADE', 25000, 100, 'AVAILABLE');
  
  -- Hotel rewards
  INSERT INTO rewards (reward_id, name, description, category, miles_required, availability, status)
  VALUES (seq_reward_id.NEXTVAL, 'Premium Hotel Stay - 1 Night', 
    'One night stay at a premium hotel at select destinations worldwide', 
    'HOTEL', 20000, 500, 'AVAILABLE');
  
  INSERT INTO rewards (reward_id, name, description, category, miles_required, availability, status)
  VALUES (seq_reward_id.NEXTVAL, 'Luxury Resort - 3 Nights', 
    'Three nights at a luxury resort with breakfast included', 
    'HOTEL', 50000, 100, 'AVAILABLE');
  
  -- Car rental
  INSERT INTO rewards (reward_id, name, description, category, miles_required, availability, status)
  VALUES (seq_reward_id.NEXTVAL, 'Car Rental - 1 Week', 
    'One week car rental from premium car rental partners', 
    'CAR', 15000, 300, 'AVAILABLE');
  
  -- Merchandise
  INSERT INTO rewards (reward_id, name, description, category, miles_required, availability, status)
  VALUES (seq_reward_id.NEXTVAL, 'Noise Cancelling Headphones', 
    'Premium wireless noise cancelling headphones', 
    'MERCHANDISE', 35000, 50, 'AVAILABLE');
  
  INSERT INTO rewards (reward_id, name, description, category, miles_required, availability, status)
  VALUES (seq_reward_id.NEXTVAL, 'Travel Luggage Set', 
    'Premium hardshell luggage set (carry-on + checked bag)', 
    'MERCHANDISE', 45000, 75, 'AVAILABLE');
  
  INSERT INTO rewards (reward_id, name, description, category, miles_required, availability, status)
  VALUES (seq_reward_id.NEXTVAL, 'Smartwatch', 
    'Latest model smartwatch with fitness tracking', 
    'MERCHANDISE', 50000, 30, 'LIMITED');
  
  -- Gift cards
  INSERT INTO rewards (reward_id, name, description, category, miles_required, availability, status)
  VALUES (seq_reward_id.NEXTVAL, 'Amazon Gift Card - $50', 
    '$50 Amazon gift card for online shopping', 
    'GIFT_CARD', 7500, 1000, 'AVAILABLE');
  
  INSERT INTO rewards (reward_id, name, description, category, miles_required, availability, status)
  VALUES (seq_reward_id.NEXTVAL, 'Restaurant Gift Card - $100', 
    '$100 gift card for participating restaurants', 
    'GIFT_CARD', 15000, 500, 'AVAILABLE');
  
  -- Donations
  INSERT INTO rewards (reward_id, name, description, category, miles_required, availability, status)
  VALUES (seq_reward_id.NEXTVAL, 'Charity Donation - $100', 
    'Donate miles equivalent to $100 to participating charities', 
    'DONATION', 10000, 9999, 'AVAILABLE');
  
  COMMIT;
END;
/

SELECT category, COUNT(*) AS reward_count FROM rewards GROUP BY category ORDER BY category;
