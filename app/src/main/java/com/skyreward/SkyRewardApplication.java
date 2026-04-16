package com.skyreward;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * SkyReward Airlines Loyalty Program Application.
 *
 * Migrated from Oracle Database to Azure Database for PostgreSQL.
 * Key migration changes reflected in this application:
 * - Oracle JDBC (ojdbc) replaced with PostgreSQL JDBC driver
 * - Oracle-specific SQL dialects replaced with PostgreSQL-compatible queries
 * - PL/SQL package calls replaced with PL/pgSQL standalone function calls
 * - Oracle sequences replaced with PostgreSQL sequences (DEFAULT nextval)
 * - HikariCP connection pool (Spring Boot default) replaces Oracle UCP
 */
@SpringBootApplication
public class SkyRewardApplication {

    public static void main(String[] args) {
        SpringApplication.run(SkyRewardApplication.class, args);
    }
}
