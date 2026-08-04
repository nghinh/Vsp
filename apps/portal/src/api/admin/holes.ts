/**
 * API client for Hole Admin endpoints.
 * Per Story 8.1 Slice 2.
 *
 * Endpoints:
 *   POST   /admin/courses/{courseId}/holes     — create hole
 *   GET    /admin/courses/{courseId}/holes     — list holes
 *   GET    /admin/holes/{holeId}              — get hole
 *   PUT    /admin/holes/{holeId}              — update hole
 *   DELETE /admin/holes/{holeId}              — delete hole
 */

import type {
  HoleCreateRequest,
  HoleUpdateRequest,
  HoleResponse,
} from '@/types/admin/hole';
import type { ApiError } from '@/types/admin/facility';

const BASE = import.meta.env.VITE_API_BASE_URL ?? 'https://api.vsp.local';

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

export class HoleAdminApi {
  constructor(private baseUrl: string = BASE) {}

  /**
   * Create a new hole under a course.
   * Requires COURSE_ADMIN or SUPER_ADMIN role.
   */
  async createHole(
    courseId: number,
    request: HoleCreateRequest,
    token: string
  ): Promise<HoleResponse> {
    const res = await fetch(`${this.baseUrl}/admin/courses/${courseId}/holes`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify(request),
    });
    return handleResponse<HoleResponse>(res);
  }

  /**
   * List all holes under a course.
   * Requires COURSE_ADMIN or SUPER_ADMIN role.
   */
  async listHoles(courseId: number, token: string): Promise<HoleResponse[]> {
    const res = await fetch(`${this.baseUrl}/admin/courses/${courseId}/holes`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    return handleResponse<HoleResponse[]>(res);
  }

  /**
   * Get a hole by ID.
   * Requires COURSE_ADMIN or SUPER_ADMIN role.
   */
  async getHole(holeId: number, token: string): Promise<HoleResponse> {
    const res = await fetch(`${this.baseUrl}/admin/holes/${holeId}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    return handleResponse<HoleResponse>(res);
  }

  /**
   * Update a hole (partial update).
   * Requires COURSE_ADMIN or SUPER_ADMIN role.
   */
  async updateHole(
    holeId: number,
    request: HoleUpdateRequest,
    token: string
  ): Promise<HoleResponse> {
    const res = await fetch(`${this.baseUrl}/admin/holes/${holeId}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify(request),
    });
    return handleResponse<HoleResponse>(res);
  }

  /**
   * Delete a hole.
   * Requires SUPER_ADMIN role.
   * Note: backend currently returns 501 — not implemented.
   */
  async deleteHole(holeId: number, token: string): Promise<void> {
    const res = await fetch(`${this.baseUrl}/admin/holes/${holeId}`, {
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

export const holeAdminApi = new HoleAdminApi();
