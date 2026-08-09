/**
 * Running a club outing.
 *
 * Everything here is on the critical path of a few minutes: the last flight
 * hands in its card, someone types eleven scorecards, and the prizes are read
 * out. So the calls are batched the way the work is — a flight at a time — and
 * the results endpoint is cheap enough to poll while the typing is still going
 * on.
 */

import { getAuthToken } from '../auth';
import { API_BASE } from './base';

// ─── Rules ────────────────────────────────────────────────────────────────

/** A prize group. The number of titles is how many prizes the group has. */
export interface Division {
  code: string;
  name: string;
  minHandicap: number;
  maxHandicap: number;
  prizeTitles: string[];
}

/** "Các Golfers HDC trên {above} sẽ cắt về {playOff}." */
export interface HandicapCap {
  above: number;
  playOff: number;
}

/** One band of the daily-CAP scale, in strokes over par. Null bounds are open. */
export interface CapBand {
  minOverPar: number | null;
  maxOverPar: number | null;
  adjustment: number;
}

export type TechnicalKind = 'NEAREST_TO_PIN' | 'LONGEST_DRIVE';

export interface TechnicalPrizeSpec {
  code: string;
  label: string;
  kind: TechnicalKind;
  holes: number[];
  unit: string;
}

/**
 * Everything about how this outing is judged.
 *
 * None of it is hardcoded anywhere: the divisions, the cap, the floor, the
 * countback windows, the CAP scale and the technical prizes all travel with
 * the event, because the club changes them between outings and has been known
 * to change them in the week before one.
 */
export interface OutingRules {
  holePars: number[];
  divisions: Division[];
  handicapCap: HandicapCap | null;
  judgingFloor: number | null;
  countbackWindows: number[];
  dailyCapBands: CapBand[];
  technicalPrizes: TechnicalPrizeSpec[];
  onePrizePerPlayer: boolean;
}

// ─── Roster ───────────────────────────────────────────────────────────────

export interface RosterEntry {
  displayName: string;
  vgaCode?: string | null;
  handicap?: number | null;
  divisionCode?: string | null;
  flightNumber?: number | null;
  playerId?: number | null;
}

export interface OutingPlayer {
  id: string;
  displayName: string | null;
  vgaCode: string | null;
  divisionCode: string | null;
  playingHandicap: number | null;
  handicap: number | null;
  flightNumber: number | null;
  grossTotal: number | null;
  holeScores: (number | null)[] | null;
  /** Reported by the flight; only used where the holes are absent. */
  birdieCount: number | null;
  eagleCount: number | null;
  hasScore: boolean;
}

// ─── Scores ───────────────────────────────────────────────────────────────

export interface ScoreEntry {
  tournamentPlayerId: string;
  grossTotal?: number | null;
  holeScores?: (number | null)[] | null;
  /**
   * Only meaningful on the fast path. With eighteen hole scores the server
   * counts these itself and ignores whatever is sent.
   */
  birdieCount?: number | null;
  eagleCount?: number | null;
}

export interface TechnicalEntry {
  tournamentPlayerId: string;
  prizeCode: string;
  holeNumber: number;
  measurement: number;
}

// ─── Results ──────────────────────────────────────────────────────────────

export interface ResultEntry {
  tournamentPlayerId: string;
  displayName: string | null;
  vgaCode: string | null;
  flightNumber: number | null;
  playingHandicap: number;
  gross: number | null;
  net: number | null;
  judgingScore: number | null;
  rank: number;
  prizeTitle: string | null;
  countbackAvailable: boolean;
  tiedAndUnresolved: boolean;
  dailyCapAdjustment: number | null;
  birdies: number;
  eagles: number;
}

export interface TechnicalAward {
  prizeCode: string;
  prizeLabel: string;
  holeNumber: number;
  tournamentPlayerId: string;
  displayName: string | null;
  measurement: number;
  unit: string;
}

export interface OutingResults {
  tournamentId: string;
  computedAt: string;
  publishedAt: string | null;
  rosterSize: number;
  scoresEntered: number;
  divisions: Record<string, ResultEntry[]>;
  technicalAwards: TechnicalAward[];
  /** Players whose handicap fell outside every configured division. */
  unplaced: string[];
}

// ─── Client ───────────────────────────────────────────────────────────────

async function handle<T>(res: Response): Promise<T> {
  if (!res.ok) {
    const err = await res.json().catch(() => ({ message: res.statusText }));
    throw err;
  }
  return res.status === 204 ? (undefined as T) : ((await res.json()) as T);
}

function headers(): HeadersInit {
  return {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${getAuthToken()}`,
  };
}

function base(tournamentId: string): string {
  return `${API_BASE}/tournaments/${tournamentId}/outing`;
}

export const outingApi = {
  getRules(tournamentId: string): Promise<OutingRules> {
    return fetch(`${base(tournamentId)}/rules`, { headers: headers() }).then(handle<OutingRules>);
  },

  saveRules(tournamentId: string, rules: OutingRules): Promise<OutingRules> {
    return fetch(`${base(tournamentId)}/rules`, {
      method: 'PUT',
      headers: headers(),
      body: JSON.stringify(rules),
    }).then(handle<OutingRules>);
  },

  getRoster(tournamentId: string): Promise<OutingPlayer[]> {
    return fetch(`${base(tournamentId)}/roster`, { headers: headers() }).then(handle<OutingPlayer[]>);
  },

  importRoster(tournamentId: string, entries: RosterEntry[]): Promise<OutingPlayer[]> {
    return fetch(`${base(tournamentId)}/roster`, {
      method: 'PUT',
      headers: headers(),
      body: JSON.stringify(entries),
    }).then(handle<OutingPlayer[]>);
  },

  /** One flight's cards in one request. */
  saveScores(tournamentId: string, entries: ScoreEntry[]): Promise<OutingPlayer[]> {
    return fetch(`${base(tournamentId)}/scores`, {
      method: 'POST',
      headers: headers(),
      body: JSON.stringify(entries),
    }).then(handle<OutingPlayer[]>);
  },

  getTechnical(tournamentId: string): Promise<TechnicalEntry[]> {
    return fetch(`${base(tournamentId)}/technical`, { headers: headers() }).then(
      handle<TechnicalEntry[]>,
    );
  },

  saveTechnical(tournamentId: string, entries: TechnicalEntry[]): Promise<void> {
    return fetch(`${base(tournamentId)}/technical`, {
      method: 'POST',
      headers: headers(),
      body: JSON.stringify(entries),
    }).then(handle<void>);
  },

  getResults(tournamentId: string): Promise<OutingResults> {
    return fetch(`${base(tournamentId)}/results`, { headers: headers() }).then(handle<OutingResults>);
  },

  publish(tournamentId: string): Promise<OutingResults> {
    return fetch(`${base(tournamentId)}/results/publish`, {
      method: 'POST',
      headers: headers(),
    }).then(handle<OutingResults>);
  },
};
