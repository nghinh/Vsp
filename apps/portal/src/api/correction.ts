import { API_BASE } from './base';

/**
 * API client for correction queue endpoints.
 *
 * Endpoints:
 * - GET  /admin/corrections              — paginated queue with filters
 * - GET  /admin/corrections/{id}        — correction detail
 * - POST /admin/corrections/{id}/review  — apply review action
 * - GET  /admin/corrections/{id}/map-context — official geometry for map overlay
 *
 * Per Story 9.2 AC-1, AC-2, AC-3.
 */

import type {
  CorrectionQueueFilters,
  CorrectionQueueResponse,
  CorrectionDetailResponse,
  CorrectionReviewRequest,
  CorrectionReviewResponse,
  CorrectionMapContext,
  CorrectionApiError,
} from '@/types/correction';

const BASE = API_BASE;

async function parseError(res: Response): Promise<CorrectionApiError> {
  return await res.json().catch(() => ({
    code: 'UNKNOWN',
    message: res.statusText,
  }));
}

export class CorrectionApi {
  constructor(private baseUrl: string = BASE) {}

  /**
   * List corrections with optional filters (paginated).
   *
   * GET /admin/corrections?courseId=&hole=&type=&status=&confidenceMin=&confidenceMax=&from=&to=&page=&size=
   */
  async getQueue(
    token: string,
    filters: CorrectionQueueFilters = {},
    page = 0,
    pageSize = 20
  ): Promise<CorrectionQueueResponse> {
    const params = new URLSearchParams();
    if (filters.courseId != null) params.set('courseId', String(filters.courseId));
    if (filters.holeNumber != null) params.set('hole', String(filters.holeNumber));
    if (filters.type) params.set('type', filters.type);
    if (filters.status) params.set('status', filters.status);
    if (filters.confidenceMin != null) params.set('confidenceMin', String(filters.confidenceMin));
    if (filters.confidenceMax != null) params.set('confidenceMax', String(filters.confidenceMax));
    if (filters.from) params.set('from', filters.from);
    if (filters.to) params.set('to', filters.to);
    params.set('page', String(page));
    params.set('size', String(pageSize));

    const url = `${this.baseUrl}/admin/corrections?${params.toString()}`;
    const res = await fetch(url, {
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
    });

    if (!res.ok) {
      throw await parseError(res);
    }

    return res.json() as Promise<CorrectionQueueResponse>;
  }

  /**
   * Get full correction detail.
   *
   * GET /admin/corrections/{id}
   */
  async getDetail(token: string, id: number): Promise<CorrectionDetailResponse> {
    const url = `${this.baseUrl}/admin/corrections/${id}`;
    const res = await fetch(url, {
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
    });

    if (!res.ok) {
      throw await parseError(res);
    }

    return res.json() as Promise<CorrectionDetailResponse>;
  }

  /**
   * Apply a review action to a correction.
   *
   * POST /admin/corrections/{id}/review
   */
  async review(
    token: string,
    id: number,
    request: CorrectionReviewRequest
  ): Promise<CorrectionReviewResponse> {
    const url = `${this.baseUrl}/admin/corrections/${id}/review`;
    const res = await fetch(url, {
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

    return res.json() as Promise<CorrectionReviewResponse>;
  }

  /**
   * Fetch official geometry for the map overlay comparison.
   *
   * GET /admin/corrections/{id}/map-context
   */
  async getMapContext(token: string, id: number): Promise<CorrectionMapContext> {
    const url = `${this.baseUrl}/admin/corrections/${id}/map-context`;
    const res = await fetch(url, {
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
    });

    if (!res.ok) {
      throw await parseError(res);
    }

    return res.json() as Promise<CorrectionMapContext>;
  }
}

export const correctionApi = new CorrectionApi();
