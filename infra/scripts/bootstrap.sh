#!/bin/bash
# bootstrap.sh — Master bootstrap: validates prerequisites and runs all setup
# Run from repository root: ./infra/scripts/bootstrap.sh
#
# Usage:
#   ./infra/scripts/bootstrap.sh          # Full bootstrap
#   ./infra/scripts/bootstrap.sh --skip-services  # Skip Docker services
#   ./infra/scripts/bootstrap.sh --help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../" && pwd)"
SKIP_SERVICES=false

# Parse flags
for arg in "$@"; do
  case $arg in
    --skip-services) SKIP_SERVICES=true ;;
    --help)
      echo "Usage: $0 [--skip-services]"
      echo "  --skip-services  Skip Docker service startup"
      exit 0
      ;;
    *)
      echo "Unknown flag: $arg"
      echo "Use: $0 [--skip-services]"
      exit 1
      ;;
  esac
done

echo "╔═══════════════════════════════════════════╗"
echo "║  Vietnam Smart Golf Platform — Bootstrap  ║"
echo "╚═══════════════════════════════════════════╝"
echo ""

# ============================================
# Step 1: Check prerequisites
# ============================================
echo "=== Step 1: Prerequisites ==="

ERRORS=0

# git
if command -v git &> /dev/null; then
  GIT_VERSION=$(git --version)
  echo "✓ git: $GIT_VERSION"
else
  echo "✗ git: not found"
  ERRORS=$((ERRORS + 1))
fi

# Flutter
if command -v flutter &> /dev/null; then
  FLUTTER_VERSION=$(flutter --version 2>/dev/null | head -n1 || echo "unknown")
  echo "✓ Flutter: $FLUTTER_VERSION"
else
  echo "⚠ Flutter: not found (mobile development optional)"
fi

# Docker
if command -v docker &> /dev/null; then
  DOCKER_VERSION=$(docker --version)
  echo "✓ Docker: $DOCKER_VERSION"
else
  echo "⚠ Docker: not found (required for local services)"
fi

# docker compose
if docker compose version &>/dev/null || docker-compose version &>/dev/null; then
  COMPOSE_VERSION=$(docker compose version 2>/dev/null || docker-compose version 2>/dev/null)
  echo "✓ Docker Compose: $COMPOSE_VERSION"
else
  echo "⚠ Docker Compose: not found (required for local services)"
fi

# PostgreSQL client (optional — for manual DB access)
if command -v psql &> /dev/null; then
  echo "✓ psql: $(psql --version)"
elif command -v pg_isready &> /dev/null; then
  echo "✓ pg_isready: available"
else
  echo "⚠ psql/pg_isready: not found (optional — Docker service provides these)"
fi

if [[ $ERRORS -gt 0 ]]; then
  echo ""
  echo "❌ Bootstrap cannot proceed: git is required but not found."
  exit 1
fi

echo ""

# ============================================
# Step 2: Setup environment variables
# ============================================
echo "=== Step 2: Environment Variables ==="
"$SCRIPT_DIR/setupLocalEnv.sh"
echo ""

# ============================================
# Step 3: Start local services (optional)
# ============================================
if [[ "$SKIP_SERVICES" == "false" ]]; then
  echo "=== Step 3: Local Services ==="
  if command -v docker &> /dev/null && (docker compose version &>/dev/null || docker-compose version &>/dev/null); then
    "$SCRIPT_DIR/runLocalServices.sh"
  else
    echo "⚠ Skipping services — Docker not available"
    echo "  Run ./infra/scripts/runLocalServices.sh after installing Docker"
  fi
else
  echo "=== Step 3: Local Services — SKIPPED (--skip-services) ==="
fi
echo ""

# ============================================
# Step 4: Flutter setup
# ============================================
echo "=== Step 4: Flutter Setup ==="
if command -v flutter &> /dev/null; then
  "$SCRIPT_DIR/bootstrapFlutter.sh"
else
  echo "⚠ Skipping Flutter — Flutter not installed"
  echo "  Install from: https://docs.flutter.dev/get-started/install"
fi
echo ""

# ============================================
# Step 5: API setup
# ============================================
echo "=== Step 5: API Setup ==="
"$SCRIPT_DIR/bootstrapApi.sh"
echo ""

# ============================================
# Done
# ============================================
echo "╔═══════════════════════════════════════════╗"
echo "║   Bootstrap Complete                      ║"
echo "╚═══════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "  1. Fill in secrets in .env.local (if not already done)"
echo "  2. Review docs/ for project documentation"
echo "  3. Start development:"
echo "       Mobile:  cd apps/mobile && flutter run"
echo "       API:     cd apps/api && # Story 1.2 will provide run commands"
echo ""
echo "Useful scripts:"
echo "  ./infra/scripts/runLocalServices.sh   # Start PostgreSQL + Redis"
echo "  ./infra/scripts/stopLocalServices.sh  # Stop services"
echo "  ./infra/scripts/bootstrapFlutter.sh    # Re-run Flutter setup"
echo "  ./infra/scripts/bootstrapApi.sh       # Re-run API setup"
