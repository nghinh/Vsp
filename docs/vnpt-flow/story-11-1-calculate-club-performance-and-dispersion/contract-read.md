# Contract Read — 11.1

## Implicit Source-Root Contracts
No explicit `contract.md` exists for this story. Contract is derived from:

### Epic 2 Story 2.4 — Club Entity (Backend API)
- `packages/contracts/schema/club.yaml` or equivalent OpenAPI contract
- Club model fields: `id`, `userId`, `bagId`, `name`, `loft`, `carryDistance`, `totalDistance`, `dispersion`, `shaft`, `useDate`, `createdAt`, `updatedAt`
- Dispersion field already exists on Club model — Story 11.1 populates it from shot history

### Epic 10 Story 10.3 — Shot Tracking (Backend API)
- Shot entity contract: `id`, `roundId`, `playerId`, `clubId`, `startLocation`, `endLocation`, `lie`, `carryDistance`, `totalDistance`, `result`, `source`, `confidence`, `timestamp`
- Shot list/aggregate API endpoint needed

### Epic 6 — Course Geometry (PostGIS + Package)
- Hole geometry: tees, fairways, greens, bunkers, water hazards
- GeoJSON geometry stored in `holes.geometry` table
- Used for hazard overlay comparison in dispersion view

### Epic 1 Story 1.3 — API Contracts Standard
- OpenAPI contracts in `packages/contracts/`
- Stable error codes, idempotency keys, pagination
- Bearer token auth on private endpoints

## Required New/Updated Contracts

### Club Performance API (new)
```
GET /users/{userId}/bags/{bagId}/clubs/{clubId}/performance
Response: {
  clubId, sampleSize, computedAt,
  carry: { avg, median, stdDev, min, max },
  total: { avg, median, stdDev, min, max },
  leftRight: { avg, median, stdDev },   // negative=left, positive=right
  shortLong: { avg, median, stdDev },   // negative=short, positive=long
  confidence: { level: "low"|"medium"|"high", reason }
}
```

### Club Performance Batch (new)
```
GET /users/{userId}/bags/{bagId}/performance
Response: { clubs: [...performance objects...] }
```

### Dispersion Overlay (new)
```
GET /users/{userId}/bags/{bagId}/clubs/{clubId}/dispersion?holeId={holeId}
Response: {
  clubId, holeId,
  scatterPoints: [{ relativeX, relativeY, result }],
  hazards: [{ type, geometry, distanceToCenter }],
  overlayGeoJSON: { type: "FeatureCollection", features: [...] }
}
```

## Flutter Contract Points
- `ClubPerformance` domain model
- `DispersionOverlay` domain model
- `ClubRepository.getPerformance(clubId)` method
- `ClubRepository.getDispersionOverlay(clubId, holeId)` method
