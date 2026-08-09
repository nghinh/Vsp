/**
 * Parsing the club's own flight sheet.
 *
 * The fixtures below are the real thing: rows copied out of
 * "Sap FL 19042026", tabs and all. A parser tested against tidied-up input is
 * a parser that works until the first paste.
 */

import { describe, expect, it } from 'vitest';

import { parseDivision, parseFlightCell, parseHandicap, parseRosterPaste } from './roster-paste';

describe('parseFlightCell', () => {
  it('reads the number out of the sheet’s own cell', () => {
    // The cell holds the tee time on a second line.
    expect(parseFlightCell('FLY 1\n06h30.')).toBe(1);
    expect(parseFlightCell('FLY 11\n06h30.')).toBe(11);
  });

  it('is not fussy about case or spacing', () => {
    expect(parseFlightCell('Fly 3')).toBe(3);
    expect(parseFlightCell('fly7')).toBe(7);
  });

  it('is null for a cell that is not a flight marker', () => {
    expect(parseFlightCell('Nguyễn Đức Kiên')).toBeNull();
    expect(parseFlightCell('')).toBeNull();
    expect(parseFlightCell('27')).toBeNull();
  });
});

describe('parseHandicap', () => {
  it('reads the numbers the sheet uses', () => {
    expect(parseHandicap('27')).toBe(27);
    expect(parseHandicap(' 6 ')).toBe(6);
    expect(parseHandicap('27.5')).toBe(27.5);
    expect(parseHandicap('27,5')).toBe(27.5);
  });

  it('is null when the organisers have not set one', () => {
    expect(parseHandicap('')).toBeNull();
    expect(parseHandicap('-')).toBeNull();
    expect(parseHandicap('chưa có')).toBeNull();
  });
});

describe('parseDivision', () => {
  it('reads A and B however they are written', () => {
    expect(parseDivision('A')).toBe('A');
    expect(parseDivision('b')).toBe('B');
    expect(parseDivision('Nhóm A')).toBe('A');
  });

  it('is null for anything else', () => {
    expect(parseDivision('')).toBeNull();
    expect(parseDivision('C')).toBeNull();
  });
});

describe('parseRosterPaste', () => {
  // Rows 4–12 of the real sheet: two flights, the flight cell filled only on
  // the first row of each, a blank separator row between them, and a stray
  // note column on the last line.
  const REAL_PASTE = [
    '#\tHọ và tên\tHandicap xét giải\tNhóm\tMã VGA\tVHD\tGhi chú',
    'FLY 1\t06h30.\tPhạm Đức Long\t27\tB\t38632\t\tStart Hố 1',
    '\tNguyễn Đức Kiên\t22\tA\t241279',
    '\tĐỗ Mai Lan\t16\tA\t5606',
    '\tNguyễn Văn Bắc HGG\t21\tA\t2640',
    '',
    'FLY 2\t06h30\tĐinh Đức Thụ\t27\tB\t14143\t\t\tBs',
    '\tNguyễn Sơn Hải Media\t17\tA\t5012',
    '\tHồ Trọng Đạt\t23\tA\t5045\t\t\tbs',
  ].join('\n');

  it('reads every player off the block', () => {
    const { entries } = parseRosterPaste(REAL_PASTE);
    expect(entries).toHaveLength(7);
    expect(entries.map((e) => e.displayName)).toEqual([
      'Phạm Đức Long',
      'Nguyễn Đức Kiên',
      'Đỗ Mai Lan',
      'Nguyễn Văn Bắc HGG',
      'Đinh Đức Thụ',
      'Nguyễn Sơn Hải Media',
      'Hồ Trọng Đạt',
    ]);
  });

  it('carries the flight down its four rows', () => {
    // The sheet writes "FLY 1" once, in a cell merged across four players.
    const { entries } = parseRosterPaste(REAL_PASTE);
    expect(entries.map((e) => e.flightNumber)).toEqual([1, 1, 1, 1, 2, 2, 2]);
  });

  it('keeps the handicap and division the organisers assigned', () => {
    const { entries } = parseRosterPaste(REAL_PASTE);
    expect(entries[0]).toMatchObject({ handicap: 27, divisionCode: 'B', vgaCode: '38632' });
    expect(entries[2]).toMatchObject({ handicap: 16, divisionCode: 'A', vgaCode: '5606' });
  });

  it('does not mistake the handicap for the VGA code', () => {
    // Both are bare integers in adjacent columns. Mã VGA runs to six digits;
    // a handicap never passes 54, and taking the wrong one would silently
    // move a player between divisions.
    const { entries } = parseRosterPaste(REAL_PASTE);
    expect(entries[1]).toMatchObject({ handicap: 22, vgaCode: '241279' });
  });

  it('skips the header row', () => {
    const { entries } = parseRosterPaste(REAL_PASTE);
    expect(entries.some((e) => e.displayName.includes('Họ và tên'))).toBe(false);
  });

  it('ignores the blank rows between flights', () => {
    const { skipped } = parseRosterPaste(REAL_PASTE);
    expect(skipped).toHaveLength(0);
  });

  it('ignores a trailing note column', () => {
    const { entries } = parseRosterPaste(REAL_PASTE);
    // "Bs" must not become the division or the name.
    expect(entries[4]).toMatchObject({ displayName: 'Đinh Đức Thụ', divisionCode: 'B' });
  });

  it('reports what it could not read rather than dropping it', () => {
    // A silently skipped line is a golfer who does not appear at prize-giving.
    const { entries, skipped } = parseRosterPaste('FLY 1\n\t\t\t\n\tNgười Chơi\t20\tA\t1234');

    expect(entries).toHaveLength(1);
    expect(skipped).toHaveLength(0);

    const messy = parseRosterPaste('FLY 1\n\t27\t\t\n\tNgười Chơi\t20\tA\t1234');
    expect(messy.entries).toHaveLength(1);
    expect(messy.skipped[0]).toMatchObject({ reason: 'không tìm thấy tên' });
  });

  it('takes a name-only sheet, for a field that has no handicaps yet', () => {
    const { entries } = parseRosterPaste('FLY 1\tNgười Một\n\tNgười Hai');
    expect(entries).toHaveLength(2);
    expect(entries[0]).toMatchObject({ displayName: 'Người Một', handicap: null, flightNumber: 1 });
  });

  it('handles a sheet with an STT column in front of the name', () => {
    const { entries } = parseRosterPaste('FLY 1\t1\tNgười Một\t20\tA\t1234');
    expect(entries[0]).toMatchObject({ displayName: 'Người Một', handicap: 20 });
  });

  it('returns nothing for an empty paste rather than throwing', () => {
    expect(parseRosterPaste('').entries).toEqual([]);
    expect(parseRosterPaste('\n\n  \n').entries).toEqual([]);
  });
});
