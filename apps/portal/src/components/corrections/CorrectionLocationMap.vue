<template>
  <section class="correction-location-map" aria-label="Location context">
    <h3 class="section-title">Location Context</h3>

    <!-- Map container -->
    <div class="map-wrapper" ref="wrapperRef">
      <div
        ref="mapRef"
        class="map-canvas"
        role="img"
        :aria-label="mapAriaLabel"
        tabindex="0"
      />

      <!-- Loading overlay -->
      <div v-if="mapLoading" class="map-loading" aria-busy="true" aria-label="Loading map">
        <span class="map-spinner" aria-hidden="true" />
      </div>

      <!-- Deferred notice -->
      <div v-if="mapContext.message && !mapContext.officialGeometry" class="deferred-notice">
        <span aria-hidden="true">🗺</span>
        <span>{{ mapContext.message }}</span>
      </div>
    </div>

    <!-- GPS coordinates -->
    <div v-if="gpsCoordinates" class="gps-info">
      <div class="gps-row">
        <span class="gps-label">Reporter GPS</span>
        <span class="gps-value">{{ gpsCoordinates }}</span>
      </div>
      <div v-if="detail.holeNumber != null" class="gps-row">
        <span class="gps-label">Reported Hole</span>
        <span class="gps-value">#{{ detail.holeNumber }}</span>
      </div>
    </div>

    <p v-else class="no-location">No GPS location recorded for this correction.</p>
  </section>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, watch } from 'vue';
import type { CorrectionDetailResponse, CorrectionMapContext, GeoCoordinate } from '@/types/correction';

const props = defineProps<{
  detail: CorrectionDetailResponse;
  mapContext: CorrectionMapContext;
}>();

defineEmits<{
  (e: 'load-context', id: number): void;
}>();

const mapRef = ref<HTMLDivElement | null>(null);
const wrapperRef = ref<HTMLDivElement | null>(null);
const mapLoading = ref(false);

// ─── GPS parsing ───────────────────────────────────────────────────────────

/**
 * Parse WKT POINT string like "POINT(106.7205 10.8506)"
 * into [lon, lat].
 */
function parseWktPoint(wkt: string): GeoCoordinate | null {
  const match = wkt.match(/POINT\s*\(\s*([-\d.]+)\s+([-\d.]+)\s*\)/i);
  if (!match) return null;
  return {
    type: 'Point',
    coordinates: [parseFloat(match[1]), parseFloat(match[2])],
  };
}

const gpsCoordinates = computed<string | null>(() => {
  if (!props.detail.reporterGpsLocation) return null;
  const coord = parseWktPoint(props.detail.reporterGpsLocation);
  if (!coord) return props.detail.reporterGpsLocation;
  return `${coord.coordinates[1].toFixed(6)}, ${coord.coordinates[0].toFixed(6)} (lat, lon)`;
});

const reporterLocation = computed<GeoCoordinate | null>(() => {
  if (!props.detail.reporterGpsLocation) return null;
  return parseWktPoint(props.detail.reporterGpsLocation);
});

const mapAriaLabel = computed(() => {
  if (reporterLocation.value) {
    return `Map showing reporter location near course`;
  }
  return 'Map context for correction review';
});

// ─── MapLibre map ─────────────────────────────────────────────────────────

let map: unknown = null;
let maplibreModule: typeof import('maplibre-gl') | null = null;

async function initMap() {
  if (!mapRef.value) return;
  if (!reporterLocation.value) return;

  try {
    mapLoading.value = true;

    if (!maplibreModule) {
      maplibreModule = await import('maplibre-gl');
      await import('maplibre-gl/dist/maplibre-gl.css');
    }

    const Map = maplibreModule.Map;

    map = new Map({
      container: mapRef.value,
      style: 'https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json',
      center: reporterLocation.value.coordinates,
      zoom: 15,
      attributionControl: false,
    });

    (map as InstanceType<typeof Map>).on('load', () => {
      mapLoading.value = false;

      // Add reporter marker
      (map as InstanceType<typeof Map>).addSource('reporter', {
        type: 'geojson',
        data: {
          type: 'Feature',
          geometry: {
            type: 'Point',
            coordinates: reporterLocation.value!.coordinates,
          },
          properties: {},
        },
      });

      (map as InstanceType<typeof Map>).addLayer({
        id: 'reporter-point',
        type: 'circle',
        source: 'reporter',
        paint: {
          'circle-radius': 8,
          'circle-color': '#3b82f6',
          'circle-stroke-width': 2,
          'circle-stroke-color': '#ffffff',
        },
      });

      // Add label
      (map as InstanceType<typeof Map>).addLayer({
        id: 'reporter-label',
        type: 'symbol',
        source: 'reporter',
        layout: {
          'text-field': 'Reporter',
          'text-size': 12,
          'text-offset': [0, -1.5],
        },
        paint: {
          'text-color': '#3b82f6',
          'text-halo-color': '#ffffff',
          'text-halo-width': 1.5,
        },
      });

      // If official geometry is available from map context, add it
      if (props.mapContext.officialGeometry) {
        (map as InstanceType<typeof Map>).addSource('official', {
          type: 'geojson',
          data: props.mapContext.officialGeometry as unknown as GeoJSON.GeoJSON,
        });
        (map as InstanceType<typeof Map>).addLayer({
          id: 'official-geometry',
          type: 'fill',
          source: 'official',
          paint: {
            'fill-opacity': 0.3,
            'fill-color': '#22c55e',
          },
        });
      }
    });
  } catch {
    mapLoading.value = false;
  }
}

function destroyMap() {
  if (map && typeof (map as { remove: () => void }).remove === 'function') {
    (map as { remove: () => void }).remove();
    map = null;
  }
}

onMounted(() => {
  if (reporterLocation.value) {
    initMap();
  }
});

watch(() => props.mapContext, () => {
  destroyMap();
  if (reporterLocation.value) {
    initMap();
  }
});

onUnmounted(() => {
  destroyMap();
});
</script>

<style scoped>
.correction-location-map {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.section-title {
  font-size: 0.9375rem;
  font-weight: 700;
  color: #dae2fd;
  margin: 0;
  padding-bottom: 0.5rem;
  border-bottom: 1px solid #2d3449;
}

.map-wrapper {
  position: relative;
  border-radius: 8px;
  overflow: hidden;
  border: 1px solid #2d3449;
  background: #222a3d;
}

.map-canvas {
  width: 100%;
  height: 220px;
}

.map-loading {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(249, 250, 251, 0.8);
}

.map-spinner {
  width: 28px;
  height: 28px;
  border: 3px solid #2d3449;
  border-top-color: #3b82f6;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.deferred-notice {
  position: absolute;
  bottom: 0.5rem;
  left: 0.5rem;
  background: rgba(255, 255, 255, 0.92);
  border: 1px solid #2d3449;
  border-radius: 6px;
  padding: 0.4rem 0.75rem;
  font-size: 0.75rem;
  color: #97a2c0;
  display: flex;
  align-items: center;
  gap: 0.4rem;
  max-width: 80%;
}

/* GPS info */
.gps-info {
  background: #171f33;
  border-radius: 6px;
  border: 1px solid #2d3449;
  padding: 0.75rem;
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
}

.gps-row {
  display: flex;
  justify-content: space-between;
  font-size: 0.8125rem;
}

.gps-label {
  color: #97a2c0;
  font-weight: 500;
}

.gps-value {
  color: #dae2fd;
  font-weight: 600;
  font-family: monospace;
  font-size: 0.75rem;
}

.no-location {
  font-size: 0.875rem;
  color: #97a2c0;
  font-style: italic;
  margin: 0;
}
</style>
