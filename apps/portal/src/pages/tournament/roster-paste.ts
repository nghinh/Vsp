/**
 * Turning the club's flight sheet into a roster.
 *
 * The organisers keep the field in a spreadsheet — "Sap FL 19042026" — with
 * the flight in a merged cell spanning its four players, and columns for name,
 * "Handicap xét giải", "Nhóm" and "Mã VGA". Copying that block and pasting it
 * is a great deal faster and less error-prone than retyping forty-four names,
 * and it is what an organiser will try first.
 *
 * So this parses what actually comes off the clipboard: tab-separated columns,
 * the flight cell filled only on the first of its four rows, blank separator
 * rows between flights, a "FLY 3\n06h30." cell carrying the tee time as well
 * as the number, and a trailing notes column that is sometimes "Bs" and
 * sometimes nothing.
 */

import type { RosterEntry } from '@/api/outing';

/** What a paste produced, including the lines it could not use. */
export interface ParsedRoster {
  entries: RosterEntry[];
  /** Lines skipped, with the reason — shown so a silent drop is impossible. */
  skipped: Array<{ line: number; text: string; reason: string }>;
}

/** Header words that mark the column row rather than a player. */
const HEADER_WORDS = ['họ và tên', 'handicap', 'nhóm', 'mã vga', 'stt'];

/**
 * Pull a flight number out of a cell like `FLY 11\n06h30.` or `Fly 3`.
 *
 * Returns null when the cell is not a flight marker at all, which is the
 * common case: only the first row of each flight carries one.
 */
export function parseFlightCell(cell: string): number | null {
  const match = /\bfly\s*(\d{1,2})\b/i.exec(cell);
  return match ? Number.parseInt(match[1], 10) : null;
}

/**
 * A handicap cell.
 *
 * Accepts "27", "27.0" and "+2" — a plus handicap is a real thing and reads as
 * negative strokes, but the club's sheet writes scratch-and-better as plain
 * small numbers, so a leading "+" is taken at face value rather than negated.
 * Blank and "-" mean the organisers have not set one yet.
 */
export function parseHandicap(cell: string): number | null {
  const cleaned = cell.trim().replace(',', '.').replace(/^\+/, '');
  if (cleaned === '' || cleaned === '-') return null;
  const n = Number.parseFloat(cleaned);
  return Number.isFinite(n) ? n : null;
}

/**
 * A tee-time cell: `06h30`, `06h30.`, `06:30`, `6h`.
 *
 * These sit in their own column immediately after the flight marker on the
 * first row of each flight, so without this the name finder takes the tee time
 * as the player and the actual first name of every flight is lost.
 */
export function isTimeCell(cell: string): boolean {
  return /^\d{1,2}\s*[h:]\s*\d{0,2}\.?$/i.test(cell.trim());
}

/** A division cell: "A", "b", "Nhóm A". Anything else is left for the server. */
export function parseDivision(cell: string): string | null {
  const match = /\b([AB])\b/i.exec(cell.trim());
  return match ? match[1].toUpperCase() : null;
}

/**
 * Parse a pasted block into roster lines.
 *
 * Columns are matched by position against the club's sheet — flight, name,
 * handicap, division, VGA — but a row with fewer columns still parses as far
 * as it goes, because an organiser part-way through building next month's
 * sheet will have the names before the handicaps.
 */
export function parseRosterPaste(text: string): ParsedRoster {
  const entries: RosterEntry[] = [];
  const skipped: ParsedRoster['skipped'] = [];

  // The flight carries down: the sheet writes it once per group of four.
  let currentFlight: number | null = null;

  text.split('\n').forEach((rawLine, index) => {
    const line = rawLine.replace(/\r$/, '');
    const lineNumber = index + 1;

    if (line.trim() === '') return;

    // Excel writes a merged multi-line cell as one column containing a
    // newline, but a clipboard paste flattens it; either way the flight marker
    // may arrive on a line of its own.
    const columns = line.split('\t').map((c) => c.trim());

    const flightHere = parseFlightCell(columns[0] ?? '');
    if (flightHere !== null) currentFlight = flightHere;

    const lower = line.toLowerCase();
    if (HEADER_WORDS.some((w) => lower.includes(w))) return;

    // The name is the first column after the flight marker that reads like a
    // name rather than a number. Sheets differ on whether they carry an STT.
    const nameIndex = columns.findIndex(
      (c, i) =>
        i > 0 &&
        c !== '' &&
        !/^\d+$/.test(c) &&
        parseFlightCell(c) === null &&
        !isTimeCell(c),
    );

    if (nameIndex === -1) {
      // A flight marker on its own line is structure, not a dropped player.
      if (flightHere === null) {
        skipped.push({ line: lineNumber, text: line.trim(), reason: 'không tìm thấy tên' });
      }
      return;
    }

    const rest = columns.slice(nameIndex + 1);
    const handicap = rest.map(parseHandicap).find((h) => h !== null) ?? null;
    const division = rest.map(parseDivision).find((d) => d !== null) ?? null;

    // The VGA code is a bare integer, and it is not the handicap: the club's
    // codes run to six digits while a handicap never passes 54.
    const vga = rest.find((c) => /^\d{3,}$/.test(c)) ?? null;

    entries.push({
      displayName: columns[nameIndex],
      vgaCode: vga,
      handicap,
      divisionCode: division,
      flightNumber: currentFlight,
    });
  });

  return { entries, skipped };
}
