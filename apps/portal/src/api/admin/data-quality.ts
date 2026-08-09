import { API_BASE } from '../base';

/**
 * API client for Data Quality Admin endpoints.
 * Per Story 9.4 Wave 2.
 *
 * Endpoints:
 *   GET  /admin/data-quality/metrics  — geometry completeness, verified courses,
 *                                       Class A/B coverage, correction volume, resolution time
 *   GET  /admin/data-quality/stale    — stale pin, green speed, course condition records
 *   GET  /admin/data-quality/export   — CSV/XLSX export of metrics + stale records
 */

import type {
  DataQualityMetrics,
  StaleRecord,
  DataQualityQuery,
  ApiError,
} from '@/types/admin/data-quality';

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

export class DataQualityAdminApi {
  constructor(private baseUrl: string = BASE) {}

  /**
   * Fetch data quality metrics for the given filter criteria.
   * Requires COURSE_ADMIN, SUPER_ADMIN, or AUDITOR role.
   */
  async getMetrics(query: DataQualityQuery, token: string): Promise<DataQualityMetrics> {
    const params = new URLSearchParams({
      from: query.from,
      to: query.to,
    });
    if (query.facilityId != null) params.set('facilityId', String(query.facilityId));
    if (query.courseId != null) params.set('courseId', String(query.courseId));

    const res = await fetch(`${this.baseUrl}/admin/data-quality/metrics?${params}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    return handleResponse<DataQualityMetrics>(res);
  }

  /**
   * Fetch stale pin, green speed, and course condition records.
   * Requires COURSE_ADMIN, SUPER_ADMIN, or AUDITOR role.
   */
  async getStaleRecords(
    facilityId?: number,
    courseId?: number,
    token?: string
  ): Promise<StaleRecord[]> {
    const params = new URLSearchParams();
    if (facilityId != null) params.set('facilityId', String(facilityId));
    if (courseId != null) params.set('courseId', String(courseId));
    const query = params.toString();

    const res = await fetch(`${this.baseUrl}/admin/data-quality/stale${query ? `?${query}` : ''}`, {
      headers: token ? { Authorization: `Bearer ${token}` } : {},
    });
    return handleResponse<StaleRecord[]>(res);
  }

  /**
   * Trigger a CSV/XLSX export download of metrics and stale records.
   * Requires COURSE_ADMIN, SUPER_ADMIN, or AUDITOR role.
   */
  async exportDataQuality(
    query: DataQualityQuery,
    format: 'csv' | 'xlsx' = 'csv',
    token?: string
  ): Promise<string> {
    const params = new URLSearchParams({
      from: query.from,
      to: query.to,
      format,
    });
    if (query.facilityId != null) params.set('facilityId', String(query.facilityId));
    if (query.courseId != null) params.set('courseId', String(query.courseId));

    const res = await fetch(`${this.baseUrl}/admin/data-quality/export?${params}`, {
      headers: token ? { Authorization: `Bearer ${token}` } : {},
    });
    if (!res.ok) {
      const err: ApiError = await res.json().catch(() => ({
        code: 'UNKNOWN',
        message: res.statusText,
      }));
      throw err;
    }
    return res.text();
  }
}

export const dataQualityAdminApi = new DataQualityAdminApi();
