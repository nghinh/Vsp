# Field Test Protocol — GPS Accuracy and Battery Validation

**Story**: 6.6 — Validate Pilot GPS Accuracy and Battery
**Epic**: 6 — Live Golf GPS Experience
**Phase**: MVP 1 — Pilot Validation
**Document Version**: 1.0
**Last Updated**: 2026-08-02

---

## 1. Purpose and Scope

This protocol defines the methodology for validating GPS distance accuracy and battery endurance during live field tests at pilot courses. It is designed for execution by the product team, field researchers, or designated QA personnel without specialized surveying equipment beyond the approved RTK receiver and reference device set.

**Objectives:**

1. Validate that displayed distances meet the 95% critical-point mapping accuracy target (PRD §10, NFR8).
2. Confirm that target mobile devices can complete a full 18-hole round within the battery goal (PRD §10.4, NFR4).
3. Collect GPS quality, map latency, and battery telemetry for post-round analysis.

**Out of Scope:**

- RTK survey data collection itself (assumed to be pre-collected and agreed with pilot course operators before this protocol runs).
- Laboratory battery drain testing (covered in `battery-validation-spec.md`).
- Accuracy testing of non-GPS features (score entry, course rendering, etc.).

---

## 2. RTK Checkpoint Methodology

### 2.1 What Are RTK Checkpoints?

RTK (Real-Time Kinematic) checkpoints are reference positions surveyed with centimeter-level accuracy using dual-frequency GNSS receivers and a local base station. These represent the ground-truth against which displayed distances are compared.

RTK checkpoint data must be provided by the pilot course operator or a licensed surveyor prior to field test execution. Each checkpoint must include:

- WGS84 latitude, longitude, and altitude (decimal degrees, 8 decimal places).
- Elevation relative to the geoid (meters).
- Checkpoint label matching the course map feature (e.g., "Hole 1 Tee", "Green Center", "Bunker Edge Left").
- Accuracy class (per PRD §9.4 — Class A preferred for critical points).

### 2.2 Checkpoint Categories

Critical points are classified into three categories that reflect their impact on golfer experience:

| Category | Description | Examples | Minimum Count per Course |
|---------|-------------|----------|--------------------------|
| **A — Tee Markers** | Player position at address | Front/middle/back tee | 2 per hole |
| **B — Green Centers** | Approximate pin target area | Green center, front edge, back edge | 3 per hole |
| **C — Hazard Carries** | Distance-critical shot landing areas | Bunker lip, water edge, OB stake line | 2 per hole |
| **D — Layup / Layup Distances** | Intermediate distances commonly displayed | 100 yd, 150 yd, 200 yd markers | 1 per hole |

### 2.3 Distance Measurement Procedure

For each RTK checkpoint:

1. Position the reference device (or approved comparison device) at the exact RTK checkpoint coordinates using a tripod and pole.
2. Allow the device to achieve a stable GPS fix with reported accuracy ≤ 0.05 m (horizontal).
3. Record the RTK-reported position (latitude, longitude, altitude).
4. From the VSP mobile app, observe the displayed distance from the current GPS position to each mapped course feature in the checkpoint category.
5. Record the displayed distance, GPS accuracy indicator, and any stale/warning state shown in the app.
6. Calculate the error: `error_meters = |displayed_distance - rtk_reference_distance|`.
7. Flag if the app displays an accuracy warning or stale state at the checkpoint.

**Display Distance Sources (Stories 6.1–6.5):**

| Display Element | Story | Validation Method |
|----------------|-------|-------------------|
| Current golfer position | 6.1 | Compare displayed position to RTK checkpoint |
| Distance to front/center/back of green | 6.4 | Compare displayed distance to RTK checkpoint distance |
| Distance to hazard | 6.4 | Compare to RTK hazard boundary distance |
| Distance to target | 6.5 | Compare to RTK target marker distance |

### 2.4 Pass / Fail Criteria

| Criterion | Threshold | Measurement |
|-----------|-----------|-------------|
| Critical point accuracy | ≥ 95% of checkpoints within ±5 m of RTK reference | Error ≤ 5 m |
| Accuracy warning coverage | ≥ 90% of checkpoints shown with accuracy indicator ≤ 10 m | GPS accuracy display |
| Stale position rate | ≤ 5% of checkpoints trigger stale warning | `isStale` flag from telemetry |
| Green distance accuracy | ≥ 95% of green checkpoints within ±3 m | Subset of critical points |

**Per-Round Validation:**

- A round is considered VALID for GPS accuracy if ≥ 95% of all collected checkpoints pass the ±5 m threshold.
- A round is considered VALID for stale position rate if ≤ 5% of all GPS samples flag `isStale = true`.

---

## 3. Battery Endurance Validation

### 3.1 Procedure

Battery validation is conducted concurrently during the accuracy test round:

1. **Pre-round**: Record device battery level at 100% (or note starting level if not full). Enable all typical on-course settings (screen auto-brightness, GPS polling, background sync).
2. **During round**: Battery telemetry is recorded by the app automatically every 60 seconds and on hole-change events via `BatteryTelemetry` (Story 6.6, Slice A).
3. **End of round**: Record final battery level and note total elapsed time.
4. **Post-round**: Export battery telemetry via the debug/export panel and compute consumption metrics.

### 3.2 Pass / Fail Criteria

| Criterion | Threshold | Measurement |
|-----------|-----------|-------------|
| 18-hole battery survival | Final battery ≥ 10% after 18 holes | Direct observation |
| Battery consumption rate | ≤ 5.5% per hole (100% ÷ 18 holes) | `consumptionRatePerHole()` from `BatteryTelemetry` |
| Estimated end-of-round battery | `estimatedEndOfRoundBattery()` ≥ 10% | Derived from mid-round telemetry |

**Device Matrix:**

Battery validation must be run on at least two distinct device models from the target device matrix. The target device matrix is defined in `battery-validation-spec.md`.

---

## 4. Telemetry Collection Requirements

### 4.1 Required Telemetry Events

The following telemetry events must be recorded during each test round (via `TelemetryService`, Story 6.6, Slice B):

| Telemetry Type | Event Trigger | Key Fields |
|----------------|--------------|------------|
| `GpsQualityTelemetry` | Every GPS sample (typically 1 Hz) | `horizontalAccuracyMeters`, `isStale`, `fixQuality`, `batteryLevel` |
| `BatteryTelemetry` | Every 60 s + on hole change | `batteryLevel`, `batteryState`, `holesCompleted`, `gpsPollingFrequencyHz` |
| `MapLatencyTelemetry` | On each map load / pan / zoom event | `durationMilliseconds`, `eventType`, `servedFromCache`, `batteryLevel` |

### 4.2 Round Metadata

Each test round must also record:

- Test date and start/end time.
- Course name and hole set (tee/color).
- Device model and OS version.
- Weather conditions (sunny, overcast, rain — affects GPS performance).
- Number of players in group (affects pace and GPS conditions).
- Whether a course package was downloaded before the round (offline vs. online).

### 4.3 Export Format

Telemetry data is exported from the device as JSON via the debug/export panel and uploaded to the analysis workspace. The export schema matches `GpsTelemetryDto`, `BatteryTelemetryDto`, and `MapLatencyDto` (Story 6.6, Slice A).

---

## 5. Test Procedures

### 5.1 Pre-Test Setup

1. Confirm RTK checkpoint files are loaded on the reference device.
2. Confirm the VSP app is installed on the test device with a clean local database.
3. Verify the test device has GPS fix with accuracy ≤ 10 m before approaching Hole 1 tee.
4. Confirm the course package for the pilot course is downloaded and accessible offline.
5. Enable all telemetry recording flags in the debug panel.
6. Set screen brightness to 70% (or match typical golfer setting).
7. Begin battery telemetry recording at 100% (or note starting level).

### 5.2 During the Round

- Do NOT manually trigger hole changes — allow the app to detect them automatically (story 6.2 behavior) to test hole detection.
- If the app shows an accuracy warning, note the location and continue — do not reset GPS.
- If the app loses GPS fix for more than 30 seconds, note the timestamp and attempt manual re-acquisition before continuing.
- Record any instances where displayed distances seem obviously wrong (golfers are good at estimating — use judgment).

### 5.3 Post-Test

1. Allow the app to sync telemetry in the background (or export manually if offline).
2. Record final battery level immediately after completing Hole 18.
3. Complete the Test Round Report Form (Section 7).
4. Upload telemetry JSON exports and the completed report to the analysis workspace.

### 5.4 Special Conditions

| Condition | Action |
|-----------|--------|
| Device runs out of battery before Hole 18 | Record last telemetry timestamp and final battery level; note as FAILED for battery criterion |
| GPS loses fix for > 60 s cumulative | Note total outage time; exclude affected holes from accuracy analysis |
| App crashes | Note timestamp; restart and continue if possible; exclude interrupted hole from accuracy analysis |
| Weather changes to heavy rain | Suspend test; document conditions; reschedule if possible |

---

## 6. Reporting

### 6.1 Per-Round Summary Metrics

| Metric | Value | Pass / Fail |
|--------|-------|-------------|
| Total checkpoints collected | N | — |
| Checkpoints within ±5 m | N (% of total) | ≥ 95% → PASS |
| Checkpoints within ±3 m (green subset) | N (% of total) | ≥ 95% → PASS |
| GPS samples with `isStale = true` | N (% of total samples) | ≤ 5% → PASS |
| Starting battery level | X% | — |
| Final battery level | X% | ≥ 10% → PASS |
| Battery consumption rate per hole | X% | ≤ 5.5% → PASS |
| Estimated end-of-round battery | X% | ≥ 10% → PASS |
| Average map load time (cached) | X ms | ≤ 2000 ms → PASS |
| Average distance update latency | X ms | ≤ 1000 ms → PASS |

### 6.2 Pass / Fail Summary

A field test is considered PASS overall if:

- GPS critical point accuracy criterion is met (≥ 95% within ±5 m).
- Battery endurance criterion is met (≥ 10% battery remaining after 18 holes OR consumption rate ≤ 5.5% per hole).
- Telemetry data was successfully recorded and exported for at least 16 of 18 holes.

---

## 7. Test Round Report Template

```
## Field Test Report — [Course Name] — [Date]

### Test Configuration
- Device Model: _______________
- OS Version: _______________
- VSP App Version: _______________
- Starting Battery Level: _______________
- Course Package Version: _______________

### Weather & Conditions
- Weather: _______________
- Temperature: _______________
- Start Time: _______________
- End Time: _______________

### GPS Accuracy Results
- Total checkpoints: _______________
- Within ±5 m: _______________ (___%)
- Within ±3 m (green): _______________ (___%)
- GPS stale samples: _______________ (___%)
- Accuracy warnings shown: _______________

### Battery Results
- Final Battery Level: _______________
- Holes Completed: ___/18
- Consumption Rate per Hole: ___%
- Estimated End-of-Round Battery: ___%

### Map Latency Results
- Avg Initial Load (cached): ___ ms
- Avg Pan/Zoom Load: ___ ms
- Avg Distance Update: ___ ms

### Issues Observed
1. _______________
2. _______________

### Telemetry Export
- GPS telemetry file: _______________
- Battery telemetry file: _______________
- Map latency telemetry file: _______________

### Overall Result: PASS / FAIL
```

---

## 8. Open Decisions and Deferred Items

| Item | Status | Notes |
|------|--------|-------|
| Pilot course list | OPEN | Courses must be agreed with pilot partners before testing |
| RTK checkpoint coordinates | OPEN | Must be provided by course operator or licensed surveyor |
| Target device matrix | OPEN | Deferred to field team — see `battery-validation-spec.md` |
| Number of test rounds per course | OPEN | Recommend minimum 3 rounds per course for statistical significance |

---

## 9. References

- PRD §10 (Non-Functional Requirements — Accuracy, Performance, Battery)
- PRD §9.4 (Accuracy Classes A–D)
- Architecture §8.4 (GPS and Battery) and §13 (Observability Architecture)
- Story 6.6 — Slice A (Telemetry DTOs and Domain Models)
- Story 6.6 — Slice B (Telemetry Service and Persistence)
- `gps-accuracy-validation-spec.md`
- `battery-validation-spec.md`
