/**
 * Shared TypeScript types for the Course Geometry Editor.
 * These types mirror the PostGIS schema from Story 3.1 and the
 * GeoJSON representation used in the GeometryController API.
 *
 * Layer types are derived from the PRD (8.11) and Architecture (10).
 * All coordinates use SRID 4326 (WGS 84).
 */

// ─── Geometry Primitives ────────────────────────────────────────────────────

/** GeoJSON-compatible coordinate: [longitude, latitude] in SRID 4326. */
export type GeoCoordinate = [number, number];

/** GeoJSON-compatible ring: array of coordinates, closed (first == last). */
export type GeoRing = GeoCoordinate[];

/** GeoJSON Polygon coordinate rings: [outerRing, innerRing[], ...]. */
export type GeoPolygonCoordinates = [GeoRing, ...GeoRing[]];

/** GeoJSON LineString coordinate array. */
export type GeoLineStringCoordinates = GeoCoordinate[];

/** GeoJSON Point coordinate. */
export type GeoPointCoordinate = GeoCoordinate;

// ─── GeoJSON Feature Types ─────────────────────────────────────────────────

export type GeometryType = 'Point' | 'LineString' | 'Polygon' | 'MultiPoint' | 'MultiLineString' | 'MultiPolygon';

export interface GeoJSONPoint {
  type: 'Point';
  coordinates: GeoPointCoordinate;
}

export interface GeoJSONLineString {
  type: 'LineString';
  coordinates: GeoLineStringCoordinates;
}

export interface GeoJSONPolygon {
  type: 'Polygon';
  coordinates: GeoPolygonCoordinates;
}

export type GeoJSONGeometry = GeoJSONPoint | GeoJSONLineString | GeoJSONPolygon;

export interface GeoJSONFeature<G extends GeoJSONGeometry = GeoJSONGeometry, P = Record<string, unknown>> {
  type: 'Feature';
  id?: string | number;
  geometry: G;
  properties: P;
}

export interface GeoJSONFeatureCollection<G extends GeoJSONGeometry = GeoJSONGeometry, P = Record<string, unknown>> {
  type: 'FeatureCollection';
  features: Array<GeoJSONFeature<G, P>>;
}

// ─── Layer Types ───────────────────────────────────────────────────────────

/**
 * All editable layer types in the course geometry editor.
 * Derived from PRD 8.11 and Architecture 10.
 */
export type LayerType =
  | 'tee'
  | 'fairway'
  | 'rough'
  | 'green'
  | 'bunker'
  | 'water'
  | 'penalty'
  | 'ob'
  | 'cart_path'
  | 'landmark';

/** Human-readable label for each layer type. */
export const LAYER_TYPE_LABELS: Record<LayerType, string> = {
  tee: 'Tee',
  fairway: 'Fairway',
  rough: 'Rough',
  green: 'Green',
  bunker: 'Bunker',
  water: 'Water Hazard',
  penalty: 'Penalty Area',
  ob: 'Out of Bounds',
  cart_path: 'Cart Path',
  landmark: 'Landmark',
};

/** Default geometry type for each layer type. */
export const LAYER_DEFAULT_GEOMETRY_TYPE: Record<LayerType, GeometryType> = {
  tee: 'Point',
  fairway: 'Polygon',
  rough: 'Polygon',
  green: 'Polygon',
  bunker: 'Polygon',
  water: 'Polygon',
  penalty: 'Polygon',
  ob: 'LineString',
  cart_path: 'LineString',
  landmark: 'Point',
};

/** Whether a layer type supports polygon geometry. */
export const LAYER_SUPPORTS_POLYGON: Record<LayerType, boolean> = {
  tee: false,
  fairway: true,
  rough: true,
  green: true,
  bunker: true,
  water: true,
  penalty: true,
  ob: true,
  cart_path: false,
  landmark: false,
};

/** Whether a layer type supports line geometry. */
export const LAYER_SUPPORTS_LINE: Record<LayerType, boolean> = {
  tee: false,
  fairway: true,
  rough: false,
  green: false,
  bunker: false,
  water: true,
  penalty: true,
  ob: true,
  cart_path: true,
  landmark: false,
};

/** Whether a layer type supports point geometry. */
export const LAYER_SUPPORTS_POINT: Record<LayerType, boolean> = {
  tee: true,
  fairway: false,
  rough: false,
  green: false,
  bunker: false,
  water: false,
  penalty: false,
  ob: false,
  cart_path: false,
  landmark: true,
};

// ─── Feature Properties ────────────────────────────────────────────────────

/** Common properties on all geometry features. */
export interface BaseFeatureProperties {
  layerType: LayerType;
  holeNumber?: number;        // 1–18, derived from hole association
  courseId: number;
  /** ISO 8601 timestamp of last modification. */
  updatedAt?: string;
  updatedBy?: string;
  /** Draft vs published state. */
  state: 'draft' | 'published';
}

/** Tee feature properties. */
export interface TeeFeatureProperties extends BaseFeatureProperties {
  layerType: 'tee';
  teeSetId?: number;
  teeSetName?: string;
  yardage?: number;
}

/** Fairway feature properties. */
export interface FairwayFeatureProperties extends BaseFeatureProperties {
  layerType: 'fairway';
  holeNumber: number;
}

/** Rough feature properties. */
export interface RoughFeatureProperties extends BaseFeatureProperties {
  layerType: 'rough';
  holeNumber: number;
}

/** Green feature properties. */
export interface GreenFeatureProperties extends BaseFeatureProperties {
  layerType: 'green';
  holeNumber: number;
}

/** Bunker feature properties. */
export interface BunkerFeatureProperties extends BaseFeatureProperties {
  layerType: 'bunker';
  holeNumber: number;
}

/** Water hazard feature properties. */
export interface WaterFeatureProperties extends BaseFeatureProperties {
  layerType: 'water';
  hazardType?: 'water' | 'lateral_water';
  holeNumber: number;
}

/** Penalty area feature properties. */
export interface PenaltyFeatureProperties extends BaseFeatureProperties {
  layerType: 'penalty';
  holeNumber: number;
}

/** Out of bounds feature properties. */
export interface OBFeatureProperties extends BaseFeatureProperties {
  layerType: 'ob';
}

/** Cart path feature properties. */
export interface CartPathFeatureProperties extends BaseFeatureProperties {
  layerType: 'cart_path';
  pathType?: string;
}

/** Landmark feature properties. */
export interface LandmarkFeatureProperties extends BaseFeatureProperties {
  layerType: 'landmark';
  landmarkType?: string;
  name?: string;
}

export type GeometryFeatureProperties =
  | TeeFeatureProperties
  | FairwayFeatureProperties
  | RoughFeatureProperties
  | GreenFeatureProperties
  | BunkerFeatureProperties
  | WaterFeatureProperties
  | PenaltyFeatureProperties
  | OBFeatureProperties
  | CartPathFeatureProperties
  | LandmarkFeatureProperties;

// ─── Feature Collections by Layer ─────────────────────────────────────────

/** Typed feature alias for the editor. */
export type GeometryFeature = GeoJSONFeature<GeoJSONGeometry, GeometryFeatureProperties>;

/** Feature collection keyed by layer type. */
export type LayerFeatureMap = Partial<Record<LayerType, GeometryFeature[]>>;

// ─── Editor State ──────────────────────────────────────────────────────────

/** Active drawing tool. */
export type EditorTool = 'select' | 'point' | 'line' | 'polygon' | 'edit';

/** Visibility and selection state per layer. */
export interface LayerState {
  visible: boolean;
  /** Feature IDs selected for editing. */
  selectedFeatureIds: string[];
}

export type LayerStateMap = Partial<Record<LayerType, LayerState>>;

// ─── API DTOs ──────────────────────────────────────────────────────────────

export interface DraftGeometryResponse {
  courseId: number;
  state: 'draft';
  version: number;
  features: GeometryFeature[];
  updatedAt: string;
  updatedBy: string;
}

export interface ValidateGeometryRequest {
  courseId: number;
  features: GeometryFeature[];
}

export interface ValidationError {
  featureId?: string;
  field?: string;
  code: string;
  message: string;
}

export interface ValidateGeometryResponse {
  valid: boolean;
  errors: ValidationError[];
}

// ─── RBAC ─────────────────────────────────────────────────────────────────

/** Portal roles that can edit geometry. */
export const GEOMETRY_EDIT_ROLES = ['ROLE_COURSE_ADMIN', 'ROLE_GREENKEEPER'] as const;
export type GeometryEditRole = typeof GEOMETRY_EDIT_ROLES[number];

/** Read-only portal roles. */
export const GEOMETRY_READ_ONLY_ROLES = ['ROLE_AUDITOR', 'ROLE_READONLY'] as const;
export type GeometryReadOnlyRole = typeof GEOMETRY_READ_ONLY_ROLES[number];
