/**
 * TypeScript types for Course Version Publish API (Story 8.3 PUBLISH-PORTAL).
 * Mirror the OpenAPI schemas from packages/contracts/schemas/course.yaml.
 */

import type { ApiError } from './package-build';

// ─── Validation ────────────────────────────────────────────────────────────────

export type ValidationResultCode =
  | 'VALID'
  | 'GEOMETRY_INVALID'
  | 'METADATA_MISSING'
  | 'LICENSE_MISSING'
  | 'QUALITY_INSUFFICIENT'
  | 'SOURCE_MISSING'
  | 'VALIDATION_ERROR';

export interface ValidationError {
  entity: string;
  entityId: number;
  field: string;
  code: ValidationResultCode;
  message: string;
}

export interface ValidationWarning {
  entity: string;
  entityId: number;
  field: string;
  code: string;
  message: string;
}

export interface ValidationResponse {
  versionId: number;
  result: ValidationResultCode;
  errors: ValidationError[];
  warnings: ValidationWarning[];
}

// ─── Version Diff ──────────────────────────────────────────────────────────────

export type ChangeType = 'ADDED' | 'REMOVED' | 'CHANGED';

export interface VersionDiffEntry {
  entity: string;
  entityId: number;
  field: string;
  changeType: ChangeType;
  oldValue: string | null;
  newValue: string | null;
}

export interface VersionDiff {
  draftVersionId: number;
  publishedVersionId: number | null;
  added: VersionDiffEntry[];
  removed: VersionDiffEntry[];
  changed: VersionDiffEntry[];
}

// ─── Publish ───────────────────────────────────────────────────────────────────

export interface PublishRequest {
  publishNote: string;
  forcePublish?: boolean;
}

export interface PublishResponse {
  newVersionId: number;
  status: 'PUBLISHED';
  auditId: string;
  buildJobId: string;
  publishedAt: string; // ISO-8601
}

// ─── API Error ─────────────────────────────────────────────────────────────────

export interface PublishApiError extends ApiError {
  code:
    | 'VERSION_NOT_FOUND'
    | 'VALIDATION_FAILED'
    | 'PUBLISH_FORBIDDEN'
    | 'BUILD_JOB_QUEUED'
    | 'UNKNOWN';
}
