# Map Style Package — Vietnam Smart Golf Platform

## Overview

MapLibre style documents and layer definitions for rendering golf course maps on mobile. Defines the visual language for vector tiles, annotations, and overlays.

## Contents

- `style.json` — MapLibre style document (shell)
- `layers/` — Layer definitions (deferred)
- `sprites/` — Icon sprites (deferred)
- `fonts/` — Custom font stacks (deferred)

## Style Layers (MVP)

- Tee boxes, fairway, rough, green (fill)
- Bunker, water, penalty area, OB (fill/line)
- Cart paths, shot paths, distance rings (line)
- Pin, golfer position, targets, landmarks (symbol/circle)
- Hazard labels (symbol)

## Principles

- High-contrast outdoor-readable style
- Dark base (`#0F172A`) with bright accent colors
- Vector-first; raster only where licensed satellite imagery exists
- Sub-100ms layer toggle latency

## Status

Initialized as shell. Full style defined as course geometry data is finalized in later stories.
