# Wave D — Mockup ↔ UI Traceability & Design Conformance

**Date:** 2026-08-04
**Source mockups:** `docs/mockup/` (51 screens, generated via Stitch per `docs/mockup/DESIGN.md`)
**Goal:** Map every mockup to its implemented screen/route and check design conformance.

> Note: pixel-level visual verification requires rendering the apps (Flutter simulator /
> portal browser). This document establishes **traceability + token conformance**; a manual
> visual QA pass against each mockup is the remaining step (flagged at the end).

## 1. Mobile app (mockups 01–24 → `apps/mobile/lib/features`)

| Mockup | Screen | Implemented feature / screen | Epic·Story |
| --- | --- | --- | --- |
| 01 | Welcome | `features/auth` (welcome/login) | 2-1 |
| 02 | OTP verify | `features/auth` (OTP) | 2-1 |
| 03 | Onboarding | `features/auth` (onboarding/permissions) | 2-1 |
| 04 | Home | `features/play` + course entry | 3/5 |
| 05 | Course search | `features/course_search` | 3-2 |
| 06 | Course info | `features/course_detail` | 3-3 |
| 07 | Offline course package | `features/course_search` + `presentation/screens/course_download*` | 4-3 |
| 08 | Round setup | `features/round_setup` | 5-1 |
| 09 | Active round map (state) | `features/hole_map` + `features/play` | 6-3 |
| 10 | Targets & Hazards | `features/target` + `presentation/widgets/distance` | 6-4/6-5 |
| 11 | Quick score entry | `features/round` + `application/score` | 5-3 |
| 12 | Playing conditions | `features/conditions` + `features/weather` | 7-1/7-3 |
| 13 | Report wrong data | `features/correction` | 9-1 |
| 14 | Round in-progress (state) | `features/round` / `features/play` | 5/6 |
| 15 | Round summary | `features/round` (completion/review) | 5-5 |
| 16 | Round history | `features/round` (history) | 5-5 |
| 17 | Golfer profile | `features/profile` | 2-3 |
| 18 | Golf bag | `features/bag` | 2-4 |
| 19 | Security & Privacy | `features/privacy` | 2-5 |
| 20 | Shot tracking | `features/play` shot capture + `shot` (backend) | 10-3 (deferred) |
| 21 | Club performance | `features/performance` | 11-1 (deferred) |
| 22 | Active hole (Hố 7 · Par 4) | `features/hole_map` active-round map | 6-3 |
| 23 | Tournament leaderboard | (backend `Leaderboard`/`Tournament`) — mobile view | 12-1 (deferred) |
| 24 | Payment | (backend `Payment`) — mobile view | 12-3 (deferred) |

## 2. Course Operations Portal (mockups 25–39 → `apps/portal`, routes in `src/router.ts`)

| Mockup | Screen | Route | Page | Epic·Story |
| --- | --- | --- | --- | --- |
| 25 | Portal Login & MFA | (auth shell) | login/MFA | 2-1/2-5 |
| 26 | Operations dashboard | `/dashboard` | dashboard | 8/9 |
| 27 | Facilities & Courses | `/facilities` | `facilities/index.vue` | 8-1 |
| 28 | Course detail & metadata | `/facilities/:id` | `facilities/[id].vue`, `courses/[courseId]/*` | 8-1 |
| 29 | Course data import | (course import) | import view + `CourseImportController` | 3-4 |
| 30 | GIS map editor | `/map-editor`→facilities→`courses/[courseId]/edit-geometry` | `edit-geometry/index.vue` | 8-2 |
| 31 | Validate & Publish | `courses/[courseId]/versions/[versionId]/publish` | publish page | 8-3 |
| 32 | Versions & Audit log | `courses/[courseId]/versions` | `versions/index.vue` | 8-3/8-4 |
| 33 | Pin positions & conditions | `/pin-positions`, `/course-conditions` | pins/conditions pages | 8-5 |
| 34 | Course alerts | `/alerts` | alerts page | 8-6 |
| 35 | Correction queue | `/corrections` | `corrections/index.vue` | 9-2 |
| 36 | Data quality | `/admin/data-quality` | `admin/data-quality/index.vue` | 9-4 |
| 37 | Users & Roles | `/users` | users page | 2-5 |
| 38 | Tournament ops | `/tournaments`, `/tournament/:id` | `tournament/*.vue`, `tournaments/*` | 12-1 (deferred) |
| 39 | Market & Integrations | `/market-integrations` | market page | 12-4 (deferred) |

## 3. Smartwatch (mockups 40–42 → `apps/watch_apple`, `apps/wear-os`)

| Mockup | Screen | Implemented | Epic·Story |
| --- | --- | --- | --- |
| 40.1–40.4 | Apple Watch (Glance, Hazards, …) | `apps/watch_apple` (Flutter) | 10-1 (deferred) |
| 41.1–41.4 | Wear OS (Glance, Targets, Quick Score, Status) | `apps/wear-os` (Kotlin/Compose) | 10-2 (deferred) |
| 42.1–42.4 | Wear OS (VN localized) | `apps/wear-os` | 10-2 (deferred) |

## 4. Coverage summary

- **MVP 1 mockups (01–19, 25–37):** every screen maps to an implemented mobile feature or
  portal route. No missing implementations for MVP 1 UI.
- **Deferred-phase mockups (20–24, 38–42):** implementations exist (features/backend/watch
  apps) but belong to MVP 2–4 and carry the known deferred-phase gaps (Epic 10–12).

## 5. Design-token conformance

The mockups were generated with `DESIGN.md`'s **Material-3 dark-tonal** palette; the apps
implement `packages/mobile-theme` (`vsp_color.dart`) + `packages/portal-ui`, which follow
`docs/planning-artifacts/ux-spec.md`.

| Token | Mockup (DESIGN.md) | Implemented (vsp_color) | Match |
| --- | --- | --- | --- |
| Brand primary | `#ffb599` (dark-tonal) / focus ring `#EA580C` | light `#EA580C`, dark `#FB923C` | Same brand orange, different tonal hex |
| Background (dark) | `#0b1326` | `#0F172A` | Near-match (both slate navy) |
| Accent / success | emerald (`#68dba9` dark-tonal) | `#059669` light / `#34D399` dark | Same emerald family |
| Typography | Fira Sans + Fira Code | Fira Sans + Fira Code | ✅ Match |
| Grid / spacing | 8pt grid, 44pt touch | 4/8dp rhythm, 44/48 touch | ✅ Match |
| Shape | 4px base / pills | soft tokens | ✅ Match |

**Finding:** the design **language** (Soft UI, orange primary + emerald accent, Fira fonts,
8pt grid, semantic tokens, official/estimated/stale badges) is consistent between mockups and
implementation. Exact dark-theme hex values differ because `DESIGN.md` is a Material-3
generated palette while `vsp_color` is hand-tuned per the formal `ux-spec.md`. `ux-spec.md`
is the authoritative design spec (both docs agree the brand orange is `#EA580C`), so the
implementation is conformant to the spec; the mockups are directional for exact tonal values.
**No action required** unless the mockup palette is later declared the source of truth, in
which case regenerate `vsp_color` dark tiers from `DESIGN.md`.

## 6. Remaining manual step
A visual QA pass (render each mobile screen in the Flutter simulator and each portal route in
the browser, compare against the corresponding `docs/mockup/*.png`) is the final conformance
check. All screens/routes needed for that pass exist and compile.
