-- ========================================
-- PostgreSQL Table Definitions
-- ========================================
-- Converted from Oracle-specific data types to PostgreSQL equivalents
-- Tables for SkyReward Airlines loyalty program
--
-- Conversion notes:
--   NUMBER(n)       -> INTEGER (n <= 9), BIGINT (n > 9)
--   NUMBER(n,m)     -> NUMERIC(n,m)
--   VARCHAR2(n)     -> VARCHAR(n)
--   CLOB            -> TEXT
--   DATE            -> TIMESTAMP (Oracle DATE includes time component)
--   SYSDATE         -> CURRENT_TIMESTAMP
--   USER            -> CURRENT_USER
--   Primary keys use SERIAL/BIGSERIAL for auto-increment

-- ----------------------------------------
-- Members table - Core member information
-- ----------------------------------------
CREATE TABLE members (
  member_id         INTEGER       NOT NULL,
  membership_number VARCHAR(20)   NOT NULL,
  first_name        VARCHAR(100)  NOT NULL,
  last_name         VARCHAR(100)  NOT NULL,
  email             VARCHAR(255)  NOT NULL,
  phone             VARCHAR(30),
  date_of_birth     DATE,
  gender            VARCHAR(1),
  address_line1     VARCHAR(255),
  address_line2     VARCHAR(255),
  city              VARCHAR(100),
  state_province    VARCHAR(100),
  postal_code       VARCHAR(20),
  country           VARCHAR(3)    DEFAULT 'US',
  tier_status       VARCHAR(20)   DEFAULT 'BLUE',
  total_miles       BIGINT        DEFAULT 0,
  available_miles   BIGINT        DEFAULT 0,
  ytd_miles         BIGINT        DEFAULT 0,
  lifetime_miles    BIGINT        DEFAULT 0,
  enrollment_date   TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
  tier_expiry_date  TIMESTAMP,
  last_activity_date TIMESTAMP,
  preferred_airport VARCHAR(5),
  preferred_language VARCHAR(5)   DEFAULT 'en',
  communication_pref VARCHAR(20)  DEFAULT 'EMAIL',
  status            VARCHAR(20)   DEFAULT 'ACTIVE',
  notes             TEXT,
  created_date      TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
  updated_date      TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
  created_by        VARCHAR(50)   DEFAULT CURRENT_USER,
  updated_by        VARCHAR(50)   DEFAULT CURRENT_USER,
  CONSTRAINT pk_members PRIMARY KEY (member_id),
  CONSTRAINT uk_members_number UNIQUE (membership_number),
  CONSTRAINT uk_members_email UNIQUE (email),
  CONSTRAINT chk_members_tier CHECK (tier_status IN ('BLUE', 'SILVER', 'GOLD', 'PLATINUM', 'DIAMOND')),
  CONSTRAINT chk_members_status CHECK (status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED', 'CLOSED')),
  CONSTRAINT chk_members_gender CHECK (gender IN ('M', 'F', 'O'))
);

COMMENT ON TABLE members IS 'Core member table for SkyReward Airlines loyalty program. Stores member profile, contact info, and loyalty status.';
COMMENT ON COLUMN members.member_id IS 'Unique member identifier, generated from seq_member_id';
COMMENT ON COLUMN members.membership_number IS 'Public-facing membership number displayed on loyalty card';
COMMENT ON COLUMN members.first_name IS 'Member first name as on government-issued ID';
COMMENT ON COLUMN members.last_name IS 'Member last name as on government-issued ID';
COMMENT ON COLUMN members.email IS 'Primary email address for account communications';
COMMENT ON COLUMN members.tier_status IS 'Current tier: BLUE, SILVER, GOLD, PLATINUM, or DIAMOND';
COMMENT ON COLUMN members.total_miles IS 'Total lifetime miles earned (never decreases)';
COMMENT ON COLUMN members.available_miles IS 'Current redeemable miles balance';
COMMENT ON COLUMN members.ytd_miles IS 'Year-to-date qualifying miles for tier calculation';
COMMENT ON COLUMN members.lifetime_miles IS 'Cumulative lifetime miles across all years';
COMMENT ON COLUMN members.enrollment_date IS 'Date member first enrolled in the loyalty program';
COMMENT ON COLUMN members.tier_expiry_date IS 'Date current tier status expires for re-evaluation';
COMMENT ON COLUMN members.last_activity_date IS 'Date of last qualifying activity (flight, redemption, etc.)';
COMMENT ON COLUMN members.preferred_airport IS 'IATA code for member preferred home airport';
COMMENT ON COLUMN members.status IS 'Account status: ACTIVE, INACTIVE, SUSPENDED, or CLOSED';
COMMENT ON COLUMN members.notes IS 'Free-text notes about the member account';

-- ----------------------------------------
-- Flights table - Flight activity records
-- ----------------------------------------
CREATE TABLE flights (
  flight_id         BIGINT        NOT NULL,
  member_id         INTEGER       NOT NULL,
  flight_number     VARCHAR(10)   NOT NULL,
  airline_code      VARCHAR(3)    NOT NULL,
  departure_airport VARCHAR(5)    NOT NULL,
  arrival_airport   VARCHAR(5)    NOT NULL,
  flight_date       TIMESTAMP     NOT NULL,
  booking_class     VARCHAR(2)    NOT NULL,
  cabin_class       VARCHAR(20)   NOT NULL,
  ticket_number     VARCHAR(20),
  pnr_locator       VARCHAR(10),
  distance_miles    INTEGER       NOT NULL,
  base_miles        INTEGER       NOT NULL,
  bonus_miles       INTEGER       DEFAULT 0,
  tier_miles        INTEGER       DEFAULT 0,
  total_miles       INTEGER       NOT NULL,
  fare_amount       NUMERIC(10,2),
  fare_currency     VARCHAR(3)    DEFAULT 'USD',
  accrual_status    VARCHAR(20)   DEFAULT 'PENDING',
  processed_date    TIMESTAMP,
  partner_code      VARCHAR(10),
  status            VARCHAR(20)   DEFAULT 'ACTIVE',
  created_date      TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
  updated_date      TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pk_flights PRIMARY KEY (flight_id),
  CONSTRAINT fk_flights_member FOREIGN KEY (member_id) REFERENCES members(member_id),
  CONSTRAINT chk_flights_cabin CHECK (cabin_class IN ('ECONOMY', 'PREMIUM_ECONOMY', 'BUSINESS', 'FIRST')),
  CONSTRAINT chk_flights_accrual CHECK (accrual_status IN ('PENDING', 'PROCESSED', 'REJECTED', 'REVERSED')),
  CONSTRAINT chk_flights_status CHECK (status IN ('ACTIVE', 'CANCELLED', 'DISPUTED'))
);

COMMENT ON TABLE flights IS 'Flight activity records for miles accrual. Each row represents one flight segment taken by a member.';
COMMENT ON COLUMN flights.flight_id IS 'Unique flight record identifier, generated from seq_flight_id';
COMMENT ON COLUMN flights.member_id IS 'Reference to the member who took this flight';
COMMENT ON COLUMN flights.flight_number IS 'Airline flight number (e.g., SR1234)';
COMMENT ON COLUMN flights.airline_code IS 'IATA airline code (e.g., SR for SkyReward)';
COMMENT ON COLUMN flights.departure_airport IS 'IATA code of departure airport';
COMMENT ON COLUMN flights.arrival_airport IS 'IATA code of arrival airport';
COMMENT ON COLUMN flights.booking_class IS 'Fare booking class letter code (e.g., Y, B, M)';
COMMENT ON COLUMN flights.cabin_class IS 'Cabin class: ECONOMY, PREMIUM_ECONOMY, BUSINESS, or FIRST';
COMMENT ON COLUMN flights.distance_miles IS 'Great-circle distance of the flight segment in miles';
COMMENT ON COLUMN flights.base_miles IS 'Base miles earned from distance and booking class';
COMMENT ON COLUMN flights.bonus_miles IS 'Additional bonus miles from tier status or promotions';
COMMENT ON COLUMN flights.tier_miles IS 'Qualifying miles that count toward tier status';
COMMENT ON COLUMN flights.total_miles IS 'Total miles credited: base + bonus';
COMMENT ON COLUMN flights.accrual_status IS 'Processing status: PENDING, PROCESSED, REJECTED, REVERSED';

-- ----------------------------------------
-- Rewards table - Available reward catalog
-- ----------------------------------------
CREATE TABLE rewards (
  reward_id         INTEGER       NOT NULL,
  reward_code       VARCHAR(30)   NOT NULL,
  reward_name       VARCHAR(200)  NOT NULL,
  description       TEXT,
  category          VARCHAR(50)   NOT NULL,
  subcategory       VARCHAR(50),
  miles_required    INTEGER       NOT NULL,
  cash_copay        NUMERIC(10,2) DEFAULT 0,
  quantity_available INTEGER,
  min_tier_required VARCHAR(20)   DEFAULT 'BLUE',
  partner_id        INTEGER,
  valid_from        TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
  valid_until       TIMESTAMP,
  terms_conditions  TEXT,
  image_url         VARCHAR(500),
  status            VARCHAR(20)   DEFAULT 'ACTIVE',
  created_date      TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
  updated_date      TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pk_rewards PRIMARY KEY (reward_id),
  CONSTRAINT uk_rewards_code UNIQUE (reward_code),
  CONSTRAINT chk_rewards_category CHECK (category IN ('FLIGHT', 'UPGRADE', 'LOUNGE', 'HOTEL', 'CAR_RENTAL', 'MERCHANDISE', 'GIFT_CARD', 'EXPERIENCE')),
  CONSTRAINT chk_rewards_status CHECK (status IN ('ACTIVE', 'INACTIVE', 'DISCONTINUED'))
);

COMMENT ON TABLE rewards IS 'Reward catalog available for miles redemption. Includes flights, upgrades, merchandise, and partner rewards.';
COMMENT ON COLUMN rewards.reward_id IS 'Unique reward identifier, generated from seq_reward_id';
COMMENT ON COLUMN rewards.reward_code IS 'Short code for the reward used in APIs and displays';
COMMENT ON COLUMN rewards.reward_name IS 'Display name of the reward';
COMMENT ON COLUMN rewards.description IS 'Full description of the reward';
COMMENT ON COLUMN rewards.category IS 'Reward category: FLIGHT, UPGRADE, LOUNGE, HOTEL, CAR_RENTAL, MERCHANDISE, GIFT_CARD, EXPERIENCE';
COMMENT ON COLUMN rewards.miles_required IS 'Number of miles required to redeem this reward';
COMMENT ON COLUMN rewards.min_tier_required IS 'Minimum tier status required to access this reward';
COMMENT ON COLUMN rewards.quantity_available IS 'Remaining inventory count, NULL for unlimited';

-- ----------------------------------------
-- Redemptions table - Miles redemption records
-- ----------------------------------------
CREATE TABLE redemptions (
  redemption_id     BIGINT        NOT NULL,
  member_id         INTEGER       NOT NULL,
  reward_id         INTEGER       NOT NULL,
  redemption_date   TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
  miles_used        INTEGER       NOT NULL,
  cash_paid         NUMERIC(10,2) DEFAULT 0,
  quantity          INTEGER       DEFAULT 1,
  confirmation_code VARCHAR(20),
  fulfillment_date  TIMESTAMP,
  expiry_date       TIMESTAMP,
  redemption_channel VARCHAR(30)  DEFAULT 'WEB',
  status            VARCHAR(20)   DEFAULT 'PENDING',
  notes             TEXT,
  created_date      TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
  updated_date      TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pk_redemptions PRIMARY KEY (redemption_id),
  CONSTRAINT fk_redemptions_member FOREIGN KEY (member_id) REFERENCES members(member_id),
  CONSTRAINT fk_redemptions_reward FOREIGN KEY (reward_id) REFERENCES rewards(reward_id),
  CONSTRAINT chk_redemptions_channel CHECK (redemption_channel IN ('WEB', 'MOBILE', 'CALL_CENTER', 'AIRPORT', 'PARTNER')),
  CONSTRAINT chk_redemptions_status CHECK (status IN ('PENDING', 'CONFIRMED', 'FULFILLED', 'CANCELLED', 'EXPIRED'))
);

COMMENT ON TABLE redemptions IS 'Records of reward redemptions by members. Tracks the lifecycle from request to fulfillment.';
COMMENT ON COLUMN redemptions.redemption_id IS 'Unique redemption identifier, generated from seq_redemption_id';
COMMENT ON COLUMN redemptions.member_id IS 'Reference to the redeeming member';
COMMENT ON COLUMN redemptions.reward_id IS 'Reference to the redeemed reward';
COMMENT ON COLUMN redemptions.miles_used IS 'Number of miles deducted for this redemption';
COMMENT ON COLUMN redemptions.cash_paid IS 'Any cash co-payment amount';
COMMENT ON COLUMN redemptions.confirmation_code IS 'Unique confirmation code sent to the member';
COMMENT ON COLUMN redemptions.status IS 'Redemption lifecycle status: PENDING, CONFIRMED, FULFILLED, CANCELLED, EXPIRED';

-- ----------------------------------------
-- Partners table - Partner airline/company info
-- ----------------------------------------
CREATE TABLE partners (
  partner_id        INTEGER       NOT NULL,
  partner_code      VARCHAR(10)   NOT NULL,
  partner_name      VARCHAR(200)  NOT NULL,
  partner_type      VARCHAR(30)   NOT NULL,
  contact_name      VARCHAR(200),
  contact_email     VARCHAR(255),
  contact_phone     VARCHAR(30),
  conversion_rate   NUMERIC(5,2)  DEFAULT 1.0,
  agreement_start   TIMESTAMP,
  agreement_end     TIMESTAMP,
  settlement_currency VARCHAR(3)  DEFAULT 'USD',
  status            VARCHAR(20)   DEFAULT 'ACTIVE',
  notes             TEXT,
  created_date      TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
  updated_date      TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pk_partners PRIMARY KEY (partner_id),
  CONSTRAINT uk_partners_code UNIQUE (partner_code),
  CONSTRAINT chk_partners_type CHECK (partner_type IN ('AIRLINE', 'HOTEL', 'CAR_RENTAL', 'RETAIL', 'FINANCIAL', 'DINING')),
  CONSTRAINT chk_partners_status CHECK (status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED', 'TERMINATED'))
);

COMMENT ON TABLE partners IS 'Partner airlines, hotels, and companies participating in the SkyReward loyalty ecosystem.';
COMMENT ON COLUMN partners.partner_id IS 'Unique partner identifier, generated from seq_partner_id';
COMMENT ON COLUMN partners.partner_code IS 'Short unique code identifying the partner';
COMMENT ON COLUMN partners.partner_type IS 'Type of partner: AIRLINE, HOTEL, CAR_RENTAL, RETAIL, FINANCIAL, DINING';
COMMENT ON COLUMN partners.conversion_rate IS 'Miles conversion rate relative to SkyReward base miles';

-- ----------------------------------------
-- Partner Transactions table
-- ----------------------------------------
CREATE TABLE partner_transactions (
  txn_id            BIGINT        NOT NULL,
  member_id         INTEGER       NOT NULL,
  partner_id        INTEGER       NOT NULL,
  transaction_date  TIMESTAMP     NOT NULL,
  transaction_type  VARCHAR(20)   NOT NULL,
  partner_ref       VARCHAR(50),
  description       VARCHAR(500),
  amount            NUMERIC(12,2),
  currency          VARCHAR(3)    DEFAULT 'USD',
  miles_earned      INTEGER       DEFAULT 0,
  miles_redeemed    INTEGER       DEFAULT 0,
  conversion_rate   NUMERIC(5,2),
  status            VARCHAR(20)   DEFAULT 'PENDING',
  processed_date    TIMESTAMP,
  created_date      TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
  updated_date      TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pk_partner_txn PRIMARY KEY (txn_id),
  CONSTRAINT fk_partner_txn_member FOREIGN KEY (member_id) REFERENCES members(member_id),
  CONSTRAINT fk_partner_txn_partner FOREIGN KEY (partner_id) REFERENCES partners(partner_id),
  CONSTRAINT chk_partner_txn_type CHECK (transaction_type IN ('EARN', 'REDEEM', 'TRANSFER', 'ADJUSTMENT')),
  CONSTRAINT chk_partner_txn_status CHECK (status IN ('PENDING', 'PROCESSED', 'REJECTED', 'REVERSED'))
);

COMMENT ON TABLE partner_transactions IS 'Cross-partner earning and redemption transactions. Tracks miles flow between SkyReward and partners.';
COMMENT ON COLUMN partner_transactions.txn_id IS 'Unique transaction identifier, generated from seq_partner_txn_id';
COMMENT ON COLUMN partner_transactions.transaction_type IS 'Transaction type: EARN, REDEEM, TRANSFER, ADJUSTMENT';
COMMENT ON COLUMN partner_transactions.miles_earned IS 'Miles earned through this partner transaction';
COMMENT ON COLUMN partner_transactions.miles_redeemed IS 'Miles redeemed through this partner transaction';
COMMENT ON COLUMN partner_transactions.conversion_rate IS 'Applied conversion rate at time of transaction';

-- ----------------------------------------
-- Tier Rules table - Tier qualification rules
-- ----------------------------------------
CREATE TABLE tier_rules (
  rule_id           INTEGER       NOT NULL,
  tier_name         VARCHAR(20)   NOT NULL,
  min_miles         INTEGER       NOT NULL,
  min_segments      INTEGER       DEFAULT 0,
  qualification_period_months INTEGER DEFAULT 12,
  miles_multiplier  NUMERIC(3,1)  DEFAULT 1.0,
  lounge_access     VARCHAR(1)    DEFAULT 'N',
  priority_boarding VARCHAR(1)    DEFAULT 'N',
  free_upgrades     INTEGER       DEFAULT 0,
  bonus_miles_pct   NUMERIC(5,2)  DEFAULT 0,
  bag_allowance     INTEGER       DEFAULT 1,
  effective_date    TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
  expiry_date       TIMESTAMP,
  status            VARCHAR(20)   DEFAULT 'ACTIVE',
  created_date      TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
  updated_date      TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pk_tier_rules PRIMARY KEY (rule_id),
  CONSTRAINT chk_tier_rules_name CHECK (tier_name IN ('BLUE', 'SILVER', 'GOLD', 'PLATINUM', 'DIAMOND')),
  CONSTRAINT chk_tier_rules_lounge CHECK (lounge_access IN ('Y', 'N')),
  CONSTRAINT chk_tier_rules_priority CHECK (priority_boarding IN ('Y', 'N'))
);

COMMENT ON TABLE tier_rules IS 'Tier qualification rules defining requirements and benefits for each loyalty tier level.';
COMMENT ON COLUMN tier_rules.rule_id IS 'Unique rule identifier, generated from seq_tier_rule_id';
COMMENT ON COLUMN tier_rules.tier_name IS 'Tier level: BLUE, SILVER, GOLD, PLATINUM, DIAMOND';
COMMENT ON COLUMN tier_rules.min_miles IS 'Minimum qualifying miles required for this tier';
COMMENT ON COLUMN tier_rules.min_segments IS 'Minimum qualifying flight segments required';
COMMENT ON COLUMN tier_rules.qualification_period_months IS 'Rolling period in months for qualification';
COMMENT ON COLUMN tier_rules.miles_multiplier IS 'Earning multiplier for this tier (e.g., 1.5x for Gold)';
COMMENT ON COLUMN tier_rules.bonus_miles_pct IS 'Percentage of bonus miles on top of base earn rate';

-- ----------------------------------------
-- Miles Expiry table - Track miles expiration
-- ----------------------------------------
CREATE TABLE miles_expiry (
  expiry_id         BIGINT        NOT NULL,
  member_id         INTEGER       NOT NULL,
  source_type       VARCHAR(20)   NOT NULL,
  source_id         BIGINT,
  miles_amount      INTEGER       NOT NULL,
  earned_date       TIMESTAMP     NOT NULL,
  expiry_date       TIMESTAMP     NOT NULL,
  expired_miles     INTEGER       DEFAULT 0,
  status            VARCHAR(20)   DEFAULT 'ACTIVE',
  batch_id          BIGINT,
  processed_date    TIMESTAMP,
  created_date      TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pk_miles_expiry PRIMARY KEY (expiry_id),
  CONSTRAINT fk_miles_expiry_member FOREIGN KEY (member_id) REFERENCES members(member_id),
  CONSTRAINT chk_miles_expiry_source CHECK (source_type IN ('FLIGHT', 'PARTNER', 'BONUS', 'PROMOTION', 'ADJUSTMENT')),
  CONSTRAINT chk_miles_expiry_status CHECK (status IN ('ACTIVE', 'EXPIRED', 'USED', 'EXTENDED'))
);

COMMENT ON TABLE miles_expiry IS 'Tracks individual miles batches and their expiration dates. Used by the miles expiry batch job.';
COMMENT ON COLUMN miles_expiry.expiry_id IS 'Unique expiry record identifier';
COMMENT ON COLUMN miles_expiry.source_type IS 'How the miles were earned: FLIGHT, PARTNER, BONUS, PROMOTION, ADJUSTMENT';
COMMENT ON COLUMN miles_expiry.miles_amount IS 'Original miles amount in this batch';
COMMENT ON COLUMN miles_expiry.expired_miles IS 'Miles that have been expired from this batch';
COMMENT ON COLUMN miles_expiry.batch_id IS 'Reference to the batch job that processed expiry';

-- ----------------------------------------
-- Audit Log table
-- ----------------------------------------
CREATE TABLE audit_log (
  audit_id          BIGINT        NOT NULL,
  table_name        VARCHAR(50)   NOT NULL,
  operation         VARCHAR(10)   NOT NULL,
  record_id         BIGINT,
  member_id         INTEGER,
  old_values        TEXT,
  new_values        TEXT,
  changed_by        VARCHAR(50)   DEFAULT CURRENT_USER,
  changed_date      TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
  ip_address        VARCHAR(45),
  session_id        BIGINT,
  CONSTRAINT pk_audit_log PRIMARY KEY (audit_id),
  CONSTRAINT chk_audit_operation CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE'))
);

COMMENT ON TABLE audit_log IS 'Audit trail for all data changes across loyalty program tables. Populated by database triggers.';
COMMENT ON COLUMN audit_log.audit_id IS 'Unique audit record identifier, generated from seq_audit_id';
COMMENT ON COLUMN audit_log.table_name IS 'Name of the table where the change occurred';
COMMENT ON COLUMN audit_log.operation IS 'DML operation: INSERT, UPDATE, or DELETE';
COMMENT ON COLUMN audit_log.old_values IS 'JSON representation of old column values';
COMMENT ON COLUMN audit_log.new_values IS 'JSON representation of new column values';

-- ----------------------------------------
-- Notifications table
-- ----------------------------------------
CREATE TABLE notifications (
  notification_id   BIGINT        NOT NULL,
  member_id         INTEGER       NOT NULL,
  notification_type VARCHAR(50)   NOT NULL,
  channel           VARCHAR(20)   DEFAULT 'EMAIL',
  subject           VARCHAR(500),
  body              TEXT,
  priority          INTEGER       DEFAULT 3,
  status            VARCHAR(20)   DEFAULT 'PENDING',
  scheduled_date    TIMESTAMP,
  sent_date         TIMESTAMP,
  retry_count       INTEGER       DEFAULT 0,
  error_message     VARCHAR(1000),
  created_date      TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
  updated_date      TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pk_notifications PRIMARY KEY (notification_id),
  CONSTRAINT fk_notifications_member FOREIGN KEY (member_id) REFERENCES members(member_id),
  CONSTRAINT chk_notif_type CHECK (notification_type IN ('TIER_CHANGE', 'MILES_EXPIRY', 'REDEMPTION_CONFIRM', 'WELCOME', 'PROMOTION', 'STATEMENT', 'ALERT')),
  CONSTRAINT chk_notif_channel CHECK (channel IN ('EMAIL', 'SMS', 'PUSH', 'MAIL')),
  CONSTRAINT chk_notif_status CHECK (status IN ('PENDING', 'SENT', 'FAILED', 'CANCELLED'))
);

COMMENT ON TABLE notifications IS 'Outbound notification queue for member communications including emails, SMS, and push notifications.';
COMMENT ON COLUMN notifications.notification_id IS 'Unique notification identifier, generated from seq_notification_id';
COMMENT ON COLUMN notifications.notification_type IS 'Type: TIER_CHANGE, MILES_EXPIRY, REDEMPTION_CONFIRM, WELCOME, PROMOTION, STATEMENT, ALERT';
COMMENT ON COLUMN notifications.channel IS 'Delivery channel: EMAIL, SMS, PUSH, MAIL';
COMMENT ON COLUMN notifications.priority IS 'Priority level 1 (highest) to 5 (lowest)';
COMMENT ON COLUMN notifications.retry_count IS 'Number of send retry attempts made';

-- ----------------------------------------
-- Batch Processing Log table
-- ----------------------------------------
CREATE TABLE batch_processing_log (
  batch_id          BIGINT        NOT NULL,
  batch_type        VARCHAR(50)   NOT NULL,
  batch_name        VARCHAR(200),
  start_time        TIMESTAMP     NOT NULL,
  end_time          TIMESTAMP,
  records_processed INTEGER       DEFAULT 0,
  records_succeeded INTEGER       DEFAULT 0,
  records_failed    INTEGER       DEFAULT 0,
  status            VARCHAR(20)   DEFAULT 'RUNNING',
  error_message     TEXT,
  parameters        TEXT,
  run_by            VARCHAR(50)   DEFAULT CURRENT_USER,
  created_date      TIMESTAMP     DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pk_batch_log PRIMARY KEY (batch_id),
  CONSTRAINT chk_batch_type CHECK (batch_type IN ('MILES_EXPIRY', 'TIER_RECALC', 'STATEMENT_GEN', 'DATA_CLEANUP', 'PARTNER_SETTLEMENT', 'BULK_ACCRUAL')),
  CONSTRAINT chk_batch_status CHECK (status IN ('RUNNING', 'COMPLETED', 'FAILED', 'CANCELLED'))
);

COMMENT ON TABLE batch_processing_log IS 'Log of batch processing jobs for tracking execution history and results.';
COMMENT ON COLUMN batch_processing_log.batch_id IS 'Unique batch execution identifier';
COMMENT ON COLUMN batch_processing_log.batch_type IS 'Type: MILES_EXPIRY, TIER_RECALC, STATEMENT_GEN, DATA_CLEANUP, PARTNER_SETTLEMENT, BULK_ACCRUAL';
COMMENT ON COLUMN batch_processing_log.records_processed IS 'Total records processed in this batch run';
COMMENT ON COLUMN batch_processing_log.records_succeeded IS 'Number of records successfully processed';
COMMENT ON COLUMN batch_processing_log.records_failed IS 'Number of records that failed processing';
