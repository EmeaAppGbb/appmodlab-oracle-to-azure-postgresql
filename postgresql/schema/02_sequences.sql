-- ========================================
-- PostgreSQL Sequences for ID Generation
-- ========================================
-- Converted from Oracle sequences
-- Removed Oracle-specific NOCACHE/NOCYCLE syntax
-- These sequences are kept for backward compatibility;
-- tables can also use SERIAL/BIGSERIAL columns as an alternative.

-- Member IDs
CREATE SEQUENCE seq_member_id
  START WITH 1000000
  INCREMENT BY 1;

-- Flight record IDs
CREATE SEQUENCE seq_flight_id
  START WITH 1
  INCREMENT BY 1
  CACHE 100;

-- Redemption IDs
CREATE SEQUENCE seq_redemption_id
  START WITH 5000000
  INCREMENT BY 1
  CACHE 50;

-- Reward IDs
CREATE SEQUENCE seq_reward_id
  START WITH 1
  INCREMENT BY 1;

-- Partner transaction IDs
CREATE SEQUENCE seq_partner_txn_id
  START WITH 1
  INCREMENT BY 1
  CACHE 100;

-- Tier rule IDs
CREATE SEQUENCE seq_tier_rule_id
  START WITH 1
  INCREMENT BY 1;

-- Audit log IDs
CREATE SEQUENCE seq_audit_id
  START WITH 1
  INCREMENT BY 1
  CACHE 200;

-- Notification IDs
CREATE SEQUENCE seq_notification_id
  START WITH 1
  INCREMENT BY 1
  CACHE 100;

-- Partner IDs
CREATE SEQUENCE seq_partner_id
  START WITH 1000
  INCREMENT BY 1;

-- Miles expiry IDs
CREATE SEQUENCE seq_expiry_id
  START WITH 1
  INCREMENT BY 1;

-- Batch processing log IDs
CREATE SEQUENCE seq_batch_id
  START WITH 1
  INCREMENT BY 1;

-- Wire up default values so primary keys auto-populate from sequences
ALTER TABLE members ALTER COLUMN member_id SET DEFAULT nextval('seq_member_id');
ALTER TABLE flights ALTER COLUMN flight_id SET DEFAULT nextval('seq_flight_id');
ALTER TABLE redemptions ALTER COLUMN redemption_id SET DEFAULT nextval('seq_redemption_id');
ALTER TABLE rewards ALTER COLUMN reward_id SET DEFAULT nextval('seq_reward_id');
ALTER TABLE partner_transactions ALTER COLUMN txn_id SET DEFAULT nextval('seq_partner_txn_id');
ALTER TABLE tier_rules ALTER COLUMN rule_id SET DEFAULT nextval('seq_tier_rule_id');
ALTER TABLE audit_log ALTER COLUMN audit_id SET DEFAULT nextval('seq_audit_id');
ALTER TABLE notifications ALTER COLUMN notification_id SET DEFAULT nextval('seq_notification_id');
ALTER TABLE partners ALTER COLUMN partner_id SET DEFAULT nextval('seq_partner_id');
ALTER TABLE miles_expiry ALTER COLUMN expiry_id SET DEFAULT nextval('seq_expiry_id');
ALTER TABLE batch_processing_log ALTER COLUMN batch_id SET DEFAULT nextval('seq_batch_id');

-- Set sequence ownership so they are dropped with their tables
ALTER SEQUENCE seq_member_id OWNED BY members.member_id;
ALTER SEQUENCE seq_flight_id OWNED BY flights.flight_id;
ALTER SEQUENCE seq_redemption_id OWNED BY redemptions.redemption_id;
ALTER SEQUENCE seq_reward_id OWNED BY rewards.reward_id;
ALTER SEQUENCE seq_partner_txn_id OWNED BY partner_transactions.txn_id;
ALTER SEQUENCE seq_tier_rule_id OWNED BY tier_rules.rule_id;
ALTER SEQUENCE seq_audit_id OWNED BY audit_log.audit_id;
ALTER SEQUENCE seq_notification_id OWNED BY notifications.notification_id;
ALTER SEQUENCE seq_partner_id OWNED BY partners.partner_id;
ALTER SEQUENCE seq_expiry_id OWNED BY miles_expiry.expiry_id;
ALTER SEQUENCE seq_batch_id OWNED BY batch_processing_log.batch_id;
