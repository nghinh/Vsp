# GPS Accuracy Validation Specification

**Story**: 6.6 — Validate Pilot GPS Accuracy and Battery
**Epic**: 6 — Live Golf GPS Experience
**Spec Version**: 1.0
**Last Updated**: 2026-08-02

---

## 1. Overview

This specification defines the quantitative acceptance criteria for GPS distance accuracy at pilot courses, per NFR7 and NFR8 (PRD §10). It translates the 95% critical-point mapping accuracy target into concrete checkpoint categories, distance thresholds, and validation procedures.

**Source Requirements:**
- NFR7: GPS accuracy visible; stale/>10 m positions trigger warning (PRD §10.1)
- NFR8: ≥95% critical points correctly mapped at pilot courses (PRD §10.1, §11)
- GPS telemetry captured per NFR15 and Architecture §13

---

## 2. Accuracy Classes

Per PRD §9.4, mapping data is classified into accuracy classes that determine the expected precision of displayed distances:

| Class | Source | Expected GPS Accuracy | Distance Display Tolerance |
|-------|--------|-----------------------|---------------------------|
| **A** | RTK surveyed or course verified | ±1–2 m | ±2 m |
| **B** | Licensed professional provider | ±2–5 m | ±5 m |
| **C** | Verified satellite digitization | ±5–10 m | ±10 m |
| **D** | Unverified community data | >10 m | N/A — warning only |

**Tolerance Application:**
- Critical point distances (tee, green, hazard) use Class A or B data → ±5 m threshold applies.
- Distances on Class C data → ±10 m threshold applies (extended grace for lower-quality sources).
- Class D data → Distance shown with accuracy warning; no pass/fail applies.

---

## 3. Critical Point Categories

Critical points are the golfer-facing distance reference locations on a hole. They are grouped by impact on golfer decision-making:

### 3.1 Category Definitions

| Category | Label | Description | Count per Hole (Min) |
|----------|-------|-------------|---------------------|
| **CP-A** | Tee Positions | Front, middle, back of each tee box | 2 |
| **CP-B** | Green Targets | Front edge, center, back edge of green | 3 |
| **CP-C** | Hazard Carries | Bunker lip, water edge, OB line | 2 |
| **CP-D** | Layup Distances | Intermediate markers (100, 150, 200 yd) | 1 |

**Total minimum checkpoints per hole: 8**

### 3.2 Accuracy Targets by Category

| Category | Pass Threshold | Source Accuracy Class Required |
|----------|---------------|-------------------------------|
| CP-A (Tee) | ±5 m | A or B |
| CP-B (Green) | ±3 m | A |
| CP-C (Hazard) | ±5 m | A or B |
| CP-D (Layup) | ±10 m | A, B, or C |

The stricter ±3 m threshold for CP-B reflects the golfer's primary decision point (approaching the green).

---

## 4. Distance Accuracy Validation

### 4.1 Reference Measurement Method

1. Each RTK checkpoint is surveyed with dual-frequency GNSS receiver, local base station, and reported accuracy ≤ 0.05 m (1σ horizontal).
2. The reference distance from the golfer's displayed position to each mapped critical point is computed using the same geodesic calculation as the app (Haversine or Vincenty on WGS84).
3. App-displayed distance is recorded from the UI at the moment the golfer is stationary at the RTK checkpoint position.
4. Error is computed as: `error_m = |displayed_distance_m - reference_distance_m|`.

### 4.2 Acceptance Criteria

| Criterion ID | Description | Threshold | Telemetry Evidence |
|-------------|-------------|-----------|-------------------|
| **AC-GPS-01** | Overall critical point accuracy | ≥ 95% of all CP checkpoints within ±5 m | `GpsQualityTelemetry` + manual distance log |
| **AC-GPS-02** | Green distance accuracy | ≥ 95% of CP-B checkpoints within ±3 m | `GpsQualityTelemetry` + manual distance log |
| **AC-GPS-03** | Hazard carry accuracy | ≥ 95% of CP-C checkpoints within ±5 m | `GpsQualityTelemetry` + manual distance log |
| **AC-GPS-04** | Stale position rate | ≤ 5% of GPS samples flag `isStale = true` | `GpsQualityTelemetry.isStale` |
| **AC-GPS-05** | Accuracy warning coverage | ≥ 90% of CP checkpoints show GPS accuracy indicator ≤ 10 m | UI observation + `GpsQualityTelemetry.horizontalAccuracyMeters` |

### 4.3 Sample Size Requirements

- Minimum **3 rounds** per pilot course to account for GPS variability.
- Minimum **50 total checkpoints** per course across all rounds.
- Minimum **15 green checkpoints** (CP-B) per course across all rounds.

Statistical significance: if ≥ 95% of 50 checkpoints pass, the 95% CI lower bound is approximately 85% — acceptable for MVP. For tighter bounds, 100+ checkpoints are recommended.

---

## 5. GPS Quality Thresholds

### 5.1 Fix Quality Requirements

| Fix Quality | Acceptable for Distance Display? | Accuracy Class Assigned |
|-------------|--------------------------------|------------------------|
| `rtkFixed` | Yes — use for validation reference | A |
| `rtkFloat` | Yes — with reduced confidence | A (degraded) |
| `threeDimensional` | Yes — normal operation | B |
| `twoDimensional` | Yes — normal operation | B |
| `noFix` | No — suppress distance display | D |
| `unknown` | No — suppress distance display | D |

### 5.2 Stale Position Definition (NFR7)

A GPS position is considered **stale** when EITHER condition is true:

- `horizontalAccuracyMeters > 10.0` — accuracy degraded beyond warning threshold
- Sample age > 5 seconds since last valid fix

Stale positions must trigger a visible accuracy warning in the UI (per NFR7). The `isStale` flag in `GpsQualityTelemetry` encodes this logic.

### 5.3 Accuracy Warning Trigger

| Condition | UI Behavior |
|-----------|-------------|
| `horizontalAccuracyMeters > 10 m` | Show accuracy indicator in yellow/warning state |
| `horizontalAccuracyMeters > 20 m` | Show accuracy indicator in red/critical state |
| `isStale == true` | Show stale position warning icon |

---

## 6. Telemetry Evidence Requirements

Each validation round must produce the following telemetry evidence:

### 6.1 GpsQualityTelemetry Fields Used for Validation

| Field | Purpose |
|-------|---------|
| `horizontalAccuracyMeters` | AC-GPS-04, AC-GPS-05 |
| `isStale` | AC-GPS-04 |
| `fixQuality` | Assign accuracy class |
| `recordedAt` | Correlate with checkpoint timestamps |
| `batteryLevel` | Context for battery correlation with accuracy |

### 6.2 Post-Round Analysis

The telemetry JSON export (via `TelemetryService.getGpsTelemetry(roundId)`) is processed to produce:

1. **Accuracy histogram**: Distribution of `horizontalAccuracyMeters` across all samples.
2. **Stale rate**: `count(isStale == true) / total_samples`.
3. **Checkpoint accuracy table**: Per-checkpoint error vs. RTK reference.
4. **Per-hole summary**: Average accuracy and stale rate by hole.

---

## 7. Validation Test Matrix

| Course | Round | Date | Device | CP Count | CP Pass Rate | Stale Rate | Overall |
|--------|-------|------|--------|----------|-------------|------------|---------|
| TBD | 1 | — | — | — | — | — | — |
| TBD | 2 | — | — | — | — | — | — |
| TBD | 3 | — | — | — | — | — | — |

*Populated during field test execution.*

---

## 8. Success Criteria

The GPS accuracy validation is considered **PASS** for MVP if:

1. At least one pilot course achieves **AC-GPS-01** (≥ 95% of checkpoints within ±5 m) across a minimum of 3 test rounds.
2. **AC-GPS-04** (≤ 5% stale rate) is met in at least 2 of 3 rounds on that course.
3. Telemetry data is successfully recorded and exportable for post-round analysis.

**Note**: Full 95% across all pilot courses is the production target; MVP validation confirms the system is capable of meeting the target in controlled field conditions.

---

## 9. References

- PRD §9.4 (Accuracy Classes)
- PRD §10.1 (Accuracy NFRs)
- PRD §10.2 (Performance NFRs — 1 s distance update)
- Architecture §8.4 (GPS and Battery)
- Architecture §13 (Observability)
- Story 6.6 — Slice A: `GpsQualityTelemetry` domain model
- Story 6.6 — Slice B: `TelemetryService`, `GpsTelemetryDto`
- `field-test-protocol.md` — Field execution procedure
