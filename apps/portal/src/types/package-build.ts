/**
 * TypeScript types for package build job API responses.
 * These mirror the OpenAPI schemas from Story 4.2 PKG-PUBLISH-3.
 */

export interface PackageBuildJobDto {
  jobId: string;
  courseId: number;
  dataVersionId: number;
  manifestVersion: string | null;
  status: PackageBuildStatus;
  createdAt: string; // ISO-8601
  startedAt: string | null;
  completedAt: string | null;
  errorCode: string | null;
  errorMessage: string | null;
  errorDetail: string | null;
  triggeredBy: string;
  buildDurationMs: number | null;
}

export type PackageBuildStatus =
  | 'QUEUED'
  | 'VALIDATING'
  | 'BUILDING'
  | 'ASSEMBLING'
  | 'UPLOADING'
  | 'PUBLISHING'
  | 'COMPLETED'
  | 'FAILED';

export interface TriggerBuildRequest {
  dataVersionId: number;
  triggeredBy: string;
}

export interface TriggerBuildResponse {
  jobId: string;
}

export interface PackageBuildJobListResponse {
  jobs: PackageBuildJobDto[];
  total: number;
  page: number;
  pageSize: number;
}

export interface ApiError {
  code: string;
  message: string;
  correlationId: string;
  field?: string;
  details?: Array<{ key: string; value: string }>;
}
