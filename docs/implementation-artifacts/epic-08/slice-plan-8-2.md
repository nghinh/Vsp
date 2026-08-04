# Slice Plan — Story 8.2: Edit Course Geometry

## Story Metadata

| Field | Value |
|---|---|
| Story | 8.2 |
| Epic | 8 — Course Editing |
| Title | Edit Course Geometry |
| Status | `in-progress` |
| Phase | MVP 1 |
| User Story | As a GIS administrator, I want layer-based draw/edit tools so that official course maps can be maintained. |
| Dependencies | 8.1 (Manage Facilities and Courses), 3.1 (Model Course and Golf Geometry — foundational) |

---

## Acceptance Criteria (AC)

1. **AC-1**: Editor supports point/line/polygon tools, layer visibility, vertices, snapping, undo, and redo.
2. **AC-2**: Unsaved-change guard prevents accidental loss.
3. **AC-3**: Keyboard and pointer workflows remain accessible; controls have visible labels/focus.

---

## Context Evidence

### PRD (8.11 — Course Operations Portal)
- Admin can edit geometry layers with polygon, line, point tools.
- Admin can import GeoJSON/KML/KMZ/Shapefile/CSV where feasible.
- Every published change creates version history and audit log.
- Admin can roll back published course data.

### Architecture (10 — Portal Architecture)
- Geometry editor with draw/edit/snap/undo/publish/rollback.
- GeoJSON/KML/KMZ/Shapefile/CSV import pipeline.
- Portal RBAC roles: Super Admin, Course Admin, Greenkeeper, Tournament Director, Caddie Master, Read-only Auditor.

### UX Spec (7.3 — Map Editor UX)
- Layer list with visibility toggles.
- Draw polygon/line/point tools.
- Edit vertices.
- Snap and undo/redo.
- Import workflow.
- Validation errors before publish.
- Draft/published state clearly visible.
- Unsaved changes guard in editor.
- Keyboard shortcuts may be added for map editor, but visible buttons remain required.

### Geometry Foundation (Story 3.1)
- PostGIS schema: facilities, courses, holes, tees, fairways, rough, greens, bunkers, water, penalty areas, OB, paths, landmarks.
- SRID 4326, validity constraints, GIST indexes.
- Source, license, quality, confidence, verification, effective/expiry, publisher, version metadata.

---

## Implementation Slices

### Slice 1: Portal Geometry Editor Shell (UI Layer)

**Goal**: Scaffold the map editor UI component with layer panel and basic tool palette.

**Deliverables**:
- `apps/portal/src/components/geometry/GeometryEditor.tsx` — main editor shell
- `apps/portal/src/components/geometry/LayerPanel.tsx` — layer list with visibility toggles
- `apps/portal/src/components/geometry/ToolPalette.tsx` — point/line/polygon tool buttons
- `apps/portal/src/pages/courses/[courseId]/edit-geometry.tsx` — editor page route
- `apps/portal/src/types/geometry.ts` — shared geometry types

**Layer Types** (editable layers per PRD/Architecture):
- Tee (point)
- Fairway (polygon/line)
- Rough (polygon)
- Green (polygon)
- Bunker (polygon)
- Water Hazard (polygon/line)
- Penalty Area (polygon/line)
- OB (line/polygon)
- Cart Path (line)
- Landmark (point)

**RBAC**: Course Admin, Greenkeeper roles can edit. Auditor is read-only.

---

### Slice 2: MapLibre Integration for Portal

**Goal**: Render course geometry layers on MapLibre GL JS in the portal.

**Deliverables**:
- `apps/portal/src/components/geometry/CourseMap.tsx` — MapLibre map with vector layer rendering
- `apps/portal/src/components/geometry/DraftIndicator.tsx` — draft vs published state badge
- API call to fetch draft geometry version for a course

**Map Behavior**:
- Vector layers for each geometry type with distinct styling
- Layer visibility toggled from LayerPanel
- High-contrast style for portal readability (dark mode)
- Satellite imagery toggle if licensed assets available

---

### Slice 3: Drawing Tools (Point/Line/Polygon)

**Goal**: Enable drawing new geometry features and editing existing ones.

**Deliverables**:
- `apps/portal/src/components/geometry/DrawTools.ts` — drawing mode handlers
- Vertex handles on existing geometry for edit mode
- Point placement for tees/landmarks
- Line drawing for cart paths/OB
- Polygon drawing for fairways/greens/bunkers/water/rough/penalty areas

**Snapping**:
- Snap to existing vertices within tolerance (e.g., 10px screen distance)
- Snap to existing edges
- Visual snap indicator during draw

---

### Slice 4: Undo/Redo Stack

**Goal**: Full undo/redo for all edit operations.

**Deliverables**:
- `apps/portal/src/components/geometry/UndoRedoManager.ts` — command pattern stack
- Undo/redo toolbar buttons with keyboard shortcuts (Ctrl+Z / Ctrl+Shift+Z)
- State diff tracking for geometry changes

**Operations tracked**:
- Add feature
- Delete feature
- Move vertex
- Add vertex
- Delete vertex
- Modify geometry property

---

### Slice 5: Unsaved-Change Guard

**Goal**: Prevent accidental data loss when navigating away with unsaved edits.

**Deliverables**:
- `apps/portal/src/components/geometry/UnsavedChangesGuard.tsx` — confirmation dialog
- `apps/portal/src/hooks/useUnsavedChanges.ts` — hook to track dirty state
- Trigger on: route change, tool switch, layer switch with unsaved edits

**User Options**:
- Save Draft
- Discard Changes
- Cancel

---

### Slice 6: Geometry API Endpoints (Backend)

**Goal**: CRUD endpoints for draft geometry management.

**Deliverables** (in `apps/api/src/main/java/com/vsp/course/`):
- `GeometryController.java` — REST endpoints
- `GeometryService.java` — business logic
- `GeometryRepository.java` — PostGIS persistence

**Endpoints**:
```
GET  /admin/courses/{courseId}/geometry/draft          — fetch all draft geometry
PUT  /admin/courses/{courseId}/geometry/draft          — batch update draft geometry
POST /admin/courses/{courseId}/geometry/draft/features  — create feature
PUT  /admin/courses/{courseId}/geometry/draft/features/{id} — update feature
DEL  /admin/courses/{courseId}/geometry/draft/features/{id} — delete feature
POST /admin/courses/{courseId}/geometry/validate        — validate geometry before publish
```

**Validation**:
- SRID 4326 check
- Geometry validity (ST_IsValid)
- Required fields (layer type, coordinates)
- No duplicate features

---

### Slice 7: Accessibility (AC-3)

**Goal**: Keyboard and pointer workflows accessible; controls have visible labels/focus.

**Deliverables**:
- All tool buttons: `aria-label`, `title`, visible focus ring (`.ring` token)
- Keyboard navigation: Tab through tools, Enter/Space to activate
- Map keyboard: Arrow keys for pan, +/- for zoom
- Screen reader announcements for tool state changes
- Minimum 44x44pt touch targets for mobile portal users
- Reduced motion support via `prefers-reduced-motion`

---

### Slice 8: Integration, Draft State, and Audit Trail

**Goal**: Wire editor to API, show draft/published state, and log changes.

**Deliverables**:
- Connect editor to GeometryController endpoints
- Draft vs published indicator in editor header
- Audit log entry for every geometry save (who, when, what changed)
- Optimistic UI with error recovery

---

## Slice Execution Order

| Order | Slice | Rationale |
|---|---|---|
| 1 | Slice 6 (API) | Backend first — UI depends on contracts |
| 2 | Slice 1 (Editor Shell) | Scaffold UI without map |
| 3 | Slice 2 (MapLibre) | Render map with layers |
| 4 | Slice 3 (Draw Tools) | Core editing functionality |
| 5 | Slice 4 (Undo/Redo) | Required for safe editing |
| 6 | Slice 5 (Guard) | Safety net |
| 7 | Slice 7 (Accessibility) | AC-3, embed in all slices |
| 8 | Slice 8 (Integration) | Full end-to-end |

---

## Technical Stack

| Layer | Technology |
|---|---|
| Portal UI | Next.js (Pages Router), React 18 |
| Map | MapLibre GL JS (web) |
| State | React Context + useReducer for editor state |
| HTTP | Fetch / SWR |
| Backend | Java Spring Boot, PostGIS |
| Auth | Session-based with RBAC |
| Geometry Format | GeoJSON (SRID 4326) |

---

## Data Flow

```
GIS Admin (Portal)
  → GeometryEditor (React)
    → CourseMap (MapLibre GL JS)
    → LayerPanel (visibility)
    → ToolPalette (draw mode)
    → UndoRedoManager (command stack)
      → GeometryController (REST)
        → GeometryService
          → PostGIS (ST_GeomFromGeoJSON, ST_IsValid, etc.)
```

---

## Verification Checklist

| AC | Verification Method |
|---|---|
| AC-1: Point/Line/Polygon tools | Manual test: create each type |
| AC-1: Layer visibility | Toggle each layer, verify map render |
| AC-1: Vertices | Edit existing feature, drag vertex |
| AC-1: Snapping | Draw near existing vertex, verify snap |
| AC-1: Undo/Redo | Make change, undo, redo |
| AC-2: Unsaved-change guard | Navigate away with edits, verify dialog |
| AC-3: Accessibility | Tab through tools, verify focus visible, aria labels |

---

## Non-Goals (Deferred)

- Import workflow (GeoJSON/KML/KMZ/Shapefile/CSV) — story 8.3 (Validate and Publish) scope
- Publish/rollback — story 8.3 and 8.4 scope
- Mobile map editing — portal-only for MVP

---

## Risks

| Risk | Mitigation |
|---|---|
| MapLibre GL JS vertex editing complexity | Use @mapbox/mapbox-gl-draw or similar library |
| Snapping algorithm accuracy | Use PostGIS ST_Snap for backend validation |
| Performance with many vertices | Simplify geometry on display, full precision on save |
| Concurrent edit conflicts | Optimistic locking with version field |

---

## Dependencies on Other Stories

| Story | Dependency | Blocker? |
|---|---|---|
| 8.1 (Manage Facilities) | Course CRUD, RBAC setup | Yes — editor needs course context |
| 3.1 (Model Course Geometry) | PostGIS schema, layer types | Yes — geometry storage exists |
| 8.3 (Validate and Publish) | Geometry validation, publish workflow | No — can ship editor first |
