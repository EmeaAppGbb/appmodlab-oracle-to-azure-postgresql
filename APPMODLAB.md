---
title: "Oracle to Azure PostgreSQL"
description: "Migrate Oracle databases to Azure PostgreSQL with schema conversion, PL/SQL to PL/pgSQL translation using ora2pg"
authors: ["marconsilva"]
category: "Data Modernization"
industry: "Cross-Industry"
services: ["Azure Database for PostgreSQL", "Azure Database Migration Service"]
languages: ["SQL", "PL/SQL", "Python", "Java"]
frameworks: ["Spring Boot"]
modernizationTools: ["ora2pg"]
agenticTools: []
tags: ["oracle", "postgresql", "database-migration", "plsql", "plpgsql", "ora2pg"]
extensions: ["github.copilot"]
thumbnail: "https://raw.githubusercontent.com/EmeaAppGbb/appmodlab-oracle-to-azure-postgresql/main/assets/thumbnail-gpt-image.png"
video: ""
version: "1.0.0"
screenshots:
  - path: "assets/screenshots/01-schema-tables.html"
    title: "Oracle Schema — Tables DDL"
    description: "Core table definitions using Oracle NUMBER, VARCHAR2, CLOB, SYSDATE, CHECK constraints for the SkyReward Airlines loyalty program (10 tables)."
  - path: "assets/screenshots/02-package-member-mgmt.html"
    title: "PL/SQL Package — Member Management"
    description: "PKG_MEMBER_MGMT: registration, profile updates, miles balance, account merging. Uses %TYPE, INDEX BY, RAISE_APPLICATION_ERROR, sequences."
  - path: "assets/screenshots/03-package-flight-accrual.html"
    title: "PL/SQL Package — Flight Accrual"
    description: "PKG_FLIGHT_ACCRUAL: miles calculation with cabin/class multipliers, BULK COLLECT + FORALL for batch processing."
  - path: "assets/screenshots/04-trigger-flight-validation.html"
    title: "Oracle Trigger — Flight Validation"
    description: "TRG_FLIGHT_VALIDATION: BEFORE INSERT/UPDATE trigger enforcing business rules — active member check, date validation, duplicate detection, data normalization."
  - path: "assets/screenshots/05-function-calculate-miles.html"
    title: "Oracle Function — Calculate Miles"
    description: "FN_CALCULATE_MILES: DETERMINISTIC function computing total miles from distance × cabin × booking class × tier bonus."
  - path: "assets/screenshots/06-view-member-summary.html"
    title: "Oracle View — Member Summary"
    description: "VW_MEMBER_SUMMARY: Uses MONTHS_BETWEEN, DECODE, RANK() OVER, NVL, TRUNC(..,'YYYY') — key Oracle-specific constructs to convert."
  - path: "assets/screenshots/07-procedure-expire-miles.html"
    title: "Oracle Procedure — Expire Miles"
    description: "PR_EXPIRE_MILES: Batch expiration job using cursor FOR loop, %TYPE records, DBMS_OUTPUT, periodic COMMIT."
  - path: "assets/screenshots/08-queue-reward-fulfillment.html"
    title: "Oracle AQ — Reward Fulfillment Queue"
    description: "DBMS_AQ/DBMS_AQADM queue with custom TYPE payload, enqueue/dequeue procedures. Migration target: pgmq or Azure Service Bus."
---

# Oracle to Azure Database for PostgreSQL

## Overview

This lab migrates an Oracle database powering the SkyReward Airlines loyalty program to Azure Database for PostgreSQL. You'll convert Oracle-specific constructs — PL/SQL packages, triggers, functions, views, queues — to PostgreSQL equivalents using ora2pg.

## Legacy Oracle Schema

### Table Definitions

The Oracle schema consists of 10 core tables using Oracle-specific data types (NUMBER, VARCHAR2, CLOB) with SYSDATE defaults and CHECK constraints for the loyalty program domain.

[View: Oracle Schema — Tables DDL](assets/screenshots/01-schema-tables.html)

*Open the HTML file in a browser to view the syntax-highlighted rendering.*

## PL/SQL Packages

### Member Management Package

PKG_MEMBER_MGMT handles registration, profile updates, miles balance queries, and account merging. Uses Oracle-specific constructs like %TYPE, INDEX BY tables, RAISE_APPLICATION_ERROR, and sequences that need PL/pgSQL equivalents.

[View: PL/SQL Package — Member Management](assets/screenshots/02-package-member-mgmt.html)

*Open the HTML file in a browser to view the syntax-highlighted rendering.*

### Flight Accrual Package

PKG_FLIGHT_ACCRUAL calculates miles with cabin and class multipliers, using BULK COLLECT and FORALL for batch processing. These Oracle bulk operations must be translated to PostgreSQL set-based patterns.

[View: PL/SQL Package — Flight Accrual](assets/screenshots/03-package-flight-accrual.html)

*Open the HTML file in a browser to view the syntax-highlighted rendering.*

## Triggers, Functions, and Views

### Flight Validation Trigger

TRG_FLIGHT_VALIDATION is a BEFORE INSERT/UPDATE trigger enforcing business rules — active member checks, date validation, duplicate detection, and data normalization.

[View: Oracle Trigger — Flight Validation](assets/screenshots/04-trigger-flight-validation.html)

*Open the HTML file in a browser to view the syntax-highlighted rendering.*

### Calculate Miles Function

FN_CALCULATE_MILES is a DETERMINISTIC function computing total miles from distance × cabin × booking class × tier bonus. The DETERMINISTIC keyword maps to PostgreSQL's IMMUTABLE or STABLE volatility.

[View: Oracle Function — Calculate Miles](assets/screenshots/05-function-calculate-miles.html)

*Open the HTML file in a browser to view the syntax-highlighted rendering.*

### Member Summary View

VW_MEMBER_SUMMARY uses Oracle-specific functions: MONTHS_BETWEEN, DECODE, RANK() OVER, NVL, and TRUNC(..,'YYYY'). Each requires a PostgreSQL equivalent (e.g., COALESCE for NVL, DATE_TRUNC for TRUNC).

[View: Oracle View — Member Summary](assets/screenshots/06-view-member-summary.html)

*Open the HTML file in a browser to view the syntax-highlighted rendering.*

## Batch Processing and Queues

### Expire Miles Procedure

PR_EXPIRE_MILES handles batch expiration using cursor FOR loops, %TYPE records, DBMS_OUTPUT, and periodic COMMIT. PostgreSQL uses RAISE NOTICE instead of DBMS_OUTPUT.

[View: Oracle Procedure — Expire Miles](assets/screenshots/07-procedure-expire-miles.html)

*Open the HTML file in a browser to view the syntax-highlighted rendering.*

### Reward Fulfillment Queue

The Oracle Advanced Queuing (DBMS_AQ/DBMS_AQADM) setup uses a custom TYPE payload with enqueue/dequeue procedures. Migration target is pgmq or Azure Service Bus.

[View: Oracle AQ — Reward Fulfillment Queue](assets/screenshots/08-queue-reward-fulfillment.html)

*Open the HTML file in a browser to view the syntax-highlighted rendering.*

## Screenshots

Visual walkthroughs of the Oracle database objects requiring conversion. Open the HTML files in a browser for syntax-highlighted views.

| # | Screenshot | Description |
|---|-----------|-------------|
| 1 | [Schema Tables](assets/screenshots/01-schema-tables.html) | Core table definitions with Oracle NUMBER, VARCHAR2, CLOB, SYSDATE, CHECK constraints |
| 2 | [Member Management Package](assets/screenshots/02-package-member-mgmt.html) | PKG_MEMBER_MGMT: registration, profile updates, %TYPE, INDEX BY, sequences |
| 3 | [Flight Accrual Package](assets/screenshots/03-package-flight-accrual.html) | PKG_FLIGHT_ACCRUAL: miles calculation, BULK COLLECT + FORALL batch processing |
| 4 | [Flight Validation Trigger](assets/screenshots/04-trigger-flight-validation.html) | BEFORE INSERT/UPDATE trigger with business rule enforcement |
| 5 | [Calculate Miles Function](assets/screenshots/05-function-calculate-miles.html) | DETERMINISTIC function for miles computation |
| 6 | [Member Summary View](assets/screenshots/06-view-member-summary.html) | View using MONTHS_BETWEEN, DECODE, RANK() OVER, NVL, TRUNC |
| 7 | [Expire Miles Procedure](assets/screenshots/07-procedure-expire-miles.html) | Batch expiration with cursor FOR loop and periodic COMMIT |
| 8 | [Reward Fulfillment Queue](assets/screenshots/08-queue-reward-fulfillment.html) | DBMS_AQ/DBMS_AQADM queue with custom TYPE payload |

## Solution Walkthrough

This solution was built using the **GitHub Copilot CLI** (`copilot`) in fully autonomous mode. Each step was executed as a single CLI prompt, with all code changes made by Copilot. The `solution-final` branch contains the complete migration.

### Branch & Tags

| Branch / Tag | Description |
|---|---|
| `solution-final` | Complete solution branch with all 8 steps |
| `step-01-explore-oracle` | Oracle database assessment and feature catalog |
| `step-02-ora2pg-assessment` | ora2pg configuration and migration complexity report |
| `step-03-schema-conversion` | PostgreSQL schema (tables, sequences, indexes, constraints) |
| `step-04-plsql-migration` | PL/SQL → PL/pgSQL conversion (packages, functions, triggers, views) |
| `step-05-azure-postgresql-setup` | Azure Bicep IaC, Docker Compose, setup docs |
| `step-06-data-migration` | Data conversion, DMS config, validation scripts |
| `step-07-app-adaptation` | Spring Boot app with PostgreSQL JDBC |
| `step-08-validation` | CI/CD, integration tests, validation suite |

### CLI Commands Used

All steps were run from the repository root with:

```bash
copilot -p "PROMPT" --allow-all-tools --yolo 2>&1 | Tee-Object -FilePath "assets/outputs/step-NN-slug.txt"
```

#### Step 1 — Explore Oracle Database
```bash
copilot -p "Step 1: Explore Oracle Database. Review all files in the oracle/ directory and analyze all Oracle-specific features. Create docs/01-oracle-assessment.md cataloging all tables, sequences, packages, functions, procedures, views, triggers, queues, scheduler jobs, and synonyms with PostgreSQL equivalents." --allow-all-tools --yolo
```
**Output:** [`assets/outputs/step-01-explore-oracle.txt`](assets/outputs/step-01-explore-oracle.txt)
**Created:** `docs/01-oracle-assessment.md` — Full feature catalog with migration complexity matrix

#### Step 2 — Run ora2pg Assessment
```bash
copilot -p "Step 2: Run ora2pg Assessment. Create ora2pg/ora2pg.conf configuration and docs/02-ora2pg-assessment-report.md with migration complexity scores, conversion effort ratings, and data type mappings." --allow-all-tools --yolo
```
**Output:** [`assets/outputs/step-02-ora2pg-assessment.txt`](assets/outputs/step-02-ora2pg-assessment.txt)
**Created:** `ora2pg/ora2pg.conf`, `docs/02-ora2pg-assessment-report.md`

#### Step 3 — Convert Schema
```bash
copilot -p "Step 3: Convert Oracle Schema to PostgreSQL. Convert oracle/schema/ files to postgresql/schema/ with PostgreSQL data types, SERIAL/BIGSERIAL, CREATE SEQUENCE syntax, and synonym-to-view mappings." --allow-all-tools --yolo
```
**Output:** [`assets/outputs/step-03-schema-conversion.txt`](assets/outputs/step-03-schema-conversion.txt)
**Created:** `postgresql/schema/` (5 files), `postgresql/setup.sql`

#### Step 4 — Migrate PL/SQL to PL/pgSQL
```bash
copilot -p "Step 4: Migrate PL/SQL to PL/pgSQL. Convert all 10 packages, 3 functions, 3 procedures, 3 triggers, 4 views, Oracle AQ queue, and DBMS_SCHEDULER jobs to PostgreSQL equivalents." --allow-all-tools --yolo
```
**Output:** [`assets/outputs/step-04-plsql-migration.txt`](assets/outputs/step-04-plsql-migration.txt)
**Created:** `postgresql/functions/` (13 files), `postgresql/procedures/` (3), `postgresql/triggers/` (3), `postgresql/views/` (4), `postgresql/queues/` (1), `postgresql/scheduler/` (3)

#### Step 5 — Set Up Azure PostgreSQL
```bash
copilot -p "Step 5: Set Up Azure PostgreSQL Infrastructure. Create Bicep templates for PostgreSQL Flexible Server with extensions, DMS resource, deployment script, and update docker-compose.yml." --allow-all-tools --yolo
```
**Output:** [`assets/outputs/step-05-azure-postgresql-setup.txt`](assets/outputs/step-05-azure-postgresql-setup.txt)
**Created:** `infra/main.bicep`, `infra/parameters.json`, `infra/deploy.sh`, `docs/03-azure-postgresql-setup.md`

#### Step 6 — Migrate Data
```bash
copilot -p "Step 6: Migrate Data. Convert Oracle INSERT statements to PostgreSQL, create DMS config, and validation scripts." --allow-all-tools --yolo
```
**Output:** [`assets/outputs/step-06-data-migration.txt`](assets/outputs/step-06-data-migration.txt)
**Created:** `postgresql/data/` (6 files), `scripts/validate-migration.sql`, `scripts/dms-config.json`, `docs/04-data-migration.md`

#### Step 7 — Adapt Application
```bash
copilot -p "Step 7: Adapt Application. Create Spring Boot app with PostgreSQL JDBC, JPA entities, repositories, services, and REST controllers demonstrating the Oracle-to-PostgreSQL migration." --allow-all-tools --yolo
```
**Output:** [`assets/outputs/step-07-app-adaptation.txt`](assets/outputs/step-07-app-adaptation.txt)
**Created:** `app/` (Spring Boot project with 13+ files), `docs/05-application-adaptation.md`

#### Step 8 — Validate Migration
```bash
copilot -p "Step 8: Validate Migration. Create schema validation, function tests, integration tests, CI/CD workflow, and validation documentation." --allow-all-tools --yolo
```
**Output:** [`assets/outputs/step-08-validation.txt`](assets/outputs/step-08-validation.txt)
**Created:** `scripts/validate-schema.sql`, `scripts/validate-functions.sql`, `scripts/run-validation.sh`, `tests/integration/` (5 test files), `.github/workflows/ci.yml`, `docs/06-validation-guide.md`

### Key Conversion Patterns

| Oracle Construct | PostgreSQL Equivalent |
|---|---|
| `NUMBER(n)` | `INTEGER` / `BIGINT` / `NUMERIC(n)` |
| `VARCHAR2(n)` | `VARCHAR(n)` |
| `CLOB` | `TEXT` |
| `SYSDATE` | `CURRENT_TIMESTAMP` |
| `USER` | `CURRENT_USER` |
| `SEQ.NEXTVAL` | `nextval('seq_name')` |
| PL/SQL Package | PL/pgSQL functions (prefixed by package name) |
| `%TYPE` | Explicit data types |
| `RAISE_APPLICATION_ERROR` | `RAISE EXCEPTION` |
| `BULK COLLECT / FORALL` | Standard SQL set operations |
| `DBMS_OUTPUT.PUT_LINE` | `RAISE NOTICE` |
| `NVL()` | `COALESCE()` |
| `DECODE()` | `CASE WHEN` |
| `MONTHS_BETWEEN()` | `EXTRACT(EPOCH FROM age()) / 2592000` |
| `TRUNC(date, 'YYYY')` | `DATE_TRUNC('year', date)` |
| `DETERMINISTIC` | `IMMUTABLE` / `STABLE` |
| Oracle AQ (DBMS_AQ) | pgmq extension |
| `DBMS_SCHEDULER` | pg_cron extension |
| Oracle Synonyms | PostgreSQL views or `search_path` |
| Materialized View (Oracle refresh) | `CREATE MATERIALIZED VIEW` + pg_cron refresh |
