#!/bin/bash
# stopLocalServices.sh — Gracefully stop local Docker services
# Run from repository root: ./infra/scripts/stopLocalServices.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../" && pwd)"
COMPOSE_FILE="$REPO_ROOT/infra/docker/docker-compose.yaml"

echo "=== Vietnam Smart Golf Platform — Stopping Local Services ==="

if ! command -v docker &> /dev/null; then
  echo "❌ Docker not found"
  exit 1
fi

echo "Stopping PostgreSQL and Redis..."
docker compose -f "$COMPOSE_FILE" down

echo "✓ Services stopped"
echo ""
echo "Note: Named volumes (postgres_data, redis_data) are preserved."
echo "To remove volumes: docker compose -f $COMPOSE_FILE down -v"
