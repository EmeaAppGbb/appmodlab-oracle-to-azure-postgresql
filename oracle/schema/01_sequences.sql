-- ========================================
-- Sequences for ID Generation
-- ========================================
-- Oracle sequences for primary key generation
-- These will be converted to SERIAL/BIGSERIAL in PostgreSQL

-- Member IDs
CREATE SEQUENCE seq_member_id
  START WITH 1000000
  INCREMENT BY 1
  NOCACHE
  NOCYCLE;

-- Flight record IDs
CREATE SEQUENCE seq_flight_id
  START WITH 1
  INCREMENT BY 1
  CACHE 100
  NOCYCLE;

-- Redemption IDs
CREATE SEQUENCE seq_redemption_id
  START WITH 5000000
  INCREMENT BY 1
  CACHE 50
  NOCYCLE;

-- Reward IDs
CREATE SEQUENCE seq_reward_id
  START WITH 1
  INCREMENT BY 1
  NOCACHE
  NOCYCLE;

-- Partner transaction IDs
CREATE SEQUENCE seq_partner_txn_id
  START WITH 1
  INCREMENT BY 1
  CACHE 100
  NOCYCLE;

-- Tier rule IDs
CREATE SEQUENCE seq_tier_rule_id
  START WITH 1
  INCREMENT BY 1
  NOCACHE
  NOCYCLE;

-- Audit log IDs
CREATE SEQUENCE seq_audit_id
  START WITH 1
  INCREMENT BY 1
  CACHE 200
  NOCYCLE;

-- Notification IDs
CREATE SEQUENCE seq_notification_id
  START WITH 1
  INCREMENT BY 1
  CACHE 100
  NOCYCLE;

-- Partner IDs
CREATE SEQUENCE seq_partner_id
  START WITH 1000
  INCREMENT BY 1
  NOCACHE
  NOCYCLE;

-- Miles expiry batch IDs
CREATE SEQUENCE seq_expiry_batch_id
  START WITH 1
  INCREMENT BY 1
  NOCACHE
  NOCYCLE;

COMMIT;
