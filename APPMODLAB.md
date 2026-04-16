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
thumbnail: ""
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
