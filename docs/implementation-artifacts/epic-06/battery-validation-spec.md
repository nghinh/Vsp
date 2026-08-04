# Battery Validation Specification

**Story**: 6.6 — Validate Pilot GPS Accuracy and Battery
**Epic**: 6 — Live Golf GPS Experience
**Spec Version**: 1.0
**Last Updated**: 2026-08-02

---

## 1. Overview

This specification defines the quantitative acceptance criteria for battery endurance during live rounds, per NFR4 and NFR15 (PRD §10.4, §13). It translates the "complete 18 holes without charging" target into device-specific pass/fail criteria and telemetry evidence requirements.

**Source Requirements:**
- NFR4: Mobile device should complete 18 holes without charging (PRD §10.4)
- NFR4: Battery telemetry is captured (PRD §10.4)
- NFR15: Battery telemetry per round (PRD §13, Architecture §13)

---

## 2. Battery Endurance Target

### 2.1 Primary Target

**Target**: A full 18-hole round completes with ≥ 10% battery remaining on the target device set, under normal golfer usage conditions.

**Normal usage conditions:**
- Screen at 70% brightness (or auto-brightness enabled).
- GPS polling at 1 Hz during active play.
- Course package available offline (no download during round).
- Background sync enabled but not actively downloading.
- Typical pause behavior between shots (app in foreground ≈ 60% of round time).

### 2.2 Conservative Target

**Conservative target** (for pass with margin): ≥ 20% battery remaining after 18 holes, to account for device aging, temperature effects, and user behavior variation.

### 2.3 Derived Thresholds

| Metric | Conservative Target | Absolute Minimum |
|--------|-------------------|-----------------|
| Final battery after 18 holes | ≥ 20% | ≥ 10% |
| Consumption rate per hole | ≤ 4.4%/hole | ≤ 5.5%/hole |
| Estimated end-of-round battery | ≥ 20% | ≥ 10% |
| Required starting battery | ≥ 20% | ≥ 10% |

The consumption rate threshold `(100% - target%) / 18 holes` is the primary metric because it is independent of starting battery level.

---

## 3. Device Matrix

Battery validation must be performed on at least **two distinct device models** from the approved target device matrix.

### 3.1 Target Device Matrix (Initial — To Be Confirmed by Field Team)

| Device Model | SoC | Battery Capacity (mAh) | Android Version | Notes |
|-------------|-----|----------------------|----------------|-------|
| Samsung Galaxy S24 | Snapdragon 8 Gen 3 | 4000 | 14 | Primary test device |
| Samsung Galaxy S23 | Snapdragon 8 Gen 2 | 3900 | 14 | Secondary |
| Google Pixel 8 | Tensor G3 | 4575 | 14 | Alternative |
| OnePlus 12 | Snapdragon 8 Gen 3 | 5400 | 14 | Large battery baseline |

**Note**: The device matrix will be updated after field team confirms the final target device list. Battery validation on additional devices is welcome.

### 3.2 Device Selection Criteria

Primary test devices must meet all of:
- Sold within the last 2 years (2024–2026).
-主流 Android flagship or upper mid-range (Snapdragon 8-series or equivalent).
- Battery capacity ≥ 3500 mAh.
- Running Android 12 or later.

---

## 4. Validation Procedures

### 4.1 Field Test Procedure (Live Round)

Battery validation is conducted during the GPS accuracy field test round (see `field-test-protocol.md`):

1. Start with device battery at 100% (or note starting level if not full).
2. Enable all typical on-course settings before starting.
3. Allow `BatteryTelemetry` events to record automatically (every 60 seconds + on hole change).
4. At the end of Hole 18, record the final battery level immediately.
5. Export battery telemetry via the debug/export panel.

**Key `BatteryTelemetry` fields for validation:**

| Field | Purpose |
|-------|---------|
| `batteryLevel` | Track level across the round |
| `batteryState` | Confirm device is not in unexpected state (e.g., charging) |
| `holesCompleted` | Verify round completeness |
| `gpsPollingFrequencyHz` | Confirm GPS polling is at expected rate |
| `batterySaverActive` | Note if battery saver was triggered |
| `screenState` | Confirm screen usage is typical |
| `consumptionRatePerHole()` | Derived helper — compute per-hole rate |
| `estimatedEndOfRoundBattery()` | Derived helper — project final level |

### 4.2 Laboratory Test Procedure (Optional Supplementary)

For a controlled baseline measurement:

1. Set device screen to 70% brightness, GPS to 1 Hz polling.
2. Run a simulated round using a GPS playback script (pre-recorded trace from an actual round).
3. Measure battery drain over the equivalent of 18 holes (approximately 4–5 hours of active GPS).
4. Record temperature and confirm device does not thermal-throttle.

This procedure is optional for MVP; field test data is the primary acceptance criterion.

---

## 5. Acceptance Criteria

| Criterion ID | Description | Threshold | Telemetry Evidence |
|-------------|-------------|-----------|-------------------|
| **AC-BAT-01** | 18-hole battery survival | ≥ 10% battery remaining after 18 holes | Direct observation + `batteryLevel` at Hole 18 |
| **AC-BAT-02** | Battery consumption rate | ≤ 5.5% per hole | `consumptionRatePerHole()` computed from mid-round telemetry |
| **AC-BAT-03** | Estimated end-of-round battery | ≥ 10% based on mid-round projection | `estimatedEndOfRoundBattery()` at Hole 9 (midpoint) |
| **AC-BAT-04** | Battery saver activation | Battery saver mode may activate but must not degrade GPS below 0.5 Hz | `batterySaverActive` flag + GPS sample rate |
| **AC-BAT-05** | Telemetry completeness | ≥ 16 of 18 holes have battery telemetry records | `BatteryTelemetry.holesCompleted` coverage |

---

## 6. Derived Helper Calculations

These are implemented in `BatteryTelemetry` domain model (Story 6.6, Slice A):

### 6.1 `consumptionRatePerHole()`

```dart
/// Battery consumption rate as fraction per hole (0.0–1.0 per hole).
/// Null if no meaningful consumption has occurred yet.
double? consumptionRatePerHole() {
  if (holesCompleted == 0) return null;
  return (1.0 - batteryLevel) / holesCompleted;
}
```

**Acceptable range**: ≤ 0.055 (5.5% per hole) for absolute minimum; ≤ 0.044 (4.4% per hole) for conservative target.

### 6.2 `estimatedEndOfRoundBattery()`

```dart
/// Estimated battery level at end of round based on current consumption rate.
double? estimatedEndOfRoundBattery() {
  final rate = consumptionRatePerHole();
  if (rate == null) return null;
  final remaining = standardRoundHoles - holesCompleted;
  return batteryLevel - (rate * remaining);
}
```

**Acceptable range**: ≥ 0.10 (10%) for absolute minimum; ≥ 0.20 (20%) for conservative target.

---

## 7. Per-Device Validation Matrix

| Device Model | Round | Start Battery | End Battery | Rate/Hole | Est. End | AC-BAT-01 | AC-BAT-02 | AC-BAT-03 | Overall |
|-------------|-------|-------------|-------------|-----------|----------|-----------|-----------|-----------|---------|
| Samsung Galaxy S24 | 1 | 100% | — | — | — | — | — | — | — |
| Samsung Galaxy S24 | 2 | — | — | — | — | — | — | — | — |
| Samsung Galaxy S23 | 1 | — | — | — | — | — | — | — | — |
| Pixel 8 | 1 | — | — | — | — | — | — | — | — |

*Populated during field test execution.*

---

## 8. GPS Frequency and Battery Saving

### 8.1 Expected GPS Polling Rate

| Phase | Expected Polling Rate | Notes |
|-------|----------------------|-------|
| Tee-to-ball (walking) | 1 Hz | Normal golfer movement |
| Shot preparation | 1 Hz | Stationary but accuracy maintained |
| Between shots (>30 s stationary) | 0.5 Hz | Battery Saving Mode activated |
| In-bunker / under canopy | 1 Hz | Challenging GPS conditions |

### 8.2 Battery Saver Behavior

Per PRD §10.4:
- Battery Saving Mode reduces GPS frequency when stationary (>30 s stationary → 0.5 Hz).
- Battery saver must NOT reduce GPS below 0.5 Hz (minimum for acceptable accuracy).
- If battery saver activates and GPS drops below 0.5 Hz for >60 cumulative seconds during a hole, note as an observation.

---

## 9. Success Criteria

Battery validation is considered **PASS** for MVP if:

1. At least **2 distinct device models** meet **AC-BAT-01** (≥ 10% battery remaining after 18 holes) across at least 2 rounds each.
2. **AC-BAT-02** (≤ 5.5% per hole consumption rate) is met in at least 50% of test rounds.
3. **AC-BAT-03** (estimated end-of-round ≥ 10%) at Hole 9 midpoint check is met in at least 50% of test rounds.
4. **AC-BAT-05** (telemetry completeness ≥ 16 holes) is met in all test rounds.

---

## 10. Open Decisions

| Item | Status | Notes |
|------|--------|-------|
| Final target device matrix | OPEN | Deferred to field team — confirm which devices are in pilot program |
| Number of test rounds per device | OPEN | Recommend minimum 2 rounds per device for consistency |
| Temperature range for valid tests | OPEN | Recommend tests in 15–30°C ambient temperature |
| Battery aging consideration | OPEN | New device batteries may show better performance than field-deployed devices |

---

## 11. References

- PRD §10.4 (Battery NFR)
- PRD §13 (Observability — battery telemetry)
- Architecture §8.4 (GPS and Battery)
- Architecture §13 (Observability Architecture)
- Story 6.6 — Slice A: `BatteryTelemetry` domain model with `consumptionRatePerHole()` and `estimatedEndOfRoundBattery()`
- Story 6.6 — Slice B: `TelemetryService`, `BatteryTelemetryDto`
- `field-test-protocol.md` — Field execution procedure
