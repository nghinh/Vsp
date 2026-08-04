/**
 * TypeScript types for course version API endpoints.
 * Per Story 8.4 AC-1, AC-2, AC-3: version listing, impact preview, and rollback.
 */

export type DataVersionStatus = 'DRAFT' | 'PUBLISHED' | 'ARCHIVED';

/**
 * DTO for a single course version returned by GET /courses/{courseId}/versions
 * and GET /courses/{courseId}/versions/{versionId}.
 * Mirrors CourseVersionDto on the backend.
 */
export interface CourseVersionDto {
  id: number;
  versionNumber: number;
  status: DataVersionStatus;
  publishedAt: string | null; // ISO-8601, null if never published
  publishedBy: string | null;
  publishNote: string | null;
  rollbackNote: string | null;
  createdAt: string; // ISO-8601
}

/**
 * Paginated list of versions returned by GET /courses/{courseId}/versions.
 * Mirrors PageResponse<CourseVersionDto> on the backend.
 */
export interface VersionListResponse {
  content: CourseVersionDto[];
  page: number;
  size: number;
  totalElements: number;
  totalPages: number;
  first: boolean;
  last: boolean;
}

/**
 * Impact preview returned by GET /courses/{courseId}/versions/rollback-impact.
 * Describes what would change if rollback to targetVersionId were executed.
 */
export interface RollbackImpactDto {
  currentVersion: CourseVersionDto | null; // the version being replaced (null if none published)
  targetVersion: CourseVersionDto;         // the version that would be re-activated
  changesSummary: string;                  // human-readable description of the change
}

/**
 * Request body for POST /courses/{courseId}/versions/{versionId}/rollback.
 */
export interface RollbackRequest {
  rollbackNote: string; // required; the reason for rollback
}

/**
 * Response returned after a successful rollback.
 * Mirrors RollbackResponse on the backend.
 */
export interface RollbackResponse {
  newJobId: string; // UUID of the triggered package build job
  versionId: number;
  versionNumber: number;
}

/**
 * Standard API error shape returned by the VSP backend.
 */
export interface ApiError {
  code: string;
  message: string;
  correlationId?: string;
  field?: string;
  details?: Array<{ key: string; value: string }>;
}
