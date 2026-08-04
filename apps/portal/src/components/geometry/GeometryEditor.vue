<template>
  <div
    class="geometry-editor"
    role="application"
    aria-label="Course Geometry Editor"
  >
    <!-- Editor header -->
    <header class="editor-header" role="banner">
      <div class="header-left">
        <span class="course-id-label">Course {{ courseId }}</span>
        <span
          class="state-badge"
          :class="draftIndicatorClass"
          role="status"
          :aria-label="`Geometry state: ${isDraft ? 'draft' : 'published'}`"
        >
          {{ isDraft ? 'Draft' : 'Published' }}
        </span>
      </div>

      <div class="header-center">
        <span v-if="isDirty" class="unsaved-indicator" aria-live="polite">
          ● Unsaved changes
        </span>
      </div>

      <div class="header-right">
        <!-- Save draft -->
        <button
          v-if="isDirty"
          class="header-btn save-btn"
          :disabled="saving || !canEdit"
          aria-label="Save draft geometry"
          title="Save Draft (Ctrl+S)"
          @click="emit('save-draft')"
        >
          {{ saving ? 'Saving…' : 'Save Draft' }}
        </button>

        <!-- Validate -->
        <button
          class="header-btn validate-btn"
          :disabled="validating || !canEdit"
          aria-label="Validate geometry before publishing"
          title="Validate"
          @click="emit('validate')"
        >
          {{ validating ? 'Validating…' : 'Validate' }}
        </button>
      </div>
    </header>

    <!-- Error banner -->
    <div v-if="loadError" class="editor-error-banner" role="alert">
      <span class="error-icon">⚠</span>
      <span class="error-message">{{ loadError }}</span>
      <button class="retry-btn" @click="emit('retry')">Retry</button>
    </div>

    <!-- Loading state -->
    <div v-else-if="loading" class="editor-loading" aria-busy="true" aria-label="Loading geometry">
      <div class="loading-spinner" aria-hidden="true"></div>
      <span class="loading-label">Loading course geometry…</span>
    </div>

    <!-- Empty state -->
    <div v-else-if="isEmpty && !canEdit" class="editor-empty" role="status">
      <span class="empty-icon" aria-hidden="true">🗺</span>
      <p class="empty-title">No geometry for this course yet.</p>
      <p class="empty-subtitle">A Course Admin can add geometry features.</p>
    </div>

    <!-- Main editor body -->
    <div v-else class="editor-body">
      <!-- Tool palette (left sidebar) -->
      <ToolPalette
        :active-tool="activeTool"
        :active-layer="activeLayer"
        :can-undo="canUndo"
        :can-redo="canRedo"
        @tool-change="handleToolChange"
        @undo="emit('undo')"
        @redo="emit('redo')"
      />

      <!-- Layer panel (left sidebar below tools) -->
      <LayerPanel
        :layer-states="layerStates"
        :active-layer="activeLayer"
        :layer-features="layerFeatures"
        @layer-visibility-toggle="handleVisibilityToggle"
        @layer-select="handleLayerSelect"
      />

      <!-- Map canvas — MapLibre GL JS (Slice 3) -->
      <main
        class="map-canvas"
        role="main"
        aria-label="Map editing canvas"
        tabindex="-1"
      >
        <CourseMap
          ref="courseMapRef"
          :layer-features="layerFeatures"
          :layer-states="layerStates"
          :course-id="courseId"
          @map-ready="handleMapReady"
          @feature-click="handleFeatureClick"
          @map-click="(c, z) => emit('map-click', c, z)"
          @map-dblclick="(c, z) => emit('map-dblclick', c, z)"
        />
      </main>
    </div>

    <!-- Accessibility: live region for screen reader announcements -->
    <div class="sr-only" role="status" aria-live="polite" aria-atomic="true">
      {{ screenReaderAnnouncement }}
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import ToolPalette from './ToolPalette.vue';
import LayerPanel from './LayerPanel.vue';
import CourseMap from './CourseMap.vue';
import type {
  EditorTool,
  LayerType,
  LayerStateMap,
  LayerFeatureMap,
  GeometryFeature,
  GeoCoordinate,
} from '@/types/geometry';
import { LAYER_TYPE_LABELS } from '@/types/geometry';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
const courseMapRef = ref<any>(null);

const props = defineProps<{
  courseId: number;
  /** Whether geometry data is currently loading. */
  loading: boolean;
  /** Whether a save or validate operation is in progress. */
  saving?: boolean;
  validating?: boolean;
  /** Error message if the last load failed. */
  loadError: string | null;
  /** Whether the current user can edit geometry. */
  canEdit: boolean;
  /** Whether there are unsaved changes. */
  isDirty: boolean;
  /** Whether the current geometry is a draft (vs published). */
  isDraft: boolean;
  /** Per-layer visibility and selection state. */
  layerStates: LayerStateMap;
  /** Features grouped by layer type. */
  layerFeatures: LayerFeatureMap;
  /** Active drawing/editing tool. */
  activeTool: EditorTool;
  /** Active layer type being edited. */
  activeLayer: LayerType;
  /** Whether undo is available. */
  canUndo: boolean;
  /** Whether redo is available. */
  canRedo: boolean;
}>();

const emit = defineEmits<{
  (e: 'tool-change', tool: EditorTool): void;
  (e: 'layer-visibility-toggle', layerType: LayerType): void;
  (e: 'layer-select', layerType: LayerType): void;
  (e: 'undo'): void;
  (e: 'redo'): void;
  (e: 'save-draft'): void;
  (e: 'validate'): void;
  (e: 'retry'): void;
  (e: 'map-click', coord: GeoCoordinate, zoom: number): void;
  (e: 'map-dblclick', coord: GeoCoordinate, zoom: number): void;
}>();

// ─── Computed ───────────────────────────────────────────────────────────────

const isEmpty = computed(() =>
  Object.values(props.layerFeatures).every((f) => !f || f.length === 0)
);

const draftIndicatorClass = computed(() =>
  props.isDraft ? 'badge-draft' : 'badge-published'
);


const screenReaderAnnouncement = ref('');

// ─── Handlers ──────────────────────────────────────────────────────────────

function handleToolChange(tool: EditorTool) {
  screenReaderAnnouncement.value = `Tool changed to ${tool}`;
  emit('tool-change', tool);
}

function handleVisibilityToggle(layerType: LayerType) {
  screenReaderAnnouncement.value = `Layer ${LAYER_TYPE_LABELS[layerType]} visibility toggled`;
  emit('layer-visibility-toggle', layerType);
}

function handleLayerSelect(layerType: LayerType) {
  screenReaderAnnouncement.value = `Selected layer ${LAYER_TYPE_LABELS[layerType]}`;
  emit('layer-select', layerType);
}

function handleMapReady() {
  screenReaderAnnouncement.value = 'Map loaded and ready';
}

function handleFeatureClick(feature: GeometryFeature) {
  screenReaderAnnouncement.value = `Feature selected on ${LAYER_TYPE_LABELS[feature.properties.layerType]} layer`;
}
</script>

<style scoped>
.geometry-editor {
  display: flex;
  flex-direction: column;
  height: 100%;
  min-height: 0;
  background: #f9fafb;
  font-family: system-ui, -apple-system, sans-serif;
}

/* ─── Header ─────────────────────────────────────────────────────────────── */

.editor-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.625rem 1rem;
  background: #ffffff;
  border-bottom: 1px solid #e5e7eb;
  flex-shrink: 0;
  min-height: 3.25rem;
}

.header-left {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.course-id-label {
  font-size: 0.875rem;
  font-weight: 700;
  color: #111827;
}

.state-badge {
  display: inline-flex;
  align-items: center;
  padding: 0.2rem 0.6rem;
  border-radius: 9999px;
  font-size: 0.75rem;
  font-weight: 600;
  border: 1px solid currentColor;
}

.badge-draft {
  color: #92400e;
  background: #fef3c7;
}

.badge-published {
  color: #15803d;
  background: #dcfce7;
}

.header-center {
  flex: 1;
  display: flex;
  justify-content: center;
}

.unsaved-indicator {
  font-size: 0.75rem;
  color: #92400e;
  font-weight: 500;
  display: flex;
  align-items: center;
  gap: 0.3rem;
}

.header-right {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.header-btn {
  padding: 0.4rem 0.875rem;
  border-radius: 6px;
  border: 1px solid transparent;
  cursor: pointer;
  font-size: 0.8125rem;
  font-weight: 500;
  min-height: 44px;
  transition: background 0.12s, border-color 0.12s;
  outline: none;
}

.header-btn:focus-visible {
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.5);
}

.save-btn {
  background: #1d4ed8;
  color: #ffffff;
  border-color: #1d4ed8;
}

.save-btn:hover:not(:disabled) {
  background: #1e40af;
}

.save-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.validate-btn {
  background: #ffffff;
  color: #374151;
  border-color: #d1d5db;
}

.validate-btn:hover:not(:disabled) {
  background: #f9fafb;
  border-color: #9ca3af;
}

.validate-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

/* ─── Error banner ────────────────────────────────────────────────────────── */

.editor-error-banner {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.75rem 1rem;
  background: #fff5f5;
  border-bottom: 1px solid #fecaca;
  color: #dc2626;
  flex-shrink: 0;
}

.error-icon { font-size: 1.125rem; }

.error-message {
  flex: 1;
  font-size: 0.875rem;
}

.retry-btn {
  padding: 0.35rem 0.875rem;
  border-radius: 6px;
  background: #dc2626;
  color: #ffffff;
  border: none;
  cursor: pointer;
  font-size: 0.8125rem;
  min-height: 44px;
}

/* ─── Loading ─────────────────────────────────────────────────────────────── */

.editor-loading {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.75rem;
  color: #6b7280;
}

.loading-spinner {
  width: 2rem;
  height: 2rem;
  border: 3px solid #e5e7eb;
  border-top-color: #3b82f6;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.loading-label {
  font-size: 0.875rem;
}

/* ─── Empty ───────────────────────────────────────────────────────────────── */

.editor-empty {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  color: #6b7280;
  text-align: center;
  padding: 2rem;
}

.empty-icon { font-size: 2.5rem; }

.empty-title {
  font-size: 1rem;
  font-weight: 600;
  color: #374151;
  margin: 0;
}

.empty-subtitle {
  font-size: 0.875rem;
  color: #9ca3af;
  margin: 0;
}

/* ─── Body ────────────────────────────────────────────────────────────────── */

.editor-body {
  flex: 1;
  display: flex;
  min-height: 0;
  overflow: hidden;
}

/* ─── Map canvas ───────────────────────────────────────────────────────────── */

.map-canvas {
  flex: 1;
  min-width: 0;
  position: relative;
  background: #1a1a2e; /* Dark map-like background for portal readability */
  outline: none;
}

.map-canvas:focus-visible {
  outline: 3px solid rgba(59, 130, 246, 0.5);
  outline-offset: -3px;
}

/* ─── Screen reader only ───────────────────────────────────────────────────── */

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
