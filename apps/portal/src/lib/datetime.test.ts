/**
 * These tests are written against the machine's own timezone rather than a
 * pinned one, because the property that matters is not "Vietnam is +7" — it is
 * that a value survives the trip out to the input and back. A test that hard
 * codes +07:00 passes on a CI box in UTC while the bug is still there.
 */

import { describe, expect, it } from 'vitest';

import {
  endOfTodayLocalInput,
  fromLocalInput,
  hoursFromNowLocalInput,
  nowLocalInput,
  toLocalInput,
} from './datetime';

const INPUT_SHAPE = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/;

describe('toLocalInput', () => {
  it('shows the local wall clock, not the UTC one', () => {
    const instant = new Date('2026-08-08T15:47:00Z');
    const shown = toLocalInput(instant);

    // Whatever the zone, parsing the field back — which a browser does as
    // local time — must land on the instant we started from.
    expect(new Date(shown).getTime()).toBe(instant.getTime());
  });

  it('accepts the ISO string the API returns', () => {
    expect(toLocalInput('2026-08-08T15:47:00Z')).toBe(toLocalInput(new Date('2026-08-08T15:47:00Z')));
  });

  it('is empty for nothing, rather than "Invalid Date"', () => {
    expect(toLocalInput(null)).toBe('');
    expect(toLocalInput(undefined)).toBe('');
    expect(toLocalInput('')).toBe('');
    expect(toLocalInput('not a date')).toBe('');
  });
});

describe('round trip', () => {
  it('does not drift — the bug this exists to stop', () => {
    // Editing a pin re-read its time into the form and saved it again. With a
    // raw slice, every pass moved it by the UTC offset. Three passes here so a
    // drift of any size shows up.
    const original = '2026-08-08T15:47:00.000Z';
    let value = original;
    for (let i = 0; i < 3; i++) {
      value = fromLocalInput(toLocalInput(value))!;
    }
    expect(value).toBe(original);
  });
});

describe('fromLocalInput', () => {
  it('returns UTC ISO', () => {
    const iso = fromLocalInput('2026-08-08T22:47')!;
    expect(iso).toMatch(/Z$/);
    expect(new Date(iso).getTime()).toBe(new Date('2026-08-08T22:47').getTime());
  });

  it('is null for nothing', () => {
    expect(fromLocalInput('')).toBeNull();
    expect(fromLocalInput(null)).toBeNull();
    expect(fromLocalInput('not a date')).toBeNull();
  });
});

describe('the defaults', () => {
  it('are shaped the way the input requires', () => {
    expect(nowLocalInput()).toMatch(INPUT_SHAPE);
    expect(hoursFromNowLocalInput(12)).toMatch(INPUT_SHAPE);
    expect(endOfTodayLocalInput()).toMatch(INPUT_SHAPE);
  });

  it('puts the end of today at 23:59 local', () => {
    expect(endOfTodayLocalInput().slice(11)).toBe('23:59');
  });

  it('counts hours forward', () => {
    const gap =
      new Date(hoursFromNowLocalInput(12)).getTime() - new Date(nowLocalInput()).getTime();
    expect(gap).toBeGreaterThan(11.9 * 3600_000);
    expect(gap).toBeLessThan(12.1 * 3600_000);
  });
});
