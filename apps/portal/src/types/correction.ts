/**
 * TypeScript types for the Correction Queue feature.
 * These types mirror the backend DTOs from Story 9.2 Slice A.
 *
 * Per Story 9.2 AC-1 (queue filters), AC-2 (detail), AC-3 (review actions).
 */

// ─── Enums ─────────────────────────────────────────────────────────────────

/** Status values for a course correction submission. */
export type CorrectionStatusValue =
  | 'PENDING'
  | 'IN_REVIEW'
  | 'APPROVED'
  | 'REJECTED'
  | 'INFO_REQUESTED'
  | 'CONVERTED_TO_DRAFT';

/** Types of course data that can be corrected. */
export type CorrectionTypeValue =
  | 'GEOMETRY'
  | 'PIN_POSITION'
  | 'BUNKER'
  | 'WATER'
  | 'OB'
  | 'CART_PATH'
  | 'LANDMARK'
  | 'COURSE_CONDITION'
  | 'GREEN_SPEED'
  | 'OTHER';

/** Review actions available to a course administrator. */
export type CorrectionReviewActionValue =
  | 'APPROVE'
  | 'REJECT'
  | 'REQUEST_INFO'
  | 'CONVERT_TO_DRAFT';

// ─── Queue List ─────────────────────────────────────────────────────────────

/** Summary view of a correction in the queue list. */
export interface CorrectionSummary {
  id: number;
  courseId: number;
  courseName: string;
  holeNumber: number | null;
  correctionType: CorrectionTypeValue;
  status: CorrectionStatusValue;
  confidence: number | null;
  submittedAt: string; // ISO 8601
  reporterId: number;
}

/** Paginated queue list response. */
export interface CorrectionQueueResponse {
  corrections: CorrectionSummary[];
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
}

// ─── Detail View ───────────────────────────────────────────────────────────

/** Full correction detail for the review panel. */
export interface CorrectionDetailResponse {
  id: number;
  courseId: number;
  courseName: string;
  holeId: number | null;
  holeNumber: number | null;
  reporterId: number;

  // Reporter evidence
  reporterNote: string | null;
  reporterEvidenceUrl: string | null;

  // Location
  /** Reporter's GPS location as SRID 4326 WKT (e.g. "POINT(106.7205 10.8506)") */
  reporterGpsLocation: string | null;

  /**
   * The shape the reporter proposes, as SRID 4326 WKT; null when the correction
   * carries no geometry. Previously only reachable through the map-context
   * endpoint, so the detail panel could not draw what was being claimed.
   */
  proposedGeometry: string | null;

  // Classification
  correctionType: CorrectionTypeValue;
  status: CorrectionStatusValue;
  confidence: number | null;

  // Submission
  submittedAt: string;

  // Review fields
  reviewedAt: string | null;
  reviewedBy: number | null;
  reviewNote: string | null;
  resolution: string | null;

  // Data quality metadata
  source: string | null;
  license: string | null;
  accuracyClass: string | null;
  dataConfidence: number | null;
  verificationStatus: string | null;
  createdAt: string;
  updatedAt: string;
  version: number | null;
}

// ─── Review Action ──────────────────────────────────────────────────────────

/** Request payload for the review action endpoint. */
export interface CorrectionReviewRequest {
  action: CorrectionReviewActionValue;
  /** Human-readable reason — required for REJECT and REQUEST_INFO. */
  reason?: string;
  /** Optional reviewer note visible in the audit trail. */
  note?: string;
}

/** Response from the review action endpoint. */
export interface CorrectionReviewResponse {
  id: number;
  status: CorrectionStatusValue;
  reviewedAt: string;
}

// ─── Map Context ────────────────────────────────────────────────────────────

/** Official course/hole geometry for the map overlay comparison. */
export interface CorrectionMapContext {
  correctionId: number;
  message?: string; // present when deferred
  // Full geometry fields populated by Story 9.3
  officialGeometry?: GeoJSONFeatureCollection;
  reporterLocation?: GeoCoordinate;
}

/** GeoJSON types for map context (subset of geometry.ts). */
export interface GeoCoordinate {
  type: 'Point';
  coordinates: [number, number]; // [lon, lat] SRID 4326
}

export interface GeoJSONFeatureCollection {
  type: 'FeatureCollection';
  features: GeoJSONFeature[];
}

export interface GeoJSONFeature {
  type: 'Feature';
  id?: string | number;
  geometry: GeoJSONGeometry;
  properties: Record<string, unknown>;
}

export type GeoJSONGeometry =
  | { type: 'Point'; coordinates: [number, number] }
  | { type: 'LineString'; coordinates: [number, number][] }
  | { type: 'Polygon'; coordinates: [number, number][][] };

// ─── Filter Parameters ──────────────────────────────────────────────────────

export interface CorrectionQueueFilters {
  courseId?: number;
  holeNumber?: number;
  type?: CorrectionTypeValue;
  status?: CorrectionStatusValue;
  confidenceMin?: number;
  confidenceMax?: number;
  from?: string; // ISO 8601 date
  to?: string;   // ISO 8601 date
  page?: number;
  pageSize?: number;
}

// ─── API Error ──────────────────────────────────────────────────────────────

export interface CorrectionApiError {
  code: string;
  message: string;
}
