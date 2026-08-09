import { API_BASE } from '../base';

/**
 * API client for course alerts.
 *
 *   POST   /admin/alerts                    — send
 *   GET    /admin/alerts                    — list, filtered and paged
 *   GET    /admin/alerts/{id}               — one
 *   PATCH  /admin/alerts/{id}               — edit a pending alert
 *   DELETE /admin/alerts/{id}               — cancel
 *   POST   /admin/alerts/{id}/acknowledge   — mark acknowledged
 *
 * The placeholder page that stood here named `/courses/{courseId}/alerts`,
 * which does not exist. The whole controller does, and had no caller.
 */

const BASE = API_BASE;

export const ALERT_TYPES = ['SAFETY', 'PROMOTION'] as const;
export const ALERT_TARGET_TYPES = ['FACILITY', 'COURSE', 'HOLE', 'FLIGHT', 'GROUP'] as const;
export const DELIVERY_STATUSES = ['PENDING', 'DELIVERED', 'FAILED'] as const;
export const ALERT_PRIORITIES = ['LOW', 'NORMAL', 'HIGH', 'URGENT'] as const;

export type AlertType = (typeof ALERT_TYPES)[number];
export type AlertTargetType = (typeof ALERT_TARGET_TYPES)[number];
export type DeliveryStatus = (typeof DELIVERY_STATUSES)[number];

export interface CourseAlert {
  id: number;
  facilityId?: string;
  courseId?: string;
  holeId?: string;
  flightId?: string;
  groupId?: string;
  alertType: AlertType;
  title: string;
  body: string;
  priority?: number | string;
  effectiveAt?: string;
  expiresAt?: string;
  deliveryStatus?: DeliveryStatus;
  acknowledgmentRequired?: boolean;
  createdAt?: string;
}

export interface CourseAlertCreateRequest {
  facilityId?: string;
  courseId?: string;
  holeId?: string;
  flightId?: string;
  groupId?: string;
  alertType: AlertType;
  title: string;
  body: string;
  effectiveAt?: string;
  expiresAt?: string;
  acknowledgmentRequired?: boolean;
  priority?: string;
}

export type CourseAlertUpdateRequest = Partial<
  Pick<CourseAlertCreateRequest, 'title' | 'body' | 'priority' | 'effectiveAt' | 'expiresAt'>
>;

export interface AlertListFilters {
  alertType?: AlertType;
  targetType?: AlertTargetType;
  targetId?: string;
  deliveryStatus?: DeliveryStatus;
  from?: string;
  to?: string;
}

export interface AlertListResponse {
  alerts: CourseAlert[];
  pagination?: {
    page: number;
    size: number;
    totalElements: number;
    totalPages: number;
  };
}

interface ApiError {
  code: string;
  message: string;
}

async function handleResponse<T>(res: Response): Promise<T> {
  if (!res.ok) {
    const err: ApiError = await res.json().catch(() => ({
      code: 'UNKNOWN',
      message: res.statusText,
    }));
    throw err;
  }
  if (res.status === 204) return undefined as T;
  return res.json() as Promise<T>;
}

function auth(token: string): HeadersInit {
  return { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` };
}

export class AlertApi {
  constructor(private baseUrl: string = BASE) {}

  async list(token: string, filters: AlertListFilters = {}): Promise<AlertListResponse> {
    const params = new URLSearchParams();
    for (const [k, v] of Object.entries(filters)) {
      if (v !== undefined && v !== '') params.set(k, String(v));
    }
    const qs = params.toString();
    const res = await fetch(`${this.baseUrl}/admin/alerts${qs ? `?${qs}` : ''}`, {
      headers: auth(token),
    });
    return handleResponse<AlertListResponse>(res);
  }

  async create(token: string, request: CourseAlertCreateRequest): Promise<CourseAlert> {
    const res = await fetch(`${this.baseUrl}/admin/alerts`, {
      method: 'POST',
      headers: auth(token),
      body: JSON.stringify(request),
    });
    return handleResponse<CourseAlert>(res);
  }

  async update(
    token: string,
    alertId: number,
    request: CourseAlertUpdateRequest,
  ): Promise<CourseAlert> {
    const res = await fetch(`${this.baseUrl}/admin/alerts/${alertId}`, {
      method: 'PATCH',
      headers: auth(token),
      body: JSON.stringify(request),
    });
    return handleResponse<CourseAlert>(res);
  }

  /** Cancel a sent or pending alert. */
  async cancel(token: string, alertId: number): Promise<void> {
    const res = await fetch(`${this.baseUrl}/admin/alerts/${alertId}`, {
      method: 'DELETE',
      headers: auth(token),
    });
    return handleResponse<void>(res);
  }
}

export const alertApi = new AlertApi();
