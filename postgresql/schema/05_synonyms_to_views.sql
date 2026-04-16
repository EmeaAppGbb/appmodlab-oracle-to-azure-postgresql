-- ========================================
-- PostgreSQL Replacements for Oracle Synonyms
-- ========================================
-- Oracle PUBLIC SYNONYM and private SYNONYM have no direct PostgreSQL equivalent.
-- Strategy:
--   1. Use schema search_path to allow unqualified access to skyreward objects
--   2. Create views as aliases for shorthand table names (replacing private synonyms)
--   3. Create views for cross-schema synonym-like access where needed

-- ----------------------------------------
-- Schema search_path configuration
-- ----------------------------------------
-- Set the default search_path so that objects in the 'skyreward' schema
-- can be referenced without schema qualification (replaces public synonyms).
-- Run this as the database owner or superuser:
DO $$
BEGIN
  -- Create the skyreward schema if it doesn't exist
  CREATE SCHEMA IF NOT EXISTS skyreward;
EXCEPTION
  WHEN duplicate_schema THEN NULL;
END $$;

-- Set search_path for the current database so all users can find skyreward objects
-- This replaces the Oracle PUBLIC SYNONYM functionality
ALTER DATABASE CURRENT SET search_path TO skyreward, public;

-- Also set for the current session
SET search_path TO skyreward, public;

-- ----------------------------------------
-- Views replacing private synonyms (shorthand aliases)
-- ----------------------------------------
-- These views act as short aliases for table names,
-- replicating Oracle private synonyms used within the schema.

CREATE OR REPLACE VIEW mem AS SELECT * FROM members;
CREATE OR REPLACE VIEW flt AS SELECT * FROM flights;
CREATE OR REPLACE VIEW rdm AS SELECT * FROM redemptions;
CREATE OR REPLACE VIEW rwd AS SELECT * FROM rewards;
CREATE OR REPLACE VIEW ptr AS SELECT * FROM partners;
CREATE OR REPLACE VIEW ptr_txn AS SELECT * FROM partner_transactions;
CREATE OR REPLACE VIEW tr AS SELECT * FROM tier_rules;
CREATE OR REPLACE VIEW aud AS SELECT * FROM audit_log;
CREATE OR REPLACE VIEW notif AS SELECT * FROM notifications;
CREATE OR REPLACE VIEW batch_log AS SELECT * FROM batch_processing_log;
CREATE OR REPLACE VIEW mexp AS SELECT * FROM miles_expiry;

-- ----------------------------------------
-- Notes on public synonym replacements
-- ----------------------------------------
-- The following Oracle public synonyms pointed to views/packages/functions
-- in the skyreward schema. In PostgreSQL:
--
-- Views (member_summary, tier_report, monthly_accruals, partner_summary):
--   These will be accessible via search_path once created in the skyreward schema.
--   No additional synonym/view wrapper is needed.
--
-- Packages (member_mgmt, flight_accrual, tier_calc, redemption_mgmt,
--           partner_integration, reporting):
--   Oracle packages are converted to PostgreSQL schemas or function groups.
--   Access is handled via search_path.
--
-- Functions (calculate_miles, get_tier_status, validate_redemption):
--   PostgreSQL functions are accessible via search_path once created.
--   No additional synonym wrapper is needed.
