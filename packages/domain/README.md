# Domain Package — Vietnam Smart Golf Platform

## Overview

Shared domain model specifications used across mobile app, portal, and backend API. Defines core entities, value objects, and domain rules that are common across all three surfaces.

## Contents

- Domain entity definitions (golf course, hole, tee, round, score, etc.)
- Shared domain value objects
- Business rule specifications
- Validation invariants

## Status

Initialized. Full domain model defined as features are implemented in later stories.

## Key Entities (MVP)

- Facility, Course, Hole, Tee Set, Tee Box
- Pin Position, Green Condition, Course Condition
- Weather Snapshot
- Round, Flight, Score, Shot
- Course Correction, Data Version
- User, Golfer Profile

## Geospatial Standards

- All geometries: WGS84 coordinate system (SRID 4326)
- GeoJSON interchange format
- Accuracy classes: A (RTK surveyed) → B (professional) → C (satellite) → D (community)

## Data Quality Fields

Every domain object includes: source, license, accuracyClass, confidence, verificationStatus, createdAt, updatedAt, lastVerifiedAt, effectiveDate, expirationDate, version, publisher.
