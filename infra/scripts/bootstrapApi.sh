#!/bin/bash
# bootstrapApi.sh — Backend API environment bootstrap
# Run from repository root: ./infra/scripts/bootstrapApi.sh
# Language/framework to be determined in Story 1.2

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../" && pwd)"
API_DIR="$REPO_ROOT/apps/api"

echo "=== API Bootstrap ==="

# Check prerequisites
echo "Checking prerequisites..."

# Docker must be running for database migrations
if ! command -v docker &> /dev/null; then
  echo "⚠️  Docker not found — database migrations cannot run"
else
  echo "✓ Docker: $(docker --version 2>/dev/null || echo 'available')"
fi

# Detect language from existing build files
if [[ -f "$API_DIR/pom.xml" ]]; then
  BUILD_TOOL="maven"
  echo "✓ Detected: Maven (Java/Spring)"
  DEPENDENCY_CMD="mvn dependency:resolve"
  MIGRATION_CMD="mvn flyway:migrate"
elif [[ -f "$API_DIR/go.mod" ]]; then
  BUILD_TOOL="go"
  echo "✓ Detected: Go"
  DEPENDENCY_CMD="go mod download"
  MIGRATION_CMD="go run migrations/migrate.go"
elif [[ -f "$API_DIR/package.json" ]]; then
  BUILD_TOOL="node"
  echo "✓ Detected: Node.js"
  DEPENDENCY_CMD="npm install"
  MIGRATION_CMD="npm run migrate"
else
  BUILD_TOOL="none"
  echo "⚠️  No build file detected (pom.xml, go.mod, or package.json) — skipping dependency install"
  echo "   This is expected if Story 1.2 has not been implemented yet."
fi

# Install dependencies if build tool detected
if [[ "$BUILD_TOOL" != "none" ]]; then
  echo ""
  echo "Installing dependencies..."
  cd "$API_DIR"
  if eval "$DEPENDENCY_CMD" 2>&1; then
    echo "✓ Dependencies installed"
  else
    echo "⚠️  Dependency install failed — check your environment"
    echo "   (Maven/Go/Node may not be installed; this is expected before Story 1.2)"
  fi

  # Run baseline migration
  echo ""
  echo "Running baseline migration..."
  # shellcheck disable=SC2015
  if eval "$MIGRATION_CMD" 2>&1 | tail -n10; then
    echo "✓ Migrations applied"
  else
    echo "⚠️  Migration failed or no migration tooling configured yet"
    echo "   (expected if Docker services are not running or migration tooling is not set up)"
  fi
else
  echo ""
  echo "⚠️  Skipping dependency install — build file not found"
fi

echo ""
echo "=== API Bootstrap Complete ==="
echo ""
echo "Next steps (after Story 1.2):"
echo "  cd $API_DIR"
echo "  # Configure .env.local with database credentials"
echo "  $DEPENDENCY_CMD"
echo "  $MIGRATION_CMD"
echo "  # Run the API server"
