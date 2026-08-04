<template>
  <aside
    class="layer-panel"
    role="region"
    aria-label="Geometry layers"
  >
    <div class="panel-header">
      <h2 class="panel-title">Layers</h2>
      <span class="feature-count" aria-live="polite">
        {{ totalFeatureCount }} feature{{ totalFeatureCount !== 1 ? 's' : '' }}
      </span>
    </div>

    <ul class="layer-list" role="list">
      <li
        v-for="layerType in orderedLayerTypes"
        :key="layerType"
        class="layer-item"
        :class="{
          active: activeLayer === layerType,
          hidden: !layerStates[layerType]?.visible,
        }"
      >
        <!-- Visibility toggle -->
        <button
          class="visibility-btn"
          :aria-label="`${layerLabel(layerType)}: ${layerStates[layerType]?.visible ? 'hide' : 'show'}`"
          :title="`${layerLabel(layerType)} visibility: ${layerStates[layerType]?.visible ? 'hide' : 'show'}`"
          :aria-pressed="layerStates[layerType]?.visible ?? true"
          @click="emit('layer-visibility-toggle', layerType)"
        >
          <span aria-hidden="true" class="visibility-icon">
            {{ layerStates[layerType]?.visible ? '👁' : '🙈' }}
          </span>
        </button>

        <!-- Layer selection -->
        <button
          class="layer-name-btn"
          :aria-current="activeLayer === layerType ? 'true' : undefined"
          :aria-label="`Select ${layerLabel(layerType)} layer (${featureCount(layerType)} features)`"
          @click="emit('layer-select', layerType)"
        >
          <span class="layer-label">{{ layerLabel(layerType) }}</span>
          <span class="layer-count" aria-hidden="true">
            {{ featureCount(layerType) }}
          </span>
        </button>

        <!-- Geometry type indicator -->
        <span class="geometry-type-badge" :title="`Geometry: ${geometryTypeLabel(layerType)}`">
          {{ geometryTypeIcon(layerType) }}
        </span>
      </li>
    </ul>
  </aside>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { LayerType, LayerStateMap, LayerFeatureMap } from '@/types/geometry';
import {
  LAYER_TYPE_LABELS,
  LAYER_DEFAULT_GEOMETRY_TYPE,
  LAYER_SUPPORTS_POINT,
  LAYER_SUPPORTS_LINE,
  LAYER_SUPPORTS_POLYGON,
} from '@/types/geometry';

const ALL_LAYER_TYPES: LayerType[] = [
  'tee',
  'fairway',
  'rough',
  'green',
  'bunker',
  'water',
  'penalty',
  'ob',
  'cart_path',
  'landmark',
];

const props = defineProps<{
  /** Per-layer visibility and selection state. */
  layerStates: LayerStateMap;
  /** Currently selected editable layer type. */
  activeLayer: LayerType;
  /** Features grouped by layer type. */
  layerFeatures: LayerFeatureMap;
}>();

const emit = defineEmits<{
  (e: 'layer-visibility-toggle', layerType: LayerType): void;
  (e: 'layer-select', layerType: LayerType): void;
}>();

const orderedLayerTypes = ALL_LAYER_TYPES;

const totalFeatureCount = computed(() =>
  Object.values(props.layerFeatures).reduce((sum, features) => sum + (features?.length ?? 0), 0)
);

function layerLabel(type: LayerType): string {
  return LAYER_TYPE_LABELS[type] ?? type;
}

function featureCount(type: LayerType): number {
  return props.layerFeatures[type]?.length ?? 0;
}

function geometryTypeIcon(type: LayerType): string {
  const geomType = LAYER_DEFAULT_GEOMETRY_TYPE[type];
  switch (geomType) {
    case 'Point':       return '●';
    case 'LineString':  return '╱';
    case 'Polygon':     return '⬡';
    default:            return '?';
  }
}

function geometryTypeLabel(type: LayerType): string {
  const supports: string[] = [];
  if (LAYER_SUPPORTS_POINT[type])  supports.push('Point');
  if (LAYER_SUPPORTS_LINE[type])   supports.push('Line');
  if (LAYER_SUPPORTS_POLYGON[type]) supports.push('Polygon');
  return supports.join(', ');
}
</script>

<style scoped>
.layer-panel {
  display: flex;
  flex-direction: column;
  width: 11rem;
  flex-shrink: 0;
  background: #ffffff;
  border-right: 1px solid #e5e7eb;
  overflow-y: auto;
}

.panel-header {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  padding: 0.75rem 0.75rem 0.5rem;
  border-bottom: 1px solid #f3f4f6;
}

.panel-title {
  font-size: 0.875rem;
  font-weight: 700;
  color: #111827;
  margin: 0;
}

.feature-count {
  font-size: 0.6875rem;
  color: #9ca3af;
}

.layer-list {
  list-style: none;
  margin: 0;
  padding: 0.5rem 0;
  display: flex;
  flex-direction: column;
}

.layer-item {
  display: flex;
  align-items: center;
  gap: 0.25rem;
  padding: 0.3rem 0.5rem;
  border-radius: 6px;
  margin: 0 0.375rem;
  transition: background 0.12s;
}

.layer-item:hover {
  background: #f9fafb;
}

.layer-item.active {
  background: #eff6ff;
}

.layer-item.hidden {
  opacity: 0.55;
}

.visibility-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 1.75rem;
  height: 1.75rem;
  border-radius: 4px;
  border: none;
  background: transparent;
  cursor: pointer;
  font-size: 0.875rem;
  flex-shrink: 0;
  transition: background 0.12s;
  outline: none;
}

.visibility-btn:focus-visible {
  box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.5);
}

.visibility-btn:hover {
  background: #f3f4f6;
}

.visibility-icon {
  font-size: 0.875rem;
  line-height: 1;
}

.layer-name-btn {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.25rem;
  background: none;
  border: none;
  cursor: pointer;
  padding: 0.2rem 0.25rem;
  border-radius: 4px;
  text-align: left;
  min-height: 44px; /* Touch target */
  outline: none;
}

.layer-name-btn:focus-visible {
  box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.5);
}

.layer-label {
  font-size: 0.8125rem;
  color: #374151;
  font-weight: 500;
}

.layer-item.active .layer-label {
  color: #1d4ed8;
  font-weight: 600;
}

.layer-count {
  font-size: 0.6875rem;
  color: #9ca3af;
  background: #f3f4f6;
  border-radius: 9999px;
  padding: 0.1rem 0.4rem;
  min-width: 1.25rem;
  text-align: center;
  flex-shrink: 0;
}

.layer-item.active .layer-count {
  background: #dbeafe;
  color: #1d4ed8;
}

.geometry-type-badge {
  font-size: 0.875rem;
  color: #9ca3af;
  flex-shrink: 0;
  width: 1rem;
  text-align: center;
}
</style>
