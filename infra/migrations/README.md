# Database Migrations — Vietnam Smart Golf Platform

## Overview

Database migration files for PostgreSQL + PostGIS. Uses a versioned migration approach (Flyway or Liquibase — TBD in Story 1.2).

## Status

Initialized as placeholder. Migration tooling and baseline schema deferred to Story 1.2.

## Contents

- Migration files (`.sql`) numbered sequentially
- `001_baseline.sql` — Initial schema including PostGIS extension and version marker

## Principles

- All geometry columns use SRID 4326 (WGS84)
- All tables include `created_at`, `updated_at` timestamps
- Spatial columns have GIST indexes
- Audit log table for all publish/rollback/pin-update events
- Data version table for append-versioned course data

## Usage

```bash
# Run migrations (once tooling is set up in Story 1.2)
flyway migrate

# Check status
flyway info

# Baseline existing database
flyway baseline
```

## Bootstrap

See `infra/scripts/bootstrapApi.sh` for migration baseline steps.
