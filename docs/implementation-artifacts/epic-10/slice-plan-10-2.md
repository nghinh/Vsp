# Slice Plan — Story 10.2: Deliver Wear OS Core Round Experience

**Story:** 10.2  
**Epic:** 10 (Watch Experience)  
**Phase:** MVP 2–3  
**Status:** `in-progress`  
**Runner:** `vnpt-epic-story-runner`  
**Date:** 2026-08-02  
**Epic Run Folder:** `docs/vnpt-flow/epic-run-run_2026_08_02_010/`

---

## Context Summary

### Story ACs
1. **Compose app supports equivalent MVP watch information and scoring** — hole/par/score, front-center-back, pin/hazard, navigation, quick score
2. **Bezel/crown/button behavior adapts by device capability** — detect and adapt to rotating crown, touch bezel, button-only devices
3. **Offline, always-on, haptic, and battery-saving states are supported**

### Key Constraints from Story Spec
- Preserve Flutter/MapLibre/modular-monolith/PostgreSQL/PostGIS decisions where relevant
- Keep writes locally durable before sync
- Use OpenAPI contracts, structured errors, idempotency, RBAC, auditability, data-quality metadata
- Meet UX: glanceability, one-hand/two-tap flows, explicit confidence/offline states, semantic tokens, accessibility
- Do NOT implement deferred AI, analytics, tournament-platform, ecosystem scope

### Dependency Analysis
- **Story 10.1** (Apple Watch, same epic, also backlog): Both target equivalent watch experiences on different platforms. No code-level dependency; parallel execution is valid. 10.2 can proceed independently.
- **Epic 1–9 outputs**: Mobile domain models (`apps/mobile/lib/domain/models/`), contracts (`packages/contracts/`), and design tokens (`packages/mobile-theme/`) are available for reuse.

### Repository State
- `apps/mobile/` — Flutter iOS/Android app (MVP phases), domain models, services, presentation layer
- `packages/contracts/` — OpenAPI schemas (round, score, course, weather, etc.)
- `packages/course-package/` — Course package manifest and repository
- `packages/mobile-theme/` — Shared design tokens and components
- `apps/portal-ui/` — Course Operations Portal web UI
- **No watch-specific code exists** — Wear OS requires a new Android app with Jetpack Compose (separate from Flutter)

---

## Slice Architecture

### Platform Reality
Wear OS is Android-based and does NOT run Flutter. The existing `apps/mobile` Flutter app cannot be reused for Wear OS. A new Android Kotlin/Jetpack Compose project under `apps/` is required.

### Shared Contracts (to reuse from existing codebase)
- Round and Score DTOs from `packages/contracts/lib/src/dto/`
- Hole/Score domain models from `apps/mobile/lib/domain/models/`
- Course package manifest schema from `packages/course-package/`
- Design tokens from `packages/mobile-theme/` (adapted for Wear OS screen constraints)

### New Wear OS App Structure
```
apps/wear-os/                          # New Android Kotlin project
├── src/main/java/vnpt/vsp/wear/
│   ├── WearOsApplication.kt
│   ├── MainActivity.kt
│   ├── ui/
│   │   ├── theme/
│   │   │   ├── Color.kt
│   │   │   ├── Type.kt
│   │   │   └── WearTheme.kt
│   │   ├── screens/
│   │   │   ├── round/
│   │   │   │   ├── WatchRoundScreen.kt       # AC1: equivalent watch info
│   │   │   │   ├── DistanceCard.kt           # front-center-back, pin/hazard
│   │   │   │   ├── ScoreCard.kt              # quick score entry
│   │   │   │   └── HoleInfoCard.kt           # hole/par display
│   │   │   └── common/
│   │   │       ├── OfflineIndicator.kt
│   │   │       ├── SyncStatusIndicator.kt
│   │   │       └── BatterySavingIndicator.kt
│   │   ├── input/
│   │   │   ├── DeviceCapabilityDetector.kt   # AC2: bezel/crown/button
│   │   │   ├── CrownInputHandler.kt
│   │   │   ├── BezelInputHandler.kt
│   │   │   └── ButtonNavigationHandler.kt
│   │   ├── state/
│   │   │   ├── RoundState.kt
│   │   │   ├── ScoreState.kt
│   │   │   └── WatchState.kt                 # offline, always-on, haptics, battery
│   │   ├── services/
│   │   │   ├── WatchDataSyncService.kt       # AC1: offline course subset
│   │   │   ├── WatchLocationService.kt        # AC3: battery-saving GPS
│   │   │   ├── WatchHapticService.kt          # AC3: haptic feedback
│   │   │   └── AlwaysOnService.kt             # AC3: always-on state
│   │   └── repository/
│   │       ├── WearRoundRepository.kt         # Local SQLite + sync
│   │       └── WearScoreRepository.kt
│   └── data/
│       └── dto/                               # Watch-specific DTOs
└── src/main/res/
    └── xml/
        └── watch_accuracy.xml                 # Screen shape and dpi configs
```

---

## Slice Plan

### Slice 1: Wear OS Project Foundation
**Scope:** Create Android Kotlin project shell with Jetpack Compose, confirm build, add Wear OS specific dependencies.

**Files to create:**
- `apps/wear-os/build.gradle.kts`
- `apps/wear-os/settings.gradle.kts`
- `apps/wear-os/src/main/AndroidManifest.xml`
- `apps/wear-os/src/main/java/vnpt/vsp/wear/WearOsApplication.kt`
- `apps/wear-os/src/main/java/vnpt/vsp/wear/MainActivity.kt`
- `apps/wear-os/src/main/java/vnpt/vsp/wear/ui/theme/WearTheme.kt`

**Verification:** `./gradlew assembleDebug` succeeds; APK generated.

---

### Slice 2: Watch Domain Models and Shared Contracts
**Scope:** Define Wear OS round/score/hole models aligned with existing `apps/mobile` domain models and `packages/contracts` DTOs. Establish local SQLite persistence for offline.

**Files to create:**
- `apps/wear-os/src/main/java/vnpt/vsp/wear/domain/model/WearRound.kt`
- `apps/wear-os/src/main/java/vnpt/vsp/wear/domain/model/WearHoleScore.kt`
- `apps/wear-os/src/main/java/vnpt/vsp/wear/domain/model/WearDistance.kt`
- `apps/wear-os/src/main/java/vnpt/vsp/wear/domain/model/WearCourseSubset.kt` — offline course subset (AC1)
- `apps/wear-os/src/main/java/vnpt/vsp/wear/data/local/WearDatabase.kt` — SQLite for round/score persistence

**Verification:** Domain models compile; local DB schema created.

---

### Slice 3: Device Capability Detection (AC2)
**Scope:** Detect rotating crown, touch bezel, button-only configurations and adapt input handlers.

**Files to create:**
- `apps/wear-os/src/main/java/vnpt/vsp/wear/ui/input/DeviceCapabilityDetector.kt`
- `apps/wear-os/src/main/java/vnpt/vsp/wear/ui/input/CrownInputHandler.kt`
- `apps/wear-os/src/main/java/vnpt/vsp/wear/ui/input/BezelInputHandler.kt`
- `apps/wear-os/src/main/java/vnpt/vsp/wear/ui/input/ButtonNavigationHandler.kt`

**Verification:** Device capability logged on startup; input adapts per device type.

---

### Slice 4: Core Watch Round UI (AC1)
**Scope:** Implement WatchRoundScreen with hole/par/score, front-center-back distances, pin/hazard display, navigation, and quick score entry. All glanceable, one/two-tap flows.

**Files to create:**
- `apps/wear-os/src/main/java/vnpt/vsp/wear/ui/screens/round/WatchRoundScreen.kt`
- `apps/wear-os/src/main/java/vnpt/vsp/wear/ui/screens/round/DistanceCard.kt`
- `apps/wear-os/src/main/java/vnpt/vsp/wear/ui/screens/round/ScoreCard.kt`
- `apps/wear-os/src/main/java/vnpt/vsp/wear/ui/screens/round/HoleInfoCard.kt`

**Verification:** UI renders distance, score, hole info; navigation between screens works via crown/button.

---

### Slice 5: Offline, Always-On, Haptic, Battery-Saving States (AC3)
**Scope:** Implement WatchDataSyncService for offline course subset sync, AlwaysOnService for ambient mode, WatchHapticService for haptic feedback, and battery-saving GPS mode.

**Files to create:**
- `apps/wear-os/src/main/java/vnpt/vsp/wear/ui/services/WatchDataSyncService.kt`
- `apps/wear-os/src/main/java/vnpt/vsp/wear/ui/services/WatchLocationService.kt`
- `apps/wear-os/src/main/java/vnpt/vsp/wear/ui/services/WatchHapticService.kt`
- `apps/wear-os/src/main/java/vnpt/vsp/wear/ui/services/AlwaysOnService.kt`
- `apps/wear-os/src/main/java/vnpt/vsp/wear/ui/screens/common/OfflineIndicator.kt`
- `apps/wear-os/src/main/java/vnpt/vsp/wear/ui/screens/common/BatterySavingIndicator.kt`

**Verification:** Offline indicator shown; haptics fire on interactions; always-on mode activates; battery-saving reduces GPS frequency.

---

### Slice 6: Integration and Repository Layer
**Scope:** Wire RoundState/ScoreState/WatchState to repositories; integrate with existing `packages/contracts` OpenAPI client for round/score sync; ensure local-first writes.

**Files to create:**
- `apps/wear-os/src/main/java/vnpt/vsp/wear/data/repository/WearRoundRepository.kt`
- `apps/wear-os/src/main/java/vnpt/vsp/wear/data/repository/WearScoreRepository.kt`
- `apps/wear-os/src/main/java/vnpt/vsp/wear/data/sync/WatchSyncWorker.kt`
- `apps/wear-os/src/main/java/vnpt/vsp/wear/domain/state/WatchStateHolder.kt`

**Verification:** Round persists locally; syncs to backend when connectivity available; no data loss on restart.

---

### Slice 7: Verification Gates
**Scope:** Run all applicable build, lint, test, and accessibility gates for the Wear OS surface.

**Gates to run:**
- `./gradlew lintDebug` — no critical lint errors
- `./gradlew testDebugUnitTest` — all unit tests pass
- `./gradlew connectedAndroidTest` — instrumented tests pass (if device/emulator available)
- Screen reader (TalkBack) verification for distance/score/hole info screens
- Offline round completion simulation
- Battery impact verification (GPS polling frequency reduction in battery-saving mode)

---

## Evidence

### Planning Evidence
- PRD sections read: §2 (positioning), §6 (tech), §7 (MVP scope — smartwatch deferred to Phase 2), §12 (Phase 2 roadmap: "Apple Watch and Wear OS")
- Architecture sections read: §15 (Watch adapter boundary deferred hook), §8 (mobile layers)
- UX spec sections read: §3 (Design Principles), §6 (Active Round UX), §10 (Accessibility)
- Epic story 10.2 read: ACs, tasks, dependencies, verification expectations
- Epic story 10.1 read: parallel Apple Watch story for comparison
- Sprint status read: epic-10 status `backlog`, story 10.2 status `backlog` (now `in-progress`)
- Existing mobile code confirmed at `apps/mobile/` (Flutter iOS/Android)
- No watch-specific code exists in repo

### Anti-Shortcut Evidence
- No watch code in repo — starting from scratch with new Android project
- Flutter mobile app cannot be reused for Wear OS (different platform)
- Each AC mapped to explicit slice and verification criterion
- No speculative AI/analytics/tournament scope included

### Dependency Evidence
- Story 10.1 (Apple Watch) is parallel independent story — no code-level dependency
- Mobile domain models from `apps/mobile/lib/domain/models/` available for alignment
- OpenAPI contracts from `packages/contracts/` available for round/score DTOs
- Design tokens from `packages/mobile-theme/` available for adaptation

---

## Risk Notes

1. **Platform mismatch**: Flutter mobile ≠ Wear OS. New Kotlin/Jetpack Compose project required.
2. **No existing watch contracts**: Watch-specific API contracts not yet in `packages/contracts/` — may need addition.
3. **GPS on Wear OS**: Battery-aware GPS on watch is more constrained than phone — Slice 5 must handle this carefully.
4. **Screen size**: Round info must be condensed for small watch face — glanceability is critical.

---

## Next Step
Return this slice plan to `vnpt-dev-epic-orchestrator` for implementer dispatch. Story status: `in-progress`.
