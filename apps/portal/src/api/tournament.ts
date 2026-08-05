/**
 * Tournament API client for the VSP Portal.
 *
 * Per Story 12.1 Slice G.
 *
 * Endpoints:
 *   GET    /tournaments                 — list tournaments
 *   POST   /tournaments                 — create tournament (TD role)
 *   GET    /tournaments/{id}            — get tournament detail
 *   PATCH  /tournaments/{id}            — update tournament (before inProgress)
 *   POST   /tournaments/{id}/publish   — open registration
 *   POST   /tournaments/{id}/start      — start tournament
 *   POST   /tournaments/{id}/complete  — complete tournament
 *   POST   /tournaments/{id}/players    — register player
 *   POST   /tournaments/{id}/players/import — bulk import
 *   DELETE /tournaments/{id}/players/{playerId} — withdraw
 *   GET    /tournaments/{id}/players    — list players
 *   POST   /tournaments/{id}/flights    — create flight
 *   PATCH  /tournaments/{id}/flights/{flightId} — update flight
 *   POST   /tournaments/{id}/flights/{flightId}/confirm — confirm flight scores
 *   GET    /tournaments/{id}/flights    — list flights
 *   POST   /tournaments/{id}/tee-times — create tee time
 *   PATCH  /tournaments/{id}/tee-times/{teeTimeId} — assign flight
 *   GET    /tournaments/{id}/tee-times — list tee times
 *   GET    /tournaments/{id}/leaderboard — current standings (polling)
 *   GET    /tournaments/{id}/leaderboard/stream — SSE live updates
 *   POST   /tournaments/{id}/results/publish — publish final results
 *   GET    /tournaments/{id}/results — get published results
 */

import type {
  TournamentSummary,
  TournamentDetail,
  TournamentCreateRequest,
  TournamentUpdateRequest,
  TournamentPlayerCreateRequest,
  TournamentBulkImportRequest,
  FlightCreateRequest,
  FlightUpdateRequest,
  TeeTimeCreateRequest,
  TeeTimeUpdateRequest,
  LeaderboardResponse,
  TournamentResultResponse,
} from '@/types/tournament';

const BASE = import.meta.env.VITE_API_BASE_URL ?? 'https://api.vsp.local';

async function handleResponse<T>(res: Response): Promise<T> {
  if (!res.ok) {
    const err = await res.json().catch(() => ({
      code: 'UNKNOWN',
      message: res.statusText,
    }));
    throw err;
  }
  return res.json() as Promise<T>;
}

export class TournamentApi {
  constructor(private baseUrl: string = BASE) {}

  // ─── Tournament CRUD ───────────────────────────────────────────────────

  async listTournaments(
    token: string,
    params?: { status?: string; courseId?: number }
  ): Promise<TournamentSummary[]> {
    const query = new URLSearchParams();
    if (params?.status) query.set('status', params.status);
    if (params?.courseId) query.set('courseId', params.courseId.toString());
    const url = `${this.baseUrl}/tournaments${query.toString() ? '?' + query.toString() : ''}`;
    const res = await fetch(url, {
      headers: { Authorization: `Bearer ${token}` },
    });
    return handleResponse<TournamentSummary[]>(res);
  }

  async getTournament(token: string, tournamentId: string): Promise<TournamentDetail> {
    const res = await fetch(`${this.baseUrl}/tournaments/${tournamentId}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    return handleResponse<TournamentDetail>(res);
  }

  async createTournament(
    token: string,
    request: TournamentCreateRequest
  ): Promise<TournamentSummary> {
    const res = await fetch(`${this.baseUrl}/tournaments`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify(request),
    });
    return handleResponse<TournamentSummary>(res);
  }

  async updateTournament(
    token: string,
    tournamentId: string,
    request: TournamentUpdateRequest
  ): Promise<TournamentSummary> {
    const res = await fetch(`${this.baseUrl}/tournaments/${tournamentId}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify(request),
    });
    return handleResponse<TournamentSummary>(res);
  }

  // ─── Tournament lifecycle ─────────────────────────────────────────────

  async openRegistration(token: string, tournamentId: string): Promise<void> {
    const res = await fetch(`${this.baseUrl}/tournaments/${tournamentId}/publish`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!res.ok) throw await res.json().catch(() => ({ code: 'UNKNOWN', message: res.statusText }));
  }

  async startTournament(token: string, tournamentId: string): Promise<void> {
    const res = await fetch(`${this.baseUrl}/tournaments/${tournamentId}/start`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!res.ok) throw await res.json().catch(() => ({ code: 'UNKNOWN', message: res.statusText }));
  }

  async completeTournament(token: string, tournamentId: string): Promise<void> {
    const res = await fetch(`${this.baseUrl}/tournaments/${tournamentId}/complete`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!res.ok) throw await res.json().catch(() => ({ code: 'UNKNOWN', message: res.statusText }));
  }

  // ─── Players ──────────────────────────────────────────────────────────

  async registerPlayer(
    token: string,
    tournamentId: string,
    request: TournamentPlayerCreateRequest
  ) {
    const res = await fetch(`${this.baseUrl}/tournaments/${tournamentId}/players`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify(request),
    });
    return handleResponse(res);
  }

  async bulkImportPlayers(
    token: string,
    tournamentId: string,
    request: TournamentBulkImportRequest
  ) {
    const res = await fetch(`${this.baseUrl}/tournaments/${tournamentId}/players/import`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify(request),
    });
    return handleResponse(res);
  }

  async withdrawPlayer(token: string, tournamentId: string, playerId: number) {
    const res = await fetch(`${this.baseUrl}/tournaments/${tournamentId}/players/${playerId}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!res.ok) throw await res.json().catch(() => ({ code: 'UNKNOWN', message: res.statusText }));
  }

  // ─── Flights ─────────────────────────────────────────────────────────

  async createFlight(
    token: string,
    tournamentId: string,
    request: FlightCreateRequest
  ) {
    const res = await fetch(`${this.baseUrl}/tournaments/${tournamentId}/flights`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify(request),
    });
    return handleResponse(res);
  }

  async updateFlight(
    token: string,
    tournamentId: string,
    flightId: string,
    request: FlightUpdateRequest
  ) {
    const res = await fetch(`${this.baseUrl}/tournaments/${tournamentId}/flights/${flightId}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify(request),
    });
    return handleResponse(res);
  }

  /**
   * Confirm all scores for a flight (score confirmation gate before completion).
   * Backend: POST /tournaments/{id}/flights/{flightId}/confirm
   */
  async confirmFlight(token: string, tournamentId: string, flightId: string) {
    const res = await fetch(
      `${this.baseUrl}/tournaments/${tournamentId}/flights/${flightId}/confirm`,
      {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
      }
    );
    if (!res.ok) throw await res.json().catch(() => ({ code: 'UNKNOWN', message: res.statusText }));
  }

  // ─── Tee Times ───────────────────────────────────────────────────────

  async createTeeTime(
    token: string,
    tournamentId: string,
    request: TeeTimeCreateRequest
  ) {
    const res = await fetch(`${this.baseUrl}/tournaments/${tournamentId}/tee-times`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify(request),
    });
    return handleResponse(res);
  }

  async updateTeeTime(
    token: string,
    tournamentId: string,
    teeTimeId: string,
    request: TeeTimeUpdateRequest
  ) {
    const res = await fetch(`${this.baseUrl}/tournaments/${tournamentId}/tee-times/${teeTimeId}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify(request),
    });
    return handleResponse(res);
  }

  // ─── Leaderboard ──────────────────────────────────────────────────────

  async getLeaderboard(token: string, tournamentId: string): Promise<LeaderboardResponse> {
    const res = await fetch(`${this.baseUrl}/tournaments/${tournamentId}/leaderboard`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    return handleResponse<LeaderboardResponse>(res);
  }

  /**
   * SSE stream URL for live leaderboard updates.
   * Use with EventSource in the browser.
   */
  leaderboardSseUrl(_token: string, tournamentId: string): string {
    return `${this.baseUrl}/tournaments/${tournamentId}/leaderboard/stream`;
  }

  // ─── Results ──────────────────────────────────────────────────────────

  async publishResults(token: string, tournamentId: string): Promise<void> {
    const res = await fetch(`${this.baseUrl}/tournaments/${tournamentId}/results/publish`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!res.ok) throw await res.json().catch(() => ({ code: 'UNKNOWN', message: res.statusText }));
  }

  async getResults(token: string, tournamentId: string): Promise<TournamentResultResponse[]> {
    const res = await fetch(`${this.baseUrl}/tournaments/${tournamentId}/results`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    return handleResponse<TournamentResultResponse[]>(res);
  }
}

export const tournamentApi = new TournamentApi();
