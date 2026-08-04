/**
 * TypeScript types for Hole Admin API.
 * Mirror the backend DTOs from Story 8.1 Slice 1.
 */

import type { DataQuality } from './facility';

/** Full hole response DTO. */
export interface HoleResponse {
  id: number;
  courseId: number;
  holeNumber: number;
  par: number;
  /** WKT POINT string (SRID 4326) */
  teeingGroundLocation: string | null;
  /** WKT POINT string (SRID 4326) */
  greenLocation: string | null;
  playingLengthMeters: number | null;
  dataQuality: DataQuality | null;
  teeBoxesCount: number;
  createdAt: string; // ISO-8601
  updatedAt: string; // ISO-8601
}

/** Request to create a new hole under a course. */
export interface HoleCreateRequest {
  holeNumber: number;
  par: number;
  /** WKT POINT string (SRID 4326) */
  teeingGroundLocation?: string;
  /** WKT POINT string (SRID 4326) */
  greenLocation?: string;
  playingLengthMeters?: number;
}

/** Request to update a hole (partial update). */
export interface HoleUpdateRequest {
  holeNumber?: number;
  par?: number;
  /** WKT POINT string (SRID 4326) */
  teeingGroundLocation?: string;
  /** WKT POINT string (SRID 4326) */
  greenLocation?: string;
  playingLengthMeters?: number;
}
