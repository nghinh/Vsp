# Contracts Package — Vietnam Smart Golf Platform

## Overview

OpenAPI specifications and shared DTO schemas used across mobile app, portal, and backend API.

## Contents

- `openapi.yaml` — OpenAPI 3.x contract for all REST API endpoints
- `schemas/` — Shared JSON Schema / DTO definitions (deferred to later stories)

## API Groups

- `/auth/*` — Identity and session management
- `/users/*` — User profile
- `/courses/*` — Course catalog and versions
- `/holes/*` — Hole geometry
- `/rounds/*` — Round management
- `/scores/*` — Score entry
- `/weather/*` — Weather snapshots
- `/corrections/*` — Data correction workflow
- `/admin/*` — Portal admin APIs (RBAC protected)

## Principles

- All dates: ISO 8601
- All geometries: GeoJSON / WGS84 (SRID 4326)
- Structured errors with stable codes
- Idempotency keys on write endpoints
- Pagination on list endpoints

## Status

Initialized as shell. Full contract defined in later stories as features are implemented.
