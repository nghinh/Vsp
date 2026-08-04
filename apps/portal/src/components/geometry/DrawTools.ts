/**
 * DrawTools — Drawing mode handlers for the geometry editor.
 *
 * Slice 4: Draw Tools (Point/Line/Polygon creation, Vertex editing, Snapping)
 *
 * Features:
 * - Point placement for tee/landmark layers
 * - Line drawing for cart_path/ob layers
 * - Polygon drawing for fairway/rough/green/bunker/water/penalty layers
 * - Snap to existing vertices (10px screen tolerance)
 * - Snap to existing edges (10px screen tolerance)
 * - Visual snap indicator during draw
 *
 * Usage:
 *   const tools = createDrawTools({ layerType, geometryType, features, onFeatureComplete });
 *   tools.handleMapClick(lngLat);
 *   tools.cancel();
 */

import type {
  LayerType,
  GeometryFeature,
  GeoJSONPoint,
  GeoJSONLineString,
  GeoJSONPolygon,
  GeoCoordinate,
} from '@/types/geometry';

// ─── Types ───────────────────────────────────────────────────────────────────

export interface DrawToolsOptions {
  /** The layer type being drawn. */
  layerType: LayerType;
  /** The geometry type for this draw session. */
  geometryType: 'Point' | 'LineString' | 'Polygon';
  /** Existing features on the map (used for snapping). */
  existingFeatures: GeometryFeature[];
  /** Called when a feature is completed (confirmed by double-click or special action). */
  onFeatureComplete: (feature: GeometryFeature) => void;
  /** Called when an existing feature is deleted via a map interaction. */
  onFeatureDelete?: (feature: GeometryFeature) => void;
  /** Called when an existing feature's geometry is modified via a map interaction. */
  onFeatureModify?: (before: GeometryFeature, after: GeometryFeature) => void;
  /** Called when the snap indicator should update. */
  onSnapIndicator?: (snapPoint: GeoCoordinate | null) => void;
  /** Screen-pixel tolerance for snapping (default 10). */
  snapTolerancePx?: number;
}

interface SnapResult {
  point: GeoCoordinate;
  type: 'vertex' | 'edge';
  distancePx: number;
}

// ─── Snap logic ─────────────────────────────────────────────────────────────

/**
 * Find the nearest existing vertex to the given coordinates.
 * Returns null if nothing is within snapTolerancePx.
 */
export function snapToVertex(
  coord: GeoCoordinate,
  existingFeatures: GeometryFeature[],
  tolerancePx: number,
  zoom: number
): SnapResult | null {
  let best: SnapResult | null = null;

  for (const feature of existingFeatures) {
    const coords = extractCoordinates(feature.geometry);
    for (const c of coords) {
      const dist = haversineDistancePx(coord, c, zoom);
      if (dist <= tolerancePx && (!best || dist < best.distancePx)) {
        best = { point: c, type: 'vertex', distancePx: dist };
      }
    }
  }

  return best;
}

/**
 * Find the nearest point on any existing edge to the given coordinates.
 * Returns null if nothing is within tolerance.
 */
export function snapToEdge(
  coord: GeoCoordinate,
  existingFeatures: GeometryFeature[],
  tolerancePx: number,
  zoom: number
): SnapResult | null {
  let best: SnapResult | null = null;

  for (const feature of existingFeatures) {
    if (feature.geometry.type === 'Point') continue;
    const rings = feature.geometry.type === 'Polygon'
      ? feature.geometry.coordinates
      : [feature.geometry.coordinates]; // LineString → single ring

    for (const ring of rings) {
      for (let i = 0; i < ring.length - 1; i++) {
        const a = ring[i] as GeoCoordinate;
        const b = ring[i + 1] as GeoCoordinate;
        const nearest = nearestPointOnSegment(coord, a, b);
        const dist = haversineDistancePx(coord, nearest, zoom);
        if (dist <= tolerancePx && (!best || dist < best.distancePx)) {
          best = { point: nearest, type: 'edge', distancePx: dist };
        }
      }
    }
  }

  return best;
}

/**
 * Combined snap — prefers vertex over edge when both are within tolerance.
 */
export function findSnap(
  coord: GeoCoordinate,
  existingFeatures: GeometryFeature[],
  tolerancePx: number,
  zoom: number
): SnapResult | null {
  const vertexSnap = snapToVertex(coord, existingFeatures, tolerancePx, zoom);
  if (vertexSnap) return vertexSnap;
  return snapToEdge(coord, existingFeatures, tolerancePx, zoom);
}

// ─── Coordinate extraction ───────────────────────────────────────────────────

function extractCoordinates(geometry: GeoJSONPoint | GeoJSONLineString | GeoJSONPolygon): GeoCoordinate[] {
  switch (geometry.type) {
    case 'Point':
      return [geometry.coordinates];
    case 'LineString':
      return geometry.coordinates;
    case 'Polygon':
      return geometry.coordinates.flat();
    default:
      return [];
  }
}

/**
 * Project a point onto the segment AB. Returns the closest point on the segment.
 */
function nearestPointOnSegment(
  p: GeoCoordinate,
  a: GeoCoordinate,
  b: GeoCoordinate
): GeoCoordinate {
  const dx = b[0] - a[0];
  const dy = b[1] - a[1];
  const lenSq = dx * dx + dy * dy;
  if (lenSq === 0) return a; // a === b

  const t = Math.max(0, Math.min(1,
    ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / lenSq
  ));

  return [a[0] + t * dx, a[1] + t * dy];
}

/**
 * Approximate screen-pixel distance between two geographic coordinates at a given zoom.
 * Uses a simple equirectangular approximation; sufficient for snap tolerance.
 */
function haversineDistancePx(a: GeoCoordinate, b: GeoCoordinate, zoom: number): number {
  const R = 6371000; // Earth radius in metres
  const latAvg = (a[1] + b[1]) / 2;
  const latRad = latAvg * Math.PI / 180;

  const dx = (b[0] - a[0]) * Math.PI / 180 * R * Math.cos(latRad);
  const dy = (b[1] - a[1]) * Math.PI / 180 * R;

  const metresPerPx = (40075016.686 * Math.cos(latRad)) / (2 ** zoom) / 256;
  const distPx = Math.sqrt(dx * dx + dy * dy) / metresPerPx;

  return distPx;
}

// ─── DrawTools factory ──────────────────────────────────────────────────────

export interface DrawTools {
  /** Handle a map click during drawing. Returns true if handled. */
  handleClick(lngLat: GeoCoordinate, zoom: number): boolean;
  /** Handle double-click to complete drawing. */
  handleDoubleClick(lngLat: GeoCoordinate, zoom: number): boolean;
  /** Cancel the current drawing session. */
  cancel(): void;
  /** Current in-progress coordinates. */
  readonly currentCoords: GeoCoordinate[];
  /** Whether a drawing is in progress. */
  readonly isDrawing: boolean;
  /** The snap indicator point (null if none). */
  readonly snapPoint: GeoCoordinate | null;
}

export function createDrawTools(options: DrawToolsOptions): DrawTools {
  const {
    geometryType,
    existingFeatures,
    onFeatureComplete,
    onSnapIndicator,
    snapTolerancePx = 10,
  } = options;

  let coords: GeoCoordinate[] = [];
  let snapPoint: GeoCoordinate | null = null;

  function updateSnap(coord: GeoCoordinate, zoom: number) {
    const snap = findSnap(coord, existingFeatures, snapTolerancePx, zoom);
    snapPoint = snap?.point ?? null;
    onSnapIndicator?.(snapPoint);
  }

  function clearSnap() {
    snapPoint = null;
    onSnapIndicator?.(null);
  }

  function reset() {
    coords = [];
    clearSnap();
  }

  function handleClick(lngLat: GeoCoordinate, zoom: number): boolean {
    if (geometryType === 'Point') {
      // For point: single click places the point
      updateSnap(lngLat, zoom);
      const finalCoord = snapPoint ?? lngLat;
      const feature = buildFeature(finalCoord, geometryType);
      onFeatureComplete(feature);
      reset();
      return true;
    }

    // For line/polygon: add intermediate point
    updateSnap(lngLat, zoom);
    const finalCoord = snapPoint ?? lngLat;

    if (geometryType === 'LineString') {
      // Line: first click starts, second click completes
      coords.push(finalCoord);
      if (coords.length === 2) {
        const feature = buildFeature(coords as [GeoCoordinate, GeoCoordinate], 'LineString');
        onFeatureComplete(feature);
        reset();
        return true;
      }
      return true;
    }

    // Polygon: accumulate points; double-click completes
    coords.push(finalCoord);
    return true;
  }

  function handleDoubleClick(lngLat: GeoCoordinate, zoom: number): boolean {
    if (geometryType !== 'Polygon' || coords.length < 3) return false;

    updateSnap(lngLat, zoom);
    const finalCoord = snapPoint ?? lngLat;

    // Close the polygon by adding the first point at the end
    const closedCoords = [...coords, finalCoord];

    // Validate ring closure (first === last)
    if (
      closedCoords[0][0] !== closedCoords[closedCoords.length - 1][0] ||
      closedCoords[0][1] !== closedCoords[closedCoords.length - 1][1]
    ) {
      closedCoords.push(closedCoords[0]);
    }

    // A polygon's coordinates is an array of rings; wrap the single closed ring.
    const feature = buildFeature([closedCoords] as GeoJSONPolygon['coordinates'], 'Polygon');
    onFeatureComplete(feature);
    reset();
    return true;
  }

  function cancel() {
    reset();
  }

  function buildFeature(
    coordinates: GeoJSONPoint['coordinates'] | GeoJSONLineString['coordinates'] | GeoJSONPolygon['coordinates'],
    type: 'Point' | 'LineString' | 'Polygon'
  ): GeometryFeature {
    return {
      type: 'Feature',
      geometry: { type, coordinates } as GeoJSONPoint | GeoJSONLineString | GeoJSONPolygon,
      properties: {
        layerType: options.layerType,
        courseId: 0, // caller fills this
        state: 'draft',
      } as GeometryFeature['properties'],
    };
  }

  return {
    get currentCoords() { return coords; },
    get isDrawing() { return geometryType !== 'Point' || coords.length === 0; },
    get snapPoint() { return snapPoint; },
    handleClick,
    handleDoubleClick,
    cancel,
  };
}

// ─── Vertex editing ─────────────────────────────────────────────────────────

export interface VertexEditOptions {
  /** The feature whose vertices are being edited. */
  feature: GeometryFeature;
  /** Vertex index being moved. */
  vertexIndex: number;
  /** New coordinates for the vertex. */
  newCoord: GeoCoordinate;
  /** Snapping candidate features. */
  snapCandidates: GeometryFeature[];
  /** Zoom level for snap tolerance. */
  zoom: number;
  /** Screen-pixel snap tolerance. */
  snapTolerancePx?: number;
}

/**
 * Move a single vertex of a feature, returning a new feature with updated geometry.
 * Applies snapping if the moved vertex is near an existing one.
 */
export function moveVertex(
  options: VertexEditOptions
): GeometryFeature {
  const { feature, vertexIndex, newCoord, snapCandidates, zoom, snapTolerancePx = 10 } = options;

  // Apply snapping
  const snap = findSnap(newCoord, snapCandidates, snapTolerancePx, zoom);
  const finalCoord = snap?.point ?? newCoord;

  let newGeom: GeoJSONPoint | GeoJSONLineString | GeoJSONPolygon;
  switch (feature.geometry.type) {
    case 'Point': {
      newGeom = { type: 'Point', coordinates: finalCoord };
      break;
    }
    case 'LineString': {
      const coords = [...feature.geometry.coordinates] as GeoCoordinate[];
      coords[vertexIndex] = finalCoord;
      newGeom = { type: 'LineString', coordinates: coords };
      break;
    }
    case 'Polygon': {
      const rings = feature.geometry.coordinates.map((ring, ringIdx) => {
        if (ringIdx > 0) return ring; // Don't modify inner rings
        const coords = [...ring] as GeoCoordinate[];
        // Adjust the closing point if we moved the first/last vertex
        const targetIdx = vertexIndex % coords.length;
        coords[targetIdx] = finalCoord;
        if (vertexIndex === 0) {
          coords[coords.length - 1] = finalCoord; // Close the ring
        }
        return coords;
      });
      newGeom = { type: 'Polygon', coordinates: rings as GeoJSONPolygon['coordinates'] };
      break;
    }
    default:
      newGeom = feature.geometry as GeoJSONPoint | GeoJSONLineString | GeoJSONPolygon;
  }

  return {
    ...feature,
    geometry: newGeom,
  };
}

/**
 * Add a vertex to a LineString or Polygon at the given index.
 */
export function addVertex(
  feature: GeometryFeature,
  afterIndex: number,
  newCoord: GeoCoordinate
): GeometryFeature {
  let newGeom: GeoJSONLineString | GeoJSONPolygon;

  switch (feature.geometry.type) {
    case 'LineString': {
      const coords = [...feature.geometry.coordinates] as GeoCoordinate[];
      coords.splice(afterIndex + 1, 0, newCoord);
      newGeom = { type: 'LineString', coordinates: coords };
      break;
    }
    case 'Polygon': {
      const rings = feature.geometry.coordinates.map((ring, ringIdx) => {
        if (ringIdx > 0) return ring;
        const coords = [...ring] as GeoCoordinate[];
        coords.splice(afterIndex + 1, 0, newCoord);
        return coords;
      });
      newGeom = { type: 'Polygon', coordinates: rings as GeoJSONPolygon['coordinates'] };
      break;
    }
    default:
      return feature;
  }

  return { ...feature, geometry: newGeom };
}

/**
 * Delete a vertex from a LineString or Polygon.
 * For LineString: requires at least 2 vertices.
 * For Polygon: requires at least 4 vertices (3 + closing point).
 */
export function deleteVertex(
  feature: GeometryFeature,
  vertexIndex: number
): GeometryFeature | null {
  switch (feature.geometry.type) {
    case 'LineString': {
      const coords = [...feature.geometry.coordinates] as GeoCoordinate[];
      if (coords.length <= 2) return null; // Need at least 2 points
      coords.splice(vertexIndex, 1);
      return { ...feature, geometry: { type: 'LineString', coordinates: coords } };
    }
    case 'Polygon': {
      const rings = feature.geometry.coordinates.map((ring, ringIdx) => {
        if (ringIdx > 0) return ring;
        const coords = [...ring] as GeoCoordinate[];
        if (coords.length <= 4) return null; // Need at least 3 + closing point
        coords.splice(vertexIndex, 1);
        // Re-close the ring
        if (vertexIndex === 0 || vertexIndex === coords.length) {
          coords[coords.length - 1] = coords[0];
        }
        return coords;
      });
      if (rings[0] === null) return null;
      return { ...feature, geometry: { type: 'Polygon', coordinates: rings as GeoJSONPolygon['coordinates'] } };
    }
    default:
      return feature;
  }
}
