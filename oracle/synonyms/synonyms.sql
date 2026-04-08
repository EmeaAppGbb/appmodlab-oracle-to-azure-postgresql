-- ========================================
-- Synonyms for SkyReward Airlines
-- ========================================
-- Public and private synonyms for simplified access

-- ----------------------------------------
-- Public Synonyms (cross-schema access)
-- ----------------------------------------
CREATE OR REPLACE PUBLIC SYNONYM members FOR skyreward.members;
CREATE OR REPLACE PUBLIC SYNONYM flights FOR skyreward.flights;
CREATE OR REPLACE PUBLIC SYNONYM rewards FOR skyreward.rewards;
CREATE OR REPLACE PUBLIC SYNONYM redemptions FOR skyreward.redemptions;
CREATE OR REPLACE PUBLIC SYNONYM partners FOR skyreward.partners;
CREATE OR REPLACE PUBLIC SYNONYM partner_transactions FOR skyreward.partner_transactions;
CREATE OR REPLACE PUBLIC SYNONYM tier_rules FOR skyreward.tier_rules;

-- Public synonyms for views
CREATE OR REPLACE PUBLIC SYNONYM member_summary FOR skyreward.vw_member_summary;
CREATE OR REPLACE PUBLIC SYNONYM tier_report FOR skyreward.vw_tier_status_report;
CREATE OR REPLACE PUBLIC SYNONYM monthly_accruals FOR skyreward.mvw_monthly_accruals;
CREATE OR REPLACE PUBLIC SYNONYM partner_summary FOR skyreward.mvw_partner_summary;

-- Public synonyms for packages
CREATE OR REPLACE PUBLIC SYNONYM member_mgmt FOR skyreward.pkg_member_mgmt;
CREATE OR REPLACE PUBLIC SYNONYM flight_accrual FOR skyreward.pkg_flight_accrual;
CREATE OR REPLACE PUBLIC SYNONYM tier_calc FOR skyreward.pkg_tier_calculation;
CREATE OR REPLACE PUBLIC SYNONYM redemption_mgmt FOR skyreward.pkg_redemption_mgmt;
CREATE OR REPLACE PUBLIC SYNONYM partner_integration FOR skyreward.pkg_partner_integration;
CREATE OR REPLACE PUBLIC SYNONYM reporting FOR skyreward.pkg_reporting;

-- Public synonyms for standalone functions
CREATE OR REPLACE PUBLIC SYNONYM calculate_miles FOR skyreward.fn_calculate_miles;
CREATE OR REPLACE PUBLIC SYNONYM get_tier_status FOR skyreward.fn_get_tier_status;
CREATE OR REPLACE PUBLIC SYNONYM validate_redemption FOR skyreward.fn_validate_redemption;

-- ----------------------------------------
-- Private Synonyms (within schema shortcuts)
-- ----------------------------------------
CREATE OR REPLACE SYNONYM mem FOR members;
CREATE OR REPLACE SYNONYM flt FOR flights;
CREATE OR REPLACE SYNONYM rdm FOR redemptions;
CREATE OR REPLACE SYNONYM rwd FOR rewards;
CREATE OR REPLACE SYNONYM ptr FOR partners;
CREATE OR REPLACE SYNONYM ptr_txn FOR partner_transactions;
CREATE OR REPLACE SYNONYM tr FOR tier_rules;
CREATE OR REPLACE SYNONYM aud FOR audit_log;
CREATE OR REPLACE SYNONYM notif FOR notifications;
CREATE OR REPLACE SYNONYM batch_log FOR batch_processing_log;
CREATE OR REPLACE SYNONYM mexp FOR miles_expiry;
