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
      :loading="loading"
      :saving="saving"
      :validating="validating"
      :load-error="loadError"
      :can-edit="canEdit"
      :is-dirty="isDirty"
      :is-draft="isDraft"
      :layer-states="layerStates"
      :layer-features="layerFeatures"
      :active-tool="activeTool"
      :active-layer="activeLayer"
      :can-undo="undoManager.canUndo > 0"
      :can-redo="undoManager.canRedo > 0"
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
    />
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue';
import GeometryEditor from '@/components/geometry/GeometryEditor.vue';
import UnsavedChangesGuard from '@/components/geometry/UnsavedChangesGuard.vue';
import { createDrawTools } from '@/components/geometry/DrawTools';
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

const auditLog: import('@/hooks/useGeometryApi').AuditLogEntry[] = [];

function appendAudit(entry: import('@/hooks/useGeometryApi').AuditLogEntry) {
  auditLog.push(entry);
  // In production: forward to an audit logging service
  console.debug('[GeometryAudit]', entry);
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
const loadError = api.error;

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

// Per-layer visibility state
const layerStates = ref<LayerStateMap>(
  Object.fromEntries(ALL_LAYER_TYPES.map((t) => [t, { visible: true, selectedFeatureIds: [] }]))
);

// Features grouped by layer
const layerFeatures = ref<LayerFeatureMap>({});

// ─── Data loading ────────────────────────────────────────────────────────────

async function loadDraftGeometry() {
  try {
    const data = await api.fetchDraftGeometry(props.courseId);
    applyDraftGeometryResponse(data);
  } catch {
    // error is set by the api composable
  }
}

function applyDraftGeometryResponse(data: DraftGeometryResponse) {
  isDraft.value = data.state === 'draft';
  const grouped: LayerFeatureMap = {};
  for (const feature of data.features) {
    const lt = feature.properties.layerType;
    if (!grouped[lt]) grouped[lt] = [];
    grouped[lt]!.push(feature);
  }
  layerFeatures.value = grouped;
  isDirty.value = false;
  undoManager.reset();
}

// ─── Tool / layer handlers ───────────────────────────────────────────────────

function handleToolChange(tool: EditorTool) {
  // Guard: warn if switching tools with unsaved edits
  if (isDirty.value && activeTool.value !== tool) {
    showUnsavedDialog.value = true;
    pendingToolChange.value = tool;
    pendingAction.value = 'tool-switch';
    return;
  }
  activeTool.value = tool;
  // Prepare the draw-tools engine for the active layer/tool.
  ensureDrawTools();
}

function handleLayerSelect(layerType: LayerType) {
  activeLayer.value = layerType;
  // Draw geometry type depends on the active layer — rebuild on next use.
  currentDrawTools = null;
}

// ─── Map drawing interaction ─────────────────────────────────────────────────

function handleMapClick(coord: GeoCoordinate, zoom: number) {
  // In select mode, clicks are for feature selection (handled via feature-click).
  if (activeTool.value === 'select') return;
  ensureDrawTools().handleClick(coord, zoom);
}

function handleMapDblClick(coord: GeoCoordinate, zoom: number) {
  if (activeTool.value === 'select') return;
  ensureDrawTools().handleDoubleClick(coord, zoom);
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

let currentDrawTools: ReturnType<typeof createDrawTools> | null = null;

function ensureDrawTools() {
  if (currentDrawTools) return currentDrawTools;

  const geomType = LAYER_DEFAULT_GEOMETRY_TYPE[activeLayer.value];
  const tools = createDrawTools({
    layerType: activeLayer.value,
    geometryType: geomType as 'Point' | 'LineString' | 'Polygon',
    existingFeatures: getAllFeatures(),
    onFeatureComplete(feature) {
      applyFeatureAdd(feature);
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
  screenReaderAnnouncement.value = `Modified ${before.properties.layerType} feature`;
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
    const result = await api.saveDraftGeometry(props.courseId, allFeatures);
    isDirty.value = false;
    undoManager.markSaved();
    applyDraftGeometryResponse(result);
    screenReaderAnnouncement.value = 'Draft saved successfully';
  } catch {
    // error handled by api composable
  }
}

async function handleValidate(): Promise<ValidationError[]> {
  try {
    const allFeatures = getAllFeatures();
    const result = await api.validateGeometry(props.courseId, allFeatures);
    if (result.valid) {
      screenReaderAnnouncement.value = 'Geometry validation passed';
    } else {
      screenReaderAnnouncement.value = `Geometry validation failed: ${result.errors.length} errors`;
    }
    return result.errors;
  } catch {
    return [];
  }
}

// ─── Unsaved changes guard ──────────────────────────────────────────────────

const showUnsavedDialog = ref(false);
const unsavedDialogTitle = ref('Unsaved Changes');
const unsavedDialogMessage = ref('You have unsaved geometry edits. What would you like to do?');

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

  // Ctrl+S / Cmd+S → save draft
  if (ctrlKey && (event.key === 's' || event.key === 'S')) {
    event.preventDefault();
    if (canEdit.value && !saving.value) {
      handleSaveDraft();
    }
  }
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
  height: 100vh;
  min-height: 0;
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
