/**
 * CourseMap — MapLibre GL JS map component for the geometry editor.
 *
 * Slice 2: MapLibre Integration for Portal
 *
 * Features:
 * - Vector layer rendering for each geometry type (tee, fairway, rough, green,
 *   bunker, water, penalty, ob, cart_path, landmark)
 * - Dark high-contrast style for portal readability
 * - Layer visibility toggles driven by layerStates prop
 * - Satellite imagery toggle
 * - Bounding-box fit on feature load
 * - Keyboard pan (arrow keys) and zoom (+/-)
 *
 * Dependencies:
 *   npm install maplibre-gl @types/maplibre-gl
 *
 * Style:
 *   Basemap: CartoDB Dark Matter (free, no API key)
 *   Satellite: ESRI World Imagery (free, no API key)
 */

<template>
  <div class="course-map-wrapper" ref="wrapperRef">
    <!-- Map container -->
    <div
      ref="mapRef"
      class="course-map"
      role="img"
      :aria-label="`Course map showing ${totalFeatureCount} geometry features`"
      tabindex="0"
      @keydown="handleKeydown"
    />

    <!-- Satellite toggle button -->
    <button
      class="sat-toggle"
      :class="{ active: satelliteEnabled }"
      :aria-label="satelliteEnabled ? 'Switch to dark map' : 'Switch to satellite imagery'"
      :title="satelliteEnabled ? 'Dark map' : 'Satellite'"
      @click="toggleSatellite"
    >
      <span aria-hidden="true" class="sat-icon">🛰</span>
      <span class="sat-label">{{ satelliteEnabled ? 'Dark' : 'Satellite' }}</span>
    </button>

    <!-- Attribution (MapLibre requirement) -->
    <div class="map-attribution">
      ©
      <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener">OpenStreetMap</a>
      contributors ©
      <a href="https://carto.com/attributions" target="_blank" rel="noopener">CARTO</a>
    </div>

    <!-- Loading overlay -->
    <div v-if="mapLoading" class="map-loading-overlay" aria-busy="true" aria-label="Loading map">
      <div class="map-spinner" aria-hidden="true" />
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, watch, onMounted, onUnmounted, computed } from 'vue';
import type {
  LayerType,
  LayerStateMap,
  LayerFeatureMap,
  GeometryFeature,
  GeoJSONGeometry,
  GeoCoordinate,
} from '@/types/geometry';

// ─── MapLibre dynamic import (SSR-safe) ──────────────────────────────────────

let maplibreModule: typeof import('maplibre-gl') | null = null;

async function getMapLibre(): Promise<typeof import('maplibre-gl')> {
  if (!maplibreModule) {
    maplibreModule = await import('maplibre-gl');
    // Import styles dynamically too
    await import('maplibre-gl/dist/maplibre-gl.css');
  }
  return maplibreModule;
}

// ─── Layer style definitions ─────────────────────────────────────────────────

interface LayerStyle {
  color: string;       // hex fill/line color
  opacity: number;     // fill opacity (polygons)
  weight: number;      // line weight (px)
  radius: number;      // point radius (px)
  dashArray?: string;  // line dash array
}

const LAYER_STYLES: Record<LayerType, LayerStyle> = {
  tee:       { color: '#FFD700', opacity: 1,   weight: 2, radius: 7 },
  fairway:   { color: '#22C55E', opacity: 0.35, weight: 1.5, radius: 0 },
  rough:     { color: '#15803D', opacity: 0.4,  weight: 1,   radius: 0 },
  green:     { color: '#86EFAC', opacity: 0.5,  weight: 1.5, radius: 0 },
  bunker:    { color: '#D4A76A', opacity: 0.7,  weight: 1,   radius: 0 },
  water:     { color: '#3B82F6', opacity: 0.45, weight: 1.5, radius: 0 },
  penalty:   { color: '#EF4444', opacity: 0.35, weight: 1.5, radius: 0 },
  ob:        { color: '#F97316', opacity: 1,   weight: 2.5, radius: 0, dashArray: '6,4' },
  cart_path: { color: '#9CA3AF', opacity: 1,   weight: 3,   radius: 0 },
  landmark:  { color: '#A855F7', opacity: 1,   weight: 2,   radius: 6 },
};

// ─── Props ───────────────────────────────────────────────────────────────────

const props = defineProps<{
  /** Features grouped by layer type to render on the map. */
  layerFeatures: LayerFeatureMap;
  /** Per-layer visibility and selection state. */
  layerStates: LayerStateMap;
  /** Initial map center [lng, lat] — defaults to Hanoi region. */
  initialCenter?: [number, number];
  /** Initial zoom level. */
  initialZoom?: number;
  /** Course ID for debugging/aria labels. */
  courseId?: number;
}>();

const emit = defineEmits<{
  /** Fired when the map finishes loading. */
  (e: 'map-ready'): void;
  /** Fired when the user clicks a feature. */
  (e: 'feature-click', feature: GeometryFeature): void;
  /** Fired on any map click — used by the draw-tools engine. */
  (e: 'map-click', coord: GeoCoordinate, zoom: number): void;
  /** Fired on map double-click — completes line/polygon drawing. */
  (e: 'map-dblclick', coord: GeoCoordinate, zoom: number): void;
}>();

// ─── Template refs ────────────────────────────────────────────────────────────

const mapRef = ref<HTMLDivElement | null>(null);
const wrapperRef = ref<HTMLDivElement | null>(null);

// ─── Map instance ────────────────────────────────────────────────────────────

// eslint-disable-next-line @typescript-eslint/no-explicit-any
let map: any = null;

const mapLoading = ref(true);
const satelliteEnabled = ref(false);

// ─── Computed ────────────────────────────────────────────────────────────────

const totalFeatureCount = computed(() =>
  Object.values(props.layerFeatures).reduce((sum, features) => sum + (features?.length ?? 0), 0)
);

// ─── Style URLs ──────────────────────────────────────────────────────────────

/** Dark basemap — CartoDB Dark Matter (free, no API key). */
const DARK_STYLE = 'https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json';

/** Satellite basemap — ESRI World Imagery. */
const SAT_STYLE = 'https://basemaps.cartocdn.com/gl/satellite-gl-style/style.json';

// ─── GeoJSON source management ────────────────────────────────────────────────

const SOURCE_PREFIX = 'src-';
const LAYER_PREFIX  = 'lyr-';

/**
 * Build a GeoJSON FeatureCollection from layer features.
 * Filters to valid geometries to avoid MapLibre errors.
 */
function buildFeatureCollection(features: GeometryFeature[]): GeoJSON.FeatureCollection {
  return {
    type: 'FeatureCollection',
    features: features.filter((f) => f?.geometry != null),
  };
}

/**
 * Add or replace a GeoJSON source for the given layer type.
 */
function upsertSource(mapInstance: import('maplibre-gl').Map, layerType: LayerType, features: GeometryFeature[]) {
  const sourceId = SOURCE_PREFIX + layerType;
  const fc = buildFeatureCollection(features);
  if (mapInstance.getSource(sourceId)) {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (mapInstance.getSource(sourceId) as any).setData(fc);
  } else {
    mapInstance.addSource(sourceId, { type: 'geojson', data: fc });
  }
}

/**
 * Add vector layers (fill/line/circle) for a given layer type.
 * Must be called after the source is added.
 */
function addLayers(mapInstance: import('maplibre-gl').Map, layerType: LayerType) {
  const sourceId = SOURCE_PREFIX + layerType;
  const style   = LAYER_STYLES[layerType];
  const geomType = getLayerGeomType(layerType);

  if (geomType === 'Polygon') {
    // Fill layer
    if (!mapInstance.getLayer(LAYER_PREFIX + layerType + '-fill')) {
      mapInstance.addLayer({
        id: LAYER_PREFIX + layerType + '-fill',
        type: 'fill',
        source: sourceId,
        paint: {
          'fill-color': style.color,
          'fill-opacity': style.opacity,
        },
      });
    }
    // Line layer
    if (!mapInstance.getLayer(LAYER_PREFIX + layerType + '-line')) {
      mapInstance.addLayer({
        id: LAYER_PREFIX + layerType + '-line',
        type: 'line',
        source: sourceId,
        paint: {
          'line-color': style.color,
          'line-width': style.weight,
          'line-dasharray': style.dashArray
            ? style.dashArray.split(',').map(Number)
            : undefined,
        },
      });
    }
  } else if (geomType === 'LineString') {
    if (!mapInstance.getLayer(LAYER_PREFIX + layerType + '-line')) {
      mapInstance.addLayer({
        id: LAYER_PREFIX + layerType + '-line',
        type: 'line',
        source: sourceId,
        paint: {
          'line-color': style.color,
          'line-width': style.weight,
          'line-dasharray': style.dashArray
            ? style.dashArray.split(',').map(Number)
            : undefined,
        },
      });
    }
  } else {
    // Point → circle
    if (!mapInstance.getLayer(LAYER_PREFIX + layerType + '-circle')) {
      mapInstance.addLayer({
        id: LAYER_PREFIX + layerType + '-circle',
        type: 'circle',
        source: sourceId,
        paint: {
          'circle-color': style.color,
          'circle-radius': style.radius,
          'circle-opacity': style.opacity,
          'circle-stroke-width': style.weight,
          'circle-stroke-color': '#ffffff',
        },
      });
    }
  }
}

/**
 * Returns the primary geometry type for a layer.
 * Mirrors LAYER_DEFAULT_GEOMETRY_TYPE from geometry.ts.
 */
function getLayerGeomType(layerType: LayerType): 'Point' | 'LineString' | 'Polygon' {
  switch (layerType) {
    case 'tee':
    case 'landmark':
      return 'Point';
    case 'cart_path':
    case 'ob':
      return 'LineString';
    default:
      return 'Polygon';
  }
}

const ALL_LAYER_TYPES: LayerType[] = [
  'tee', 'fairway', 'rough', 'green', 'bunker',
  'water', 'penalty', 'ob', 'cart_path', 'landmark',
];

// ─── Visibility management ───────────────────────────────────────────────────

/**
 * Sync layer visibility with the layerStates prop.
 * Sets paint opacity to 0 for hidden layers.
 */
function syncVisibility() {
  if (!map) return;
  for (const layerType of ALL_LAYER_TYPES) {
    const state = props.layerStates[layerType];
    const visible = state?.visible ?? true;
    const geomType = getLayerGeomType(layerType);
    const style = LAYER_STYLES[layerType];

    if (geomType === 'Polygon') {
      const fillId = LAYER_PREFIX + layerType + '-fill';
      const lineId = LAYER_PREFIX + layerType + '-line';
      if (map.getLayer(fillId)) {
        map.setPaintProperty(fillId, 'fill-opacity', visible ? style.opacity : 0);
      }
      if (map.getLayer(lineId)) {
        map.setPaintProperty(lineId, 'line-opacity', visible ? 1 : 0);
      }
    } else if (geomType === 'LineString') {
      const lineId = LAYER_PREFIX + layerType + '-line';
      if (map.getLayer(lineId)) {
        map.setPaintProperty(lineId, 'line-opacity', visible ? 1 : 0);
      }
    } else {
      const circleId = LAYER_PREFIX + layerType + '-circle';
      if (map.getLayer(circleId)) {
        map.setPaintProperty(circleId, 'circle-opacity', visible ? style.opacity : 0);
      }
    }
  }
}

// ─── Feature click handler ───────────────────────────────────────────────────

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function handleFeatureClick(e: any) {
  if (!e.features || e.features.length === 0) return;
  const feature = e.features[0] as GeometryFeature;
  emit('feature-click', feature);
}

// ─── Map initialisation ──────────────────────────────────────────────────────

async function initMap() {
  if (!mapRef.value) return;

  const ml = await getMapLibre();

  const center: [number, number] = props.initialCenter ?? [105.85, 21.01]; // Hanoi
  const zoom  = props.initialZoom ?? 15;

  map = new ml.Map({
    container: mapRef.value,
    style: satelliteEnabled.value ? SAT_STYLE : DARK_STYLE,
    center,
    zoom,
    attributionControl: false,
    antialias: true,
  });

  map.addControl(new ml.NavigationControl({ showCompass: true }), 'top-right');
  map.addControl(new ml.ScaleControl({ maxWidth: 160, unit: 'metric' }), 'bottom-left');

  map.on('load', () => {
    mapLoading.value = false;

    // Add all layers from initial features
    for (const layerType of ALL_LAYER_TYPES) {
      const features = props.layerFeatures[layerType] ?? [];
      if (features.length > 0) {
        upsertSource(map, layerType, features);
        addLayers(map, layerType);
      }
    }

    syncVisibility();
    fitToBounds();
    emit('map-ready');

    // General map clicks drive the draw-tools engine. Double-click zoom is
    // disabled so a double-click can complete a line/polygon instead.
    map.doubleClickZoom.disable();
    map.on('click', (e: { lngLat: { lng: number; lat: number } }) => {
      emit('map-click', [e.lngLat.lng, e.lngLat.lat], map!.getZoom());
    });
    map.on('dblclick', (e: { lngLat: { lng: number; lat: number } }) => {
      emit('map-dblclick', [e.lngLat.lng, e.lngLat.lat], map!.getZoom());
    });
  });

  // Feature click
  for (const layerType of ALL_LAYER_TYPES) {
    const geomType = getLayerGeomType(layerType);
    if (geomType === 'Polygon') {
      map.on('click', LAYER_PREFIX + layerType + '-fill', handleFeatureClick);
    } else if (geomType === 'LineString') {
      map.on('click', LAYER_PREFIX + layerType + '-line', handleFeatureClick);
    } else {
      map.on('click', LAYER_PREFIX + layerType + '-circle', handleFeatureClick);
    }
  }

  // Change cursor on hover
  for (const layerType of ALL_LAYER_TYPES) {
    const geomType = getLayerGeomType(layerType);
    if (geomType === 'Polygon') {
      map.on('mouseenter', LAYER_PREFIX + layerType + '-fill', () => { map.getCanvas().style.cursor = 'pointer'; });
      map.on('mouseleave', LAYER_PREFIX + layerType + '-fill', () => { map.getCanvas().style.cursor = ''; });
    } else if (geomType === 'LineString') {
      map.on('mouseenter', LAYER_PREFIX + layerType + '-line', () => { map.getCanvas().style.cursor = 'pointer'; });
      map.on('mouseleave', LAYER_PREFIX + layerType + '-line', () => { map.getCanvas().style.cursor = ''; });
    } else {
      map.on('mouseenter', LAYER_PREFIX + layerType + '-circle', () => { map.getCanvas().style.cursor = 'pointer'; });
      map.on('mouseleave', LAYER_PREFIX + layerType + '-circle', () => { map.getCanvas().style.cursor = ''; });
    }
  }
}

// ─── Fit to features ─────────────────────────────────────────────────────────

function fitToBounds() {
  if (!map) return;
  const allFeatures: GeometryFeature[] = [];
  for (const features of Object.values(props.layerFeatures)) {
    if (features) allFeatures.push(...features);
  }
  if (allFeatures.length === 0) return;

  const allCoords: [number, number][] = [];
  for (const feature of allFeatures) {
    collectCoordinates(feature.geometry, allCoords);
  }

  if (allCoords.length === 0) return;

  let minLng = Infinity, maxLng = -Infinity, minLat = Infinity, maxLat = -Infinity;
  for (const [lng, lat] of allCoords) {
    if (lng < minLng) minLng = lng;
    if (lng > maxLng) maxLng = lng;
    if (lat < minLat) minLat = lat;
    if (lat > maxLat) maxLat = lat;
  }

  // Add padding
  const pad = 0.002;
  map.fitBounds(
    [[minLng - pad, minLat - pad], [maxLng + pad, maxLat + pad]],
    { duration: 800, maxZoom: 18 }
  );
}

function collectCoordinates(geometry: GeoJSONGeometry, out: [number, number][]) {
  switch (geometry.type) {
    case 'Point':
      out.push(geometry.coordinates as [number, number]);
      break;
    case 'LineString':
      for (const coord of geometry.coordinates) out.push(coord as [number, number]);
      break;
    case 'Polygon':
      for (const ring of geometry.coordinates) {
        for (const coord of ring) out.push(coord as [number, number]);
      }
      break;
  }
}

// ─── Satellite toggle ────────────────────────────────────────────────────────

async function toggleSatellite() {
  satelliteEnabled.value = !satelliteEnabled.value;
  if (!map) return;

  const targetStyle = satelliteEnabled.value ? SAT_STYLE : DARK_STYLE;

  // MapLibre style switch — reload style then re-add sources/layers
  // We use setStyle with {diff: false} to force a full reload
  map.setStyle(targetStyle, { diff: false });

  map.once('styledata', () => {
    // After style reload, re-add all sources and layers
    for (const layerType of ALL_LAYER_TYPES) {
      const features = props.layerFeatures[layerType] ?? [];
      if (features.length > 0) {
        upsertSource(map, layerType, features);
        addLayers(map, layerType);
      }
    }
    syncVisibility();
  });
}

// ─── Keyboard navigation ──────────────────────────────────────────────────────

function handleKeydown(event: KeyboardEvent) {
  if (!map) return;
  const PAN_DISTANCE = 0.0005;

  switch (event.key) {
    case 'ArrowUp':
      event.preventDefault();
      map.panBy([0, -PAN_DISTANCE]);
      break;
    case 'ArrowDown':
      event.preventDefault();
      map.panBy([0, PAN_DISTANCE]);
      break;
    case 'ArrowLeft':
      event.preventDefault();
      map.panBy([-PAN_DISTANCE, 0]);
      break;
    case 'ArrowRight':
      event.preventDefault();
      map.panBy([PAN_DISTANCE, 0]);
      break;
    case '+':
    case '=':
      event.preventDefault();
      map.zoomIn();
      break;
    case '-':
      event.preventDefault();
      map.zoomOut();
      break;
  }
}

// ─── Watchers ────────────────────────────────────────────────────────────────

/**
 * When features change, update GeoJSON sources and re-add layers.
 */
watch(
  () => props.layerFeatures,
  async (newFeatures) => {
    if (!map || mapLoading.value) return;
    for (const layerType of ALL_LAYER_TYPES) {
      const features = newFeatures[layerType] ?? [];
      if (features.length > 0) {
        upsertSource(map, layerType, features);
        // Ensure layers exist (may have been removed by style reload)
        if (!map.getLayer(LAYER_PREFIX + layerType + '-fill') &&
            !map.getLayer(LAYER_PREFIX + layerType + '-line') &&
            !map.getLayer(LAYER_PREFIX + layerType + '-circle')) {
          addLayers(map, layerType);
        }
      }
    }
    syncVisibility();
    fitToBounds();
  },
  { deep: true }
);

/**
 * When visibility changes, update layer paint properties.
 */
watch(
  () => props.layerStates,
  () => {
    syncVisibility();
  },
  { deep: true }
);

// ─── Lifecycle ───────────────────────────────────────────────────────────────

onMounted(() => {
  initMap();
});

onUnmounted(() => {
  if (map) {
    map.remove();
    map = null;
  }
});

// ─── Expose for parent ───────────────────────────────────────────────────────

defineExpose({
  /** Trigger a map resize (call after DOM changes). */
  resize() { map?.resize(); },
  /** Get the underlying MapLibre instance. */
  getMap() { return map; },
});
</script>

<style scoped>
.course-map-wrapper {
  position: relative;
  width: 100%;
  height: 100%;
  background: #0d1117;
}

.course-map {
  width: 100%;
  height: 100%;
  outline: none;
}

.course-map:focus-visible {
  outline: 3px solid rgba(59, 130, 246, 0.5);
  outline-offset: -3px;
}

/* ─── Satellite toggle ─────────────────────────────────────────────────────── */

.sat-toggle {
  position: absolute;
  top: 0.75rem;
  left: 0.75rem;
  z-index: 10;
  display: flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.4rem 0.75rem;
  background: rgba(13, 17, 23, 0.85);
  color: #d1d5db;
  border: 1.5px solid rgba(255, 255, 255, 0.15);
  border-radius: 8px;
  cursor: pointer;
  font-size: 0.75rem;
  font-weight: 600;
  font-family: system-ui, -apple-system, sans-serif;
  backdrop-filter: blur(6px);
  transition: background 0.12s, border-color 0.12s, color 0.12s;
  min-height: 44px;
  outline: none;
}

.sat-toggle:focus-visible {
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.5);
  border-color: #3b82f6;
}

.sat-toggle:hover {
  background: rgba(30, 40, 55, 0.9);
  border-color: rgba(255, 255, 255, 0.3);
}

.sat-toggle.active {
  color: #93c5fd;
  border-color: rgba(59, 130, 246, 0.5);
}

.sat-icon {
  font-size: 0.875rem;
  line-height: 1;
}

.sat-label {
  line-height: 1;
}

/* ─── Attribution ──────────────────────────────────────────────────────────── */

.map-attribution {
  position: absolute;
  bottom: 0.25rem;
  right: 0.25rem;
  z-index: 10;
  font-size: 0.625rem;
  color: rgba(255, 255, 255, 0.4);
  font-family: system-ui, -apple-system, sans-serif;
}

.map-attribution a {
  color: rgba(255, 255, 255, 0.5);
  text-decoration: none;
}

.map-attribution a:hover {
  text-decoration: underline;
}

/* ─── Loading overlay ─────────────────────────────────────────────────────── */

.map-loading-overlay {
  position: absolute;
  inset: 0;
  z-index: 20;
  background: rgba(13, 17, 23, 0.7);
  display: flex;
  align-items: center;
  justify-content: center;
  backdrop-filter: blur(2px);
}

.map-spinner {
  width: 2.5rem;
  height: 2.5rem;
  border: 3px solid rgba(255, 255, 255, 0.15);
  border-top-color: #3b82f6;
  border-radius: 50%;
  animation: map-spin 0.75s linear infinite;
}

@keyframes map-spin {
  to { transform: rotate(360deg); }
}
</style>
