#!/usr/bin/env bash
# ============================================================================
# SkyReward Migration Validation Runner
# ============================================================================
# Connects to PostgreSQL, deploys schema, and runs all validation scripts.
#
# Usage:
#   ./scripts/run-validation.sh
#
# Environment variables (with defaults from docker-compose.yml):
#   PGHOST      (default: localhost)
#   PGPORT      (default: 5433)
#   PGUSER      (default: skyreward_admin)
#   PGPASSWORD  (default: PostgresPass123)
#   PGDATABASE  (default: skyreward)
#   SKIP_SETUP  (default: false) – set to "true" to skip schema deployment
# ============================================================================

set -euo pipefail

# --- Configuration ---
PGHOST="${PGHOST:-localhost}"
PGPORT="${PGPORT:-5433}"
PGUSER="${PGUSER:-skyreward_admin}"
PGPASSWORD="${PGPASSWORD:-PostgresPass123}"
PGDATABASE="${PGDATABASE:-skyreward}"
SKIP_SETUP="${SKIP_SETUP:-false}"

export PGHOST PGPORT PGUSER PGPASSWORD PGDATABASE

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS_COUNT=0
FAIL_COUNT=0
RESULTS=()

# --- Helpers ---
log()  { echo "[$(date '+%H:%M:%S')] $*"; }
pass() { PASS_COUNT=$((PASS_COUNT + 1)); RESULTS+=("✅  PASS: $1"); log "✅  PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); RESULTS+=("❌  FAIL: $1"); log "❌  FAIL: $1"; }

run_sql_file() {
    local label="$1"
    local file="$2"
    log "Running: $label ($file)"
    if psql -v ON_ERROR_STOP=1 --no-psqlrc -f "$file" 2>&1; then
        pass "$label"
    else
        fail "$label"
    fi
}

# --- Pre-flight check ---
log "Connecting to PostgreSQL at $PGHOST:$PGPORT/$PGDATABASE as $PGUSER ..."
if ! psql -c "SELECT 1" > /dev/null 2>&1; then
    log "ERROR: Cannot connect to PostgreSQL. Check connection settings."
    exit 1
fi
log "Connection OK"

# --- Phase 1: Schema Deployment ---
if [ "$SKIP_SETUP" = "true" ]; then
    log "SKIP_SETUP=true – skipping schema deployment"
else
    log ""
    log "========================================"
    log "  Phase 1: Schema Deployment"
    log "========================================"
    cd "$REPO_ROOT/postgresql"
    run_sql_file "Schema deployment (setup.sql)" "setup.sql"
    cd "$REPO_ROOT"
fi

# --- Phase 2: Schema Validation ---
log ""
log "========================================"
log "  Phase 2: Schema Validation"
log "========================================"
run_sql_file "Schema object validation" "$REPO_ROOT/scripts/validate-schema.sql"

# --- Phase 3: Function Validation ---
log ""
log "========================================"
log "  Phase 3: Function Validation"
log "========================================"
run_sql_file "Function tests" "$REPO_ROOT/scripts/validate-functions.sql"

# --- Phase 4: Integration Tests ---
log ""
log "========================================"
log "  Phase 4: Integration Tests"
log "========================================"

if [ -d "$REPO_ROOT/tests/integration" ]; then
    for test_file in "$REPO_ROOT"/tests/integration/test_*.sql; do
        if [ -f "$test_file" ]; then
            test_name="$(basename "$test_file" .sql)"
            run_sql_file "Integration: $test_name" "$test_file"
        fi
    done
else
    log "No integration test directory found – skipping"
fi

# --- Phase 5: Data Validation ---
log ""
log "========================================"
log "  Phase 5: Data Validation"
log "========================================"
if [ -f "$REPO_ROOT/scripts/validate-migration.sql" ]; then
    run_sql_file "Data migration validation" "$REPO_ROOT/scripts/validate-migration.sql"
else
    log "validate-migration.sql not found – skipping"
fi

# --- Summary ---
log ""
log "========================================"
log "  VALIDATION SUMMARY"
log "========================================"
for r in "${RESULTS[@]}"; do
    echo "  $r"
done
log ""
log "Passed: $PASS_COUNT  |  Failed: $FAIL_COUNT  |  Total: $((PASS_COUNT + FAIL_COUNT))"
log ""

if [ "$FAIL_COUNT" -gt 0 ]; then
    log "❌  VALIDATION FAILED"
    exit 1
else
    log "✅  ALL VALIDATIONS PASSED"
    exit 0
fi
