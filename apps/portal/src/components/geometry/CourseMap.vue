<template>
  <div class="course-map-wrapper" ref="wrapperRef">
    <!-- Map container -->
    <div
      ref="mapRef"
      class="course-map"
      role="img"
      :aria-label="`Bản đồ sân, đang hiển thị ${totalFeatureCount} đối tượng hình học`"
      tabindex="0"
      @keydown="handleKeydown"
    />

    <!-- Satellite toggle button -->
    <button
      class="sat-toggle"
      :class="{ active: satelliteEnabled }"
      :disabled="!satelliteAvailable && !satelliteEnabled"
      :title="satelliteAvailable
        ? (satelliteEnabled ? 'Bản đồ tối' : 'Ảnh vệ tinh')
        : 'Chưa cấu hình nguồn ảnh vệ tinh'"
      :aria-label="satelliteAvailable
        ? (satelliteEnabled ? 'Chuyển sang bản đồ tối' : 'Chuyển sang ảnh vệ tinh')
        : 'Chưa cấu hình nguồn ảnh vệ tinh'"
      @click="toggleSatellite"
    >
      <span aria-hidden="true" class="sat-icon">🛰</span>
      <span class="sat-label">{{ satelliteEnabled ? 'Bản đồ tối' : 'Ảnh vệ tinh' }}</span>
    </button>

    <!-- Refitting is useful; doing it uninvited is not. -->
    <button
      type="button"
      class="fit-toggle"
      title="Thu về vừa toàn bộ hình đã vẽ"
      aria-label="Thu về vừa toàn bộ hình đã vẽ"
      :disabled="!hasAnyFeature()"
      @click="fitToBounds()"
    >
      <span aria-hidden="true">⤢</span>
      <span class="sat-label">Vừa khung</span>
    </button>

    <!-- Delete selected feature (Story 8-2) -->
    <button
      v-if="activeTool === 'select' && selectedFeatureId != null"
      class="delete-selected-btn"
      aria-label="Xoá đối tượng đang chọn"
      title="Xoá đối tượng đang chọn (Del)"
      @click="handleDeleteSelected"
    >
      <span aria-hidden="true">🗑</span>
      <span class="delete-label">Xoá đối tượng</span>
    </button>

    <!-- Credit whatever is actually on screen.
         This used to name OpenStreetMap and CARTO in fixed markup. CARTO's
         tiles were removed and the imagery comes from whichever provider the
         deployment configures, so the credit named a provider we no longer
         call and omitted the one we do. Attribution is a licence term, not
         decoration: it now reads from the same config the tiles come from. -->
    <div class="map-attribution" v-if="activeAttribution">{{ activeAttribution }}</div>

    <!-- The basemap did not arrive. Drawing still works over the blank
         canvas, which is worth saying rather than leaving a spinner up. -->
    <div v-if="basemapError" class="map-basemap-error" role="status">{{ basemapError }}</div>

    <!-- Loading overlay -->
    <div v-if="mapLoading" class="map-loading-overlay" aria-busy="true" aria-label="Đang tải bản đồ">
      <div class="map-spinner" aria-hidden="true" />
    </div>
  </div>
</template>

<script setup lang="ts">
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
 *   Both basemaps come from /config/basemap. Nothing is hardcoded here — the
 *   CartoDB Dark Matter URL that used to be started answering 404 mid-session
 *   and could not be changed without a release.
 */

import { markRaw, ref, watch, onMounted, onUnmounted, computed } from 'vue';
import {
  baseStyleFrom,
  blankDarkStyle,
  fetchBasemapConfig,
  rasterStyleFrom,
  type RasterStyle,
} from '@/api/basemap';
import { visibleTimeout, type VisibleTimeout } from '@/lib/visible-timeout';
import type {
  LayerType,
  LayerStateMap,
  LayerFeatureMap,
  GeometryFeature,
  GeoJSONGeometry,
  GeoCoordinate,
  EditorTool,
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
  /**
   * Where to open, as [lng, lat].
   *
   * Required in practice. This used to fall back to Hanoi, and because a
   * course with no geometry yet also has nothing to fit the view to, the
   * editor opened 1,600 km from a course in Đồng Nai — over a park — with the
   * satellite imagery pointed at the wrong city. For a tool whose whole job is
   * tracing a fairway off an aerial photo, that is the difference between
   * usable and not.
   */
  initialCenter?: [number, number];
  /** Initial zoom level. */
  initialZoom?: number;
  /** Course ID for debugging/aria labels. */
  courseId?: number;
  /** Active editing tool — selection/vertex editing is only active for `select`. */
  activeTool?: EditorTool;
  /** Id of the currently selected feature (drives vertex handle rendering). */
  selectedFeatureId?: string | number | null;
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
  /** Fired when a feature is selected in select mode. */
  (e: 'feature-select', payload: { id: string | number; layerType: LayerType }): void;
  /** Fired when the user clicks empty map area in select mode. */
  (e: 'feature-deselect'): void;
  /** Fired when a vertex handle drag completes. */
  (e: 'vertex-move', payload: { featureId: string | number; layerType: LayerType; vertexIndex: number; coord: GeoCoordinate; zoom: number }): void;
  /** Fired when the selected feature should be deleted (delete button). */
  (e: 'feature-delete', payload: { featureId: string | number; layerType: LayerType }): void;
}>();

// ─── Template refs ────────────────────────────────────────────────────────────

const mapRef = ref<HTMLDivElement | null>(null);
const wrapperRef = ref<HTMLDivElement | null>(null);

// ─── Map instance ────────────────────────────────────────────────────────────

// eslint-disable-next-line @typescript-eslint/no-explicit-any
let map: any = null;

const mapLoading = ref(true);

/** Backstop for a load that never resolves; cancelled once one does. */
let settleTimer: VisibleTimeout | null = null;

/** Why there is no basemap, when there is no basemap. */
const basemapError = ref<string | null>(null);
const satelliteEnabled = ref(false);

// ─── Computed ────────────────────────────────────────────────────────────────

const totalFeatureCount = computed(() =>
  Object.values(props.layerFeatures).reduce((sum, features) => sum + (features?.length ?? 0), 0)
);

// ─── Style URLs ──────────────────────────────────────────────────────────────

/**
 * The plain basemap, from configuration.
 *
 * Was CARTO's dark-matter style, hardcoded. CARTO stopped serving it during a
 * working session: the map never fired `load`, the spinner never cleared, and
 * there was no way to point the editor somewhere else without a release. Now
 * it comes from /config/basemap like the imagery does, and where nothing is
 * configured the client draws its own canvas and calls nobody.
 */
// markRaw because MapLibre keeps this object and mutates it internally, and
// there is nothing for Vue to gain by tracking a style it does not render.
// Wrapping it in a reactive proxy costs work on every internal write.
//
// It is not a correctness fix, despite an earlier comment here claiming it
// stopped `load` from firing. It does not: a map whose `load` never arrives is
// a map whose render loop is not running, because MapLibre announces the load
// from that loop and browsers suspend requestAnimationFrame for a page that is
// not on screen. See lib/visible-timeout.ts, which is the actual handling.
const baseStyle = ref<Record<string, unknown>>(markRaw(blankDarkStyle()));

/**
 * Satellite basemap, from whatever provider this deployment is configured with.
 *
 * This used to be `https://basemaps.cartocdn.com/gl/satellite-gl-style/
 * style.json`, hardcoded. CARTO has removed that style: the URL answers 404. So
 * the Satellite button switched to a style that never loaded, and the one job
 * this editor exists for — tracing a fairway off an aerial photo — could not be
 * done at all.
 *
 * Null until the config arrives, and null for good on a deployment with no
 * imagery. The button says so instead of switching to a blank canvas.
 */
const satStyle = ref<RasterStyle>(null);
const satelliteAvailable = computed(() => satStyle.value !== null);

/** Attribution for the basemap currently drawn, straight from its config. */
const satelliteAttribution = ref('');
const baseAttribution = ref('');
const activeAttribution = computed(() =>
  satelliteEnabled.value ? satelliteAttribution.value : baseAttribution.value
);

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
    features: features
      .filter((f) => f?.geometry != null)
      .map((f) => ({
        type: 'Feature',
        // Mirror the feature id into properties (`__fid`) so map click hit-tests
        // can resolve back to the original feature object regardless of the id
        // type (MapLibre only surfaces numeric top-level ids reliably).
        id: typeof f.id === 'number' ? f.id : undefined,
        geometry: f.geometry as GeoJSON.Geometry,
        properties: { ...f.properties, __fid: f.id ?? null },
      })),
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
        paint: linePaint(style),
      });
    }
  } else if (geomType === 'LineString') {
    if (!mapInstance.getLayer(LAYER_PREFIX + layerType + '-line')) {
      mapInstance.addLayer({
        id: LAYER_PREFIX + layerType + '-line',
        type: 'line',
        source: sourceId,
        paint: linePaint(style),
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

// ─── Selection + vertex editing (Story 8-2) ──────────────────────────────────

const HANDLE_SOURCE = 'src-vertex-handles';
const HANDLE_LAYER  = 'lyr-vertex-handles';

/** Ids of the feature layers eligible for selection hit-testing. */
function editableLayerIds(): string[] {
  const ids: string[] = [];
  for (const layerType of ALL_LAYER_TYPES) {
    const geomType = getLayerGeomType(layerType);
    if (geomType === 'Polygon') ids.push(LAYER_PREFIX + layerType + '-fill');
    else if (geomType === 'LineString') ids.push(LAYER_PREFIX + layerType + '-line');
    else ids.push(LAYER_PREFIX + layerType + '-circle');
  }
  return ids.filter((id) => map?.getLayer(id));
}

/** Resolve the currently selected feature from props by matching its id. */
function findSelectedFeature(): GeometryFeature | null {
  if (props.selectedFeatureId == null) return null;
  for (const features of Object.values(props.layerFeatures)) {
    const match = features?.find((f) => f.id === props.selectedFeatureId);
    if (match) return match;
  }
  return null;
}

/**
 * Build the draggable vertex handle features for a selected feature.
 * For polygons the closing vertex is skipped (it is kept in sync with vertex 0
 * by moveVertex), so each rendered handle maps to a distinct editable index.
 */
function buildVertexHandles(feature: GeometryFeature): GeoJSON.Feature[] {
  const handles: GeoJSON.Feature[] = [];
  const push = (coord: GeoCoordinate, index: number) => {
    handles.push({
      type: 'Feature',
      geometry: { type: 'Point', coordinates: coord },
      properties: { vertexIndex: index },
    });
  };

  const geom = feature.geometry;
  if (geom.type === 'Point') {
    push(geom.coordinates as GeoCoordinate, 0);
  } else if (geom.type === 'LineString') {
    geom.coordinates.forEach((c, i) => push(c as GeoCoordinate, i));
  } else if (geom.type === 'Polygon') {
    const ring = geom.coordinates[0] ?? [];
    // Skip the final closing vertex (duplicate of index 0).
    for (let i = 0; i < ring.length - 1; i++) {
      push(ring[i] as GeoCoordinate, i);
    }
  }
  return handles;
}

/** Ensure the handle source + circle layer exist (re-added after style reloads). */
function ensureHandleLayer() {
  if (!map) return;
  if (!map.getSource(HANDLE_SOURCE)) {
    map.addSource(HANDLE_SOURCE, {
      type: 'geojson',
      data: { type: 'FeatureCollection', features: [] },
    });
  }
  if (!map.getLayer(HANDLE_LAYER)) {
    map.addLayer({
      id: HANDLE_LAYER,
      type: 'circle',
      source: HANDLE_SOURCE,
      paint: {
        'circle-radius': 6,
        'circle-color': '#ffffff',
        'circle-stroke-width': 2.5,
        'circle-stroke-color': '#3b82f6',
      },
    });
    // Grab cursor on hover.
    map.on('mouseenter', HANDLE_LAYER, () => {
      if (!draggingVertexIndex && map) map.getCanvas().style.cursor = 'grab';
    });
    map.on('mouseleave', HANDLE_LAYER, () => {
      if (!draggingVertexIndex && map) map.getCanvas().style.cursor = '';
    });
    map.on('mousedown', HANDLE_LAYER, onHandleMouseDown);
  }
}

/** Last handle FeatureCollection pushed to the source (for live drag preview). */
let currentHandleData: GeoJSON.FeatureCollection = { type: 'FeatureCollection', features: [] };

/** Refresh the handle geometries for the current selection. */
function syncVertexHandles() {
  if (!map) return;
  ensureHandleLayer();
  const source = map.getSource(HANDLE_SOURCE);
  if (!source) return;
  const feature = findSelectedFeature();
  currentHandleData = {
    type: 'FeatureCollection',
    features: feature ? buildVertexHandles(feature) : [],
  };
  source.setData(currentHandleData);
}

// ─── Vertex drag ─────────────────────────────────────────────────────────────

let draggingVertexIndex: number | null = null;

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function onHandleMouseDown(e: any) {
  if (props.activeTool !== 'select') return;
  if (!e.features || e.features.length === 0) return;
  const idx = e.features[0].properties?.vertexIndex;
  if (idx == null) return;

  e.preventDefault(); // stop the map from panning
  draggingVertexIndex = Number(idx);
  map.dragPan.disable();
  map.getCanvas().style.cursor = 'grabbing';
  map.on('mousemove', onHandleMouseMove);
  map.once('mouseup', onHandleMouseUp);
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function onHandleMouseMove(e: any) {
  if (draggingVertexIndex == null || !map) return;
  const source = map.getSource(HANDLE_SOURCE);
  if (!source) return;
  // Live preview: move just the dragged handle.
  const moved: GeoJSON.FeatureCollection = {
    type: 'FeatureCollection',
    features: currentHandleData.features.map((f) =>
      f.properties?.vertexIndex === draggingVertexIndex
        ? { ...f, geometry: { type: 'Point', coordinates: [e.lngLat.lng, e.lngLat.lat] } }
        : f
    ),
  };
  source.setData(moved);
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function onHandleMouseUp(e: any) {
  if (!map) return;
  map.off('mousemove', onHandleMouseMove);
  map.dragPan.enable();
  map.getCanvas().style.cursor = '';

  const feature = findSelectedFeature();
  if (feature && feature.id != null && draggingVertexIndex != null) {
    emit('vertex-move', {
      featureId: feature.id,
      layerType: feature.properties.layerType,
      vertexIndex: draggingVertexIndex,
      coord: [e.lngLat.lng, e.lngLat.lat],
      zoom: map.getZoom(),
    });
  }
  draggingVertexIndex = null;
}

// ─── Selection click ─────────────────────────────────────────────────────────

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function handleSelectClick(e: any) {
  if (!map) return;
  const layers = editableLayerIds();
  if (layers.length === 0) {
    emit('feature-deselect');
    return;
  }
  const hits = map.queryRenderedFeatures(e.point, { layers });
  const hit = hits.find(
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (f: any) => f.properties && f.properties.__fid != null
  );
  if (hit) {
    emit('feature-select', {
      id: hit.properties.__fid,
      layerType: hit.properties.layerType as LayerType,
    });
  } else {
    emit('feature-deselect');
  }
}

/** Delete button overlay handler. */
function handleDeleteSelected() {
  const feature = findSelectedFeature();
  if (feature && feature.id != null) {
    emit('feature-delete', {
      featureId: feature.id,
      layerType: feature.properties.layerType,
    });
  }
}

// ─── Map initialisation ──────────────────────────────────────────────────────

async function initMap() {
  if (!mapRef.value) return;

  const ml = await getMapLibre();

  // Only reached when the course itself has no location on record; the page
  // says so rather than pretending this is the course.
  const center: [number, number] = props.initialCenter ?? [106.0, 16.0];
  const zoom = props.initialZoom ?? (props.initialCenter ? 16 : 5);

  map = new ml.Map({
    container: mapRef.value,
    style: (satelliteEnabled.value && satStyle.value
      ? satStyle.value
      : baseStyle.value) as never,
    center,
    zoom,
    attributionControl: false,
    antialias: true,
  });

  map.addControl(new ml.NavigationControl({ showCompass: true }), 'top-right');
  map.addControl(new ml.ScaleControl({ maxWidth: 160, unit: 'metric' }), 'bottom-left');

  // Interaction is wired before, and independently of, the basemap loading.
  //
  // All of this used to live inside the `load` handler. When that event does
  // not arrive — a blocked tile host, an offline laptop in a club house — the
  // spinner never clears *and* no click handler is ever attached, so the
  // editor becomes a dead rectangle with no explanation. Drawing does not need
  // the basemap; it needs the map object, which exists now.
  map.doubleClickZoom.disable();
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  map.on('click', (e: any) => {
    emit('map-click', [e.lngLat.lng, e.lngLat.lat], map!.getZoom());
    // In select mode a click either picks the feature under the cursor or
    // clears the selection when it lands on empty map.
    if (props.activeTool === 'select') {
      handleSelectClick(e);
    }
  });
  map.on('dblclick', (e: { lngLat: { lng: number; lat: number } }) => {
    emit('map-dblclick', [e.lngLat.lng, e.lngLat.lat], map!.getZoom());
  });

  // A style that fails is worth saying out loud rather than spinning forever.
  map.on('error', (e: { error?: { message?: string } }) => {
    const message = e?.error?.message ?? 'Không tải được nền bản đồ';
    if (mapLoading.value) {
      mapLoading.value = false;
      basemapError.value = message;
    }
    console.warn('[CourseMap]', message);
  });

  // And a style that neither loads nor errors — a request left hanging — must
  // not hold the editor hostage either. Measured in visible time: MapLibre
  // reports a finished load from a requestAnimationFrame loop, and browsers
  // suspend that loop for a background tab, so a wall-clock deadline blamed
  // the map for time nobody spent looking at it.
  settleTimer = visibleTimeout(12_000, () => {
    if (!mapLoading.value) return;
    mapLoading.value = false;
    basemapError.value = 'Nền bản đồ tải quá lâu — vẫn vẽ được, nhưng không có ảnh nền.';
  });

  map.on('load', () => {
    settleTimer?.cancel();
    settleTimer = null;
    basemapError.value = null;
    mapLoading.value = false;

    // Add all layers from initial features. Every layer gets a source, even
    // an empty one, so that emptying it later has somewhere to write.
    for (const layerType of ALL_LAYER_TYPES) {
      const features = props.layerFeatures[layerType] ?? [];
      upsertSource(map, layerType, features);
      if (features.length > 0) {
        addLayers(map, layerType);
      }
    }

    syncVisibility();
    ensureHandleLayer();
    syncVertexHandles();
    if (hasAnyFeature()) {
      hasFittedOnce = true;
      fitToBounds();
    }
    emit('map-ready');
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

/**
 * Move to the course when its location lands after the map is already up.
 *
 * The map is built as soon as the container exists; the course record is a
 * separate request. Without this the editor stays wherever it opened even once
 * it knows better.
 */
watch(
  () => props.initialCenter,
  (centre) => {
    if (!map || !centre) return;
    // Anything already drawn is a better target than the course centroid —
    // fitBounds has run and the user may have panned deliberately.
    if (hasAnyFeature()) return;
    map.jumpTo({ center: centre, zoom: props.initialZoom ?? 16 });
  },
);

/** Whether the view has already been fitted to the course's geometry. */
let hasFittedOnce = false;

function hasAnyFeature(): boolean {
  return Object.values(props.layerFeatures ?? {}).some((list) => (list?.length ?? 0) > 0);
}

/**
 * Paint for a line layer, with the dash left out when there is no dash.
 *
 * MapLibre validates a paint object by the keys present, not by their values:
 * `'line-dasharray': undefined` fails as "array expected, undefined found" and
 * `addLayer` throws. Every layer style without a dashArray — green, fairway,
 * bunker, tee — hit that, so their outlines were never added, and the throw
 * escaped the features watcher and skipped the visibility and vertex-handle
 * sync behind it.
 */
function linePaint(style: { color: string; weight: number; dashArray?: string }) {
  const paint: Record<string, unknown> = {
    'line-color': style.color,
    'line-width': style.weight,
  };
  if (style.dashArray) {
    paint['line-dasharray'] = style.dashArray.split(',').map(Number);
  }
  return paint;
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
  // Nothing to switch to. Better to leave the dark map up than to blank the
  // editor a person is drawing on.
  if (!satelliteEnabled.value && !satelliteAvailable.value) return;
  satelliteEnabled.value = !satelliteEnabled.value;
  if (!map) return;

  const targetStyle = (satelliteEnabled.value
    ? satStyle.value
    : baseStyle.value) as never;

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
    ensureHandleLayer();
    syncVertexHandles();
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

      // Push the data unconditionally, empty collections included. Skipping
      // the update for an empty layer meant deleting a layer's last feature
      // left it on screen: the source kept the old shape, the panel counted
      // zero, and the operator deleted something that was already gone.
      upsertSource(map, layerType, features);

      if (features.length > 0) {
        // Ensure layers exist (may have been removed by style reload)
        if (!map.getLayer(LAYER_PREFIX + layerType + '-fill') &&
            !map.getLayer(LAYER_PREFIX + layerType + '-line') &&
            !map.getLayer(LAYER_PREFIX + layerType + '-circle')) {
          addLayers(map, layerType);
        }
      }
    }
    syncVisibility();
    syncVertexHandles();

    // Fit once, when the course's existing geometry first arrives — not on
    // every change. This watcher also fires for the operator's own drawing,
    // and refitting there moved the ground under them: finish a green and the
    // map flies to make that green fill the screen; draw the next and it zooms
    // out again. Tracing eighteen holes means eighteen involuntary jumps.
    if (!hasFittedOnce && hasAnyFeature()) {
      hasFittedOnce = true;
      fitToBounds();
    }
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

/**
 * When the selection changes, refresh the vertex handles.
 */
watch(
  () => props.selectedFeatureId,
  () => {
    syncVertexHandles();
  }
);

// ─── Lifecycle ───────────────────────────────────────────────────────────────

onMounted(async () => {
  // Resolve the imagery provider before the map exists, so a tracer who opens
  // the editor and immediately hits Satellite gets imagery rather than the
  // 404 the hardcoded CARTO style used to give them.
  const config = await fetchBasemapConfig();
  satelliteAttribution.value = config?.satelliteAttribution?.trim() ?? '';
  baseAttribution.value = config?.baseAttribution?.trim() ?? '';
  const satellite = rasterStyleFrom(config);
  satStyle.value = satellite ? markRaw(satellite) : null;
  baseStyle.value = markRaw(baseStyleFrom(config));

  // Start on imagery whenever there is imagery to start on. Tracing a green
  // means tracing it over a picture of the green, so this is the working
  // default and the dark canvas is the exception. It matters more since the
  // plain basemap became empty by default: without this the editor opens on a
  // blank black rectangle, which reads as a broken page rather than as a
  // basemap one click away.
  satelliteEnabled.value = satellite !== null;

  initMap();
});

onUnmounted(() => {
  settleTimer?.cancel();
  settleTimer = null;
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
  color: var(--on-surface, var(--on-surface));
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

.fit-toggle {
  position: absolute;
  top: 3.25rem;
  left: 0.75rem;
  z-index: 2;
  display: flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.45rem 0.7rem;
  border: 1px solid var(--outline-variant, var(--surface-container-highest));
  border-radius: 8px;
  background: rgba(19, 27, 46, 0.92);
  color: var(--on-surface, var(--on-surface));
  font-size: 0.75rem;
  font-weight: 600;
  cursor: pointer;
}
.fit-toggle:disabled {
  opacity: 0.4;
  cursor: default;
}
.sat-label {
  line-height: 1;
}

/* ─── Delete selected button ───────────────────────────────────────────────── */

.delete-selected-btn {
  position: absolute;
  top: 0.75rem;
  left: 50%;
  transform: translateX(-50%);
  z-index: 11;
  display: flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.4rem 0.75rem;
  background: rgba(13, 17, 23, 0.85);
  color: #fca5a5;
  border: 1.5px solid rgba(239, 68, 68, 0.5);
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

.delete-selected-btn:hover {
  background: rgba(127, 29, 29, 0.6);
  border-color: #ef4444;
  color: #fecaca;
}

.delete-selected-btn:focus-visible {
  box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.5);
  border-color: #ef4444;
}

.delete-label {
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

.map-basemap-error {
  position: absolute;
  bottom: 0.75rem;
  left: 50%;
  transform: translateX(-50%);
  z-index: 3;
  max-width: 80%;
  padding: 0.5rem 0.9rem;
  border: 1px solid #6b5620;
  border-radius: 8px;
  background: rgba(19, 27, 46, 0.95);
  color: #f0c869;
  font-size: 0.75rem;
  text-align: center;
}
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
