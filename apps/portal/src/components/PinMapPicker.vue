<script setup lang="ts">
/**
 * Click a green to place the pin.
 *
 * The first version of the pin page asked for latitude and longitude in two
 * text boxes. That is a coordinate entry form, not a pin placement tool: a
 * greenkeeper knows where the hole is cut because they cut it, and they know
 * it as a spot on the green, not as 10.861240. Typing it means reading it off
 * another device first, and a typo in the fifth decimal is 11 metres.
 *
 * So: satellite imagery, click where the hole is. The numeric fields stay
 * beside it as a readout and for nudging, which is also what makes the value
 * checkable — but they are no longer how the work is done.
 *
 * The imagery comes from the same provider the phone uses, resolved from
 * /config/basemap, so the portal and the golfer are looking at one picture
 * under one licence. Where no provider is configured the map still works over
 * a plain canvas, which is honest and still clickable — the existing pins and
 * the hole's own green marker give enough context to place a new one.
 */
import { onBeforeUnmount, onMounted, ref, watch } from 'vue';

import { fetchBasemapConfig, rasterStyleFrom } from '@/api/basemap';
import type { RasterStyle } from '@/api/basemap';

const props = defineProps<{
  /** Currently chosen point, or null when nothing has been placed yet. */
  latitude: number | null;
  longitude: number | null;
  /** Where to open the map when there is no chosen point yet. */
  centre: { latitude: number; longitude: number } | null;
  /** Pins already scheduled, drawn for context. */
  existing?: Array<{ latitude: number; longitude: number; holeNumber: number }>;
}>();

const emit = defineEmits<{
  (e: 'picked', point: { latitude: number; longitude: number }): void;
}>();

const mapRef = ref<HTMLDivElement | null>(null);
const status = ref<string | null>(null);

// eslint-disable-next-line @typescript-eslint/no-explicit-any
let ml: any = null;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
let map: any = null;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
let marker: any = null;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
let existingMarkers: any[] = [];

const FALLBACK_CENTRE = { latitude: 16.0, longitude: 106.0 };

function currentCentre(): [number, number] {
  if (props.latitude != null && props.longitude != null) {
    return [props.longitude, props.latitude];
  }
  const c = props.centre ?? FALLBACK_CENTRE;
  return [c.longitude, c.latitude];
}

/** A plain dark canvas, for a deployment with no imagery provider. */
function blankStyle(): Record<string, unknown> {
  return {
    version: 8,
    sources: {},
    layers: [
      { id: 'bg', type: 'background', paint: { 'background-color': '#131b2e' } },
    ],
  };
}

function placeMarker(lngLat: [number, number]) {
  if (!map || !ml) return;
  if (marker) {
    marker.setLngLat(lngLat);
  } else {
    const el = document.createElement('div');
    el.className = 'pin-marker';
    marker = new ml.Marker({ element: el, draggable: true })
      .setLngLat(lngLat)
      .addTo(map);
    // Dragging the marker is the same act as clicking, and it is how a
    // placement gets nudged the last two metres.
    marker.on('dragend', () => {
      const at = marker.getLngLat();
      emit('picked', { latitude: at.lat, longitude: at.lng });
    });
  }
}

/**
 * The pins already scheduled, as numbered dots.
 *
 * Markers rather than a GeoJSON source and layers, for two reasons the first
 * attempt ran into. A source can only be added once the style has loaded, and
 * this is called from a watcher that fires whenever the pin list arrives —
 * which is usually earlier; the throw escaped into Vue and took the whole
 * page's update with it, leaving the list stuck on "loading". And a `symbol`
 * layer's text-field needs a `glyphs` endpoint, which a raster imagery style
 * has no reason to carry.
 *
 * A DOM marker has neither constraint, and the hole number is just text.
 */
function drawExisting() {
  if (!map || !ml) return;

  for (const m of existingMarkers) m.remove();
  existingMarkers = [];

  for (const p of props.existing ?? []) {
    const el = document.createElement('div');
    el.className = 'pin-existing';
    el.textContent = String(p.holeNumber);
    el.title = `Hố ${p.holeNumber}`;
    existingMarkers.push(
      new ml.Marker({ element: el }).setLngLat([p.longitude, p.latitude]).addTo(map),
    );
  }
}

async function init() {
  if (!mapRef.value) return;
  ml = await import('maplibre-gl');
  // Alongside the module, always. Without it the canvas still draws tiles, so
  // the map looks fine — but .maplibregl-marker never gets position:absolute,
  // and the marker MapLibre has correctly transformed to the clicked point
  // sits in document flow below the map instead. Same for the zoom control.
  await import('maplibre-gl/dist/maplibre-gl.css');

  let style: RasterStyle = null;
  try {
    style = rasterStyleFrom(await fetchBasemapConfig());
  } catch {
    style = null;
  }
  if (!style) {
    status.value =
      'Chưa cấu hình nguồn ảnh vệ tinh — vẫn đặt được vị trí, nhưng không có ảnh nền.';
  }

  map = new ml.Map({
    container: mapRef.value,
    style: (style ?? blankStyle()) as never,
    center: currentCentre(),
    zoom: props.latitude != null ? 18 : 15,
    attributionControl: { compact: true },
  });
  map.addControl(new ml.NavigationControl({ showCompass: false }), 'top-right');

  drawExisting();
  if (props.latitude != null && props.longitude != null) {
    placeMarker([props.longitude, props.latitude]);
  }

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  map.on('click', (e: any) => {
    placeMarker([e.lngLat.lng, e.lngLat.lat]);
    emit('picked', { latitude: e.lngLat.lat, longitude: e.lngLat.lng });
  });
}

// Typing into the numeric fields, or loading a pin to edit, moves the marker.
watch(
  () => [props.latitude, props.longitude],
  ([lat, lng]) => {
    if (lat == null || lng == null || !map) return;
    placeMarker([lng, lat]);
  },
);

watch(() => props.existing, drawExisting, { deep: true });

watch(
  () => props.centre,
  (c) => {
    if (c && map && props.latitude == null) {
      map.easeTo({ center: [c.longitude, c.latitude], zoom: 15 });
    }
  },
);

onMounted(init);
onBeforeUnmount(() => {
  for (const m of existingMarkers) m.remove();
  existingMarkers = [];
  map?.remove();
  map = null;
});
</script>

<template>
  <div class="pin-map">
    <div ref="mapRef" class="pin-map-canvas"></div>
    <p class="pin-map-hint">
      Chạm vào bản đồ để đặt vị trí cờ, hoặc kéo dấu để chỉnh.
      <span v-if="status" class="pin-map-status">{{ status }}</span>
    </p>
  </div>
</template>

<style scoped>
.pin-map {
  grid-column: 1 / -1;
}
.pin-map-canvas {
  height: 380px;
  border-radius: 8px;
  overflow: hidden;
  border: 1px solid var(--border);
}
.pin-map-hint {
  margin: 6px 0 0;
  font-size: 12px;
  color: var(--muted);
}
.pin-map-status {
  color: var(--error);
  margin-left: 6px;
}
</style>

<style>
/* Unscoped: the marker element is created imperatively and attached by
   MapLibre outside this component's scope. */
.pin-existing {
  display: grid;
  place-items: center;
  min-width: 18px;
  height: 18px;
  padding: 0 3px;
  border-radius: 9px;
  background: rgba(3, 37, 26, 0.85);
  border: 1px solid var(--tertiary);
  color: var(--tertiary);
  font: 600 10px/1 system-ui, sans-serif;
}
.pin-marker {
  width: 16px;
  height: 16px;
  border-radius: 50%;
  background: var(--primary-container);
  border: 2px solid #fff;
  box-shadow: 0 0 0 2px rgba(246, 96, 24, 0.4);
  cursor: grab;
}
</style>
