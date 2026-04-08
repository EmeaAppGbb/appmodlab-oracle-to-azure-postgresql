-- ========================================
-- Table Definitions
-- ========================================
-- Oracle-specific data types: NUMBER, VARCHAR2, DATE, CLOB
-- Tables for SkyReward Airlines loyalty program

-- ----------------------------------------
-- Members table - Core member information
-- ----------------------------------------
CREATE TABLE members (
  member_id         NUMBER(10)      NOT NULL,
  membership_number VARCHAR2(20)    NOT NULL,
  first_name        VARCHAR2(100)   NOT NULL,
  last_name         VARCHAR2(100)   NOT NULL,
  email             VARCHAR2(255)   NOT NULL,
  phone             VARCHAR2(30),
  date_of_birth     DATE,
  gender            VARCHAR2(1),
  address_line1     VARCHAR2(255),
  address_line2     VARCHAR2(255),
  city              VARCHAR2(100),
  state_province    VARCHAR2(100),
  postal_code       VARCHAR2(20),
  country           VARCHAR2(3)     DEFAULT 'US',
  tier_status       VARCHAR2(20)    DEFAULT 'BLUE',
  total_miles       NUMBER(12)      DEFAULT 0,
  available_miles   NUMBER(12)      DEFAULT 0,
  ytd_miles         NUMBER(12)      DEFAULT 0,
  lifetime_miles    NUMBER(15)      DEFAULT 0,
  enrollment_date   DATE            DEFAULT SYSDATE,
  tier_expiry_date  DATE,
  last_activity_date DATE,
  preferred_airport VARCHAR2(5),
  preferred_language VARCHAR2(5)    DEFAULT 'en',
  communication_pref VARCHAR2(20)   DEFAULT 'EMAIL',
  status            VARCHAR2(20)    DEFAULT 'ACTIVE',
  notes             CLOB,
  created_date      DATE            DEFAULT SYSDATE,
  updated_date      DATE            DEFAULT SYSDATE,
  created_by        VARCHAR2(50)    DEFAULT USER,
  updated_by        VARCHAR2(50)    DEFAULT USER,
  CONSTRAINT pk_members PRIMARY KEY (member_id),
  CONSTRAINT uk_members_number UNIQUE (membership_number),
  CONSTRAINT uk_members_email UNIQUE (email),
  CONSTRAINT chk_members_tier CHECK (tier_status IN ('BLUE', 'SILVER', 'GOLD', 'PLATINUM', 'DIAMOND')),
  CONSTRAINT chk_members_status CHECK (status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED', 'CLOSED')),
  CONSTRAINT chk_members_gender CHECK (gender IN ('M', 'F', 'O'))
);

-- ----------------------------------------
-- Flights table - Flight activity records
-- ----------------------------------------
CREATE TABLE flights (
  flight_id         NUMBER(12)      NOT NULL,
  member_id         NUMBER(10)      NOT NULL,
  flight_number     VARCHAR2(10)    NOT NULL,
  airline_code      VARCHAR2(3)     NOT NULL,
  departure_airport VARCHAR2(5)     NOT NULL,
  arrival_airport   VARCHAR2(5)     NOT NULL,
  flight_date       DATE            NOT NULL,
  booking_class     VARCHAR2(2)     NOT NULL,
  cabin_class       VARCHAR2(20)    NOT NULL,
  ticket_number     VARCHAR2(20),
  pnr_locator       VARCHAR2(10),
  distance_miles    NUMBER(8)       NOT NULL,
  base_miles        NUMBER(8)       NOT NULL,
  bonus_miles       NUMBER(8)       DEFAULT 0,
  tier_miles        NUMBER(8)       DEFAULT 0,
  total_miles       NUMBER(8)       NOT NULL,
  fare_amount       NUMBER(10,2),
  fare_currency     VARCHAR2(3)     DEFAULT 'USD',
  accrual_status    VARCHAR2(20)    DEFAULT 'PENDING',
  processed_date    DATE,
  partner_code      VARCHAR2(10),
  status            VARCHAR2(20)    DEFAULT 'ACTIVE',
  created_date      DATE            DEFAULT SYSDATE,
  updated_date      DATE            DEFAULT SYSDATE,
  CONSTRAINT pk_flights PRIMARY KEY (flight_id),
  CONSTRAINT fk_flights_member FOREIGN KEY (member_id) REFERENCES members(member_id),
  CONSTRAINT chk_flights_cabin CHECK (cabin_class IN ('ECONOMY', 'PREMIUM_ECONOMY', 'BUSINESS', 'FIRST')),
  CONSTRAINT chk_flights_accrual CHECK (accrual_status IN ('PENDING', 'PROCESSED', 'REJECTED', 'REVERSED')),
  CONSTRAINT chk_flights_status CHECK (status IN ('ACTIVE', 'CANCELLED', 'DISPUTED'))
);

-- ----------------------------------------
-- Rewards table - Available reward catalog
-- ----------------------------------------
CREATE TABLE rewards (
  reward_id         NUMBER(10)      NOT NULL,
  reward_code       VARCHAR2(30)    NOT NULL,
  reward_name       VARCHAR2(200)   NOT NULL,
  description       CLOB,
  category          VARCHAR2(50)    NOT NULL,
  subcategory       VARCHAR2(50),
  miles_required    NUMBER(10)      NOT NULL,
  cash_copay        NUMBER(10,2)    DEFAULT 0,
  quantity_available NUMBER(8),
  min_tier_required VARCHAR2(20)    DEFAULT 'BLUE',
  partner_id        NUMBER(10),
  valid_from        DATE            DEFAULT SYSDATE,
  valid_until       DATE,
  terms_conditions  CLOB,
  image_url         VARCHAR2(500),
  status            VARCHAR2(20)    DEFAULT 'ACTIVE',
  created_date      DATE            DEFAULT SYSDATE,
  updated_date      DATE            DEFAULT SYSDATE,
  CONSTRAINT pk_rewards PRIMARY KEY (reward_id),
  CONSTRAINT uk_rewards_code UNIQUE (reward_code),
  CONSTRAINT chk_rewards_category CHECK (category IN ('FLIGHT', 'UPGRADE', 'LOUNGE', 'HOTEL', 'CAR_RENTAL', 'MERCHANDISE', 'GIFT_CARD', 'EXPERIENCE')),
  CONSTRAINT chk_rewards_status CHECK (status IN ('ACTIVE', 'INACTIVE', 'DISCONTINUED'))
);

-- ----------------------------------------
-- Redemptions table - Miles redemption records
-- ----------------------------------------
CREATE TABLE redemptions (
  redemption_id     NUMBER(12)      NOT NULL,
  member_id         NUMBER(10)      NOT NULL,
  reward_id         NUMBER(10)      NOT NULL,
  redemption_date   DATE            DEFAULT SYSDATE,
  miles_used        NUMBER(10)      NOT NULL,
  cash_paid         NUMBER(10,2)    DEFAULT 0,
  quantity          NUMBER(5)       DEFAULT 1,
  confirmation_code VARCHAR2(20),
  fulfillment_date  DATE,
  expiry_date       DATE,
  redemption_channel VARCHAR2(30)   DEFAULT 'WEB',
  status            VARCHAR2(20)    DEFAULT 'PENDING',
  notes             CLOB,
  created_date      DATE            DEFAULT SYSDATE,
  updated_date      DATE            DEFAULT SYSDATE,
  CONSTRAINT pk_redemptions PRIMARY KEY (redemption_id),
  CONSTRAINT fk_redemptions_member FOREIGN KEY (member_id) REFERENCES members(member_id),
  CONSTRAINT fk_redemptions_reward FOREIGN KEY (reward_id) REFERENCES rewards(reward_id),
  CONSTRAINT chk_redemptions_channel CHECK (redemption_channel IN ('WEB', 'MOBILE', 'CALL_CENTER', 'AIRPORT', 'PARTNER')),
  CONSTRAINT chk_redemptions_status CHECK (status IN ('PENDING', 'CONFIRMED', 'FULFILLED', 'CANCELLED', 'EXPIRED'))
);

-- ----------------------------------------
-- Partners table - Partner airline/company info
-- ----------------------------------------
CREATE TABLE partners (
  partner_id        NUMBER(10)      NOT NULL,
  partner_code      VARCHAR2(10)    NOT NULL,
  partner_name      VARCHAR2(200)   NOT NULL,
  partner_type      VARCHAR2(30)    NOT NULL,
  contact_name      VARCHAR2(200),
  contact_email     VARCHAR2(255),
  contact_phone     VARCHAR2(30),
  conversion_rate   NUMBER(5,2)     DEFAULT 1.0,
  agreement_start   DATE,
  agreement_end     DATE,
  settlement_currency VARCHAR2(3)   DEFAULT 'USD',
  status            VARCHAR2(20)    DEFAULT 'ACTIVE',
  notes             CLOB,
  created_date      DATE            DEFAULT SYSDATE,
  updated_date      DATE            DEFAULT SYSDATE,
  CONSTRAINT pk_partners PRIMARY KEY (partner_id),
  CONSTRAINT uk_partners_code UNIQUE (partner_code),
  CONSTRAINT chk_partners_type CHECK (partner_type IN ('AIRLINE', 'HOTEL', 'CAR_RENTAL', 'RETAIL', 'FINANCIAL', 'DINING')),
  CONSTRAINT chk_partners_status CHECK (status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED', 'TERMINATED'))
);

-- ----------------------------------------
-- Partner Transactions table
-- ----------------------------------------
CREATE TABLE partner_transactions (
  txn_id            NUMBER(12)      NOT NULL,
  member_id         NUMBER(10)      NOT NULL,
  partner_id        NUMBER(10)      NOT NULL,
  transaction_date  DATE            NOT NULL,
  transaction_type  VARCHAR2(20)    NOT NULL,
  partner_ref       VARCHAR2(50),
  description       VARCHAR2(500),
  amount            NUMBER(12,2),
  currency          VARCHAR2(3)     DEFAULT 'USD',
  miles_earned      NUMBER(10)      DEFAULT 0,
  miles_redeemed    NUMBER(10)      DEFAULT 0,
  conversion_rate   NUMBER(5,2),
  status            VARCHAR2(20)    DEFAULT 'PENDING',
  processed_date    DATE,
  created_date      DATE            DEFAULT SYSDATE,
  updated_date      DATE            DEFAULT SYSDATE,
  CONSTRAINT pk_partner_txn PRIMARY KEY (txn_id),
  CONSTRAINT fk_partner_txn_member FOREIGN KEY (member_id) REFERENCES members(member_id),
  CONSTRAINT fk_partner_txn_partner FOREIGN KEY (partner_id) REFERENCES partners(partner_id),
  CONSTRAINT chk_partner_txn_type CHECK (transaction_type IN ('EARN', 'REDEEM', 'TRANSFER', 'ADJUSTMENT')),
  CONSTRAINT chk_partner_txn_status CHECK (status IN ('PENDING', 'PROCESSED', 'REJECTED', 'REVERSED'))
);

-- ----------------------------------------
-- Tier Rules table - Tier qualification rules
-- ----------------------------------------
CREATE TABLE tier_rules (
  rule_id           NUMBER(10)      NOT NULL,
  tier_name         VARCHAR2(20)    NOT NULL,
  min_miles         NUMBER(10)      NOT NULL,
  min_segments      NUMBER(5)       DEFAULT 0,
  qualification_period_months NUMBER(3) DEFAULT 12,
  miles_multiplier  NUMBER(3,1)     DEFAULT 1.0,
  lounge_access     VARCHAR2(1)     DEFAULT 'N',
  priority_boarding VARCHAR2(1)     DEFAULT 'N',
  free_upgrades     NUMBER(3)       DEFAULT 0,
  bonus_miles_pct   NUMBER(5,2)     DEFAULT 0,
  bag_allowance     NUMBER(3)       DEFAULT 1,
  effective_date    DATE            DEFAULT SYSDATE,
  expiry_date       DATE,
  status            VARCHAR2(20)    DEFAULT 'ACTIVE',
  created_date      DATE            DEFAULT SYSDATE,
  updated_date      DATE            DEFAULT SYSDATE,
  CONSTRAINT pk_tier_rules PRIMARY KEY (rule_id),
  CONSTRAINT chk_tier_rules_name CHECK (tier_name IN ('BLUE', 'SILVER', 'GOLD', 'PLATINUM', 'DIAMOND')),
  CONSTRAINT chk_tier_rules_lounge CHECK (lounge_access IN ('Y', 'N')),
  CONSTRAINT chk_tier_rules_priority CHECK (priority_boarding IN ('Y', 'N'))
);

-- ----------------------------------------
-- Miles Expiry table - Track miles expiration
-- ----------------------------------------
CREATE TABLE miles_expiry (
  expiry_id         NUMBER(12)      NOT NULL,
  member_id         NUMBER(10)      NOT NULL,
  source_type       VARCHAR2(20)    NOT NULL,
  source_id         NUMBER(12),
  miles_amount      NUMBER(10)      NOT NULL,
  earned_date       DATE            NOT NULL,
  expiry_date       DATE            NOT NULL,
  expired_miles     NUMBER(10)      DEFAULT 0,
  status            VARCHAR2(20)    DEFAULT 'ACTIVE',
  batch_id          NUMBER(12),
  processed_date    DATE,
  created_date      DATE            DEFAULT SYSDATE,
  CONSTRAINT pk_miles_expiry PRIMARY KEY (expiry_id),
  CONSTRAINT fk_miles_expiry_member FOREIGN KEY (member_id) REFERENCES members(member_id),
  CONSTRAINT chk_miles_expiry_source CHECK (source_type IN ('FLIGHT', 'PARTNER', 'BONUS', 'PROMOTION', 'ADJUSTMENT')),
  CONSTRAINT chk_miles_expiry_status CHECK (status IN ('ACTIVE', 'EXPIRED', 'USED', 'EXTENDED'))
);

-- ----------------------------------------
-- Audit Log table
-- ----------------------------------------
CREATE TABLE audit_log (
  audit_id          NUMBER(12)      NOT NULL,
  table_name        VARCHAR2(50)    NOT NULL,
  operation         VARCHAR2(10)    NOT NULL,
  record_id         NUMBER(12),
  member_id         NUMBER(10),
  old_values        CLOB,
  new_values        CLOB,
  changed_by        VARCHAR2(50)    DEFAULT USER,
  changed_date      DATE            DEFAULT SYSDATE,
  ip_address        VARCHAR2(45),
  session_id        NUMBER(12),
  CONSTRAINT pk_audit_log PRIMARY KEY (audit_id),
  CONSTRAINT chk_audit_operation CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE'))
);

-- ----------------------------------------
-- Notifications table
-- ----------------------------------------
CREATE TABLE notifications (
  notification_id   NUMBER(12)      NOT NULL,
  member_id         NUMBER(10)      NOT NULL,
  notification_type VARCHAR2(50)    NOT NULL,
  channel           VARCHAR2(20)    DEFAULT 'EMAIL',
  subject           VARCHAR2(500),
  body              CLOB,
  priority          NUMBER(1)       DEFAULT 3,
  status            VARCHAR2(20)    DEFAULT 'PENDING',
  scheduled_date    DATE,
  sent_date         DATE,
  retry_count       NUMBER(3)       DEFAULT 0,
  error_message     VARCHAR2(1000),
  created_date      DATE            DEFAULT SYSDATE,
  updated_date      DATE            DEFAULT SYSDATE,
  CONSTRAINT pk_notifications PRIMARY KEY (notification_id),
  CONSTRAINT fk_notifications_member FOREIGN KEY (member_id) REFERENCES members(member_id),
  CONSTRAINT chk_notif_type CHECK (notification_type IN ('TIER_CHANGE', 'MILES_EXPIRY', 'REDEMPTION_CONFIRM', 'WELCOME', 'PROMOTION', 'STATEMENT', 'ALERT')),
  CONSTRAINT chk_notif_channel CHECK (channel IN ('EMAIL', 'SMS', 'PUSH', 'MAIL')),
  CONSTRAINT chk_notif_status CHECK (status IN ('PENDING', 'SENT', 'FAILED', 'CANCELLED'))
);

-- ----------------------------------------
-- Batch Processing Log table
-- ----------------------------------------
CREATE TABLE batch_processing_log (
  batch_id          NUMBER(12)      NOT NULL,
  batch_type        VARCHAR2(50)    NOT NULL,
  batch_name        VARCHAR2(200),
  start_time        DATE            NOT NULL,
  end_time          DATE,
  records_processed NUMBER(10)      DEFAULT 0,
  records_succeeded NUMBER(10)      DEFAULT 0,
  records_failed    NUMBER(10)      DEFAULT 0,
  status            VARCHAR2(20)    DEFAULT 'RUNNING',
  error_message     CLOB,
  parameters        CLOB,
  run_by            VARCHAR2(50)    DEFAULT USER,
  created_date      DATE            DEFAULT SYSDATE,
  CONSTRAINT pk_batch_log PRIMARY KEY (batch_id),
  CONSTRAINT chk_batch_type CHECK (batch_type IN ('MILES_EXPIRY', 'TIER_RECALC', 'STATEMENT_GEN', 'DATA_CLEANUP', 'PARTNER_SETTLEMENT', 'BULK_ACCRUAL')),
  CONSTRAINT chk_batch_status CHECK (status IN ('RUNNING', 'COMPLETED', 'FAILED', 'CANCELLED'))
);

COMMIT;
