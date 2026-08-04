/**
 * TypeScript types for Facility Admin API.
 * Mirror the backend DTOs from Story 8.1 Slice 1.
 */

/** Data quality metadata — accuracy class and verification status. */
export interface DataQuality {
  accuracyClass: string | null;    // A, B, C, D
  verificationStatus: string | null; // VERIFIED, PENDING_REVIEW, UNVERIFIED, REJECTED
}

/** Full facility response DTO. */
export interface FacilityResponse {
  id: number;
  name: string;
  address: string | null;
  phone: string | null;
  website: string | null;
  /** WKT geometry string (SRID 4326) */
  location: string | null;
  dataQuality: DataQuality | null;
  createdAt: string; // ISO-8601
  updatedAt: string; // ISO-8601
}

/** Request to create a new facility. */
export interface FacilityCreateRequest {
  name: string;
  address?: string;
  phone?: string;
  website?: string;
  /** WKT geometry string (SRID 4326) */
  location?: string;
}

/** Request to update a facility (partial update). */
export interface FacilityUpdateRequest {
  name?: string;
  address?: string;
  phone?: string;
  website?: string;
  /** WKT geometry string (SRID 4326) */
  location?: string;
}

/** API error response shape (shared across all admin endpoints). */
export interface ApiError {
  code: string;
  message: string;
  correlationId?: string;
  field?: string;
  details?: Record<string, unknown>;
}
