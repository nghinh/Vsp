/**
 * API client for Facility Admin endpoints.
 * Per Story 8.1 Slice 2.
 *
 * Endpoints:
 *   POST   /admin/facilities              — create facility
 *   GET    /admin/facilities             — list all facilities
 *   GET    /admin/facilities/{id}        — get facility
 *   PUT    /admin/facilities/{id}        — update facility
 *   DELETE /admin/facilities/{id}        — delete facility (SUPER_ADMIN only)
 */

import type {
  FacilityCreateRequest,
  FacilityUpdateRequest,
  FacilityResponse,
  ApiError,
} from '@/types/admin/facility';

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

export class FacilityAdminApi {
  constructor(private baseUrl: string = BASE) {}

  /**
   * Create a new golf facility.
   * Requires COURSE_ADMIN or SUPER_ADMIN role.
   */
  async createFacility(
    request: FacilityCreateRequest,
    token: string
  ): Promise<FacilityResponse> {
    const res = await fetch(`${this.baseUrl}/admin/facilities`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify(request),
    });
    return handleResponse<FacilityResponse>(res);
  }

  /**
   * List all golf facilities.
   * Requires COURSE_ADMIN or SUPER_ADMIN role.
   */
  async listFacilities(token: string): Promise<FacilityResponse[]> {
    const res = await fetch(`${this.baseUrl}/admin/facilities`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    return handleResponse<FacilityResponse[]>(res);
  }

  /**
   * Get a facility by ID.
   * Requires COURSE_ADMIN or SUPER_ADMIN role.
   */
  async getFacility(facilityId: number, token: string): Promise<FacilityResponse> {
    const res = await fetch(`${this.baseUrl}/admin/facilities/${facilityId}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    return handleResponse<FacilityResponse>(res);
  }

  /**
   * Update a facility (partial update).
   * Requires COURSE_ADMIN or SUPER_ADMIN role.
   */
  async updateFacility(
    facilityId: number,
    request: FacilityUpdateRequest,
    token: string
  ): Promise<FacilityResponse> {
    const res = await fetch(`${this.baseUrl}/admin/facilities/${facilityId}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify(request),
    });
    return handleResponse<FacilityResponse>(res);
  }

  /**
   * Delete a facility.
   * Requires SUPER_ADMIN role.
   * Note: backend currently returns 501 — not implemented.
   */
  async deleteFacility(facilityId: number, token: string): Promise<void> {
    const res = await fetch(`${this.baseUrl}/admin/facilities/${facilityId}`, {
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

export const facilityAdminApi = new FacilityAdminApi();
