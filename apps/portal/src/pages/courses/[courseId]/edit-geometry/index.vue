<template>
  <div class="edit-geometry-page">
    <!-- Slice 6: Unsaved changes guard dialog -->
    <UnsavedChangesGuard
      v-model="showUnsavedDialog"
      :title="unsavedDialogTitle"
      :message="unsavedDialogMessage"
      @save="handleGuardSave"
      @discard="handleGuardDiscard"
      @cancel="handleGuardCancel"
    />

    <!-- Accessibility: live region for screen reader announcements (Slice 7) -->
    <div class="sr-only" role="status" aria-live="polite" aria-atomic="true">
      {{ screenReaderAnnouncement }}
    </div>

    <GeometryEditor
      :course-id="courseId"
      :course-name="courseName"
      :course-centre="courseCentre"
      :draw-vertex-count="drawVertexCount"
      @finish-drawing="finishDrawing"
      @cancel-drawing="cancelDrawing"
      :loading="loading"
      :saving="saving"
      :validating="validating"
      :load-error="loadError"
      :action-error="actionError"
      :validation="validation"
      :can-edit="canEdit"
      :is-dirty="isDirty"
      :is-draft="isDraft"
      :layer-states="layerStates"
      :layer-features="layerFeatures"
      :active-tool="activeTool"
      :active-layer="activeLayer"
      :can-undo="undoManager.canUndo > 0"
      :can-redo="undoManager.canRedo > 0"
      :selected-feature-id="selectedFeatureId"
      @tool-change="handleToolChange"
      @map-click="handleMapClick"
      @map-dblclick="handleMapDblClick"
      @layer-visibility-toggle="handleVisibilityToggle"
      @layer-select="handleLayerSelect"
      @undo="handleUndo"
      @redo="handleRedo"
      @save-draft="handleSaveDraft"
      @validate="handleValidate"
      @retry="loadDraftGeometry"
      @dismiss-action-error="actionError = null"
      @feature-select="handleFeatureSelect"
      @feature-deselect="handleFeatureDeselect"
      @vertex-move="handleVertexMove"
      @feature-delete="handleFeatureDeleteRequest"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { courseAdminApi } from '@/api/admin/courses';
import { parsePoint } from '@/lib/wkt';
import { snapshot, toBatchOperations } from '@/api/geometry-mapping';
import type { Baseline } from '@/api/geometry-mapping';
import GeometryEditor from '@/components/geometry/GeometryEditor.vue';
import UnsavedChangesGuard from '@/components/geometry/UnsavedChangesGuard.vue';
import { createDrawTools, ensureFeatureId } from '@/components/geometry/DrawTools';
import { useUnsavedChanges } from '@/hooks/useUnsavedChanges';
import { useGeometryApi } from '@/hooks/useGeometryApi';
import {
  createUndoRedoManager,
  attachEditorShortcuts,
  cmdAddFeature,
  cmdDeleteFeature,
  cmdModifyFeature,
} from '@/components/geometry/UndoRedoManager';
import type {
  EditorTool,
  LayerType,
  LayerStateMap,
  LayerFeatureMap,
  GeometryFeature,
  DraftGeometryResponse,
  ValidationError,
  GeoCoordinate,
} from '@/types/geometry';
import {
  GEOMETRY_EDIT_ROLES,
  LAYER_DEFAULT_GEOMETRY_TYPE,
  LAYER_TYPE_LABELS,
} from '@/types/geometry';

// ─── Props ────────────────────────────────────────────────────────────────────

const props = defineProps<{
  courseId: number;
  /** Auth token — injected by the portal shell. */
  authToken: string;
  /** Current user roles. */
  userRoles: string[];
}>();

// ─── RBAC ────────────────────────────────────────────────────────────────────

const canEdit = computed(() =>
  props.userRoles.some((role) => GEOMETRY_EDIT_ROLES.includes(role as typeof GEOMETRY_EDIT_ROLES[number]))
);

// ─── Audit log ───────────────────────────────────────────────────────────────

// Every geometry edit produces an entry, and this is where they go: an array
// nobody reads, discarded when the page unloads.
//
// That is fine, and it is worth saying why, because the comment that used to
// sit here claimed the opposite — that nothing recorded who moved a green, and
// that the geometry endpoints needed annotating. Checked against the database,
// that is false. GeometryServiceImpl calls auditService.log directly from
// createFeature, updateFeature and deleteFeature, and the batch endpoint this
// editor saves through routes every operation into those three. A save here
// lands in audit_entries as GEOMETRY_FEATURE_CREATED/UPDATED/DELETED with the
// actor, their role and the feature's UUID.
//
// So the browser-side log stays a debugging aid and nothing more. Forwarding
// it would be the wrong fix anyway: a client-supplied audit trail is worth
// exactly what the client says it is.
const auditLog: import('@/hooks/useGeometryApi').AuditLogEntry[] = [];

function appendAudit(entry: import('@/hooks/useGeometryApi').AuditLogEntry) {
  auditLog.push(entry);
}

// ─── The course itself ───────────────────────────────────────────────────────

// Where the map opens, and what the header calls this course.
//
// Neither used to be fetched. The header read "Course 8" and the map opened on
// a hardcoded Hanoi centre — so editing a course in Đồng Nai meant finding it
// by hand first, on a satellite layer 1,600 km away, before a single fairway
// could be traced. `undefined` while loading, `null` once we know the course
// has no location on record; the editor tells the operator which.
const courseName = ref<string | null>(null);
const courseCentre = ref<[number, number] | null | undefined>(undefined);

async function loadCourse() {
  try {
    const course = await courseAdminApi.getCourse(props.courseId, props.authToken);
    courseName.value = course.name ?? null;
    const at = parsePoint(course.location ?? null);
    courseCentre.value = at ? [at.longitude, at.latitude] : null;
  } catch {
    // The geometry is the point of this page; a name we could not fetch is
    // cosmetic, and a missing centre is reported by the editor itself.
    courseName.value = null;
    courseCentre.value = null;
  }
}

// ─── API ─────────────────────────────────────────────────────────────────────

const api = useGeometryApi({
  authToken: props.authToken,
  baseUrl: '/api',
  onAuditEntry: appendAudit,
});

const loading = api.loading;
const saving = api.saving;
const validating = api.validating;
/**
 * Two kinds of failure, and they must not share a banner.
 *
 * `loadError` means there is no geometry to show, so the editor body is
 * replaced and "Thử lại" reloads. `actionError` means a save or a validate
 * failed while the operator has work on screen — and the old code routed both
 * through the same ref. A failed save therefore replaced the whole editor,
 * hiding the unsaved drawing, and offered one button: reload, which would have
 * overwritten those features with the server's copy. Eighteen greens traced,
 * one failed save, and the only thing to click threw them away.
 */
/** The draft as last loaded or saved — what the next save is diffed against. */
const baseline = ref(new Map<string, Baseline>());

/**
 * The last validation result, and whether it can be trusted.
 *
 * `staleFor` records that the editor had unsaved changes when this ran: the
 * endpoint checks the stored draft, so a clean result here says nothing about
 * what is on screen. Reporting a pass over work the server has not seen is the
 * one outcome worse than reporting nothing, which is what it did before —
 * the result went only to a screen-reader live region and a sighted operator
 * saw the page not change at all.
 */
const validation = ref<
  (import('@/hooks/useGeometryApi').ServerValidationResult & { staleFor: boolean }) | null
>(null);

const loadError = ref<string | null>(null);
const actionError = ref<string | null>(null);

// ─── Undo/Redo manager ──────────────────────────────────────────────────────

const undoManager = createUndoRedoManager();

// ─── Editor state ───────────────────────────────────────────────────────────

const ALL_LAYER_TYPES: LayerType[] = [
  'tee', 'fairway', 'rough', 'green', 'bunker',
  'water', 'penalty', 'ob', 'cart_path', 'landmark',
];

const isDraft = ref(true);
const isDirty = ref(false);

// Active tool and layer
const activeTool = ref<EditorTool>('select');
const activeLayer = ref<LayerType>('tee');

// Currently selected feature (select tool) — drives on-map vertex handles.
const selectedFeatureId = ref<string | number | null>(null);

/** Resolve a feature object by id across all layers. */
function resolveFeature(id: string | number | null): GeometryFeature | null {
  if (id == null) return null;
  for (const features of Object.values(layerFeatures.value)) {
    const match = features?.find((f) => f.id === id);
    if (match) return match;
  }
  return null;
}

const selectedFeature = computed<GeometryFeature | null>(() =>
  resolveFeature(selectedFeatureId.value)
);

// Per-layer visibility state
const layerStates = ref<LayerStateMap>(
  Object.fromEntries(ALL_LAYER_TYPES.map((t) => [t, { visible: true, selectedFeatureIds: [] }]))
);

// Features grouped by layer
const layerFeatures = ref<LayerFeatureMap>({});

// ─── Data loading ────────────────────────────────────────────────────────────

async function loadDraftGeometry() {
  loadError.value = null;
  actionError.value = null;
  try {
    const data = await api.fetchDraftGeometry(props.courseId);
    applyDraftGeometryResponse(data);
  } catch (e: unknown) {
    // Nothing to show, so this one does replace the body.
    loadError.value = (e as Error)?.message ?? 'Không tải được hình học sân';
  }
}

function applyDraftGeometryResponse(data: DraftGeometryResponse) {
  isDraft.value = data.state === 'draft';
  const grouped: LayerFeatureMap = {};
  for (const raw of data.features) {
    // Guarantee a stable id so map hit-tests and modify/delete actions can
    // reliably match features (Story 8-2).
    const feature = ensureFeatureId(raw);
    const lt = feature.properties.layerType;
    if (!grouped[lt]) grouped[lt] = [];
    grouped[lt]!.push(feature);
  }
  layerFeatures.value = grouped;
  // The point the next save diffs against.
  baseline.value = snapshot(data.features);
  validation.value = null;
  isDirty.value = false;
  selectedFeatureId.value = null;
  undoManager.reset();
}

// ─── Tool / layer handlers ───────────────────────────────────────────────────

function handleToolChange(tool: EditorTool) {
  // Switching tool used to be blocked behind the unsaved-changes dialog. It
  // discards nothing — the features drawn so far stay exactly where they are —
  // so the prompt only stood between the operator and the next shape.
  activeTool.value = tool;

  // Selection/vertex handles only apply to the select tool.
  if (tool !== 'select') {
    selectedFeatureId.value = null;
  }

  // Rebuild: the engine is created for one geometry type and this changes it.
  // Only handleLayerSelect used to do this, so picking Polygon after Point
  // left the point engine in place and every click dropped another point.
  currentDrawTools = null;
  ensureDrawTools();
  syncDrawProgress();
}

function handleLayerSelect(layerType: LayerType) {
  activeLayer.value = layerType;
  // Draw geometry type depends on the active layer — rebuild on next use.
  currentDrawTools = null;
  syncDrawProgress();
}

// ─── Map drawing interaction ─────────────────────────────────────────────────

function handleMapClick(coord: GeoCoordinate, zoom: number) {
  // In select mode, clicks are for feature selection (handled via feature-click).
  if (activeTool.value === 'select') return;
  ensureDrawTools().handleClick(coord, zoom);
  syncDrawProgress();
}

function handleMapDblClick(coord: GeoCoordinate, zoom: number) {
  if (activeTool.value === 'select') return;
  ensureDrawTools().handleDoubleClick(coord, zoom);
  syncDrawProgress();
}

/**
 * How many vertices are down, so the screen can say so.
 *
 * Drawing a polygon means clicking corners and then double-clicking to close,
 * and nothing on screen said either half of that. With no basemap tiles behind
 * it — which happens whenever the tile host is slow — there is no visible
 * feedback at all: you click four times into a dark rectangle and nothing
 * appears, because an unfinished polygon is not yet a feature. It reads
 * exactly like a broken tool.
 */
const drawVertexCount = ref(0);

function syncDrawProgress() {
  drawVertexCount.value = currentDrawTools?.currentCoords.length ?? 0;
}

/** Close the shape from the keyboard or the button, not only by double-click. */
function finishDrawing() {
  const tools = ensureDrawTools();
  const coords = tools.currentCoords;
  if (coords.length === 0) return;
  // Complete at the last point placed; the engine closes the ring itself.
  tools.handleDoubleClick(coords[coords.length - 1], 16);
  syncDrawProgress();
}

function cancelDrawing() {
  currentDrawTools?.cancel();
  syncDrawProgress();
}

// ─── Select / vertex-edit / delete interaction (Story 8-2) ────────────────────

function handleFeatureSelect(payload: { id: string | number; layerType: LayerType }) {
  if (activeTool.value !== 'select') return;
  selectedFeatureId.value = payload.id;
  screenReaderAnnouncement.value = `Đã chọn đối tượng lớp ${LAYER_TYPE_LABELS[payload.layerType] ?? payload.layerType}. Kéo một đỉnh để chỉnh, hoặc bấm Delete để xoá.`;
}

function handleFeatureDeselect() {
  if (selectedFeatureId.value != null) {
    selectedFeatureId.value = null;
    screenReaderAnnouncement.value = 'Đã bỏ chọn';
  }
}

function handleVertexMove(payload: {
  featureId: string | number;
  layerType: LayerType;
  vertexIndex: number;
  coord: GeoCoordinate;
  zoom: number;
}) {
  if (!canEdit.value) return;
  const before = resolveFeature(payload.featureId);
  if (!before) return;
  // Snap against everything except the feature being edited.
  const candidates = getAllFeatures().filter((f) => f.id !== before.id);
  ensureDrawTools().moveFeatureVertex(
    before,
    payload.vertexIndex,
    payload.coord,
    payload.zoom,
    candidates
  );
}

function deleteSelectedFeature() {
  if (!canEdit.value) return;
  const feature = selectedFeature.value;
  if (!feature) return;
  ensureDrawTools().removeFeature(feature);
  selectedFeatureId.value = null;
}

function handleFeatureDeleteRequest(payload: { featureId: string | number; layerType: LayerType }) {
  if (!canEdit.value) return;
  const feature = resolveFeature(payload.featureId);
  if (!feature) return;
  ensureDrawTools().removeFeature(feature);
  selectedFeatureId.value = null;
}

function handleVisibilityToggle(layerType: LayerType) {
  const current = layerStates.value[layerType];
  if (current) {
    layerStates.value = {
      ...layerStates.value,
      [layerType]: { ...current, visible: !current.visible },
    };
  }
}

// ─── Draw tools integration ──────────────────────────────────────────────────

// Collect all existing features for snapping
function getAllFeatures(): GeometryFeature[] {
  const all: GeometryFeature[] = [];
  for (const features of Object.values(layerFeatures.value)) {
    if (features) all.push(...features);
  }
  return all;
}

/** What each drawing tool draws. Select and edit draw nothing. */
const TOOL_GEOMETRY_TYPE: Partial<Record<EditorTool, 'Point' | 'LineString' | 'Polygon'>> = {
  point: 'Point',
  line: 'LineString',
  polygon: 'Polygon',
};

let currentDrawTools: ReturnType<typeof createDrawTools> | null = null;

function ensureDrawTools() {
  if (currentDrawTools) return currentDrawTools;

  // The tool the operator picked wins; the layer only supplies a default.
  //
  // This used to read the layer alone, so the Point/Line/Polygon buttons
  // changed nothing: choosing "Vùng" on the Tee layer still dropped points,
  // one per click, and the shape the operator was tracing never appeared.
  const geomType = TOOL_GEOMETRY_TYPE[activeTool.value]
    ?? LAYER_DEFAULT_GEOMETRY_TYPE[activeLayer.value];
  const tools = createDrawTools({
    layerType: activeLayer.value,
    geometryType: geomType as 'Point' | 'LineString' | 'Polygon',
    existingFeatures: getAllFeatures(),
    onFeatureComplete(feature) {
      applyFeatureAdd(feature);
      syncDrawProgress();
    },
    onFeatureDelete(feature) {
      applyFeatureDelete(feature);
    },
    onFeatureModify(before, after) {
      applyFeatureModify(before, after);
    },
  });

  currentDrawTools = tools;
  return tools;
}

// ─── Feature mutations ───────────────────────────────────────────────────────

function applyFeatureAdd(feature: GeometryFeature) {
  const cmd = cmdAddFeature(feature);
  undoManager.push(cmd);

  const layerType = feature.properties.layerType;
  const current = layerFeatures.value[layerType] ?? [];
  layerFeatures.value = {
    ...layerFeatures.value,
    [layerType]: [...current, feature],
  };

  isDirty.value = true;
  screenReaderAnnouncement.value = `Added ${feature.properties.layerType} feature`;
}

function applyFeatureDelete(feature: GeometryFeature) {
  const cmd = cmdDeleteFeature(feature);
  undoManager.push(cmd);

  const layerType = feature.properties.layerType;
  const current = layerFeatures.value[layerType] ?? [];
  layerFeatures.value = {
    ...layerFeatures.value,
    [layerType]: current.filter((f) => f.id !== feature.id),
  };

  isDirty.value = true;
  screenReaderAnnouncement.value = `Deleted ${feature.properties.layerType} feature`;
}

function applyFeatureModify(before: GeometryFeature, after: GeometryFeature) {
  const cmd = cmdModifyFeature(before, after);
  undoManager.push(cmd);

  const layerType = before.properties.layerType;
  const current = layerFeatures.value[layerType] ?? [];
  layerFeatures.value = {
    ...layerFeatures.value,
    [layerType]: current.map((f) => (f.id === before.id ? after : f)),
  };

  isDirty.value = true;
  screenReaderAnnouncement.value = `Đã sửa một đối tượng lớp ${LAYER_TYPE_LABELS[before.properties.layerType] ?? before.properties.layerType}`;
}

// ─── Undo / Redo ─────────────────────────────────────────────────────────────

function handleUndo() {
  const cmd = undoManager.undo();
  if (!cmd) return;

  // Apply the inverse operation
  switch (cmd.type) {
    case 'add_feature':
      // Undo add = delete the added feature
      for (const f of cmd.after) {
        const layerType = f.properties.layerType;
        layerFeatures.value = {
          ...layerFeatures.value,
          [layerType]: (layerFeatures.value[layerType] ?? []).filter(
            (existing) => existing.id !== f.id
          ),
        };
      }
      break;

    case 'delete_feature':
      // Undo delete = re-add the deleted feature
      for (const f of cmd.before) {
        const layerType = f.properties.layerType;
        const current = layerFeatures.value[layerType] ?? [];
        layerFeatures.value = {
          ...layerFeatures.value,
          [layerType]: [...current, f],
        };
      }
      break;

    case 'modify_feature':
    case 'move_vertex':
    case 'add_vertex':
    case 'delete_vertex':
      // Undo = restore the before state
      for (const f of cmd.before) {
        const layerType = f.properties.layerType;
        layerFeatures.value = {
          ...layerFeatures.value,
          [layerType]: (layerFeatures.value[layerType] ?? []).map(
            (existing) => (existing.id === f.id ? f : existing)
          ),
        };
      }
      break;
  }

  // Check if still dirty
  isDirty.value = undoManager.isDirty;
  screenReaderAnnouncement.value = `Undid: ${cmd.description}`;
}

function handleRedo() {
  const cmd = undoManager.redo();
  if (!cmd) return;

  switch (cmd.type) {
    case 'add_feature':
      for (const f of cmd.after) {
        const layerType = f.properties.layerType;
        const current = layerFeatures.value[layerType] ?? [];
        layerFeatures.value = {
          ...layerFeatures.value,
          [layerType]: [...current, f],
        };
      }
      break;

    case 'delete_feature':
      for (const f of cmd.before) {
        const layerType = f.properties.layerType;
        layerFeatures.value = {
          ...layerFeatures.value,
          [layerType]: (layerFeatures.value[layerType] ?? []).filter(
            (existing) => existing.id !== f.id
          ),
        };
      }
      break;

    case 'modify_feature':
    case 'move_vertex':
    case 'add_vertex':
    case 'delete_vertex':
      for (const f of cmd.after) {
        const layerType = f.properties.layerType;
        layerFeatures.value = {
          ...layerFeatures.value,
          [layerType]: (layerFeatures.value[layerType] ?? []).map(
            (existing) => (existing.id === f.id ? f : existing)
          ),
        };
      }
      break;
  }

  isDirty.value = undoManager.isDirty;
  screenReaderAnnouncement.value = `Redid: ${cmd.description}`;
}

// ─── Save / Validate ─────────────────────────────────────────────────────────

async function handleSaveDraft() {
  try {
    const allFeatures = getAllFeatures();
    actionError.value = null;
    // Only what changed since the draft was loaded. The endpoint takes a batch
    // of CREATE/UPDATE/DELETE keyed by the server's own feature UUIDs.
    const operations = toBatchOperations(baseline.value, allFeatures);
    if (operations.length === 0) {
      isDirty.value = false;
      undoManager.markSaved();
      screenReaderAnnouncement.value = 'Không có thay đổi nào để lưu';
      return;
    }
    const result = await api.saveDraftGeometry(props.courseId, operations);
    isDirty.value = false;
    undoManager.markSaved();
    applyDraftGeometryResponse(result);
    screenReaderAnnouncement.value = 'Đã lưu bản nháp';
  } catch (e: unknown) {
    // Reported over the editor, which keeps running: the features are still in
    // memory and still on screen, and trying again is the obvious next move.
    actionError.value = (e as Error)?.message ?? 'Không lưu được bản nháp';
    screenReaderAnnouncement.value = 'Lưu bản nháp thất bại';
  }
}

async function handleValidate(): Promise<ValidationError[]> {
  try {
    actionError.value = null;
    // Server-side, against the stored draft — unsaved edits are not covered,
    // which is why the result carries that caveat when the editor is dirty.
    const result = await api.validateGeometry(props.courseId);
    validation.value = { ...result, staleFor: isDirty.value };
    screenReaderAnnouncement.value = result.valid
      ? `Hình học hợp lệ: ${result.totalChecked} đối tượng`
      : `Hình học có lỗi: ${result.invalidCount}/${result.totalChecked} đối tượng`;
    return [];
  } catch (e: unknown) {
    validation.value = null;
    actionError.value = (e as Error)?.message ?? 'Không kiểm tra được hình học';
    return [];
  }
}

// ─── Unsaved changes guard ──────────────────────────────────────────────────

const showUnsavedDialog = ref(false);
const unsavedDialogTitle = ref('Thay đổi chưa lưu');
const unsavedDialogMessage = ref('Bạn còn chỉnh sửa hình học chưa lưu. Bạn muốn làm gì?');

type PendingAction = 'tool-switch' | 'layer-switch' | 'navigate' | 'save-draft';
const pendingAction = ref<PendingAction | null>(null);
const pendingToolChange = ref<EditorTool | null>(null);
const pendingLayerChange = ref<LayerType | null>(null);

const screenReaderAnnouncement = ref('');

useUnsavedChanges({
  async onSave() {
    await handleSaveDraft();
  },
  onDiscard() {
    isDirty.value = false;
    undoManager.reset();
  },
  onCancel() {
    // Reset pending
    pendingAction.value = null;
    pendingToolChange.value = null;
    pendingLayerChange.value = null;
  },
});

// ─── Keyboard shortcuts (Slice 5) ────────────────────────────────────────────

let removeShortcuts: (() => void) | null = null;

onMounted(() => {
  loadCourse();
  loadDraftGeometry();

  removeShortcuts = attachEditorShortcuts({
    onUndo: handleUndo,
    onRedo: handleRedo,
  });

  // Slice 5: also attach Ctrl+S for save
  window.addEventListener('keydown', handleGlobalKeydown);
});

onUnmounted(() => {
  removeShortcuts?.();
  window.removeEventListener('keydown', handleGlobalKeydown);
});

function handleGlobalKeydown(event: KeyboardEvent) {
  const isMac = navigator.platform.toUpperCase().includes('MAC');
  const ctrlKey = isMac ? event.metaKey : event.ctrlKey;

  // Enter closes the shape, Escape abandons it. Double-click still works; it
  // was simply the only way, and an undiscoverable one.
  if (!isEditableTarget(event.target) && drawVertexCount.value > 0) {
    if (event.key === 'Enter') {
      event.preventDefault();
      finishDrawing();
      return;
    }
    if (event.key === 'Escape') {
      event.preventDefault();
      cancelDrawing();
      return;
    }
  }

  // Ctrl+S / Cmd+S → save draft
  if (ctrlKey && (event.key === 's' || event.key === 'S')) {
    event.preventDefault();
    if (canEdit.value && !saving.value) {
      handleSaveDraft();
    }
    return;
  }

  // Delete / Backspace → delete the selected feature (select tool only).
  if (
    (event.key === 'Xoá' || event.key === 'Backspace') &&
    activeTool.value === 'select' &&
    selectedFeatureId.value != null &&
    canEdit.value &&
    !isEditableTarget(event.target)
  ) {
    event.preventDefault();
    deleteSelectedFeature();
  }
}

/** Guard so Backspace inside a text field is never captured as a delete. */
function isEditableTarget(target: EventTarget | null): boolean {
  const el = target as HTMLElement | null;
  if (!el || !el.tagName) return false;
  const tag = el.tagName.toUpperCase();
  return tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT' || el.isContentEditable;
}

// ─── Guard handlers ─────────────────────────────────────────────────────────

async function handleGuardSave() {
  await handleSaveDraft();
  resumePendingAction();
}

function handleGuardDiscard() {
  isDirty.value = false;
  undoManager.reset();
  resumePendingAction();
}

function handleGuardCancel() {
  pendingAction.value = null;
  pendingToolChange.value = null;
  pendingLayerChange.value = null;
}

function resumePendingAction() {
  switch (pendingAction.value) {
    case 'tool-switch':
      if (pendingToolChange.value) {
        activeTool.value = pendingToolChange.value;
      }
      break;
    case 'layer-switch':
      if (pendingLayerChange.value) {
        activeLayer.value = pendingLayerChange.value;
      }
      break;
    case 'save-draft':
      handleSaveDraft();
      break;
  }
  pendingAction.value = null;
  pendingToolChange.value = null;
  pendingLayerChange.value = null;
}
</script>

<style scoped>
.edit-geometry-page {
  display: flex;
  flex-direction: column;
  /* The shell's topbar (88px) and content padding (2 × 32px) sit above and
     around this page; 100vh here made the whole shell scroll. */
  height: calc(100dvh - 152px);
  min-height: 0;
}

@media (max-width: 900px) {
  .edit-geometry-page {
    height: auto;
    min-height: calc(100dvh - 104px);
  }
}

/* Screen reader only (matches GeometryEditor.vue) */
.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border-width: 0;
}
</style>
