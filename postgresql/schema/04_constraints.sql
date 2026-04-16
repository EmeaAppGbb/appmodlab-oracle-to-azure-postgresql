-- ========================================
-- Additional Constraints
-- ========================================
-- All primary keys, foreign keys, unique constraints, and check constraints
-- are defined inline in 01_tables.sql.
--
-- This file is reserved for any additional constraints that may be needed
-- during migration, such as cross-table constraints or deferred constraints.

-- Example: Add foreign key for rewards.partner_id -> partners.partner_id
-- (not in the original Oracle schema but logically implied)
ALTER TABLE rewards
  ADD CONSTRAINT fk_rewards_partner
  FOREIGN KEY (partner_id) REFERENCES partners(partner_id);

-- Example: Add foreign key for miles_expiry.batch_id -> batch_processing_log.batch_id
ALTER TABLE miles_expiry
  ADD CONSTRAINT fk_miles_expiry_batch
  FOREIGN KEY (batch_id) REFERENCES batch_processing_log(batch_id);
