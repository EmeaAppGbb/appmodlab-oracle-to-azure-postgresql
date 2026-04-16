-- ========================================
-- PostgreSQL Indexes
-- ========================================
-- Converted from Oracle indexes
-- Oracle BITMAP indexes converted to standard B-tree indexes
-- Oracle Text (CTXSYS.CONTEXT) index converted to PostgreSQL GIN/tsvector

-- ----------------------------------------
-- Members indexes
-- ----------------------------------------
CREATE INDEX idx_members_name ON members(last_name, first_name);
CREATE INDEX idx_members_tier ON members(tier_status);
CREATE INDEX idx_members_enrollment ON members(enrollment_date);
CREATE INDEX idx_members_country ON members(country);
CREATE INDEX idx_members_status_tier ON members(status, tier_status);
CREATE INDEX idx_members_last_activity ON members(last_activity_date);
CREATE INDEX idx_members_preferred_airport ON members(preferred_airport);

-- Oracle bitmap indexes converted to B-tree (PostgreSQL has no bitmap index type)
-- For low-cardinality columns, B-tree indexes are generally sufficient in PostgreSQL
-- as the query planner can perform bitmap index scans on any B-tree index.
-- Note: idx_members_tier and idx_members_country already created above,
-- so the Oracle bitmap duplicates (bmp_members_tier, bmp_members_country) are omitted.
CREATE INDEX idx_members_status ON members(status);
CREATE INDEX idx_members_gender ON members(gender);

-- ----------------------------------------
-- Flights indexes
-- ----------------------------------------
CREATE INDEX idx_flights_member ON flights(member_id);
CREATE INDEX idx_flights_date ON flights(flight_date);
CREATE INDEX idx_flights_member_date ON flights(member_id, flight_date);
CREATE INDEX idx_flights_accrual_status ON flights(accrual_status);
CREATE INDEX idx_flights_flight_number ON flights(flight_number);
CREATE INDEX idx_flights_airline ON flights(airline_code);
CREATE INDEX idx_flights_route ON flights(departure_airport, arrival_airport);
CREATE INDEX idx_flights_partner ON flights(partner_code);
CREATE INDEX idx_flights_processed ON flights(processed_date);

-- Oracle bitmap indexes converted to B-tree
CREATE INDEX idx_flights_cabin ON flights(cabin_class);
CREATE INDEX idx_flights_status ON flights(status);

-- ----------------------------------------
-- Redemptions indexes
-- ----------------------------------------
CREATE INDEX idx_redemptions_member ON redemptions(member_id);
CREATE INDEX idx_redemptions_reward ON redemptions(reward_id);
CREATE INDEX idx_redemptions_date ON redemptions(redemption_date);
CREATE INDEX idx_redemptions_status ON redemptions(status);
CREATE INDEX idx_redemptions_confirm ON redemptions(confirmation_code);
CREATE INDEX idx_redemptions_member_date ON redemptions(member_id, redemption_date);

-- Oracle bitmap indexes converted to B-tree
CREATE INDEX idx_redemptions_channel ON redemptions(redemption_channel);

-- ----------------------------------------
-- Rewards indexes
-- ----------------------------------------
CREATE INDEX idx_rewards_category ON rewards(category);
CREATE INDEX idx_rewards_miles ON rewards(miles_required);
CREATE INDEX idx_rewards_partner ON rewards(partner_id);
CREATE INDEX idx_rewards_valid ON rewards(valid_from, valid_until);

-- Oracle Text full-text index converted to PostgreSQL GIN with tsvector
-- Supports full-text search using to_tsvector/to_tsquery
CREATE INDEX idx_rewards_desc_text ON rewards USING GIN (to_tsvector('english', COALESCE(description, '')));

-- Oracle bitmap indexes converted to B-tree
CREATE INDEX idx_rewards_status ON rewards(status);
CREATE INDEX idx_rewards_min_tier ON rewards(min_tier_required);

-- ----------------------------------------
-- Partner Transactions indexes
-- ----------------------------------------
CREATE INDEX idx_partner_txn_member ON partner_transactions(member_id);
CREATE INDEX idx_partner_txn_partner ON partner_transactions(partner_id);
CREATE INDEX idx_partner_txn_date ON partner_transactions(transaction_date);
CREATE INDEX idx_partner_txn_status ON partner_transactions(status);
CREATE INDEX idx_partner_txn_ref ON partner_transactions(partner_ref);
CREATE INDEX idx_partner_txn_member_date ON partner_transactions(member_id, transaction_date);

-- Oracle bitmap indexes converted to B-tree
CREATE INDEX idx_partner_txn_type ON partner_transactions(transaction_type);

-- ----------------------------------------
-- Partners indexes
-- ----------------------------------------
CREATE INDEX idx_partners_type ON partners(partner_type);
CREATE INDEX idx_partners_status ON partners(status);

-- ----------------------------------------
-- Tier Rules indexes
-- ----------------------------------------
CREATE INDEX idx_tier_rules_name ON tier_rules(tier_name);
CREATE INDEX idx_tier_rules_effective ON tier_rules(effective_date, expiry_date);

-- ----------------------------------------
-- Miles Expiry indexes
-- ----------------------------------------
CREATE INDEX idx_miles_expiry_member ON miles_expiry(member_id);
CREATE INDEX idx_miles_expiry_date ON miles_expiry(expiry_date);
CREATE INDEX idx_miles_expiry_status ON miles_expiry(status);
CREATE INDEX idx_miles_expiry_batch ON miles_expiry(batch_id);
CREATE INDEX idx_miles_expiry_member_status ON miles_expiry(member_id, status);

-- Oracle bitmap indexes converted to B-tree
CREATE INDEX idx_miles_expiry_source ON miles_expiry(source_type);

-- ----------------------------------------
-- Audit Log indexes
-- ----------------------------------------
CREATE INDEX idx_audit_table ON audit_log(table_name);
CREATE INDEX idx_audit_member ON audit_log(member_id);
CREATE INDEX idx_audit_date ON audit_log(changed_date);
CREATE INDEX idx_audit_table_date ON audit_log(table_name, changed_date);
CREATE INDEX idx_audit_record ON audit_log(table_name, record_id);

-- ----------------------------------------
-- Notifications indexes
-- ----------------------------------------
CREATE INDEX idx_notif_member ON notifications(member_id);
CREATE INDEX idx_notif_status ON notifications(status);
CREATE INDEX idx_notif_scheduled ON notifications(scheduled_date);
CREATE INDEX idx_notif_type_status ON notifications(notification_type, status);

-- Oracle bitmap indexes converted to B-tree
CREATE INDEX idx_notif_type ON notifications(notification_type);
CREATE INDEX idx_notif_channel ON notifications(channel);

-- ----------------------------------------
-- Batch Processing Log indexes
-- ----------------------------------------
CREATE INDEX idx_batch_type ON batch_processing_log(batch_type);
CREATE INDEX idx_batch_start ON batch_processing_log(start_time);
CREATE INDEX idx_batch_status ON batch_processing_log(status);
