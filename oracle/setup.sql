-- ========================================
-- SkyReward Airlines - Oracle Database Setup
-- ========================================
-- Master setup script for Oracle 19c database
-- Executes all DDL, package, and data scripts in correct order

SET ECHO ON
SET FEEDBACK ON
SET SERVEROUTPUT ON SIZE 1000000

-- Create application tablespace
CREATE TABLESPACE skyreward_data
  DATAFILE 'skyreward_data01.dbf' 
  SIZE 100M AUTOEXTEND ON NEXT 10M MAXSIZE UNLIMITED;

-- Create application user
CREATE USER skyreward IDENTIFIED BY SkyReward123
  DEFAULT TABLESPACE skyreward_data
  TEMPORARY TABLESPACE temp
  QUOTA UNLIMITED ON skyreward_data;

-- Grant privileges
GRANT CONNECT, RESOURCE TO skyreward;
GRANT CREATE VIEW TO skyreward;
GRANT CREATE MATERIALIZED VIEW TO skyreward;
GRANT CREATE SYNONYM TO skyreward;
GRANT CREATE PUBLIC SYNONYM TO skyreward;
GRANT CREATE JOB TO skyreward;
GRANT EXECUTE ON DBMS_SCHEDULER TO skyreward;
GRANT EXECUTE ON DBMS_LOCK TO skyreward;
GRANT AQ_ADMINISTRATOR_ROLE TO skyreward;
GRANT EXECUTE ON DBMS_AQ TO skyreward;
GRANT EXECUTE ON DBMS_AQADM TO skyreward;
GRANT CTXAPP TO skyreward;

CONNECT skyreward/SkyReward123@XEPDB1

PROMPT ========================================
PROMPT Creating Schema Objects
PROMPT ========================================

@schema/01_sequences.sql
@schema/02_tables.sql
@schema/03_indexes.sql
@schema/04_constraints.sql

PROMPT ========================================
PROMPT Creating PL/SQL Packages
PROMPT ========================================

@packages/pkg_member_mgmt.sql
@packages/pkg_flight_accrual.sql
@packages/pkg_tier_calculation.sql
@packages/pkg_redemption_mgmt.sql
@packages/pkg_partner_integration.sql
@packages/pkg_reporting.sql
@packages/pkg_batch_processing.sql
@packages/pkg_validation.sql
@packages/pkg_audit.sql
@packages/pkg_notification.sql

PROMPT ========================================
PROMPT Creating Functions and Procedures
PROMPT ========================================

@functions/fn_calculate_miles.sql
@functions/fn_get_tier_status.sql
@functions/fn_validate_redemption.sql
@procedures/pr_expire_miles.sql
@procedures/pr_recalculate_tiers.sql
@procedures/pr_process_bulk_accrual.sql

PROMPT ========================================
PROMPT Creating Views
PROMPT ========================================

@views/vw_member_summary.sql
@views/vw_tier_status_report.sql
@views/mvw_monthly_accruals.sql
@views/mvw_partner_summary.sql

PROMPT ========================================
PROMPT Creating Synonyms
PROMPT ========================================

@synonyms/synonyms.sql

PROMPT ========================================
PROMPT Creating Triggers
PROMPT ========================================

@triggers/trg_member_audit.sql
@triggers/trg_flight_validation.sql
@triggers/trg_redemption_audit.sql

PROMPT ========================================
PROMPT Creating Oracle AQ
PROMPT ========================================

@queues/reward_fulfillment_queue.sql

PROMPT ========================================
PROMPT Creating Scheduler Jobs
PROMPT ========================================

@scheduler/job_expire_miles.sql
@scheduler/job_tier_recalc.sql
@scheduler/job_materialized_view_refresh.sql

PROMPT ========================================
PROMPT Loading Sample Data
PROMPT ========================================

@data/01_tier_rules.sql
@data/02_rewards.sql
@data/03_members.sql
@data/04_flights.sql
@data/05_redemptions.sql
@data/06_partner_transactions.sql

PROMPT ========================================
PROMPT Setup Complete
PROMPT ========================================

SELECT 'Members: ' || COUNT(*) AS cnt FROM members
UNION ALL
SELECT 'Flights: ' || COUNT(*) FROM flights
UNION ALL
SELECT 'Redemptions: ' || COUNT(*) FROM redemptions
UNION ALL
SELECT 'Rewards: ' || COUNT(*) FROM rewards
UNION ALL
SELECT 'Partner Transactions: ' || COUNT(*) FROM partner_transactions;

EXIT;
