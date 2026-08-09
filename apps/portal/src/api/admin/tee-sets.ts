/**
 * API client for TeeSet Admin endpoints.
 * Per Story 8.1 Slice 2.
 *
 * Endpoints:
 *   POST   /admin/courses/{courseId}/tee-sets    — create tee set
 *   GET    /admin/courses/{courseId}/tee-sets    — list tee sets
 *   GET    /admin/tee-sets/{teeSetId}           — get tee set (not implemented in backend)
 *   PUT    /admin/tee-sets/{teeSetId}           — update tee set (not implemented in backend)
 *   DELETE /admin/tee-sets/{teeSetId}           — delete tee set (not implemented in backend)
 */

import type {
  TeeSetCreateRequest,
  TeeSetUpdateRequest,
  TeeSetResponse,
} from '@/types/admin/tee-set';
import type { ApiError } from '@/types/admin/facility';
import { API_BASE } from '../base';

const BASE = API_BASE;

async function handleResponse<T>(res: Response): Promise<T> {
  if (!res.ok) {
    const err: ApiError = await res.json().catch(() => ({
      code: 'UNKNOWN',
      message: res.statusText,
    }));
    throw err;
  }
  return res.json() as Promise<T>;
}

export class TeeSetAdminApi {
  constructor(private baseUrl: string = BASE) {}

  /**
   * Create a new tee set under a course.
   * Requires COURSE_ADMIN or SUPER_ADMIN role.
   */
  async createTeeSet(
    courseId: number,
    request: TeeSetCreateRequest,
    token: string
  ): Promise<TeeSetResponse> {
    const res = await fetch(`${this.baseUrl}/admin/courses/${courseId}/tee-sets`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify(request),
    });
    return handleResponse<TeeSetResponse>(res);
  }

  /**
   * List all tee sets under a course.
   * Requires COURSE_ADMIN or SUPER_ADMIN role.
   */
  async listTeeSets(courseId: number, token: string): Promise<TeeSetResponse[]> {
    const res = await fetch(`${this.baseUrl}/admin/courses/${courseId}/tee-sets`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    return handleResponse<TeeSetResponse[]>(res);
  }

  /**
   * Get a tee set by ID.
   * Note: backend does not implement this — use list and filter.
   */
  async getTeeSet(teeSetId: number, token: string): Promise<TeeSetResponse> {
    const res = await fetch(`${this.baseUrl}/admin/tee-sets/${teeSetId}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    return handleResponse<TeeSetResponse>(res);
  }

  /**
   * Update a tee set (partial update).
   * Note: backend does not implement this — returns 501.
   */
  async updateTeeSet(
    teeSetId: number,
    request: TeeSetUpdateRequest,
    token: string
  ): Promise<TeeSetResponse> {
    const res = await fetch(`${this.baseUrl}/admin/tee-sets/${teeSetId}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify(request),
    });
    return handleResponse<TeeSetResponse>(res);
  }

  /**
   * Delete a tee set.
   * Note: backend does not implement this — returns 501.
   */
  async deleteTeeSet(teeSetId: number, token: string): Promise<void> {
    const res = await fetch(`${this.baseUrl}/admin/tee-sets/${teeSetId}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!res.ok) {
      const err: ApiError = await res.json().catch(() => ({
        code: 'UNKNOWN',
        message: res.statusText,
      }));
      throw err;
    }
  }
}

export const teeSetAdminApi = new TeeSetAdminApi();
