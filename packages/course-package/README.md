# Course Package Package — Vietnam Smart Golf Platform

## Overview

Schema definition and tooling for offline golf course packages. A course package bundles course metadata, hole geometry, vector tiles/PMTiles, pin positions, scorecards, and weather snapshots for offline use.

## Contents

- `manifest.schema.json` — JSON Schema for course package manifests
- `tools/` — Package generation and validation tooling (deferred)
- `README.md` — This file

## Package Contents

A course package includes:

- `manifest.json` — Package metadata (version, checksum, size, effective date)
- Course and hole metadata
- Vector tiles or PMTiles for map rendering
- GeoJSON geometry for local distance calculations
- Pin position snapshots
- Green/course condition snapshots
- Scorecard definitions and local rules
- Latest weather snapshot
- Optional licensed satellite assets

## Status

Initialized as shell. Full manifest schema and tooling defined in later stories.
