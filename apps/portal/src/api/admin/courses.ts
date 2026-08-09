/**
 * API client for Course Admin endpoints.
 * Per Story 8.1 Slice 2.
 *
 * Endpoints:
 *   POST   /admin/facilities/{facilityId}/courses  — create course
 *   GET    /admin/facilities/{facilityId}/courses  — list courses
 *   GET    /admin/courses/{courseId}               — get course
 *   PUT    /admin/courses/{courseId}                — update course
 *   DELETE /admin/courses/{courseId}                — delete course
 */

import type {
  CourseCreateRequest,
  CourseUpdateRequest,
  CourseResponse,
} from '@/types/admin/course';
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

export class CourseAdminApi {
  constructor(private baseUrl: string = BASE) {}

  /**
   * Create a new course under a facility.
   * Requires COURSE_ADMIN or SUPER_ADMIN role.
   */
  async createCourse(
    facilityId: number,
    request: CourseCreateRequest,
    token: string
  ): Promise<CourseResponse> {
    const res = await fetch(`${this.baseUrl}/admin/facilities/${facilityId}/courses`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify(request),
    });
    return handleResponse<CourseResponse>(res);
  }

  /**
   * List all courses under a facility.
   * Requires COURSE_ADMIN or SUPER_ADMIN role.
   */
  async listCourses(facilityId: number, token: string): Promise<CourseResponse[]> {
    const res = await fetch(`${this.baseUrl}/admin/facilities/${facilityId}/courses`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    return handleResponse<CourseResponse[]>(res);
  }

  /**
   * Get a course by ID.
   * Requires COURSE_ADMIN or SUPER_ADMIN role.
   */
  async getCourse(courseId: number, token: string): Promise<CourseResponse> {
    const res = await fetch(`${this.baseUrl}/admin/courses/${courseId}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    return handleResponse<CourseResponse>(res);
  }

  /**
   * Update a course (partial update).
   * Requires COURSE_ADMIN or SUPER_ADMIN role.
   */
  async updateCourse(
    courseId: number,
    request: CourseUpdateRequest,
    token: string
  ): Promise<CourseResponse> {
    const res = await fetch(`${this.baseUrl}/admin/courses/${courseId}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify(request),
    });
    return handleResponse<CourseResponse>(res);
  }

  /**
   * Delete a course.
   * Requires SUPER_ADMIN role.
   * Note: backend currently returns 501 — not implemented.
   */
  async deleteCourse(courseId: number, token: string): Promise<void> {
    const res = await fetch(`${this.baseUrl}/admin/courses/${courseId}`, {
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

export const courseAdminApi = new CourseAdminApi();
