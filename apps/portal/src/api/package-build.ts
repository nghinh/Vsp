/**
 * API client for package build job endpoints.
 * Base URL is injected from environment; this module does not handle auth tokens —
 * the parent apiClient instance holds the bearer token.
 */

import type {
  PackageBuildJobDto,
  PackageBuildJobListResponse,
  TriggerBuildRequest,
  TriggerBuildResponse,
} from '@/types/package-build';

const BASE = import.meta.env.VITE_API_BASE_URL ?? 'https://api.vsp.local';

export class PackageBuildApi {
  constructor(private baseUrl: string = BASE) {}

  /**
   * Trigger a package build for a course.
   * Idempotent — returns existing job ID if build already in progress.
   */
  async triggerBuild(
    courseId: number,
    request: TriggerBuildRequest,
    token: string
  ): Promise<TriggerBuildResponse> {
    const res = await fetch(`${this.baseUrl}/courses/${courseId}/packages/build`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify(request),
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({ code: 'UNKNOWN', message: res.statusText }));
      throw err;
    }

    return res.json() as Promise<TriggerBuildResponse>;
  }

  /**
   * List all build jobs for a course (newest first).
   */
  async listBuildJobs(
    courseId: number,
    token: string,
    page = 0,
    pageSize = 20
  ): Promise<PackageBuildJobListResponse> {
    const res = await fetch(
      `${this.baseUrl}/courses/${courseId}/packages/build/jobs?page=${page}&pageSize=${pageSize}`,
      {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      }
    );

    if (!res.ok) {
      const err = await res.json().catch(() => ({ code: 'UNKNOWN', message: res.statusText }));
      throw err;
    }

    return res.json() as Promise<PackageBuildJobListResponse>;
  }

  /**
   * Get a specific build job by ID.
   */
  async getBuildJob(courseId: number, jobId: string, token: string): Promise<PackageBuildJobDto> {
    const res = await fetch(`${this.baseUrl}/courses/${courseId}/packages/build/jobs/${jobId}`, {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({ code: 'UNKNOWN', message: res.statusText }));
      throw err;
    }

    return res.json() as Promise<PackageBuildJobDto>;
  }
}

export const packageBuildApi = new PackageBuildApi();
