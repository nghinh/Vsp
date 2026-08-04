/**
 * TypeScript types for Tournament API.
 * Mirror the backend DTOs from Story 12.1 Slices A-E.
 *
 * Story 12.1 Slice G
 */

// ─── Enums ─────────────────────────────────────────────────────────────────

export type TournamentFormatValue = 'strokePlay' | 'matchPlay' | 'stableford';
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
    | 'scorecardPlayoff'
    | 'exactHandicap'
    | 'lowestRound'
    | 'mostBirdies'
    | 'draw';

export type StartingTeeValue = 'front' | 'back' | 'both';

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

export interface TournamentDetail extends TournamentSummary {
  players: TournamentPlayerResponse[];
  flights: FlightResponse[];
  teeTimes: TeeTimeResponse[];
  tieBreakRules: TieBreakRuleResponse[];
}

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
