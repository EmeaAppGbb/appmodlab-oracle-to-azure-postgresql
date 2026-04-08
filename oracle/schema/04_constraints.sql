-- ========================================
-- Table and Column Comments
-- ========================================
-- Oracle COMMENT ON statements for documentation

-- ----------------------------------------
-- Members table comments
-- ----------------------------------------
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
COMMENT ON COLUMN members.notes IS 'Free-text notes about the member account (CLOB for large text)';

-- ----------------------------------------
-- Flights table comments
-- ----------------------------------------
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
-- Rewards table comments
-- ----------------------------------------
COMMENT ON TABLE rewards IS 'Reward catalog available for miles redemption. Includes flights, upgrades, merchandise, and partner rewards.';
COMMENT ON COLUMN rewards.reward_id IS 'Unique reward identifier, generated from seq_reward_id';
COMMENT ON COLUMN rewards.reward_code IS 'Short code for the reward used in APIs and displays';
COMMENT ON COLUMN rewards.reward_name IS 'Display name of the reward';
COMMENT ON COLUMN rewards.description IS 'Full description of the reward (CLOB for rich text content, indexed by Oracle Text)';
COMMENT ON COLUMN rewards.category IS 'Reward category: FLIGHT, UPGRADE, LOUNGE, HOTEL, CAR_RENTAL, MERCHANDISE, GIFT_CARD, EXPERIENCE';
COMMENT ON COLUMN rewards.miles_required IS 'Number of miles required to redeem this reward';
COMMENT ON COLUMN rewards.min_tier_required IS 'Minimum tier status required to access this reward';
COMMENT ON COLUMN rewards.quantity_available IS 'Remaining inventory count, NULL for unlimited';

-- ----------------------------------------
-- Redemptions table comments
-- ----------------------------------------
COMMENT ON TABLE redemptions IS 'Records of reward redemptions by members. Tracks the lifecycle from request to fulfillment.';
COMMENT ON COLUMN redemptions.redemption_id IS 'Unique redemption identifier, generated from seq_redemption_id';
COMMENT ON COLUMN redemptions.member_id IS 'Reference to the redeeming member';
COMMENT ON COLUMN redemptions.reward_id IS 'Reference to the redeemed reward';
COMMENT ON COLUMN redemptions.miles_used IS 'Number of miles deducted for this redemption';
COMMENT ON COLUMN redemptions.cash_paid IS 'Any cash co-payment amount';
COMMENT ON COLUMN redemptions.confirmation_code IS 'Unique confirmation code sent to the member';
COMMENT ON COLUMN redemptions.status IS 'Redemption lifecycle status: PENDING, CONFIRMED, FULFILLED, CANCELLED, EXPIRED';

-- ----------------------------------------
-- Partners table comments
-- ----------------------------------------
COMMENT ON TABLE partners IS 'Partner airlines, hotels, and companies participating in the SkyReward loyalty ecosystem.';
COMMENT ON COLUMN partners.partner_id IS 'Unique partner identifier, generated from seq_partner_id';
COMMENT ON COLUMN partners.partner_code IS 'Short unique code identifying the partner';
COMMENT ON COLUMN partners.partner_type IS 'Type of partner: AIRLINE, HOTEL, CAR_RENTAL, RETAIL, FINANCIAL, DINING';
COMMENT ON COLUMN partners.conversion_rate IS 'Miles conversion rate relative to SkyReward base miles';

-- ----------------------------------------
-- Partner Transactions table comments
-- ----------------------------------------
COMMENT ON TABLE partner_transactions IS 'Cross-partner earning and redemption transactions. Tracks miles flow between SkyReward and partners.';
COMMENT ON COLUMN partner_transactions.txn_id IS 'Unique transaction identifier, generated from seq_partner_txn_id';
COMMENT ON COLUMN partner_transactions.transaction_type IS 'Transaction type: EARN, REDEEM, TRANSFER, ADJUSTMENT';
COMMENT ON COLUMN partner_transactions.miles_earned IS 'Miles earned through this partner transaction';
COMMENT ON COLUMN partner_transactions.miles_redeemed IS 'Miles redeemed through this partner transaction';
COMMENT ON COLUMN partner_transactions.conversion_rate IS 'Applied conversion rate at time of transaction';

-- ----------------------------------------
-- Tier Rules table comments
-- ----------------------------------------
COMMENT ON TABLE tier_rules IS 'Tier qualification rules defining requirements and benefits for each loyalty tier level.';
COMMENT ON COLUMN tier_rules.rule_id IS 'Unique rule identifier, generated from seq_tier_rule_id';
COMMENT ON COLUMN tier_rules.tier_name IS 'Tier level: BLUE, SILVER, GOLD, PLATINUM, DIAMOND';
COMMENT ON COLUMN tier_rules.min_miles IS 'Minimum qualifying miles required for this tier';
COMMENT ON COLUMN tier_rules.min_segments IS 'Minimum qualifying flight segments required';
COMMENT ON COLUMN tier_rules.qualification_period_months IS 'Rolling period in months for qualification';
COMMENT ON COLUMN tier_rules.miles_multiplier IS 'Earning multiplier for this tier (e.g., 1.5x for Gold)';
COMMENT ON COLUMN tier_rules.bonus_miles_pct IS 'Percentage of bonus miles on top of base earn rate';

-- ----------------------------------------
-- Miles Expiry table comments
-- ----------------------------------------
COMMENT ON TABLE miles_expiry IS 'Tracks individual miles batches and their expiration dates. Used by the miles expiry batch job.';
COMMENT ON COLUMN miles_expiry.expiry_id IS 'Unique expiry record identifier';
COMMENT ON COLUMN miles_expiry.source_type IS 'How the miles were earned: FLIGHT, PARTNER, BONUS, PROMOTION, ADJUSTMENT';
COMMENT ON COLUMN miles_expiry.miles_amount IS 'Original miles amount in this batch';
COMMENT ON COLUMN miles_expiry.expired_miles IS 'Miles that have been expired from this batch';
COMMENT ON COLUMN miles_expiry.batch_id IS 'Reference to the batch job that processed expiry';

-- ----------------------------------------
-- Audit Log table comments
-- ----------------------------------------
COMMENT ON TABLE audit_log IS 'Audit trail for all data changes across loyalty program tables. Populated by database triggers.';
COMMENT ON COLUMN audit_log.audit_id IS 'Unique audit record identifier, generated from seq_audit_id';
COMMENT ON COLUMN audit_log.table_name IS 'Name of the table where the change occurred';
COMMENT ON COLUMN audit_log.operation IS 'DML operation: INSERT, UPDATE, or DELETE';
COMMENT ON COLUMN audit_log.old_values IS 'JSON representation of old column values (CLOB)';
COMMENT ON COLUMN audit_log.new_values IS 'JSON representation of new column values (CLOB)';

-- ----------------------------------------
-- Notifications table comments
-- ----------------------------------------
COMMENT ON TABLE notifications IS 'Outbound notification queue for member communications including emails, SMS, and push notifications.';
COMMENT ON COLUMN notifications.notification_id IS 'Unique notification identifier, generated from seq_notification_id';
COMMENT ON COLUMN notifications.notification_type IS 'Type: TIER_CHANGE, MILES_EXPIRY, REDEMPTION_CONFIRM, WELCOME, PROMOTION, STATEMENT, ALERT';
COMMENT ON COLUMN notifications.channel IS 'Delivery channel: EMAIL, SMS, PUSH, MAIL';
COMMENT ON COLUMN notifications.priority IS 'Priority level 1 (highest) to 5 (lowest)';
COMMENT ON COLUMN notifications.retry_count IS 'Number of send retry attempts made';

-- ----------------------------------------
-- Batch Processing Log table comments
-- ----------------------------------------
COMMENT ON TABLE batch_processing_log IS 'Log of batch processing jobs for tracking execution history and results.';
COMMENT ON COLUMN batch_processing_log.batch_id IS 'Unique batch execution identifier';
COMMENT ON COLUMN batch_processing_log.batch_type IS 'Type: MILES_EXPIRY, TIER_RECALC, STATEMENT_GEN, DATA_CLEANUP, PARTNER_SETTLEMENT, BULK_ACCRUAL';
COMMENT ON COLUMN batch_processing_log.records_processed IS 'Total records processed in this batch run';
COMMENT ON COLUMN batch_processing_log.records_succeeded IS 'Number of records successfully processed';
COMMENT ON COLUMN batch_processing_log.records_failed IS 'Number of records that failed processing';

COMMIT;
