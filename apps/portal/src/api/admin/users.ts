import { API_BASE } from '../base';

/**
 * API client for operator accounts, roles and MFA.
 *
 *   GET    /admin/roles                        — roles that exist
 *   GET    /admin/users                        — operator accounts
 *   POST   /admin/users/{id}/roles             — grant
 *   DELETE /admin/users/{id}/roles/{roleName}  — revoke
 *   POST   /admin/users/{id}/mfa/enroll        — begin enrolment
 *   POST   /admin/users/{id}/mfa/confirm       — confirm with a TOTP code
 *   POST   /admin/users/{id}/mfa/disable       — turn MFA off
 *
 * Every one of these is SUPER_ADMIN only, enforced server-side. The page that
 * calls them can hide what a caller cannot use, but hiding is a courtesy: the
 * refusal is the server's, and it stays the server's.
 */

const BASE = API_BASE;

export const ROLE_NAMES = [
  'SUPER_ADMIN',
  'COURSE_ADMIN',
  'GREENKEEPER',
  'TOURNAMENT_DIRECTOR',
  'CADDIE_MASTER',
  'AUDITOR',
] as const;

export type RoleName = (typeof ROLE_NAMES)[number];

export interface AdminAccount {
  id: number;
  golferAccountId: number;
  mfaEnabled?: boolean;
  mfaVerifiedAt?: string;
  roles: RoleName[];
  createdAt?: string;
}

export interface RoleRecord {
  id: number;
  roleName: RoleName;
  createdAt?: string;
}

/** Secret for manual entry, provisioning URI for a QR code. */
export interface MfaEnrolment {
  secret: string;
  provisioningUri: string;
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

export class UserAdminApi {
  constructor(private baseUrl: string = BASE) {}

  async listRoles(token: string): Promise<RoleRecord[]> {
    const res = await fetch(`${this.baseUrl}/admin/roles`, { headers: auth(token) });
    return handleResponse<RoleRecord[]>(res);
  }

  async listAccounts(token: string): Promise<AdminAccount[]> {
    const res = await fetch(`${this.baseUrl}/admin/users`, { headers: auth(token) });
    return handleResponse<AdminAccount[]>(res);
  }

  async grantRole(
    token: string,
    golferAccountId: number,
    roleName: RoleName,
  ): Promise<AdminAccount> {
    const res = await fetch(`${this.baseUrl}/admin/users/${golferAccountId}/roles`, {
      method: 'POST',
      headers: auth(token),
      body: JSON.stringify({ golferAccountId, roleName }),
    });
    return handleResponse<AdminAccount>(res);
  }

  async revokeRole(
    token: string,
    golferAccountId: number,
    roleName: RoleName,
  ): Promise<AdminAccount> {
    const res = await fetch(
      `${this.baseUrl}/admin/users/${golferAccountId}/roles/${roleName}`,
      { method: 'DELETE', headers: auth(token) },
    );
    return handleResponse<AdminAccount>(res);
  }

  async beginMfaEnrolment(token: string, golferAccountId: number): Promise<MfaEnrolment> {
    const res = await fetch(
      `${this.baseUrl}/admin/users/${golferAccountId}/mfa/enroll`,
      { method: 'POST', headers: auth(token) },
    );
    return handleResponse<MfaEnrolment>(res);
  }

  async confirmMfaEnrolment(
    token: string,
    golferAccountId: number,
    totpCode: string,
  ): Promise<void> {
    const res = await fetch(
      `${this.baseUrl}/admin/users/${golferAccountId}/mfa/confirm`,
      { method: 'POST', headers: auth(token), body: JSON.stringify({ totpCode }) },
    );
    return handleResponse<void>(res);
  }

  async disableMfa(token: string, golferAccountId: number): Promise<void> {
    const res = await fetch(
      `${this.baseUrl}/admin/users/${golferAccountId}/mfa/disable`,
      { method: 'POST', headers: auth(token) },
    );
    return handleResponse<void>(res);
  }
}

export const userAdminApi = new UserAdminApi();
