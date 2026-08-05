/**
 * Pure helper for parsing the tournament bulk-player-import textarea.
 * Extracted from the tournament detail page so it can be unit tested.
 *
 * Story 12.1 — Operate Tournament (registration/import).
 */

import type { TournamentBulkImportRequest } from '@/types/tournament';

/**
 * Parse free text of the form `playerId,handicap` (one player per line,
 * handicap optional) into a bulk-import request.
 *
 * @throws Error when a line has a non-numeric player ID, or when no players parse.
 */
export function parseBulkImport(text: string): TournamentBulkImportRequest {
  const players = text
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line.length > 0)
    .map((line) => {
      const [idPart, hcpPart] = line.split(',').map((s) => s.trim());
      const playerId = Number.parseInt(idPart, 10);
      if (!Number.isFinite(playerId)) {
        throw new Error(`Invalid player ID in line: "${line}"`);
      }
      const handicap =
        hcpPart !== undefined && hcpPart !== '' ? Number.parseFloat(hcpPart) : undefined;
      return { playerId, handicap };
    });

  if (players.length === 0) {
    throw new Error('No players to import.');
  }
  return { players };
}
