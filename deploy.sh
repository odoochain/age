#!/bin/bash
# Apache AGE + pgvector automated deployment script
# Usage: deploy.sh <command> [options]

set -e

# ── Configurable variables ──────────────────────────────────────────
AGE_SOURCE="D:/dev/lawgraph/age-source"
PGVECTOR_SOURCE="D:/dev/lawgraph/pgvector"
PG_PORT=5433
PG_DATA="D:/mydata/pgdata"
PG_DATABASE="age_test"
PG_USER="odoo"
PG_PASSWORD="odoo"

# ── Parse options ───────────────────────────────────────────────────
PGVECTOR_ONLY=false
AGE_ONLY=false
SKIP_BUILD=false
SKIP_VERIFY=false

for arg in "$@"; do
  case "$arg" in
    --pgvector-only)  PGVECTOR_ONLY=true ;;
    --age-only)       AGE_ONLY=true ;;
    --skip-build)     SKIP_BUILD=true ;;
    --skip-verify)    SKIP_VERIFY=true ;;
    --port=*)         PG_PORT="${arg#*=}" ;;
    --db=*)           PG_DATABASE="${arg#*=}" ;;
  esac
done

# ── Helpers ─────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

step=0
total=0

ok()   { echo -e "  [${GREEN}OK${NC}] $1"; }
skip() { echo -e "  [${YELLOW}SKIP${NC}] $1"; }
fail() { echo -e "  [${RED}FAIL${NC}] $1"; exit 1; }
warn() { echo -e "  [${YELLOW}WARN${NC}] $1"; }

psql_cmd() {
  psql -p "$PG_PORT" "$@" 2>&1
}

# ── check_prerequisites ─────────────────────────────────────────────
check_prerequisites() {
  echo ""
  echo "=== Step $((++step))/$total: Check prerequisites ==="
  for cmd in gcc pg_config bison flex make psql; do
    if command -v "$cmd" >/dev/null 2>&1; then
      ok "$cmd found: $(command -v "$cmd")"
    else
      fail "$cmd not found on PATH"
    fi
  done
  local pgver
  pgver=$(pg_config --version 2>&1)
  if echo "$pgver" | grep -qi "gcc\|mingw"; then
    ok "pg_config points to MinGW build: $pgver"
  else
    warn "pg_config may not be MinGW build: $pgver"
  fi
}

# ── build_age ───────────────────────────────────────────────────────
build_age() {
  echo ""
  echo "=== Step $((++step))/$total: Build AGE ==="
  if [ "$SKIP_BUILD" = true ]; then
    skip "Skipping build (--skip-build)"
    return
  fi
  cd "$AGE_SOURCE"
  make clean >/dev/null 2>&1 || true
  make PG_CONFIG=/mingw64/bin/pg_config \
       BISON=/usr/bin/bison \
       FLEX=/usr/bin/flex \
       PERL=/mingw64/bin/perl 2>&1 | tail -5
  if [ -f age.dll ]; then
    ok "age.dll built ($(wc -c < age.dll) bytes)"
  else
    fail "age.dll not found after build"
  fi
}

# ── build_vector ────────────────────────────────────────────────────
build_vector() {
  echo ""
  echo "=== Step $((++step))/$total: Build pgvector ==="
  if [ "$SKIP_BUILD" = true ]; then
    skip "Skipping build (--skip-build)"
    return
  fi
  cd "$PGVECTOR_SOURCE"
  make clean >/dev/null 2>&1 || true
  make PG_CONFIG=/mingw64/bin/pg_config OPTFLAGS="" 2>&1 | tail -5
  if [ -f vector.dll ]; then
    ok "vector.dll built ($(wc -c < vector.dll) bytes)"
  else
    fail "vector.dll not found after build"
  fi
}

# ── install_age ─────────────────────────────────────────────────────
install_age() {
  echo ""
  echo "=== Step $((++step))/$total: Install AGE ==="
  cd "$AGE_SOURCE"
  make PG_CONFIG=/mingw64/bin/pg_config \
       BISON=/usr/bin/bison \
       FLEX=/usr/bin/flex \
       PERL=/mingw64/bin/perl install 2>&1 | tail -3
  ok "AGE installed to PG extension dir"
}

# ── install_vector ──────────────────────────────────────────────────
install_vector() {
  echo ""
  echo "=== Step $((++step))/$total: Install pgvector ==="
  cd "$PGVECTOR_SOURCE"
  make PG_CONFIG=/mingw64/bin/pg_config install 2>&1 | tail -3
  ok "pgvector installed to PG extension dir"
}

# ── pg_start ────────────────────────────────────────────────────────
pg_start() {
  echo ""
  echo "=== Step $((++step))/$total: Start PostgreSQL ==="
  if pg_ctl -D "$PG_DATA" status >/dev/null 2>&1; then
    skip "PostgreSQL already running on port $PG_PORT"
  else
    pg_ctl -D "$PG_DATA" -o "-p $PG_PORT" -l /tmp/pg_logfile start 2>&1
    sleep 3
    if pg_ctl -D "$PG_DATA" status >/dev/null 2>&1; then
      ok "PostgreSQL started on port $PG_PORT"
    else
      fail "PostgreSQL failed to start"
    fi
  fi
}

# ── init_database ───────────────────────────────────────────────────
init_database() {
  echo ""
  echo "=== Step $((++step))/$total: Initialize database ==="
  psql_cmd -d postgres -c "DROP DATABASE IF EXISTS $PG_DATABASE;" >/dev/null
  psql_cmd -d postgres -c "CREATE DATABASE $PG_DATABASE;" >/dev/null
  ok "Database '$PG_DATABASE' created"

  psql_cmd -d "$PG_DATABASE" -f "$AGE_SOURCE/enable_age.sql" >/dev/null
  ok "AGE extension enabled"

  psql_cmd -d "$PG_DATABASE" -f "$PGVECTOR_SOURCE/sql/vector.sql" >/dev/null 2>&1 || \
  psql_cmd -d "$PG_DATABASE" -c "CREATE EXTENSION IF NOT EXISTS vector;" >/dev/null
  ok "pgvector extension enabled"

  psql_cmd -d postgres -f "$AGE_SOURCE/create_odoo_user.sql" >/dev/null
  ok "User '$PG_USER' created"
}

# ── verify ──────────────────────────────────────────────────────────
verify() {
  echo ""
  echo "=== Step $((++step))/$total: Verify deployment ==="

  # AGE verify
  local tmpsql=$(mktemp /tmp/verify_age_XXXXXX.sql)
  cat > "$tmpsql" << 'AGEEOF'
LOAD 'age';
SET search_path = ag_catalog, "$user", public;
SELECT create_graph('deploy_test');
SELECT * FROM cypher('deploy_test', $$CREATE (n:Test {name: 'ok'}) RETURN n$$) AS (v agtype);
AGEEOF
  local age_result
  age_result=$(psql_cmd -d "$PG_DATABASE" -f "$tmpsql" 2>&1)
  rm -f "$tmpsql"
  if echo "$age_result" | grep -q "ok"; then
    ok "AGE Cypher query successful"
  else
    warn "AGE query result: $age_result"
  fi

  # pgvector verify
  local vec_result
  vec_result=$(psql_cmd -d "$PG_DATABASE" -c "SELECT '[1,2,3]'::vector <-> '[4,5,6]'::vector AS distance;" 2>&1) || true
  if echo "$vec_result" | grep -qE "[0-9]+\.[0-9]+"; then
    ok "pgvector distance query successful"
  else
    warn "pgvector query result: $vec_result"
  fi

  # User verify
  local user_result
  user_result=$(psql_cmd -d postgres -c "SELECT rolname FROM pg_roles WHERE rolname='$PG_USER';" 2>&1) || true
  if echo "$user_result" | grep -q "$PG_USER"; then
    ok "User '$PG_USER' exists"
  else
    warn "User check: $user_result"
  fi
}

# ── status ──────────────────────────────────────────────────────────
status_cmd() {
  echo ""
  echo "=== PostgreSQL Status ==="
  pg_ctl -D "$PG_DATA" status 2>&1 || echo "PostgreSQL is NOT running"

  echo ""
  echo "=== Installed Extensions ==="
  psql_cmd -d "$PG_DATABASE" -c "SELECT extname, extversion FROM pg_extension WHERE extname IN ('age','vector');" 2>/dev/null || echo "Cannot connect to $PG_DATABASE"

  echo ""
  echo "=== Available Extensions ==="
  psql_cmd -d postgres -f "$AGE_SOURCE/check_age.sql" 2>/dev/null || true
  psql_cmd -d "$PG_DATABASE" -c "SELECT name, default_version FROM pg_available_extensions WHERE name='vector';" 2>/dev/null || true

  echo ""
  echo "=== Users ==="
  psql_cmd -d postgres -c "SELECT rolname, rolsuper, rolcanlogin FROM pg_roles WHERE rolname='$PG_USER';" 2>/dev/null || true

  echo ""
  echo "=== Databases ==="
  psql_cmd -d postgres -c "SELECT datname FROM pg_database WHERE datistemplate=false ORDER BY datname;" 2>/dev/null || true
}

# ── Main dispatch ───────────────────────────────────────────────────
COMMAND="${1:-help}"

case "$COMMAND" in
  all)
    total=8
    check_prerequisites
    if [ "$AGE_ONLY" = false ]; then build_vector; fi
    if [ "$PGVECTOR_ONLY" = false ]; then build_age; fi
    if [ "$AGE_ONLY" = false ]; then install_vector; fi
    if [ "$PGVECTOR_ONLY" = false ]; then install_age; fi
    pg_start
    init_database
    if [ "$SKIP_VERIFY" = false ]; then verify; fi
    echo ""
    echo "=== Deployment complete ==="
    echo "  Port: $PG_PORT"
    echo "  Database: $PG_DATABASE"
    echo "  User: $PG_USER / $PG_PASSWORD"
    echo "  Connect: psql -p $PG_PORT -d $PG_DATABASE"
    ;;
  build)
    total=2
    check_prerequisites
    if [ "$PGVECTOR_ONLY" = false ]; then build_age; fi
    if [ "$AGE_ONLY" = false ]; then build_vector; fi
    ;;
  install)
    total=2
    if [ "$PGVECTOR_ONLY" = false ]; then install_age; fi
    if [ "$AGE_ONLY" = false ]; then install_vector; fi
    ;;
  init)
    total=1
    pg_start
    init_database
    ;;
  verify)
    total=1
    verify
    ;;
  status)
    status_cmd
    ;;
  start)
    pg_start
    ;;
  stop)
    echo "Stopping PostgreSQL..."
    pg_ctl -D "$PG_DATA" stop 2>&1
    ok "PostgreSQL stopped"
    ;;
  restart)
    pg_ctl -D "$PG_DATA" stop 2>&1 || true
    sleep 1
    pg_start
    ;;
  help|--help|-h)
    echo "Usage: deploy.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  all         Full deployment (build + install + init + verify)"
    echo "  build       Build AGE + pgvector from source"
    echo "  install     Install compiled extensions to PG"
    echo "  init        Initialize database (create DB, extensions, user)"
    echo "  verify      Run verification tests"
    echo "  status      Check deployment status"
    echo "  start       Start PostgreSQL"
    echo "  stop        Stop PostgreSQL"
    echo "  restart     Restart PostgreSQL"
    echo ""
    echo "Options:"
    echo "  --pgvector-only    Only build/install pgvector"
    echo "  --age-only         Only build/install AGE"
    echo "  --skip-build       Skip compilation (use existing .dll)"
    echo "  --skip-verify      Skip verification tests"
    echo "  --port=PORT        PostgreSQL port (default: 5433)"
    echo "  --db=DATABASE      Database name (default: age_test)"
    ;;
  *)
    echo "Unknown command: $COMMAND"
    echo "Run 'deploy.sh help' for usage."
    exit 1
    ;;
esac
