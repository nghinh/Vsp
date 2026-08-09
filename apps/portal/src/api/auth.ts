import { API_BASE } from './base';

/**
 * The two calls that establish who the operator is.
 *
 * Both answers come from the API. The portal used to answer the second one
 * itself, in TypeScript, with a hard-coded `["COURSE_ADMIN", "SUPER_ADMIN"]`.
 */

/**
 * Note the default. Every other module under `src/api` defaults to
 * `https://api.vsp.local`, a host that resolves nowhere unless
 * VITE_API_BASE_URL is set; `/api` is what the Vite dev proxy forwards to the
 * running API, and what `useGeometryApi` already uses. Sign-in has to work
 * against a real server or nothing else in the portal can, so it takes the
 * default that does.
 */
const BASE = API_BASE;

/** The API's error envelope: { code, message, correlationId, field? }. */
export interface ApiError {
  code: string;
  message: string;
  correlationId?: string;
  field?: string;
}

/** POST /auth/login. */
export interface LoginResponse {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  tokenType: string;
  userId: number;
  displayName: string | null;
  status: string | null;
}

/** GET /admin/me — the caller's admin identity, as the server sees it. */
export interface AdminIdentity {
  id: number;
  golferAccountId: number;
  mfaEnabled: boolean;
  mfaVerifiedAt: string | null;
  roles: string[];
  createdAt: string;
}

async function parse<T>(res: Response): Promise<T> {
  if (!res.ok) {
    const body: ApiError = await res.json().catch(() => ({
      code: 'UNKNOWN',
      message: res.statusText,
    }));
    throw body;
  }
  return res.json() as Promise<T>;
}

export class PortalAuthApi {
  constructor(private baseUrl: string = BASE) {}

  /** Exchange credentials for a bearer token. */
  async login(identifier: string, password: string): Promise<LoginResponse> {
    const res = await fetch(`${this.baseUrl}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ identifier, password }),
    });
    return parse<LoginResponse>(res);
  }

  /**
   * Ask the server which roles this token carries.
   *
   * A 403 here is the whole answer for a non-operator: `/admin/**` requires
   * some admin role, so an account with none — including a golfer who happens
   * to have an admin account row with no assignments — never reaches the
   * handler. The portal has no business showing anything to a caller the API
   * will refuse on every subsequent request.
   */
  async fetchIdentity(token: string): Promise<AdminIdentity> {
    const res = await fetch(`${this.baseUrl}/admin/me`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    return parse<AdminIdentity>(res);
  }
}

export const portalAuthApi = new PortalAuthApi();
