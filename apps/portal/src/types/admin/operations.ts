/**
 * Types for the greenkeeping endpoints: pin positions, course conditions and
 * green conditions.
 *
 * Mirrors the server DTOs in vnpt.vsp.module.operations.dto. Every one of
 * these carries a `dataQuality` block, because everything the app draws or
 * quotes has to be able to say where it came from — a pin an operator placed
 * this morning and a pin inherited from last season are both "the pin", and
 * only the provenance tells them apart.
 */

/** Provenance, as the server records it. */
export interface DataQuality {
  accuracyClass?: string;
  verificationStatus?: string;
  confidence?: number;
  source?: string;
  publisher?: string;
  license?: string;
  lastVerifiedAt?: string;
}

// ─── Pin positions ───────────────────────────────────────────────────────────

/** Where the hole is cut today. */
export interface PinPosition {
  id: number;
  courseId: number;
  holeNumber: number;
  /** WKT POINT in SRID 4326, e.g. `POINT(106.896 10.861)`. */
  position: string;
  pinPositionType?: string;
  effectiveFrom: string;
  expiresAt: string;
  publishedBy?: string;
  confidence?: number;
  dataQuality?: DataQuality;
}

export interface PinPositionCreateRequest {
  position: string;
  pinPositionType?: string;
  effectiveFrom: string;
  expiresAt: string;
  confidence?: number;
}

export type PinPositionUpdateRequest = Partial<PinPositionCreateRequest>;

/** The three the server accepts. */
export const PIN_POSITION_TYPES = ['CURRENT', 'TOURNAMENT', 'PRACTICE'] as const;

// ─── Course conditions ───────────────────────────────────────────────────────

export interface CourseCondition {
  id: number;
  courseId: number;
  conditionType: string;
  severity: string;
  description?: string;
  effectiveFrom: string;
  expiresAt?: string;
  publishedBy?: string;
  dataQuality?: DataQuality;
}

export interface CourseConditionCreateRequest {
  conditionType: string;
  severity: string;
  description?: string;
  effectiveFrom: string;
  expiresAt?: string;
}

export type CourseConditionUpdateRequest = Partial<CourseConditionCreateRequest>;

/**
 * The server's CourseCondition.ConditionType, exactly.
 *
 * This list was first written from a comment in the DTO that ended "etc.",
 * and three of its eight entries — CART_PATH_ONLY, TEMPORARY_GREEN, WEATHER —
 * are not enum constants. Choosing one produced a 500. Read the enum, not the
 * comment beside it.
 */
export const CONDITION_TYPES = [
  'GREEN_SPEED',
  'GREEN_FIRMNESS',
  'FAIRWAY_FIRMNESS',
  'ROUGH_DENSITY',
  'BUNKER_CONDITION',
  'COURSE_MOISTURE',
  'COURSE_OVERALL',
  'WEATHER_IMPACT',
  'OTHER',
] as const;

export const SEVERITIES = ['LOW', 'MODERATE', 'HIGH', 'CRITICAL'] as const;

// ─── Green conditions ────────────────────────────────────────────────────────

export interface GreenCondition {
  id: number;
  courseId: number;
  holeNumber: number;
  stimpmeterReading?: number;
  firmness?: string;
  moisture?: string;
  effectiveFrom: string;
  expiresAt?: string;
  publishedBy?: string;
  dataQuality?: DataQuality;
}

export interface GreenConditionCreateRequest {
  stimpmeter?: number;
  firmness?: string;
  moisture?: string;
  effectiveFrom: string;
  expiresAt?: string;
}

export type GreenConditionUpdateRequest = Partial<GreenConditionCreateRequest>;

export const FIRMNESS = ['SOFT', 'MEDIUM', 'FIRM', 'HARD'] as const;
export const MOISTURE = ['DRY', 'NORMAL', 'WET', 'SATURATED'] as const;

/** The server validates this range; the form should not let it be broken. */
export const STIMPMETER_MIN = 6;
export const STIMPMETER_MAX = 14;
