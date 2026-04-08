# 🎮 ORACLE → AZURE POSTGRESQL 🚀

```
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   ▄▄▄█████▓ ██░ ██ ▓█████     ▄████  ██▀███  ▓█████ ▄▄▄       ║
║   ▓  ██▒ ▓▒▓██░ ██▒▓█   ▀    ██▒ ▀█▒▓██ ▒ ██▒▓█   ▀▒████▄     ║
║   ▒ ▓██░ ▒░▒██▀▀██░▒███     ▒██░▄▄▄░▓██ ░▄█ ▒▒███  ▒██  ▀█▄   ║
║   ░ ▓██▓ ░ ░▓█ ░██ ▒▓█  ▄   ░▓█  ██▓▒██▀▀█▄  ▒▓█  ▄░██▄▄▄▄██  ║
║     ▒██▒ ░ ░▓█▒░██▓░▒████▒  ░▒▓███▀▒░██▓ ▒██▒░▒████▒▓█   ▓██▒ ║
║     ▒ ░░    ▒ ░░▒░▒░░ ▒░ ░   ░▒   ▒ ░ ▒▓ ░▒▓░░░ ▒░ ░▒▒   ▓▒█░ ║
║       ░     ▒ ░▒░ ░ ░ ░  ░    ░   ░   ░▒ ░ ▒░ ░ ░  ░ ▒   ▒▒ ░ ║
║     ░       ░  ░░ ░   ░     ░ ░   ░   ░░   ░    ░    ░   ▒    ║
║             ░  ░  ░   ░  ░        ░    ░        ░  ░     ░  ░ ║
║                                                               ║
║          🔓 ESCAPE THE LICENSING MATRIX 🔓                    ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

## 🌆 OVERVIEW

**MISSION BRIEFING:** Break free from the Oracle licensing prison! 🏴 This lab is your guide to escaping proprietary database chains and migrating a complex Oracle 19c database to the open-source paradise of **Azure Database for PostgreSQL**. 

You're the hero in this retro-futuristic database escape story — a skilled data engineer tasked with liberating **SkyReward Airlines'** 500K+ loyalty program member records from Oracle's expensive grip. Battle through PL/SQL packages, tame Oracle-specific features, and emerge victorious with a fully managed, cost-effective PostgreSQL solution in Azure! 💜✨

**THE PRIZE:** 💰 Massive licensing cost savings + cloud-native scalability + open-source freedom = **VICTORY ROYALE!** 🏆

---

## 🎯 WHAT YOU'LL LEARN

By completing this arcade-style migration quest, you'll master these **POWER-UPS**:

- 🔍 **ASSESSMENT MODE** — Use ora2pg to scan Oracle databases and generate migration complexity reports
- 🗺️ **SCHEMA TRANSLATION** — Convert Oracle DDL (sequences, synonyms, materialized views) to PostgreSQL equivalents
- 🗣️ **PL/SQL → PL/pgSQL DECODER** — Translate 50+ Oracle PL/SQL packages to PostgreSQL functions
- 🚚 **DATA TELEPORTATION** — Configure Azure Database Migration Service to move millions of rows safely
- ☕ **APP ADAPTATION** — Switch Java applications from Oracle JDBC to PostgreSQL JDBC with minimal code changes
- 🎮 **FEATURE MAPPING** — Master Oracle-to-PostgreSQL equivalents:
  - Oracle AQ → pgmq or Azure Service Bus
  - DBMS_SCHEDULER → pg_cron
  - Oracle Text → PostgreSQL full-text search (tsvector/tsquery)
  - NUMBER/VARCHAR2 → PostgreSQL native types
  - CONNECT BY → WITH RECURSIVE CTEs

**DIFFICULTY LEVEL:** ⭐⭐⭐⭐☆ (Advanced) — Boss-level PL/SQL conversion ahead!

---

## 🕹️ PREREQUISITES

Before entering the arena, make sure your loadout includes:

### 💾 **TECHNICAL SKILLS**
- 🟦 **Oracle SQL & PL/SQL** — You should know your way around cursors, packages, and procedures
- 🐘 **PostgreSQL Basics** — Familiarity with psql, PL/pgSQL helpful but not required
- 🐳 **Docker Desktop** — For running Oracle XE and PostgreSQL containers locally
- ☕ **Java 21 + Maven** — To build and run the legacy airline app
- ☁️ **Azure Subscription** — Active subscription with permission to create resources

### 🛠️ **INSTALLED SOFTWARE**
```bash
# Your toolkit checklist ✅
- Docker Desktop (running)
- Azure CLI (az)
- Git
- Java Development Kit 21
- Maven 3.9+
- GitHub Copilot CLI (gh copilot)
- ora2pg (we'll install during the lab)
```

### 🎮 **MINDSET**
- 🧠 **Patience Level:** HIGH — PL/SQL conversion can be intricate
- 🔧 **Problem-Solving:** ENGAGED — You'll manually fix conversion edge cases
- 🏃 **Persistence:** MAXIMUM — Database migration is a marathon, not a sprint!

---

## ⚡ QUICK START

**LEVEL SELECT:** Choose your path to freedom! 🎮

### 🚀 **1-PLAYER MODE (Full Experience)**

```bash
# Clone the repository
git clone https://github.com/EmeaAppGbb/appmodlab-oracle-to-azure-postgresql.git
cd appmodlab-oracle-to-azure-postgresql

# Start on the LEGACY branch (Oracle prison cell)
git checkout legacy

# Boot up Oracle XE container
docker-compose up -d oracle

# Verify Oracle is alive
docker exec -it oracle-xe sqlplus system/oracle@XEPDB1

# Run the Java app against Oracle
cd app
mvn spring-boot:run
```

### 🏆 **CO-OP MODE (With GitHub Copilot CLI)**

```bash
# Let Copilot guide you through the migration!
gh copilot suggest "Set up Oracle XE container and load sample data"

# Follow the APPMODLAB.md step-by-step guide
# Each step includes Copilot CLI prompts to speed through
```

### 🎬 **WATCH MODE (See the Solution)**

```bash
# Jump to the final boss defeated state
git checkout solution

# Start PostgreSQL
docker-compose up -d postgres

# Run migrated app
cd app
mvn spring-boot:run -Dspring.profiles.active=postgres
```

---

## 📂 PROJECT STRUCTURE

```
appmodlab-oracle-to-azure-postgresql/
│
├── 📜 README.md                    ← You are here! 🌟
├── 📘 APPMODLAB.md                 ← Complete lab walkthrough
├── 🐳 docker-compose.yml           ← Oracle XE + PostgreSQL containers
│
├── 📁 database/
│   ├── oracle/                     ← 🔴 LEGACY ZONE (Oracle DDL, PL/SQL)
│   │   ├── schema/                 ← Table definitions, sequences, synonyms
│   │   ├── packages/               ← 50+ PL/SQL packages (the final boss!)
│   │   ├── materialized-views/     ← Reporting dashboards
│   │   ├── jobs/                   ← DBMS_SCHEDULER definitions
│   │   ├── queues/                 ← Oracle AQ setup
│   │   └── seed-data.sql           ← 10K+ member records
│   │
│   └── postgres/                   ← 🟢 FREEDOM ZONE (PostgreSQL)
│       ├── schema/                 ← Converted DDL
│       ├── functions/              ← PL/pgSQL replacements for PL/SQL packages
│       ├── extensions/             ← pg_cron, pgmq, full-text search
│       └── migrated-data/          ← Post-migration validation scripts
│
├── 📁 app/                         ← Java Spring Boot loyalty program
│   ├── src/
│   │   ├── main/
│   │   │   ├── java/               ← Business logic (JDBC calls)
│   │   │   └── resources/
│   │   │       ├── application-oracle.yml
│   │   │       └── application-postgres.yml
│   └── pom.xml
│
├── 📁 migration/
│   ├── ora2pg.conf                 ← ora2pg configuration
│   ├── assessment-report.html      ← Migration complexity analysis
│   └── conversion-notes.md         ← Manual fixes documented
│
├── 📁 infrastructure/              ← Bicep templates
│   ├── postgres-flexible.bicep     ← Azure Database for PostgreSQL
│   └── dms.bicep                   ← Azure Database Migration Service
│
└── 📁 .github/workflows/
    ├── schema-deploy.yml           ← Deploy PostgreSQL schema
    └── data-validation.yml         ← Row count & checksum tests
```

---

## 🔴 LEGACY STACK (THE PRISON)

**TECH DEBT ALERT!** ⚠️ This is what you're escaping from:

### 🏢 **ORACLE 19C ENTERPRISE EDITION**
- 💸 **Licensing Cost:** $$$$$ (per-core licensing nightmare)
- 🔒 **Vendor Lock-in:** Heavy use of Oracle-specific features
- 🐌 **Scalability:** Vertical scaling only, expensive hardware

### 📦 **ORACLE-SPECIFIC FEATURES IN USE**
| Feature | Usage in SkyReward App | Pain Level |
|---------|------------------------|------------|
| **PL/SQL Packages** | 50+ packages, 200+ procedures | 🔥🔥🔥🔥🔥 |
| **Oracle Sequences** | All ID generation (20+ sequences) | 🔥🔥 |
| **Materialized Views** | 15 reporting dashboards | 🔥🔥🔥 |
| **DBMS_SCHEDULER** | 8 batch jobs (tier calc, mile expiry) | 🔥🔥🔥🔥 |
| **Oracle AQ** | Async reward fulfillment queue | 🔥🔥🔥🔥 |
| **Oracle Text** | Full-text search on reward catalog | 🔥🔥🔥 |
| **Synonyms** | Public/private for schema abstraction | 🔥 |
| **CONNECT BY** | Hierarchical partner referral queries | 🔥🔥🔥 |
| **Oracle Date Functions** | ADD_MONTHS, MONTHS_BETWEEN, TRUNC | 🔥 |
| **BULK COLLECT/FORALL** | Batch operations in PL/SQL | 🔥🔥 |

### ☕ **JAVA APPLICATION**
- Oracle JDBC Thin Driver (ojdbc8)
- SQL queries with Oracle-specific syntax (DUAL, (+) joins, ROWNUM)
- Hard-coded schema references

**THE PROBLEM:** This stack costs a fortune to license, scales poorly, and chains you to a single vendor. Time to break free! 🔓

---

## 🟢 TARGET ARCHITECTURE (THE ESCAPE PLAN)

**WELCOME TO FREEDOM!** 🎉 Here's your new open-source paradise:

### 🐘 **AZURE DATABASE FOR POSTGRESQL FLEXIBLE SERVER**
- 💰 **Cost:** 60-80% cheaper than Oracle (no per-core licensing)
- ☁️ **Managed Service:** Automatic backups, HA, patching
- 📈 **Scaling:** Horizontal read replicas + vertical compute scaling
- 🌍 **Open Source:** PostgreSQL 16 with vibrant community

### 🗺️ **ORACLE → POSTGRESQL FEATURE MAPPING**

| Oracle Feature | PostgreSQL Equivalent | Migration Tool |
|----------------|----------------------|----------------|
| **PL/SQL Packages** | PL/pgSQL Functions (schema-grouped) | ora2pg + manual |
| **Sequences** | SERIAL/BIGSERIAL or UUID | ora2pg auto |
| **Materialized Views** | Materialized Views + pg_cron refresh | ora2pg + pg_cron |
| **DBMS_SCHEDULER** | pg_cron extension | Manual migration |
| **Oracle AQ** | pgmq or Azure Service Bus | Architecture decision |
| **Oracle Text** | tsvector/tsquery (full-text search) | Manual indexing |
| **Synonyms** | PostgreSQL schemas or views | ora2pg |
| **CONNECT BY** | WITH RECURSIVE (CTEs) | Manual rewrite |
| **ADD_MONTHS()** | `date + INTERVAL '1 month'` | Code search & replace |
| **BULK COLLECT** | `FOR ... LOOP` or COPY | Manual rewrite |
| **NUMBER** | NUMERIC or INTEGER/BIGINT | ora2pg auto |
| **VARCHAR2** | VARCHAR or TEXT | ora2pg auto |

### 🛠️ **MIGRATION TOOLCHAIN**
1. **ora2pg** — Automated schema + PL/SQL conversion (does 70% of the work)
2. **Azure Database Migration Service** — Online data migration with minimal downtime
3. **GitHub Copilot CLI** — AI-assisted PL/SQL translation and debugging
4. **pg_cron** — Scheduled job replacement for DBMS_SCHEDULER
5. **pgmq** — Message queue extension (optional, or use Azure Service Bus)

### ☕ **MODERNIZED JAVA APP**
- PostgreSQL JDBC Driver (postgresql-42.x)
- SQL queries rewritten for PostgreSQL syntax
- Connection pooling with HikariCP (cloud-optimized)

**THE VICTORY:** Open-source database, cloud-native architecture, massive cost savings! 🏆💜

---

## 🎮 LAB WALKTHROUGH (USING COPILOT CLI)

**GAME PLAN:** Follow these steps to complete your escape! Each step is a level to beat. 🕹️

### 🌟 **FULL GUIDE:** See `APPMODLAB.md` for detailed walkthrough

Here's the speed-run route with Copilot CLI assist:

#### **LEVEL 1: RECONNAISSANCE** 🔍
```bash
# Check out the Oracle legacy branch
git checkout legacy

# Use Copilot to explore the Oracle schema
gh copilot suggest "Start Oracle XE container and show all tables in the SkyReward schema"

# Let Copilot help you understand the PL/SQL packages
gh copilot suggest "List all PL/SQL packages and their procedure counts"
```
**OBJECTIVE:** Understand what you're up against. Explore schema, packages, Oracle-specific features.

---

#### **LEVEL 2: MIGRATION ASSESSMENT** 📊
```bash
# Install ora2pg
gh copilot suggest "Install ora2pg on my system"

# Run migration complexity report
gh copilot suggest "Run ora2pg assessment against Oracle XE and generate HTML report"

# Review the report (migration/assessment-report.html)
open migration/assessment-report.html  # or `start` on Windows
```
**OBJECTIVE:** Generate ora2pg assessment to see migration complexity scores (A-E rating).

**BOSS TIP:** Look for "C" or worse ratings — those will need manual fixes! 🔥

---

#### **LEVEL 3: SCHEMA CONVERSION** 🗺️
```bash
# Use ora2pg to convert schema
gh copilot suggest "Export Oracle schema to PostgreSQL DDL using ora2pg"

# Review and fix generated DDL
gh copilot suggest "Show me the differences between Oracle and PostgreSQL DDL for sequences"

# Deploy to Azure PostgreSQL
gh copilot suggest "Deploy the converted schema to Azure Database for PostgreSQL Flexible Server"
```
**OBJECTIVE:** Convert DDL (tables, sequences, indexes, synonyms, materialized views) to PostgreSQL.

**CHECKPOINT:** ✅ All tables created, sequences converted to SERIAL or BIGSERIAL

---

#### **LEVEL 4: PL/SQL TRANSLATION** 🗣️ **[BOSS LEVEL]**
```bash
# This is the hardest part! 50+ packages to convert
gh copilot suggest "Convert the MEMBER_MANAGEMENT PL/SQL package to PL/pgSQL functions"

# Use Copilot to handle Oracle-specific syntax
gh copilot suggest "Rewrite this PL/SQL cursor loop using PostgreSQL FOR loop"

# Test each function
gh copilot suggest "Create a test script to validate the calculate_tier_status function"
```
**OBJECTIVE:** Translate PL/SQL packages to PL/pgSQL functions. Handle cursors, exceptions, bulk operations.

**BOSS TIPS:**
- 🎯 Start with simple packages first (utilities, lookups)
- 🧪 Test each function before moving to the next
- 🤖 Use Copilot heavily — it's trained on PL/SQL → PL/pgSQL patterns!
- 📝 Document manual changes in `migration/conversion-notes.md`

**CHECKPOINT:** ✅ All PL/pgSQL functions created and tested

---

#### **LEVEL 5: SCHEDULE & QUEUE MIGRATION** ⏰
```bash
# Convert DBMS_SCHEDULER jobs to pg_cron
gh copilot suggest "Convert Oracle DBMS_SCHEDULER job for tier recalculation to pg_cron"

# Set up pgmq or Azure Service Bus
gh copilot suggest "Migrate Oracle AQ reward fulfillment queue to Azure Service Bus"
```
**OBJECTIVE:** Replace Oracle scheduler and queuing with PostgreSQL/Azure equivalents.

**CHECKPOINT:** ✅ pg_cron jobs scheduled, queue system operational

---

#### **LEVEL 6: DATA MIGRATION** 🚚
```bash
# Set up Azure DMS
gh copilot suggest "Configure Azure Database Migration Service for Oracle to PostgreSQL"

# Run full data migration
gh copilot suggest "Start DMS migration and monitor progress"

# Validate data integrity
gh copilot suggest "Compare row counts and checksums between Oracle and PostgreSQL"
```
**OBJECTIVE:** Move 500K+ member records, flight data, redemptions to PostgreSQL.

**CHECKPOINT:** ✅ All data migrated, row counts match, checksums validated

---

#### **LEVEL 7: APPLICATION ADAPTATION** ☕
```bash
# Update Java dependencies
gh copilot suggest "Replace Oracle JDBC driver with PostgreSQL driver in pom.xml"

# Fix SQL dialect differences
gh copilot suggest "Find all SQL queries using Oracle syntax like DUAL or (+) joins"

# Switch connection string
gh copilot suggest "Update application.yml to connect to Azure PostgreSQL"

# Run the app!
mvn spring-boot:run -Dspring.profiles.active=postgres
```
**OBJECTIVE:** Adapt Java application to work with PostgreSQL.

**CHECKPOINT:** ✅ Application runs successfully against PostgreSQL

---

#### **LEVEL 8: VALIDATION** ✅
```bash
# Run end-to-end tests
gh copilot suggest "Run all integration tests against PostgreSQL"

# Compare results with Oracle
gh copilot suggest "Run parallel test suite against Oracle and PostgreSQL, compare outputs"

# Performance benchmark
gh copilot suggest "Benchmark query performance between Oracle and PostgreSQL"
```
**OBJECTIVE:** Prove that PostgreSQL version is functionally identical to Oracle.

**VICTORY CONDITIONS:**
- ✅ All tests pass
- ✅ Business logic produces identical results
- ✅ Performance is acceptable (or better!)
- 🎉 **LICENSE FREED!** You've escaped the Oracle Matrix!

---

## ⏱️ DURATION

**ESTIMATED TIME TO COMPLETE:** 5-7 hours ⏳

**SPEEDRUN SPLITS:**
- Level 1 (Reconnaissance): 30 min
- Level 2 (Assessment): 30 min
- Level 3 (Schema Conversion): 1 hour
- Level 4 (PL/SQL Translation): **3-4 hours** ⚠️ (Boss level!)
- Level 5 (Schedule/Queue): 45 min
- Level 6 (Data Migration): 1 hour
- Level 7 (App Adaptation): 45 min
- Level 8 (Validation): 30 min

**PROTIP:** Use GitHub Copilot CLI heavily during Level 4 to cut PL/SQL conversion time in half! 🤖✨

---

## 📚 RESOURCES

### 🔗 **ESSENTIAL READING**
- [Azure Database for PostgreSQL Documentation](https://learn.microsoft.com/azure/postgresql/)
- [ora2pg Official Guide](https://ora2pg.darold.net/documentation.html)
- [PostgreSQL PL/pgSQL Documentation](https://www.postgresql.org/docs/current/plpgsql.html)
- [Azure Database Migration Service](https://learn.microsoft.com/azure/dms/)
- [pg_cron Extension](https://github.com/citusdata/pg_cron)

### 🧰 **TOOLS & EXTENSIONS**
- [ora2pg](https://ora2pg.darold.net/) — Schema and PL/SQL converter
- [pgmq](https://github.com/tembo-io/pgmq) — PostgreSQL message queue
- [PostgreSQL JDBC Driver](https://jdbc.postgresql.org/)

### 🎓 **LEARNING PATHS**
- [Microsoft Learn: Migrate Oracle to PostgreSQL](https://learn.microsoft.com/training/paths/migrate-oracle-azure-postgresql/)
- [Oracle vs PostgreSQL Syntax Comparison](https://wiki.postgresql.org/wiki/Oracle_to_Postgres_Conversion)
- [PL/SQL to PL/pgSQL Migration Guide](https://www.postgresql.org/docs/current/plpgsql-porting.html)

### 💬 **COMMUNITY**
- [PostgreSQL Slack](https://postgres-slack.herokuapp.com/)
- [Azure PostgreSQL Forums](https://learn.microsoft.com/answers/tags/191/azure-database-postgresql)

---

## 🏆 ACHIEVEMENT UNLOCKED!

When you complete this lab, you'll have:

- 🔓 **ESCAPED THE MATRIX** — Broken free from Oracle licensing
- 💰 **COST OPTIMIZER** — Reduced database costs by 60-80%
- 🗣️ **PL/SQL TRANSLATOR** — Converted 50+ packages to PL/pgSQL
- 🚚 **DATA TELEPORTER** — Migrated 500K+ records with zero data loss
- 🐘 **POSTGRES PRO** — Mastered Azure Database for PostgreSQL
- 🤖 **AI-ASSISTED ENGINEER** — Leveraged Copilot CLI for complex migrations

**SHARE YOUR VICTORY:** Tag `#AzurePostgreSQL` `#OracleMigration` `#AppModLabs` when you complete! 🎉

---

## 🎨 CREDITS

**Lab Created By:** Microsoft Global Black Belt (GBB) App Innovation Team 💜  
**Arcade Aesthetics:** Synthwave/Retrowave vibes 🌆✨  
**Powered By:** GitHub Copilot CLI 🤖 + Azure ☁️  

```
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║           ⚡ READY PLAYER ONE? START THE LAB! ⚡              ║
║                                                               ║
║          👾 git checkout legacy && docker-compose up 👾       ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

**LICENSE FREED. OPEN SOURCE VICTORY. GAME OVER.** 🎮🏆✨
