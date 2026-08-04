/**
 * TypeScript types for TeeSet Admin API.
 * Mirror the backend DTOs from Story 8.1 Slice 1.
 */

import type { DataQuality } from './facility';

/** Full tee set response DTO. */
export interface TeeSetResponse {
  id: number;
  courseId: number;
  name: string;
  totalPar: number | null;
  dataQuality: DataQuality | null;
  createdAt: string; // ISO-8601
  updatedAt: string; // ISO-8601
}

/** Request to create a new tee set under a course. */
export interface TeeSetCreateRequest {
  name: string;
  totalPar?: number;
}

/** Request to update a tee set (partial update). */
export interface TeeSetUpdateRequest {
  name?: string;
  totalPar?: number;
}
