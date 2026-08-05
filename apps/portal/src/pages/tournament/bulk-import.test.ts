/**
 * Unit tests for the tournament bulk-import parser.
 * Per Story 12.1 — Operate Tournament (registration/import).
 */

import { describe, it, expect } from 'vitest';
import { parseBulkImport } from '@/pages/tournament/bulk-import';

describe('parseBulkImport', () => {
  it('parses playerId with handicap', () => {
    const res = parseBulkImport('101,12.4');
    expect(res.players).toEqual([{ playerId: 101, handicap: 12.4 }]);
  });

  it('parses a playerId without a handicap', () => {
    const res = parseBulkImport('103');
    expect(res.players).toEqual([{ playerId: 103, handicap: undefined }]);
  });

  it('parses multiple lines and ignores blank lines', () => {
    const res = parseBulkImport('101,12.4\n\n102,8.0\n  \n103');
    expect(res.players).toHaveLength(3);
    expect(res.players[1]).toEqual({ playerId: 102, handicap: 8.0 });
    expect(res.players[2]).toEqual({ playerId: 103, handicap: undefined });
  });

  it('trims whitespace around values', () => {
    const res = parseBulkImport('  201 , 5.5 ');
    expect(res.players[0]).toEqual({ playerId: 201, handicap: 5.5 });
  });

  it('throws on a non-numeric player ID', () => {
    expect(() => parseBulkImport('abc,10')).toThrow(/Invalid player ID/);
  });

  it('throws when there are no players to import', () => {
    expect(() => parseBulkImport('   \n  \n')).toThrow(/No players to import/);
  });
});
