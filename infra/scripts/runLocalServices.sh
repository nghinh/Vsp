#!/bin/bash
# runLocalServices.sh — Start local Docker services and wait for healthy status
# Run from repository root: ./infra/scripts/runLocalServices.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../" && pwd)"
COMPOSE_FILE="$REPO_ROOT/infra/docker/docker-compose.yaml"

echo "=== Starting Local Services ==="

# Check docker-compose is available
if ! command -v docker &> /dev/null; then
  echo "❌ Docker not found"
  exit 1
fi

COMPOSE_VERSION=$(docker compose version 2>/dev/null || docker-compose version 2>/dev/null || echo "unknown")
echo "✓ Docker Compose: $COMPOSE_VERSION"

# Start services
echo ""
echo "Starting PostgreSQL and Redis..."
docker compose -f "$COMPOSE_FILE" up -d

# Wait for healthy services
echo ""
echo "Waiting for services to become healthy..."

MAX_WAIT=60
ELAPSED=0
INTERVAL=5

wait_for_postgres() {
  while [[ $ELAPSED -lt $MAX_WAIT ]]; do
    if docker compose -f "$COMPOSE_FILE" exec -T postgres pg_isready -U vsp -d vsp &>/dev/null; then
      return 0
    fi
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
    echo "  Waiting... ${ELAPSED}s"
  done
  return 1
}

wait_for_redis() {
  while [[ $ELAPSED -lt $MAX_WAIT ]]; do
    if docker compose -f "$COMPOSE_FILE" exec -T redis redis-cli ping 2>/dev/null | grep -q PONG; then
      return 0
    fi
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
  done
  return 1
}

if wait_for_postgres; then
  echo "✓ PostgreSQL is ready"
else
  echo "⚠️  PostgreSQL did not become healthy within ${MAX_WAIT}s"
  echo "   Check: docker compose -f $COMPOSE_FILE logs postgres"
fi

if wait_for_redis; then
  echo "✓ Redis is ready"
else
  echo "⚠️  Redis did not become healthy within ${MAX_WAIT}s"
  echo "   Check: docker compose -f $COMPOSE_FILE logs redis"
fi

echo ""
echo "=== Local Services Running ==="
echo ""
echo "Connection info:"
echo "  PostgreSQL: postgresql://vsp:vsp_dev_password@localhost:5432/vsp"
echo "  Redis:      redis://localhost:6379"
echo ""
echo "  Host OS:    localhost"
echo "  Container:  vsp_postgres / vsp_redis"
echo ""
echo "Useful commands:"
echo "  View logs:     docker compose -f $COMPOSE_FILE logs -f"
echo "  Stop services: ./infra/scripts/stopLocalServices.sh"
echo "  pg_isready:    pg_isready -h localhost -p 5432 -U vsp"
echo "  redis ping:    docker compose -f $COMPOSE_FILE exec redis redis-cli ping"
