# Docker Infrastructure — Vietnam Smart Golf Platform

## Overview

Docker Compose configuration for local development and CI environments. Provides PostgreSQL with PostGIS, Redis, and placeholder services for backend development.

## Services

- **PostgreSQL 16 + PostGIS 3.4** — Primary database for course geometry, rounds, scores, corrections
- **Redis 7** — Caching, session, and rate-limit store

## Named Volumes

- `postgres_data` — PostgreSQL data directory (persistent)
- `redis_data` — Redis data directory (persistent)

## Ports

| Service | Port |
|---------|------|
| PostgreSQL | 5432 |
| Redis | 6379 |

## Status

Database services initialized. Application services (API, portal) added in later stories.

## Usage

Start services:
```bash
docker compose -f infra/docker/docker-compose.yaml up -d
```

Stop services:
```bash
docker compose -f infra/docker/docker-compose.yaml down
```

Check status:
```bash
docker compose -f infra/docker/docker-compose.yaml ps
```

Validate config:
```bash
docker compose -f infra/docker/docker-compose.yaml config
```

## Environment Variables

Set in `apps/api/.env.local` (see `infra/scripts/setupLocalEnv.sh` for template):

- `POSTGRES_HOST=localhost`
- `POSTGRES_PORT=5432`
- `POSTGRES_DB=vsp`
- `POSTGRES_USER=vsp`
- `POSTGRES_PASSWORD=<secret>`
- `REDIS_HOST=localhost`
- `REDIS_PORT=6379`

## Bootstrap

See `infra/scripts/bootstrap.sh` for full local environment bootstrap including database migration baseline.
