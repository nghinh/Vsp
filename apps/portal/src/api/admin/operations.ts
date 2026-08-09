/**
 * API client for the greenkeeping endpoints.
 *
 *   POST/PUT/GET  /admin/courses/{courseId}/holes/{holeNumber}/pins
 *   GET           /admin/courses/{courseId}/pins
 *   POST/PUT/GET  /admin/courses/{courseId}/conditions
 *   POST/PUT/GET  /admin/courses/{courseId}/holes/{holeNumber}/green-conditions
 *   GET           /admin/courses/{courseId}/green-conditions
 *
 * All of these existed on the server with nothing calling them. The portal
 * pages that should have were placeholders naming endpoints that do not
 * exist — `/courses/{id}/pin-positions`, `/courses/{id}/alerts` — missing the
 * `/admin` prefix and, in the pin case, the whole path shape. Anyone checking
 * whether the API was ready would have concluded it was not.
 */

import type {
  CourseCondition,
  CourseConditionCreateRequest,
  CourseConditionUpdateRequest,
  GreenCondition,
  GreenConditionCreateRequest,
  GreenConditionUpdateRequest,
  PinPosition,
  PinPositionCreateRequest,
  PinPositionUpdateRequest,
} from '@/types/admin/operations';
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
  if (res.status === 204) return undefined as T;
  return res.json() as Promise<T>;
}

function auth(token: string): HeadersInit {
  return {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${token}`,
  };
}

export class OperationsApi {
  constructor(private baseUrl: string = BASE) {}

  // ─── Pin positions ─────────────────────────────────────────────────────

  /** Every pin on the course, current and scheduled. */
  async listCoursePins(courseId: number, token: string): Promise<PinPosition[]> {
    const res = await fetch(`${this.baseUrl}/admin/courses/${courseId}/pins`, {
      headers: auth(token),
    });
    return handleResponse<PinPosition[]>(res);
  }

  async listHolePins(
    courseId: number,
    holeNumber: number,
    token: string,
  ): Promise<PinPosition[]> {
    const res = await fetch(
      `${this.baseUrl}/admin/courses/${courseId}/holes/${holeNumber}/pins`,
      { headers: auth(token) },
    );
    return handleResponse<PinPosition[]>(res);
  }

  async createPin(
    courseId: number,
    holeNumber: number,
    request: PinPositionCreateRequest,
    token: string,
  ): Promise<PinPosition> {
    const res = await fetch(
      `${this.baseUrl}/admin/courses/${courseId}/holes/${holeNumber}/pins`,
      { method: 'POST', headers: auth(token), body: JSON.stringify(request) },
    );
    return handleResponse<PinPosition>(res);
  }

  async updatePin(
    courseId: number,
    holeNumber: number,
    pinId: number,
    request: PinPositionUpdateRequest,
    token: string,
  ): Promise<PinPosition> {
    const res = await fetch(
      `${this.baseUrl}/admin/courses/${courseId}/holes/${holeNumber}/pins/${pinId}`,
      { method: 'PUT', headers: auth(token), body: JSON.stringify(request) },
    );
    return handleResponse<PinPosition>(res);
  }

  // ─── Course conditions ─────────────────────────────────────────────────

  async listConditions(
    courseId: number,
    token: string,
  ): Promise<CourseCondition[]> {
    const res = await fetch(
      `${this.baseUrl}/admin/courses/${courseId}/conditions`,
      { headers: auth(token) },
    );
    return handleResponse<CourseCondition[]>(res);
  }

  async createCondition(
    courseId: number,
    request: CourseConditionCreateRequest,
    token: string,
  ): Promise<CourseCondition> {
    const res = await fetch(
      `${this.baseUrl}/admin/courses/${courseId}/conditions`,
      { method: 'POST', headers: auth(token), body: JSON.stringify(request) },
    );
    return handleResponse<CourseCondition>(res);
  }

  async updateCondition(
    courseId: number,
    conditionId: number,
    request: CourseConditionUpdateRequest,
    token: string,
  ): Promise<CourseCondition> {
    const res = await fetch(
      `${this.baseUrl}/admin/courses/${courseId}/conditions/${conditionId}`,
      { method: 'PUT', headers: auth(token), body: JSON.stringify(request) },
    );
    return handleResponse<CourseCondition>(res);
  }

  // ─── Green conditions ──────────────────────────────────────────────────

  async listGreenConditions(
    courseId: number,
    token: string,
  ): Promise<GreenCondition[]> {
    const res = await fetch(
      `${this.baseUrl}/admin/courses/${courseId}/green-conditions`,
      { headers: auth(token) },
    );
    return handleResponse<GreenCondition[]>(res);
  }

  async createGreenCondition(
    courseId: number,
    holeNumber: number,
    request: GreenConditionCreateRequest,
    token: string,
  ): Promise<GreenCondition> {
    const res = await fetch(
      `${this.baseUrl}/admin/courses/${courseId}/holes/${holeNumber}/green-conditions`,
      { method: 'POST', headers: auth(token), body: JSON.stringify(request) },
    );
    return handleResponse<GreenCondition>(res);
  }

  async updateGreenCondition(
    courseId: number,
    holeNumber: number,
    conditionId: number,
    request: GreenConditionUpdateRequest,
    token: string,
  ): Promise<GreenCondition> {
    const res = await fetch(
      `${this.baseUrl}/admin/courses/${courseId}/holes/${holeNumber}/green-conditions/${conditionId}`,
      { method: 'PUT', headers: auth(token), body: JSON.stringify(request) },
    );
    return handleResponse<GreenCondition>(res);
  }
}

export const operationsApi = new OperationsApi();
