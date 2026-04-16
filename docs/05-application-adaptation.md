# Step 5: Application Adaptation — Oracle to PostgreSQL

This guide documents the patterns, changes, and pitfalls encountered when migrating a Java Spring Boot application from Oracle Database to Azure Database for PostgreSQL.

## Table of Contents

1. [JDBC Driver Migration](#1-jdbc-driver-migration)
2. [Connection Configuration Changes](#2-connection-configuration-changes)
3. [JPA Entity Adaptations](#3-jpa-entity-adaptations)
4. [SQL Dialect Changes](#4-sql-dialect-changes)
5. [Stored Procedure / Function Call Migration](#5-stored-procedure--function-call-migration)
6. [Data Type Mapping Reference](#6-data-type-mapping-reference)
7. [Common Pitfalls](#7-common-pitfalls)
8. [Testing the Migration](#8-testing-the-migration)

---

## 1. JDBC Driver Migration

### Maven Dependency Change

**Before (Oracle):**
```xml
<dependency>
    <groupId>com.oracle.database.jdbc</groupId>
    <artifactId>ojdbc11</artifactId>
    <version>23.3.0.23.09</version>
    <scope>runtime</scope>
</dependency>
```

**After (PostgreSQL):**
```xml
<dependency>
    <groupId>org.postgresql</groupId>
    <artifactId>postgresql</artifactId>
    <scope>runtime</scope>  <!-- version managed by Spring Boot BOM -->
</dependency>
```

### Connection Pool Migration

Oracle applications often use Oracle UCP (Universal Connection Pool). Spring Boot defaults to **HikariCP**, which works identically with PostgreSQL and requires no additional dependencies.

```xml
<!-- No longer needed -->
<!-- <artifactId>ucp</artifactId> -->
```

### Flyway Migration Module

```xml
<!-- Before: flyway-database-oracle -->
<!-- After: -->
<dependency>
    <groupId>org.flywaydb</groupId>
    <artifactId>flyway-database-postgresql</artifactId>
</dependency>
```

---

## 2. Connection Configuration Changes

### JDBC URL Format

| Component       | Oracle                                    | PostgreSQL                              |
|-----------------|-------------------------------------------|-----------------------------------------|
| URL prefix      | `jdbc:oracle:thin:@`                      | `jdbc:postgresql://`                    |
| Format          | `jdbc:oracle:thin:@host:port/service`     | `jdbc:postgresql://host:port/database`  |
| Example         | `jdbc:oracle:thin:@localhost:1521/SKYREWARD` | `jdbc:postgresql://localhost:5433/skyreward` |
| Driver class    | `oracle.jdbc.OracleDriver`                | `org.postgresql.Driver`                 |

### Spring Boot `application.yml`

```yaml
# PostgreSQL configuration
spring:
  datasource:
    url: jdbc:postgresql://localhost:5433/skyreward
    username: skyreward_admin
    password: ${DB_PASSWORD}
    driver-class-name: org.postgresql.Driver
  jpa:
    database-platform: org.hibernate.dialect.PostgreSQLDialect
```

### Key Config Differences

- **Hibernate dialect**: `OracleDialect` → `PostgreSQLDialect`
- **Schema qualification**: Oracle uses `SCHEMA.TABLE`; PostgreSQL uses `schema.table` (lowercase) or `search_path`
- **Auto-commit**: Oracle JDBC default is OFF; PostgreSQL is ON (Spring `@Transactional` manages this)

---

## 3. JPA Entity Adaptations

### ID Generation Strategy

**Oracle approach** — explicit sequence calls:
```java
@Id
@GeneratedValue(strategy = GenerationType.SEQUENCE,
    generator = "member_seq")
@SequenceGenerator(name = "member_seq",
    sequenceName = "SEQ_MEMBER_ID", allocationSize = 1)
private Integer memberId;
```

**PostgreSQL approach** — `IDENTITY` with sequence defaults:
```java
@Id
@GeneratedValue(strategy = GenerationType.IDENTITY)
@Column(name = "member_id")
private Integer memberId;
```

The PostgreSQL schema wires sequences via `ALTER TABLE ... SET DEFAULT nextval('seq_member_id')`, making the column behave like an auto-increment `IDENTITY` column. JPA's `GenerationType.IDENTITY` delegates ID generation entirely to the database.

### CLOB → TEXT

Oracle `CLOB` columns map to PostgreSQL `TEXT`:

```java
// Oracle: @Lob annotation was often required for CLOB
// PostgreSQL: simple String with columnDefinition
@Column(name = "notes", columnDefinition = "TEXT")
private String notes;
```

### Date/Timestamp Mapping

Oracle's `DATE` type includes time (unlike standard SQL). After migration to PostgreSQL `TIMESTAMP`:

```java
// Oracle DATE (with time) → PostgreSQL TIMESTAMP → Java LocalDateTime
@Column(name = "enrollment_date")
private LocalDateTime enrollmentDate;

// True date-only columns (rare in Oracle) → PostgreSQL DATE → Java LocalDate
@Column(name = "date_of_birth")
private LocalDate dateOfBirth;
```

---

## 4. SQL Dialect Changes

### Function and Expression Differences

| Feature                | Oracle                        | PostgreSQL                     |
|------------------------|-------------------------------|--------------------------------|
| Null coalescing        | `NVL(x, y)`                  | `COALESCE(x, y)`              |
| Conditional expression | `DECODE(x, a, b, c)`         | `CASE x WHEN a THEN b ELSE c END` |
| Current timestamp      | `SYSDATE`                    | `CURRENT_TIMESTAMP`            |
| Current user           | `USER`                       | `CURRENT_USER`                 |
| String concatenation   | `\|\|` (same)                | `\|\|` (same)                  |
| Sequence next value    | `seq_name.NEXTVAL`           | `nextval('seq_name')`          |
| Sequence current value | `seq_name.CURRVAL`           | `currval('seq_name')`          |
| Substring              | `SUBSTR(str, pos, len)`      | `SUBSTR(str, pos, len)` (same) |
| Truncate number        | `TRUNC(n)`                   | `TRUNC(n)` (same)              |
| String padding         | `LPAD(str, len, pad)`        | `LPAD(str, len, pad)` (same)   |
| Empty string           | Treated as `NULL`            | **Empty string ≠ NULL**        |
| Row limiting           | `ROWNUM <= n`                | `LIMIT n` / `FETCH FIRST n ROWS ONLY` |
| Outer join (+)         | `WHERE a.id = b.id(+)`      | `LEFT JOIN b ON a.id = b.id`  |

### Pagination

**Oracle (pre-12c):**
```sql
SELECT * FROM (
    SELECT t.*, ROWNUM rn FROM members t WHERE ROWNUM <= 20
) WHERE rn > 10;
```

**PostgreSQL:**
```sql
SELECT * FROM members LIMIT 10 OFFSET 10;
-- or ANSI standard (also works in Oracle 12c+):
SELECT * FROM members FETCH FIRST 10 ROWS ONLY OFFSET 10;
```

### Boolean Handling

Oracle has no native `BOOLEAN` type in SQL; it typically uses `NUMBER(1)` or `VARCHAR2(1)` with `'Y'`/`'N'`. PostgreSQL has a native `BOOLEAN` type, but the migrated schema preserves `VARCHAR(1)` columns (e.g., `lounge_access`) for backward compatibility.

---

## 5. Stored Procedure / Function Call Migration

This is the most significant change area. Oracle PL/SQL packages are refactored into PostgreSQL standalone PL/pgSQL functions.

### Package Calls → Standalone Function Calls

**Oracle JDBC (callable statement):**
```java
CallableStatement cs = conn.prepareCall(
    "{call PKG_MEMBER_MGMT.REGISTER_MEMBER(?, ?, ?, ?, ?, ?)}");
cs.setString(1, firstName);
cs.setString(2, lastName);
cs.setString(3, email);
cs.registerOutParameter(5, Types.BIGINT);    // member_id OUT
cs.registerOutParameter(6, Types.VARCHAR);   // membership_num OUT
cs.execute();
long memberId = cs.getLong(5);
String memberNum = cs.getString(6);
```

**PostgreSQL (native query via JPA):**
```java
Object[] result = (Object[]) entityManager.createNativeQuery(
    "SELECT * FROM member_mgmt_register_member(:fn, :ln, :email, :phone, NULL, :country)")
    .setParameter("fn", firstName)
    .setParameter("ln", lastName)
    .setParameter("email", email)
    .setParameter("phone", phone)
    .setParameter("country", "US")
    .getSingleResult();

long memberId = ((Number) result[0]).longValue();
String memberNum = (String) result[1];
```

### Key Differences in Function Calls

| Aspect                 | Oracle PL/SQL                          | PostgreSQL PL/pgSQL                    |
|------------------------|----------------------------------------|----------------------------------------|
| Package reference      | `PKG_NAME.PROC_NAME(args)`            | `pkg_prefix_proc_name(args)`           |
| OUT parameters         | `CallableStatement.registerOutParameter` | `RETURNS TABLE(...)` → `SELECT *`    |
| REF CURSOR return      | `SYS_REFCURSOR` OUT param             | `RETURNS TABLE(...)` with `RETURN QUERY` |
| Exception type         | `ORA-20001` custom errors             | `RAISE EXCEPTION 'message'` → `PSQLException` |
| Transaction control    | `COMMIT`/`ROLLBACK` inside procedures | External transaction control (Spring `@Transactional`) |
| Boolean parameters     | `PL/SQL BOOLEAN` (not SQL-accessible) | PostgreSQL `BOOLEAN` works in SQL      |

### Scalar Function Calls

Simple functions with scalar return values work the same way:

```java
// Works for both Oracle and PostgreSQL via JPA native query
String tierStatus = (String) entityManager.createNativeQuery(
    "SELECT fn_get_tier_status(:memberId)")
    .setParameter("memberId", memberId)
    .getSingleResult();
```

---

## 6. Data Type Mapping Reference

| Oracle Type          | PostgreSQL Type  | Java Type          | Notes                                    |
|----------------------|------------------|--------------------|------------------------------------------|
| `NUMBER(10)`         | `INTEGER`        | `Integer`          | Up to ~2 billion                         |
| `NUMBER(12)`         | `BIGINT`         | `Long`             | Large IDs, counters                      |
| `NUMBER(10,2)`       | `NUMERIC(10,2)`  | `BigDecimal`       | Exact decimal arithmetic                 |
| `NUMBER(15)`         | `BIGINT`         | `Long`             | Lifetime miles counters                  |
| `VARCHAR2(n)`        | `VARCHAR(n)`     | `String`           | Direct mapping                           |
| `CLOB`               | `TEXT`           | `String`           | No size limit in PostgreSQL              |
| `DATE`               | `TIMESTAMP`      | `LocalDateTime`    | Oracle DATE includes time component      |
| `DATE` (date-only)   | `DATE`           | `LocalDate`        | When time is not used                    |
| `RAW(16)`            | `UUID`           | `UUID`             | For UUID/GUID columns                    |
| `BLOB`               | `BYTEA`          | `byte[]`           | Binary data                              |

---

## 7. Common Pitfalls

### 7.1 Empty String vs NULL

**Oracle** treats empty strings (`''`) as `NULL`. PostgreSQL does **not**.

```java
// This query returns different results on Oracle vs PostgreSQL!
// Oracle: WHERE name IS NOT NULL  -- excludes '' (treated as NULL)
// PostgreSQL: WHERE name IS NOT NULL  -- includes '' (empty ≠ NULL)

// Fix: add explicit empty-string check if needed
"WHERE name IS NOT NULL AND name <> ''"
```

### 7.2 Case Sensitivity in Identifiers

Oracle stores unquoted identifiers as **UPPERCASE**. PostgreSQL stores them as **lowercase**.

```sql
-- Oracle: CREATE TABLE Members → stored as MEMBERS
-- PostgreSQL: CREATE TABLE Members → stored as members

-- If you quoted them in Oracle: CREATE TABLE "Members" → stored as Members
-- Same quoting behavior in PostgreSQL

-- JPA entities: use explicit @Column(name = "lower_case_name")
```

### 7.3 Sequence Usage in JPA

Oracle uses `seq.NEXTVAL` inline in SQL; PostgreSQL uses `nextval('seq')`. With JPA `GenerationType.IDENTITY`, the database handles this via column defaults — no application-level change needed.

However, if calling sequences explicitly in native queries:

```java
// Oracle:
"SELECT seq_member_id.NEXTVAL FROM dual"

// PostgreSQL:
"SELECT nextval('seq_member_id')"
```

### 7.4 DUAL Table

Oracle requires `FROM dual` for computed SELECTs. PostgreSQL does not:

```sql
-- Oracle:
SELECT SYSDATE FROM dual;

-- PostgreSQL:
SELECT CURRENT_TIMESTAMP;  -- no FROM clause needed
```

### 7.5 Exception Handling

Oracle raises `ORA-20xxx` custom errors. PostgreSQL raises `SQLSTATE` codes with custom messages:

```java
try {
    memberService.registerMember(...);
} catch (DataAccessException e) {
    // Oracle: ORA-20001: Email address already registered
    // PostgreSQL: ERROR: Email address already registered (SQLSTATE P0001)
    // Spring wraps both as DataAccessException subtypes
    String message = e.getMostSpecificCause().getMessage();
}
```

### 7.6 Date Arithmetic

```sql
-- Oracle: ADD_MONTHS(date, 12)
-- PostgreSQL: date + INTERVAL '12 months'

-- Oracle: SYSDATE - 30
-- PostgreSQL: CURRENT_DATE - INTERVAL '30 days'  (or CURRENT_DATE - 30)
```

### 7.7 ROWNUM vs LIMIT

Oracle's `ROWNUM` pseudo-column does not exist in PostgreSQL:

```sql
-- Oracle:
SELECT * FROM members WHERE ROWNUM <= 10;

-- PostgreSQL:
SELECT * FROM members LIMIT 10;
```

Spring Data JPA's `Pageable` abstracts this — use `Pageable` in repository methods to avoid writing raw pagination SQL.

### 7.8 CONNECT BY (Hierarchical Queries)

Oracle's `CONNECT BY ... START WITH` becomes PostgreSQL's `WITH RECURSIVE`:

```sql
-- Oracle:
SELECT * FROM categories
START WITH parent_id IS NULL
CONNECT BY PRIOR category_id = parent_id;

-- PostgreSQL:
WITH RECURSIVE cat_tree AS (
    SELECT * FROM categories WHERE parent_id IS NULL
    UNION ALL
    SELECT c.* FROM categories c JOIN cat_tree ct ON c.parent_id = ct.category_id
)
SELECT * FROM cat_tree;
```

---

## 8. Testing the Migration

### Verify the Application Starts

```bash
cd app/
mvn spring-boot:run
```

### Test REST Endpoints

```bash
# Calculate miles (calls fn_calculate_miles PL/pgSQL function)
curl http://localhost:8080/api/members/calculate-miles?distance=2500\&bookingClass=Y\&cabinClass=BUSINESS\&tier=GOLD

# Get member tier status (calls fn_get_tier_status PL/pgSQL function)
curl http://localhost:8080/api/members/1000000/tier-status

# Register a new member (calls member_mgmt_register_member PL/pgSQL function)
curl -X POST http://localhost:8080/api/members/register \
  -H "Content-Type: application/json" \
  -d '{"firstName":"Jane","lastName":"Doe","email":"jane.doe@example.com","phone":"+1-555-0199"}'

# Search members (uses Spring Data JPA JPQL query)
curl "http://localhost:8080/api/members/search?lastName=Smith"
```

### Checklist

- [ ] Application starts without Hibernate schema validation errors
- [ ] All REST endpoints return expected data
- [ ] PL/pgSQL function calls return correct results
- [ ] Transactions commit/rollback correctly
- [ ] No Oracle-specific SQL in logs (search for `SYSDATE`, `NVL`, `ROWNUM`, `.NEXTVAL`)
- [ ] Connection pool metrics show healthy connections via `/actuator/metrics`
- [ ] Flyway migrations apply cleanly (check `flyway_schema_history` table)
