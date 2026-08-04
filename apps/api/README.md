# Backend API — Vietnam Smart Golf Platform

## Overview

Modular monolith backend providing identity, course catalog, geospatial, round/score, weather, correction workflow, and audit APIs.

## Tech Stack

- **Style**: Modular monolith with explicit bounded-module boundaries
- **Database**: PostgreSQL + PostGIS (SRID 4326)
- **Cache**: Redis
- **API**: REST with OpenAPI contracts (see `packages/contracts/openapi.yaml`)

## Repository Structure

```
apps/api/
├── src/                 # API source (deferred to later stories)
├── test/                # API tests (deferred)
├── pom.xml              # Maven build (shell — deps added Story 1.2+)
└── README.md
```

## Bootstrap

### Prerequisites

1. **Docker** — required for local PostgreSQL and Redis
   - Install from: https://docs.docker.com/get-docker/
   - Verify: `docker --version`

2. **Database client** (optional, for manual DB access):
   - `psql` or `pg_isready` (PostgreSQL client tools)

### Setup Steps

1. **Start local services** (PostgreSQL + Redis):
   ```bash
   ./infra/scripts/runLocalServices.sh
   ```

2. **Set up environment variables:**
   ```bash
   ./infra/scripts/setupLocalEnv.sh
   ```
   This creates `.env.local.example` (template) and `.env.local` (copy with empty secrets).
   Fill in `.env.local` before running the API.

3. **Install dependencies and run migrations:**
   ```bash
   ./infra/scripts/bootstrapApi.sh
   ```

   This detects the build tool (Maven/Go/Node) from existing build files and runs:
   - Dependency installation
   - Baseline database migration (`001_baseline.sql`)

### Automated Bootstrap

Instead of manual steps above, run the master bootstrap from the repository root:

```bash
./infra/scripts/bootstrap.sh
```

This checks prerequisites, starts local services, sets up environment variables, and runs API + Flutter setup.

### Manual Service Management

```bash
# Start services
./infra/scripts/runLocalServices.sh

# Stop services
./infra/scripts/stopLocalServices.sh

# Check service health
pg_isready -h localhost -p 5432 -U vsp
redis-cli -h localhost -p 6379 ping
```

## Environment Variables

Copy `.env.local.example` from the repository root to `.env.local` and fill in required values:

```bash
cp .env.local.example .env.local
# Edit .env.local with your values
```

Key variables for API development:

| Variable | Default | Description |
|---|---|---|
| `DATABASE_HOST` | localhost | PostgreSQL host |
| `DATABASE_PORT` | 5432 | PostgreSQL port |
| `DATABASE_NAME` | vsp | Database name |
| `DATABASE_USER` | vsp | Database user |
| `DATABASE_PASSWORD` | vsp_dev_password | Database password |
| `REDIS_HOST` | localhost | Redis host |
| `REDIS_PORT` | 6379 | Redis port |
| `API_PORT` | 8080 | API server port |

Never commit `.env.local` to version control.

## Database Migrations

Baseline migration is at `infra/migrations/001_baseline.sql`. This establishes the PostGIS extension and version marker.

Real schema migrations begin with `002_*` (deferred to later stories).

### Running Migrations Manually

With Docker services running:

```bash
# Using Maven (Java/Spring)
mvn flyway:migrate

# Or connect manually
psql -h localhost -p 5432 -U vsp -d vsp -f infra/migrations/001_baseline.sql
```

## Local Services

Local development requires PostgreSQL (PostGIS) and Redis. These run via Docker Compose.

**Start:**
```bash
./infra/scripts/runLocalServices.sh
```

**Stop:**
```bash
./infra/scripts/stopLocalServices.sh
```

**Connection strings:**
- PostgreSQL: `postgresql://vsp:vsp_dev_password@localhost:5432/vsp`
- Redis: `redis://localhost:6379`
