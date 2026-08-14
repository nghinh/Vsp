/**
 * TypeScript types for Course Admin API.
 * Mirror the backend DTOs from Story 8.1 Slice 1.
 */

import type { DataQuality } from './facility';

/** Summary tee set DTO embedded in CourseResponse. */
export interface TeeSetSummary {
  id: number;
  name: string;
  totalPar: number | null;
  /** Hole number → yardage in meters */
  yardages: Record<number, number>;
  rating: number | null;
  slope: number | null;
  dataQuality: DataQuality | null;
}

/** Full course response DTO. */
export interface CourseResponse {
  id: number;
  facilityId: number;
  name: string;
  holesCount: number | null;
  parTotal: number | null;
  /** WKT geometry string (SRID 4326) */
  location: string | null;
  dataQuality: DataQuality | null;
  teeSets: TeeSetSummary[];
  createdAt: string; // ISO-8601
  updatedAt: string; // ISO-8601
  /**
   * The day this course stopped being offered, or null while it still is.
   *
   * Retired is not deleted: the course and its holes stay, because some of
   * those holes carry measured coordinates that exist on no other course. It
   * simply stops appearing in golfer search and in the round-setup picker.
   */
  retiredOn: string | null;
}

/** Request to create a new course under a facility. */
export interface CourseCreateRequest {
  name: string;
  holesCount?: number;
  parTotal?: number;
  /** WKT geometry string (SRID 4326) */
  location?: string;
}

/** Request to update a course (partial update). */
export interface CourseUpdateRequest {
  name?: string;
  holesCount?: number;
  parTotal?: number;
  /** WKT geometry string (SRID 4326) */
  location?: string;
}
