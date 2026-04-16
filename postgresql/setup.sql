-- ========================================
-- PostgreSQL Master Setup Script
-- ========================================
-- SkyReward Airlines Loyalty Program Database
-- Converted from Oracle to PostgreSQL
--
-- Usage:
--   psql -U <username> -d <database> -f setup.sql
--
-- Execution order:
--   1. Tables (with inline PK, FK, UNIQUE, CHECK constraints)
--   2. Sequences (with default value bindings to table columns)
--   3. Indexes (B-tree and GIN full-text)
--   4. Additional constraints (cross-table foreign keys)
--   5. Synonym replacements (views and search_path config)

\echo '=== Creating tables ==='
\i schema/01_tables.sql

\echo '=== Creating sequences ==='
\i schema/02_sequences.sql

\echo '=== Creating indexes ==='
\i schema/03_indexes.sql

\echo '=== Adding additional constraints ==='
\i schema/04_constraints.sql

\echo '=== Setting up synonym replacements (views & search_path) ==='
\i schema/05_synonyms_to_views.sql

\echo '=== Loading data ==='
\i data/01_tier_rules.sql
\i data/02_rewards.sql
\i data/03_members.sql
\i data/04_flights.sql
\i data/05_redemptions.sql
\i data/06_partner_transactions.sql

\echo '=== PostgreSQL setup complete (schema + data) ==='
