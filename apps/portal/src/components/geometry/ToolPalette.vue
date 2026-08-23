<template>
  <aside
    class="tool-palette"
    role="toolbar"
    aria-label="Công cụ vẽ hình học"
    tabindex="0"
    @keydown="handleKeydown"
  >
    <div class="palette-section">
      <span class="section-label" aria-hidden="true">Công cụ</span>

      <!-- Select / Edit tool -->
      <button
        class="tool-btn"
        :class="{ active: activeTool === 'select' }"
        :aria-pressed="activeTool === 'select'"
        aria-label="Chọn và sửa đối tượng"
        title="Chọn (S)"
        @click="emit('tool-change', 'select')"
      >
        <span aria-hidden="true" class="tool-icon">⬚</span>
        <span class="tool-label">Chọn</span>
      </button>

      <!-- Point tool -->
      <button
        class="tool-btn"
        :class="{ active: activeTool === 'point' }"
        :aria-pressed="activeTool === 'point'"
        aria-label="Vẽ điểm — cho lớp Tee và Mốc định vị"
        title="Điểm (P)"
        @click="emit('tool-change', 'point')"
      >
        <span aria-hidden="true" class="tool-icon">●</span>
        <span class="tool-label">Điểm</span>
      </button>

      <!-- Line tool -->
      <button
        class="tool-btn"
        :class="{ active: activeTool === 'line' }"
        :aria-pressed="activeTool === 'line'"
        aria-label="Vẽ đường — cho lớp Đường xe điện và OB"
        title="Đường (L)"
        @click="emit('tool-change', 'line')"
      >
        <span aria-hidden="true" class="tool-icon">╱</span>
        <span class="tool-label">Đường</span>
      </button>

      <!-- Polygon tool -->
      <button
        class="tool-btn"
        :class="{ active: activeTool === 'polygon' }"
        :aria-pressed="activeTool === 'polygon'"
        aria-label="Vẽ vùng — dùng cho Fairway, Rough, Green, Bunker, Nước, Khu phạt"
        title="Vùng (G)"
        @click="emit('tool-change', 'polygon')"
      >
        <span aria-hidden="true" class="tool-icon">⬡</span>
        <span class="tool-label">Vùng</span>
      </button>
    </div>

    <div class="palette-divider" role="separator" aria-hidden="true"></div>

    <!-- Undo / Redo -->
    <div class="palette-section">
      <span class="section-label" aria-hidden="true">Lịch sử</span>

      <button
        class="tool-btn"
        :disabled="!canUndo"
        aria-label="Hoàn tác thay đổi cuối"
        title="Hoàn tác (Ctrl+Z)"
        @click="emit('undo')"
      >
        <span aria-hidden="true" class="tool-icon">↩</span>
        <span class="tool-label">Hoàn tác</span>
      </button>

      <button
        class="tool-btn"
        :disabled="!canRedo"
        aria-label="Làm lại thay đổi vừa hoàn tác"
        title="Làm lại (Ctrl+Shift+Z)"
        @click="emit('redo')"
      >
        <span aria-hidden="true" class="tool-icon">↪</span>
        <span class="tool-label">Làm lại</span>
      </button>
    </div>

    <div class="palette-divider" role="separator" aria-hidden="true"></div>

    <!-- Active layer indicator -->
    <div class="palette-section">
      <span class="section-label" aria-hidden="true">Lớp đang vẽ</span>
      <span class="active-layer-badge">{{ activeLayerLabel }}</span>
    </div>
  </aside>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { EditorTool, LayerType } from '@/types/geometry';
import { LAYER_TYPE_LABELS } from '@/types/geometry';

const props = defineProps<{
  /** Currently active drawing/editing tool. */
  activeTool: EditorTool;
  /** Currently selected editable layer type. */
  activeLayer: LayerType;
  /** Whether undo is available. */
  canUndo: boolean;
  /** Whether redo is available. */
  canRedo: boolean;
}>();

const emit = defineEmits<{
  /** Fired when the user selects a different tool. */
  (e: 'tool-change', tool: EditorTool): void;
  /** Fired when the user clicks the Undo button. */
  (e: 'undo'): void;
  /** Fired when the user clicks the Redo button. */
  (e: 'redo'): void;
}>();

const activeLayerLabel = computed(() => LAYER_TYPE_LABELS[props.activeLayer] ?? props.activeLayer);

// Keyboard shortcut handler — attached to the toolbar
function handleKeydown(event: KeyboardEvent) {
  const map: Record<string, EditorTool> = {
    s: 'select',
    p: 'point',
    l: 'line',
    g: 'polygon',
  };
  const tool = map[event.key.toLowerCase()];
  if (tool && !event.ctrlKey && !event.metaKey && !event.altKey) {
    emit('tool-change', tool);
  }
}
</script>

<style scoped>
.tool-palette {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  padding: 0.75rem 0.5rem;
  background: var(--surface-container);
  border-right: 1px solid var(--surface-container-highest);
  width: 5.5rem;
  align-items: center;
  flex-shrink: 0;
}

.palette-section {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.375rem;
  width: 100%;
}

.section-label {
  font-size: 0.625rem;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--muted);
  font-weight: 600;
  align-self: flex-start;
  padding-left: 0.25rem;
}

.palette-divider {
  width: 80%;
  height: 1px;
  background: var(--surface-container-highest);
  margin: 0.25rem 0;
}

.tool-btn {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.2rem;
  width: 3.25rem;
  height: 3.25rem;
  border-radius: 8px;
  border: 1.5px solid var(--surface-container-highest);
  background: var(--surface-container-lowest, var(--surface-container-low));
  cursor: pointer;
  transition: background 0.12s, border-color 0.12s, box-shadow 0.12s;
  color: #c5cde8;
  font-size: 0.6875rem;
  font-weight: 500;
  /* Accessibility: visible focus ring */
  outline: none;
}

.tool-btn:focus-visible {
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.5);
  border-color: #3b82f6;
}

.tool-btn:hover:not(:disabled) {
  background: var(--surface-container-high);
  border-color: var(--muted);
}

.tool-btn:active:not(:disabled) {
  background: var(--surface-container-highest);
}

.tool-btn.active {
  background: var(--surface-container-high);
  border-color: #3b82f6;
  color: var(--secondary-container);
}

.tool-btn:disabled {
  opacity: 0.35;
  cursor: not-allowed;
}

.tool-icon {
  font-size: 1.25rem;
  line-height: 1;
}

.tool-label {
  font-size: 0.625rem;
  line-height: 1;
  color: inherit;
}

/* Active layer badge */
.active-layer-badge {
  font-size: 0.6875rem;
  font-weight: 600;
  color: var(--secondary-container);
  background: var(--surface-container-highest);
  border: 1px solid var(--surface-container-highest);
  border-radius: 4px;
  padding: 0.2rem 0.4rem;
  text-align: center;
  word-break: break-word;
  max-width: 4.5rem;
}

@media (max-width: 768px) {
  .tool-palette {
    flex-direction: row;
    flex-wrap: wrap;
    width: 100%;
    padding: 0.5rem;
    border-right: 0;
    border-bottom: 1px solid var(--surface-container-highest);
  }
  .palette-section {
    flex-direction: row;
    flex-wrap: wrap;
    width: auto;
  }
  .section-label {
    align-self: center;
    padding-left: 0;
  }
  .palette-divider {
    width: 1px;
    height: 2.5rem;
    margin: 0 0.25rem;
  }
}

</style>
