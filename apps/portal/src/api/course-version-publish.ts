import { API_BASE } from './base';

/**
 * API client for Course Version Publish endpoints (Story 8.3 PUBLISH-PORTAL).
 *
 * Endpoints:
 *   POST /courses/{courseId}/versions/{versionId}/validate  → ValidationResponse
 *   GET  /courses/{courseId}/versions/{versionId}/diff       → VersionDiff
 *   POST /courses/{courseId}/versions/{versionId}/publish   → PublishResponse
 *
 * These carried an `/admin` prefix that CourseVersionController has never had,
 * and the three handlers did not exist at all — so Story 8.3's publish flow was
 * a registered route with live UI and three 404s underneath. The prefix is gone
 * and the handlers now exist.
 *
 * Task 4: Loading, error, retry, offline, accessibility, authorization, audit behavior.
 * - Retries with exponential backoff on network failures (3 attempts: 1s, 2s, 4s)
 * - Detects offline state via navigator.onLine before each request
 * - Maps HTTP error status codes to structured error codes for portal UX
 */

import type {
  ValidationResponse,
  VersionDiff,
  PublishRequest,
  PublishResponse,
  PublishApiError,
} from '@/types/course-version-publish';

const BASE = API_BASE;

const MAX_RETRIES = 3;
const BASE_DELAY_MS = 1000;

/**
 * Offline error — thrown when navigator.onLine is false before a request.
 * Portal components catch this and display a user-friendly offline message.
 */
export class OfflineError extends Error {
  readonly code: string = 'OFFLINE';
  readonly correlationId: string = '';
  readonly message =
    'Mất kết nối mạng. Hãy kiểm tra đường truyền rồi thử lại.';
}

/**
 * Check browser online status.
 * Falls back to true for SSR/worker environments where navigator is unavailable.
 */
function isOnline(): boolean {
  return typeof navigator !== 'undefined' ? navigator.onLine : true;
}

/**
 * Determine if a fetch error is retryable (network-level, not HTTP-level).
 * AbortError (timeout/cancellation) and TypeError (DNS failure, no route) are retryable.
 * HTTP 4xx responses are NOT retryable.
 */
function isRetryable(err: unknown): boolean {
  if (err instanceof OfflineError) return false; // already checked online
  if (err instanceof TypeError) return true; // network failure (CORS, DNS, no route)
  if (err instanceof DOMException && err.name === 'AbortError') return true;
  return false;
}

/**
 * Sleep utility for retry delays.
 */
function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Fetch with exponential-backoff retry on network failures.
 * Throws OfflineError before attempting if the browser is offline.
 * HTTP error responses (4xx/5xx) are returned normally — handleResponse decides what to throw.
 */
async function fetchWithRetry(
  url: string,
  options: RequestInit,
  retries = MAX_RETRIES,
  delayMs = BASE_DELAY_MS
): Promise<Response> {
  if (!isOnline()) {
    throw new OfflineError();
  }

  let lastError: unknown;

  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const res = await fetch(url, options);
      return res;
    } catch (err) {
      lastError = err;

      // Do not retry on last attempt
      if (attempt === retries) break;

      // Abort/type errors are retryable; HTTP responses already returned above
      if (!isRetryable(err)) throw err;

      // Exponential backoff: 1s → 2s → 4s
      await sleep(delayMs * Math.pow(2, attempt));
    }
  }

  // All retries exhausted — surface the last error with a descriptive wrapper
  const msg =
    lastError instanceof Error ? lastError.message : 'Gọi lại nhiều lần vẫn thất bại';
  const wrapped = new Error(`Retry exhausted: ${msg}`);
  (wrapped as Error & { cause: unknown }).cause = lastError;
  throw wrapped;
}

/**
 * Map HTTP status code to a structured PublishApiError code.
 * Used when the response is not ok to give the portal actionable error codes.
 */
function mapStatusToCode(status: number): PublishApiError['code'] {
  switch (status) {
    case 401:
    case 403:
      return 'PUBLISH_FORBIDDEN'; // covers auth and authz failures
    case 404:
      return 'VERSION_NOT_FOUND';
    case 409:
      return 'PUBLISH_FORBIDDEN'; // version already published or conflict
    case 422:
      return 'VALIDATION_FAILED'; // business rule violation
    default:
      return 'UNKNOWN';
  }
}

async function handleResponse<T>(res: Response): Promise<T> {
  if (!res.ok) {
    // Try to parse structured API error; fall back to a mapped code + raw status text
    let code: PublishApiError['code'] = 'UNKNOWN';
    let message = res.statusText;
    let correlationId = '';

    try {
      const body = (await res.json()) as {
        code?: string;
        message?: string;
        correlationId?: string;
      };
      code = (body.code as PublishApiError['code']) ?? mapStatusToCode(res.status);
      message = body.message ?? res.statusText;
      correlationId = body.correlationId ?? '';
    } catch {
      // Not JSON — use mapped code from status
      code = mapStatusToCode(res.status);
      correlationId = '';
    }

    const err: PublishApiError = {
      code,
      message,
      correlationId,
    };
    throw err;
  }
  return res.json() as Promise<T>;
}

export class CourseVersionPublishApi {
  constructor(private baseUrl: string = BASE) {}

  /**
   * Validate a draft course version before publishing.
   * Runs geometry validity, metadata, source, license, and quality checks.
   * Per Story 8.3 AC-1.
   *
   * Retry: 3 attempts on network failure.
   * Error codes: VERSION_NOT_FOUND, VALIDATION_FAILED, UNKNOWN.
   */
  async validate(
    courseId: number,
    versionId: number,
    token: string
  ): Promise<ValidationResponse> {
    const res = await fetchWithRetry(
      `${this.baseUrl}/courses/${courseId}/versions/${versionId}/validate`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
      }
    );
    return handleResponse<ValidationResponse>(res);
  }

  /**
   * Get the diff between a draft version and the latest published version.
   * Shows added, removed, and changed entities with field-level detail.
   * Per Story 8.3 AC-2.
   *
   * Retry: 3 attempts on network failure.
   * Error codes: VERSION_NOT_FOUND, UNKNOWN.
   */
  async getDiff(
    courseId: number,
    versionId: number,
    token: string
  ): Promise<VersionDiff> {
    const res = await fetchWithRetry(
      `${this.baseUrl}/courses/${courseId}/versions/${versionId}/diff`,
      {
        headers: { Authorization: `Bearer ${token}` },
      }
    );
    return handleResponse<VersionDiff>(res);
  }

  /**
   * Publish a draft course version, making it immutable.
   * Orchestrates: validate → diff → immutable snapshot → audit log → build job.
   * Per Story 8.3 AC-3.
   *
   * Retry: 3 attempts on network failure (publish is idempotent via versionId).
   * Error codes: VERSION_NOT_FOUND, VALIDATION_FAILED, PUBLISH_FORBIDDEN, UNKNOWN.
   */
  async publish(
    courseId: number,
    versionId: number,
    request: PublishRequest,
    token: string
  ): Promise<PublishResponse> {
    const res = await fetchWithRetry(
      `${this.baseUrl}/courses/${courseId}/versions/${versionId}/publish`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify(request),
      }
    );
    return handleResponse<PublishResponse>(res);
  }
}

export const courseVersionPublishApi = new CourseVersionPublishApi();
