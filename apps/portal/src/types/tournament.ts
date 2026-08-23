/**
 * TypeScript types for Tournament API.
 * Mirror the backend DTOs from Story 12.1 Slices A-E.
 *
 * Story 12.1 Slice G
 */

// ─── Enums ─────────────────────────────────────────────────────────────────

/**
 * The wire values, as `packages/contracts/schemas/tournament.yaml` and the
 * server's `TournamentFormat` spell them.
 *
 * These were `strokePlay | matchPlay | stableford`. Nothing in the portal
 * checked, because nothing in the portal compares a format — it only sends one
 * and prints one back — so the mismatch surfaced exactly once, at the end of
 * the create form, as `Invalid value 'strokePlay' for 'format'`. Creating a
 * tournament from the portal was impossible in every branch of the form.
 */
export type TournamentFormatValue = 'STROKE_PLAY' | 'MATCH_PLAY' | 'STABLEFORD';
export type TournamentStatusValue =
    | 'DRAFT'
    | 'REGISTRATION_OPEN'
    | 'IN_PROGRESS'
    | 'COMPLETED'
    | 'CANCELLED';

export type TournamentPlayerStatusValue =
    | 'REGISTERED'
    | 'CONFIRMED'
    | 'WITHDRAWN'
    | 'DISQUALIFIED';

export type TieBreakRuleTypeValue =
    | 'SCORECARD_PLAYOFF'
    | 'EXACT_HANDICAP'
    | 'LOWEST_ROUND'
    | 'MOST_BIRDIES'
    | 'DRAW';

/**
 * `FRONT | BACK`, and no third value: a shotgun start is expressed by which
 * tee each flight goes off, not by a flight that goes off both. The portal
 * offered `both`, which the server's `StartingTee` has never had.
 */
export type StartingTeeValue = 'FRONT' | 'BACK';

// ─── Tournament ─────────────────────────────────────────────────────────────

export interface TournamentSummary {
  id: string;
  name: string;
  format: TournamentFormatValue;
  status: TournamentStatusValue;
  courseId: number;
  courseName?: string;
  startDate: string;
  endDate: string;
  tournamentPolicyId?: string;
  registrationDeadline?: string;
  maxPlayers?: number;
  description?: string;
  createdAt: string;
  createdBy: number;
  version: number;
  leaderboardVersion: number;
}

/*
 * There is no `TournamentDetail`.
 *
 * One used to be declared here — `TournamentSummary` plus `players`,
 * `flights`, `teeTimes` and `tieBreakRules` — and `getTournament` was typed to
 * return it. No endpoint has ever returned that shape:
 * `GET /tournaments/{id}` answers with the tournament and nothing else, and
 * the four collections are listed from their own paths. Because the fields
 * were declared optional in effect (`detail.players ?? []`), the mismatch
 * produced no error anywhere — just three permanently empty tabs behind
 * requests that had returned 201.
 *
 * If a combined response is ever added, put the type back with the endpoint
 * that serves it. Until then a type that describes nothing is worse than no
 * type, because the compiler will vouch for it.
 */

export interface TournamentCreateRequest {
  name: string;
  format: TournamentFormatValue;
  courseId: number;
  startDate: string;
  endDate: string;
  tournamentPolicyId?: string;
  registrationDeadline?: string;
  maxPlayers?: number;
  description?: string;
}

export interface TournamentUpdateRequest {
  name?: string;
  format?: TournamentFormatValue;
  startDate?: string;
  endDate?: string;
  tournamentPolicyId?: string;
  registrationDeadline?: string;
  maxPlayers?: number;
  description?: string;
}

// ─── Player ─────────────────────────────────────────────────────────────────

export interface TournamentPlayerResponse {
  id: string;
  tournamentId: string;
  playerId: number;
  playerName?: string;
  handicap?: number;
  flightId?: string;
  registrationTime: string;
  status: TournamentPlayerStatusValue;
}

export interface TournamentPlayerCreateRequest {
  playerId: number;
  handicap?: number;
}

export interface TournamentBulkImportRequest {
  players: Array<{
    playerId: number;
    handicap?: number;
  }>;
}

// ─── Flight ─────────────────────────────────────────────────────────────────

export interface FlightResponse {
  id: string;
  tournamentId: string;
  flightNumber: number;
  playerIds: string[];
  teeTimeId?: string;
  startingTee: StartingTeeValue;
  confirmedAt?: string;
  confirmedBy?: number;
}

export interface FlightCreateRequest {
  flightNumber: number;
  startingTee: StartingTeeValue;
}

export interface FlightUpdateRequest {
  playerIds?: string[];
  teeTimeId?: string;
  startingTee?: StartingTeeValue;
}

// ─── Tee Time ────────────────────────────────────────────────────────────────

export interface TeeTimeResponse {
  id: string;
  tournamentId: string;
  teeTime: string;
  courseId: number;
  startingTeeBoxId?: string;
  flightId?: string;
  startingTee: StartingTeeValue;
}

export interface TeeTimeCreateRequest {
  teeTime: string;
  courseId: number;
  startingTeeBoxId?: string;
  startingTee: StartingTeeValue;
}

export interface TeeTimeUpdateRequest {
  flightId?: string;
}

// ─── Tie Break ──────────────────────────────────────────────────────────────

export interface TieBreakRuleResponse {
  id: string;
  tournamentId: string;
  order: number;
  ruleType: TieBreakRuleTypeValue;
}

// ─── Leaderboard ─────────────────────────────────────────────────────────────

export interface LeaderboardEntryResponse {
  rank: number;
  tied: boolean;
  playerId: number;
  playerName?: string;
  score?: number;
  scoreToPar?: number;
  status: TournamentPlayerStatusValue;
  flightId?: string;
  roundNumber?: number;
}

export interface LeaderboardResponse {
  tournamentId: string;
  version: number;
  updatedAt: string;
  entries: LeaderboardEntryResponse[];
}

// ─── Results ────────────────────────────────────────────────────────────────

export interface TournamentResultResponse {
  id: string;
  tournamentId: string;
  playerId: number;
  playerName?: string;
  rank: number;
  score?: number;
  scoreToPar?: number;
  prize?: string;
  tieBreakApplied: boolean;
  publishedAt?: string;
}

// ─── Error ─────────────────────────────────────────────────────────────────

export interface TournamentApiError {
  code: string;
  message: string;
  correlationId?: string;
  field?: string;
}
