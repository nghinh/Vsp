<template>
  <div
    class="geometry-editor"
    role="application"
    aria-label="Biên tập hình học sân"
  >
    <!-- Editor header -->
    <header class="editor-header" role="banner">
      <div class="header-left">
        <span class="course-id-label">{{ courseName || `Sân #${courseId}` }}</span>
        <span v-if="courseCentre === null" class="no-location" role="status">
          Sân chưa có toạ độ — bản đồ đang mở ở mức toàn quốc
        </span>
        <span
          class="state-badge"
          :class="draftIndicatorClass"
          role="status"
          :aria-label="`Trạng thái: ${isDraft ? 'bản nháp' : 'đã công bố'}`"
        >
          {{ isDraft ? 'Bản nháp' : 'Đã công bố' }}
        </span>
      </div>

      <div class="header-center">
        <span v-if="isDirty" class="unsaved-indicator" aria-live="polite">
          ● Có thay đổi chưa lưu
        </span>
      </div>

      <div class="header-right">
        <!-- Save draft -->
        <button
          v-if="isDirty"
          class="header-btn save-btn"
          :disabled="saving || !canEdit"
          aria-label="Lưu bản nháp hình học"
          title="Lưu nháp (Ctrl+S)"
          @click="emit('save-draft')"
        >
          {{ saving ? 'Đang lưu…' : 'Lưu nháp' }}
        </button>

        <!-- Validate -->
        <button
          class="header-btn validate-btn"
          :disabled="validating || !canEdit"
          aria-label="Kiểm tra hình học trước khi công bố"
          title="Kiểm tra"
          @click="emit('validate')"
        >
          {{ validating ? 'Đang kiểm tra…' : 'Kiểm tra' }}
        </button>
      </div>
    </header>

    <!-- Error banner -->
    <div v-if="loadError" class="editor-error-banner" role="alert">
      <span class="error-icon">⚠</span>
      <span class="error-message">{{ loadError }}</span>
      <button class="retry-btn" @click="emit('retry')">Thử lại</button>
    </div>

    <!-- A failed save or validate. Sits above the editor rather than
         replacing it: the features are still in memory and still on screen,
         and the operator's next move is to try again, not to reload and lose
         them. -->
    <div v-if="actionError" class="editor-action-banner" role="alert">
      <span class="error-icon" aria-hidden="true">⚠</span>
      <span class="error-message">{{ actionError }}</span>
      <button class="dismiss-btn" aria-label="Đóng thông báo" @click="emit('dismiss-action-error')">
        ×
      </button>
    </div>

    <!-- What "Kiểm tra" found. The result used to go only to a screen-reader
         live region, so a sighted operator clicked the button and watched
         nothing happen. -->
    <div
      v-if="validation"
      class="editor-validation"
      :class="validation.valid ? 'is-ok' : 'is-bad'"
      role="status"
    >
      <span aria-hidden="true">{{ validation.valid ? '✓' : '⚠' }}</span>
      <span v-if="validation.valid">
        Hình học hợp lệ — đã kiểm tra {{ validation.totalChecked }} đối tượng.
      </span>
      <span v-else>
        {{ validation.invalidCount }}/{{ validation.totalChecked }} đối tượng có lỗi.
      </span>

      <span v-if="validation.staleFor" class="stale">
        Chỉ kiểm tra bản nháp <strong>đã lưu</strong> — các thay đổi chưa lưu
        không nằm trong kết quả này.
      </span>

      <ul v-if="validation.errors.length" class="validation-errors">
        <li v-for="(err, i) in validation.errors" :key="i">
          <template v-if="err.layerType">[{{ err.layerType }}] </template>
          {{ err.errorMessage ?? 'Không rõ lỗi' }}
        </li>
      </ul>
    </div>

    <!-- A shape in progress. Without this the only cue that anything is
         happening is the shape itself, and an unfinished polygon is not drawn
         at all — so on a course with no basemap you click into a dark square
         and nothing appears. -->
    <div v-if="(drawVertexCount ?? 0) > 0" class="editor-drawing" role="status">
      <span>Đang vẽ — đã đặt <strong>{{ drawVertexCount }}</strong> điểm.</span>
      <button type="button" class="draw-btn" @click="emit('finish-drawing')">
        Hoàn tất (Enter)
      </button>
      <button type="button" class="draw-btn draw-btn-quiet" @click="emit('cancel-drawing')">
        Huỷ (Esc)
      </button>
      <span class="draw-hint">Hoặc nháy đúp lên bản đồ để đóng hình.</span>
    </div>

    <!-- Loading state -->
    <div v-if="loading" class="editor-loading" aria-busy="true" aria-label="Đang tải hình học">
      <div class="loading-spinner" aria-hidden="true"></div>
      <span class="loading-label">Đang tải hình học sân…</span>
    </div>

    <!-- Empty state -->
    <div v-else-if="isEmpty && !canEdit" class="editor-empty" role="status">
      <span class="empty-icon" aria-hidden="true">🗺</span>
      <p class="empty-title">Sân này chưa có hình học nào.</p>
      <p class="empty-subtitle">Cần quyền Course Admin để vẽ.</p>
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
        aria-label="Khung vẽ bản đồ"
        tabindex="-1"
      >
        <CourseMap
          ref="courseMapRef"
          :layer-features="layerFeatures"
          :layer-states="layerStates"
          :course-id="courseId"
          :initial-center="courseCentre ?? undefined"
          :active-tool="activeTool"
          :selected-feature-id="selectedFeatureId"
          @map-ready="handleMapReady"
          @feature-click="handleFeatureClick"
          @map-click="(c, z) => emit('map-click', c, z)"
          @map-dblclick="(c, z) => emit('map-dblclick', c, z)"
          @feature-select="(p) => emit('feature-select', p)"
          @feature-deselect="() => emit('feature-deselect')"
          @vertex-move="(p) => emit('vertex-move', p)"
          @feature-delete="(p) => emit('feature-delete', p)"
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
  /** The course's own name, so the header is not just an id. */
  courseName?: string | null;
  /** Where the map opens, as [lng, lat]. Null when the course has no location. */
  courseCentre?: [number, number] | null;
  /** Vertices placed in the shape currently being drawn, if any. */
  drawVertexCount?: number;
  /** Whether geometry data is currently loading. */
  loading: boolean;
  /** Whether a save or validate operation is in progress. */
  saving?: boolean;
  validating?: boolean;
  /** Error message if the last load failed. */
  /** The geometry could not be loaded — there is nothing to edit. */
  loadError: string | null;
  /** A save or validate failed. The editor stays up; the work is still there. */
  actionError?: string | null;
  /** The last validation result, or null if none has run since the last load. */
  validation?: {
    valid: boolean;
    totalChecked: number;
    validCount: number;
    invalidCount: number;
    errors: Array<{ featureUuid: string | null; errorMessage: string | null; layerType: string | null }>;
    /** True when the editor had unsaved work, so this covers the saved draft only. */
    staleFor: boolean;
  } | null;
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
  /** Id of the currently selected feature (drives vertex handles). */
  selectedFeatureId?: string | number | null;
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
  (e: 'dismiss-action-error'): void;
  (e: 'finish-drawing'): void;
  (e: 'cancel-drawing'): void;
  (e: 'map-click', coord: GeoCoordinate, zoom: number): void;
  (e: 'map-dblclick', coord: GeoCoordinate, zoom: number): void;
  (e: 'feature-select', payload: { id: string | number; layerType: LayerType }): void;
  (e: 'feature-deselect'): void;
  (e: 'vertex-move', payload: { featureId: string | number; layerType: LayerType; vertexIndex: number; coord: GeoCoordinate; zoom: number }): void;
  (e: 'feature-delete', payload: { featureId: string | number; layerType: LayerType }): void;
}>();

// ─── Computed ───────────────────────────────────────────────────────────────

const isEmpty = computed(() =>
  Object.values(props.layerFeatures).every((f) => !f || f.length === 0)
);

const draftIndicatorClass = computed(() =>
  props.isDraft ? 'badge-draft' : 'badge-published'
);


/**
 * The four drawing tools, named as the palette names them.
 *
 * The announcement used to read the raw tool id — "Tool changed to polygon" —
 * to an operator whose whole screen is otherwise in Vietnamese.
 */
const TOOL_LABELS: Record<string, string> = {
  select: 'Chọn',
  point: 'Điểm',
  line: 'Đường',
  polygon: 'Vùng',
};

const screenReaderAnnouncement = ref('');

// ─── Handlers ──────────────────────────────────────────────────────────────

function handleToolChange(tool: EditorTool) {
  screenReaderAnnouncement.value = `Đã chuyển sang công cụ ${TOOL_LABELS[tool] ?? tool}`;
  emit('tool-change', tool);
}

function handleVisibilityToggle(layerType: LayerType) {
  screenReaderAnnouncement.value = `Đã bật/tắt hiển thị lớp ${LAYER_TYPE_LABELS[layerType]}`;
  emit('layer-visibility-toggle', layerType);
}

function handleLayerSelect(layerType: LayerType) {
  screenReaderAnnouncement.value = `Đã chọn lớp ${LAYER_TYPE_LABELS[layerType]}`;
  emit('layer-select', layerType);
}

function handleMapReady() {
  screenReaderAnnouncement.value = 'Bản đồ đã sẵn sàng';
}

function handleFeatureClick(feature: GeometryFeature) {
  screenReaderAnnouncement.value = `Đã chọn một đối tượng trên lớp ${LAYER_TYPE_LABELS[feature.properties.layerType]}`;
}
</script>

<style scoped>
.geometry-editor {
  display: flex;
  flex-direction: column;
  height: 100%;
  min-height: 0;
  background: var(--surface-container);
  font-family: system-ui, -apple-system, sans-serif;
}

/* ─── Header ─────────────────────────────────────────────────────────────── */

.editor-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.625rem 1rem;
  background: var(--surface-container-lowest, var(--surface-container-low));
  border-bottom: 1px solid var(--surface-container-highest);
  flex-shrink: 0;
  min-height: 3.25rem;
}

.header-left {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.no-location {
  margin-left: 10px;
  padding: 2px 8px;
  border-radius: 999px;
  background: rgba(240, 180, 41, 0.14);
  color: #f0c869;
  font-size: 11px;
}
.course-id-label {
  font-size: 0.875rem;
  font-weight: 700;
  color: var(--on-surface);
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
  color: #f0c869;
  background: rgba(240, 180, 41, 0.14);
}

.badge-published {
  color: #6ee7a8;
  background: rgba(34, 197, 94, 0.14);
}

.header-center {
  flex: 1;
  display: flex;
  justify-content: center;
}

.unsaved-indicator {
  font-size: 0.75rem;
  color: #f0c869;
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
  background: var(--secondary-container);
  color: #ffffff;
  border-color: var(--secondary-container);
}

.save-btn:hover:not(:disabled) {
  background: var(--secondary-container);
}

.save-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.validate-btn {
  background: var(--surface-container-lowest, var(--surface-container-low));
  color: #c5cde8;
  border-color: var(--on-surface, var(--on-surface));
}

.validate-btn:hover:not(:disabled) {
  background: var(--surface-container);
  border-color: var(--muted);
}

.validate-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

/* ─── Error banner ────────────────────────────────────────────────────────── */

.editor-validation {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.5rem;
  padding: 0.6rem 1rem;
  border-bottom: 1px solid var(--outline-variant, var(--surface-container-highest));
  font-size: 0.8125rem;
}
.editor-validation.is-ok {
  background: rgba(34, 197, 94, 0.1);
  border-bottom-color: #2f6f4a;
  color: #6ee7a8;
}
.editor-validation.is-bad {
  background: rgba(240, 180, 41, 0.12);
  border-bottom-color: #6b5620;
  color: #f0c869;
}
.stale {
  color: var(--muted, var(--muted));
}
.validation-errors {
  flex-basis: 100%;
  margin: 0.25rem 0 0;
  padding-left: 1.1rem;
  font-size: 0.75rem;
}

.editor-drawing {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.6rem;
  padding: 0.55rem 1rem;
  border-bottom: 1px solid #2f6f4a;
  background: rgba(34, 197, 94, 0.1);
  color: #6ee7a8;
  font-size: 0.8125rem;
}
.draw-btn {
  padding: 0.25rem 0.7rem;
  border: 1px solid #2f6f4a;
  border-radius: 5px;
  background: rgba(34, 197, 94, 0.16);
  color: #6ee7a8;
  font-size: 0.75rem;
  font-weight: 600;
  cursor: pointer;
}
.draw-btn-quiet {
  border-color: var(--outline-variant, var(--surface-container-highest));
  background: transparent;
  color: var(--muted, var(--muted));
}
.draw-hint {
  color: var(--muted, var(--muted));
  font-size: 0.75rem;
}

.editor-action-banner {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  padding: 0.6rem 1rem;
  border-bottom: 1px solid #7a3838;
  background: rgba(239, 68, 68, 0.14);
  color: #fca5a5;
  font-size: 0.8125rem;
}
.dismiss-btn {
  margin-left: auto;
  border: none;
  background: none;
  color: inherit;
  font-size: 1.1rem;
  line-height: 1;
  cursor: pointer;
}
.editor-error-banner {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.75rem 1rem;
  background: rgba(239, 68, 68, 0.12);
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
  color: var(--muted);
}

.loading-spinner {
  width: 2rem;
  height: 2rem;
  border: 3px solid var(--surface-container-highest);
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
  color: var(--muted);
  text-align: center;
  padding: 2rem;
}

.empty-icon { font-size: 2.5rem; }

.empty-title {
  font-size: 1rem;
  font-weight: 600;
  color: #c5cde8;
  margin: 0;
}

.empty-subtitle {
  font-size: 0.875rem;
  color: var(--muted);
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

/* ─── Narrow screens: panels stack above the map instead of beside it ─────── */
@media (max-width: 768px) {
  .editor-header {
    flex-wrap: wrap;
    gap: 0.5rem;
  }
  .editor-body {
    flex-direction: column;
    overflow: visible;
  }
  .map-canvas {
    flex: 1 1 auto;
    min-height: 55vh;
  }
}

</style>
