import { API_BASE } from './base';

/**
 * API client for course version endpoints.
 * Base URL is injected from environment; this module does not handle auth tokens —
 * the parent apiClient instance holds the bearer token.
 *
 * Per Story 8.4 AC-1, AC-2, AC-3:
 * - GET  /courses/{courseId}/versions                        — list all versions
 * - GET  /courses/{courseId}/versions/{versionId}           — get version detail
 * - GET  /courses/{courseId}/versions/rollback-impact       — preview rollback impact
 * - POST /courses/{courseId}/versions/{versionId}/rollback  — execute rollback
 */

import type {
  CourseVersionDto,
  VersionListResponse,
  RollbackImpactDto,
  RollbackRequest,
  RollbackResponse,
  ApiError,
} from '@/types/course-version';

const BASE = API_BASE;

/** Parses error response or falls back to a generic error object. */
async function parseError(res: Response): Promise<ApiError> {
  return await res.json().catch(() => ({
    code: 'UNKNOWN',
    message: res.statusText,
  }));
}

export class CourseVersionApi {
  constructor(private baseUrl: string = BASE) {}

  /**
   * List all versions for a course (newest first).
   *
   * GET /courses/{courseId}/versions?page=0&size=20
   */
  async listVersions(
    courseId: number,
    token: string,
    page = 0,
    pageSize = 20
  ): Promise<VersionListResponse> {
    const url = `${this.baseUrl}/courses/${courseId}/versions?page=${page}&size=${pageSize}`;
    const res = await fetch(url, {
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
    });

    if (!res.ok) {
      const err: ApiError = await res.json().catch(() => ({ code: 'UNKNOWN', message: res.statusText }));
      throw err;
    }

    return res.json() as Promise<VersionListResponse>;
  }

  /**
   * Get a single version with full metadata.
   *
   * GET /courses/{courseId}/versions/{versionId}
   */
  async getVersion(courseId: number, versionId: number, token: string): Promise<CourseVersionDto> {
    const res = await fetch(`${this.baseUrl}/courses/${courseId}/versions/${versionId}`, {
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
    });

    if (!res.ok) {
      throw await parseError(res);
    }

    return res.json() as Promise<CourseVersionDto>;
  }

  /**
   * Preview what would change if a rollback were executed to the target version.
   *
   * GET /courses/{courseId}/versions/rollback-impact?targetVersionId={id}
   */
  async getRollbackImpact(
    courseId: number,
    targetVersionId: number,
    token: string
  ): Promise<RollbackImpactDto> {
    const url = `${this.baseUrl}/courses/${courseId}/versions/rollback-impact?targetVersionId=${targetVersionId}`;
    const res = await fetch(url, {
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
    });

    if (!res.ok) {
      throw await parseError(res);
    }

    return res.json() as Promise<RollbackImpactDto>;
  }

  /**
   * Execute a rollback — re-activates an archived version as the current published version.
   *
   * POST /courses/{courseId}/versions/{versionId}/rollback
   *
   * Per Story 8.4 AC-2: rollback creates a new published version, never deletes history.
   * Per Story 8.4 AC-3: new package generation and audit record are triggered.
   */
  async executeRollback(
    courseId: number,
    versionId: number,
    request: RollbackRequest,
    token: string
  ): Promise<RollbackResponse> {
    const res = await fetch(`${this.baseUrl}/courses/${courseId}/versions/${versionId}/rollback`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(request),
    });

    if (!res.ok) {
      throw await parseError(res);
    }

    return res.json() as Promise<RollbackResponse>;
  }
}

export const courseVersionApi = new CourseVersionApi();
