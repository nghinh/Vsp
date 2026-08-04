# Wave C — Story / Code Reconciliation Audit

**Date:** 2026-08-04
**Scope:** Reconcile the 66 stories / 12 epics against the actual codebase after the
Wave A (compile) and Wave B (tests) passes.

## 1. Verification evidence

| App | Compile | Tests |
| --- | --- | --- |
| API (Java 21 / Spring Boot 3.2.5) | `mvn -o compile` clean | `mvn -o test` → **636 / 636 PASS** |
| Portal (Vue 3 / Vite / TS) | `vue-tsc --noEmit` → **0 errors** | `vitest run` → **23 / 23 PASS** |
| Mobile (Flutter) | `flutter analyze` → **0 errors** | `flutter test` → **993 PASS**, 13 fail (Epic 11, deferred) |

The prior `sprint-status.yaml` was stale/pessimistic: most stories were already
implemented, but the tree did not compile (178 mobile + 109 portal errors) before
Wave A, so nothing could be verified. After Wave A/B the true state is much further along.

## 2. Coverage summary (evidence per epic)

- **Epic 1 (Foundation)** — monorepo (`apps/`, `packages/`, `infra/`, `docs/`, CI in
  `.github/`); 27 backend modules; OpenAPI contracts + idempotency + pagination + stable
  error codes; design-token packages (`mobile-theme`, `portal-ui`, `design-tokens`)
  consumed by both clients; observability + JWT/TLS/RBAC config. **DONE.**
- **Epic 2 (Identity/Profile)** — `AuthController`, `identity`, `profile`, `bag`, `role`,
  `privacy` modules; mobile `auth`/`profile`/`bag`/`privacy` features + tests. **DONE.**
- **Epic 3 (Course catalog)** — `course`/`geometry`/`geospatial` modules; `CourseSearch`,
  `CourseDetail`, `CourseImport`, `Geometry` controllers; mobile `course_search`/
  `course_detail` + bloc/widget tests; import pipeline w/ tests. **DONE.**
- **Epic 4 (Offline packages)** — `package` module (`PackageGenerationService`,
  `PackageBuildController`, `ObjectStorageService`), `course-package` pkg (manifest schema);
  mobile course-download screens + incremental update UI. **DONE** (see gap **G3**).
- **Epic 5 (Round/scoring)** — `Round`/`Score` controllers + modules; mobile `round`/
  `round_setup`/`score` (SQLite local-first) + navigation/round-data tests; idempotent sync. **DONE.**
- **Epic 6 (Live GPS)** — location qualification, course/hole detection
  (`course_hole_detection_service` + scorer), MapLibre strategic map, distance calc engine
  (`DistanceCalculator` + `distance_cubit` tests), target placement, telemetry models. **DONE**
  except **6-6** (field validation — see gap **G4**).
- **Epic 7 (Weather/Conditions/Tournament)** — `Weather`/`PinPosition`/`CourseCondition`/
  `GreenCondition`/`TournamentPolicy` controllers + modules; mobile `weather`/`conditions`
  + tests; tournament feature guard. **DONE.**
- **Epic 8 (Course Ops Portal)** — `Facility`/`Course`/`Hole`/`TeeSet` admin controllers,
  `CourseVersion` (publish/rollback), `CourseAlert`; portal pages for facilities, courses,
  versions/publish, pins/conditions, alerts, geometry editor. **DONE** except **8-2** (see gap **G1**).
- **Epic 9 (Correction/Quality)** — `Correction`/`DataQuality` controllers + modules;
  portal correction queue + data-quality dashboard; mobile correction submission + tests. **DONE.**
- **Epics 10–12 (MVP 2–4, deferred)** — implemented but with deferred-phase gaps:
  watch apps (`wear-os`, `watch_apple`) + shot tracking (Epic 10); `Performance`/`Dispersion`
  analytics + smart-target (Epic 11, see gap **G2**); `Tournament`/`Booking`/`Payment`/
  `Loyalty`/`Membership`/`Market` controllers + modules (Epic 12). **IN-PROGRESS.**

## 3. Genuine follow-up gaps

### G1 — Geometry editor: interactive drawing pipeline (Story 8-2) — WIRED (Wave C)
**Resolved (drawing path):** `CourseMap` now emits general `map-click`/`map-dblclick`
(coord + zoom) and disables double-click zoom; `GeometryEditor` forwards them; the page
routes them to `ensureDrawTools().handleClick/handleDoubleClick` when a draw tool (not
`select`) is active. New Point/Line/Polygon features now flow map-click → `DrawTools` →
`onFeatureComplete` → `applyFeatureAdd` (undo/redo + dirty tracking). Portal compiles clean.
**Remaining (smaller):** in-place vertex edit / feature delete **via map interaction** is not
yet driven by `DrawTools` (the engine exposes draw-new only; `onFeatureDelete/onFeatureModify`
seams exist but no map gesture invokes them yet), and the drawing UX needs runtime/manual QA.
Story 8-2 kept at `review` pending that manual verification.

### G2 — Analytics widgets (Epic 11) — RESOLVED (Wave C)
Previously 13 Flutter widget tests failed (`StrokesGainedScreen` ×9, chart widgets ×4).
Root causes fixed:
- `StrokesGainedScreen` hard-hit SQLite in `initState`; caching is now **best-effort** (a
  cache-write failure no longer hides a valid computed result) and the dead cache-read was
  removed. Empty state now shows when there are no shots.
- `AccessibleBarChart`/`AccessiblePieChart` `Semantics(label: title)` merged with child
  legend text, so `bySemanticsLabel` failed → added `explicitChildNodes: true`.
- Test-only bugs corrected (self-contradictory empty-chart assertion; exact-vs-substring text
  match for the pie legend `"Fairway (50%)"`; loading-frame checked before the async drains).
**Result: mobile `flutter test` → 1006 / 1006 PASS.** (Broader MVP 2-3 acceptance for the
analytics/Smart-Caddie phase remains future work, but the shipped widgets are now tested green.)

### G3 — Manifest facility fields not populated by generator (Stories 4-1 / 6-2)
Wave A added optional facility/course descriptor fields to `manifest.schema.json` and the
Dart `CoursePackageManifest`, and the mobile offline detection repos read them. The backend
`package` generator does **not** yet write these fields into generated manifests. Because the
fields are optional/nullable nothing breaks, but offline facility/hole detection will lack
facility coordinates at runtime until the generator populates them (from the course/facility
geo).

**Flow (traced in Wave C):** the mobile obtains the manifest via the API
`GET /courses/{courseId}/packages/current` → `CoursePackageManifestDto`
(`PackageController.toDto`), then persists it locally as `manifest.json`. `assemblePackageFiles`
currently only emits `conditions.json` (no `manifest.json` file). There is also an entity
duplication to resolve: `module.package.entity.CoursePackageManifest` vs
`module.pkg.entity.CoursePackageManifest` (the controller uses the `pkg` one).

**Next (focused feature task, not done here to protect the all-green baseline):**
1. Resolve the `package`/`pkg` manifest-entity duplication.
2. Add the 8 facility/course fields to `CoursePackageManifestDto` (contract change + update
   its tests), populated in `toDto` from the course/facility (either via a new query, or by
   persisting the fields on the entity with a Flyway migration).
3. Add an API test asserting the fields serialize, and a mobile round-trip test.
This is additive/non-breaking; the current 636 API tests remain green without it.

### G4 — Pilot GPS accuracy & battery validation (Story 6-6)
Telemetry models (`gps_quality_telemetry`, `battery_telemetry`, `map_latency_telemetry`)
exist, but the acceptance criteria require **field validation** against RTK checkpoints and
an 18-hole battery run on real devices at pilot courses. This is an operational/pilot
activity, not code — cannot be closed in-repo.

## 4. Fixes applied during Waves A–C (highlights)
- Design-token fragmentation consolidated onto shared `VspSemanticColorToken` (Story 1-4).
- Manifest contract extended (additive/optional) + `LocalCoursePackageRepository` made concrete.
- Telemetry DTOs mirrored locally (Dart forbids `lib/` importing outside `lib/`).
- Portal path resolution fixed via `@/` alias; `maplibre-gl` + `@types/geojson` installed.
- Correction-queue filters referenced a *type* instead of the component (would not render) — fixed.
- Numerous real test bugs corrected (broken great-circle test helper, self-contradictory
  circuit-breaker test, de-duped bloc states, Redis-vs-PostGIS health config, Mockito
  strict-stubbing) — see git history / session log.
