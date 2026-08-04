/**
 * API client for Tournament Policy endpoints.
 * Per Story 7.4 Slice E + Slice G.
 *
 * Endpoints:
 *   POST   /tournament-policies              — create policy
 *   GET    /tournament-policies/{id}         — get policy
 *   PATCH  /tournament-policies/{id}         — update policy (locked policies require TD role)
 *   POST   /tournament-policies/{id}/lock    — lock policy
 *   GET    /tournament-policies/{id}/changes — get audit history
 */

import type {
  TournamentPolicyCreateRequest,
  TournamentPolicyUpdateRequest,
  TournamentPolicyResponse,
  TournamentPolicyChangeDto,
  ApiError,
} from '@/types/tournament-policy';

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

export class TournamentPolicyApi {
  constructor(private baseUrl: string = BASE) {}

  /**
   * Create a new tournament policy.
   * Requires TournamentDirector role.
   */
  async createPolicy(
    request: TournamentPolicyCreateRequest,
    token: string
  ): Promise<TournamentPolicyResponse> {
    const res = await fetch(`${this.baseUrl}/tournament-policies`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify(request),
    });
    return handleResponse<TournamentPolicyResponse>(res);
  }

  /**
   * Get a tournament policy by ID.
   */
  async getPolicy(policyId: string, token: string): Promise<TournamentPolicyResponse> {
    const res = await fetch(`${this.baseUrl}/tournament-policies/${policyId}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    return handleResponse<TournamentPolicyResponse>(res);
  }

  /**
   * Update a tournament policy (partial update).
   * If the policy is locked, requires TournamentDirector role.
   */
  async updatePolicy(
    policyId: string,
    request: TournamentPolicyUpdateRequest,
    token: string
  ): Promise<TournamentPolicyResponse> {
    const res = await fetch(`${this.baseUrl}/tournament-policies/${policyId}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify(request),
    });
    return handleResponse<TournamentPolicyResponse>(res);
  }

  /**
   * Lock a tournament policy (makes it immutable until unlocked).
   * Requires TournamentDirector role.
   */
  async lockPolicy(policyId: string, token: string): Promise<TournamentPolicyResponse> {
    const res = await fetch(`${this.baseUrl}/tournament-policies/${policyId}/lock`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
    });
    return handleResponse<TournamentPolicyResponse>(res);
  }

  /**
   * Get the audit / change history for a tournament policy.
   */
  async getPolicyChanges(
    policyId: string,
    token: string
  ): Promise<TournamentPolicyChangeDto[]> {
    const res = await fetch(`${this.baseUrl}/tournament-policies/${policyId}/changes`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    return handleResponse<TournamentPolicyChangeDto[]>(res);
  }
}

export const tournamentPolicyApi = new TournamentPolicyApi();
