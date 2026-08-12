/**
 * Reading a golfer's proposed card, and what the reviewer is warned about.
 *
 * The reviewer's job is to check eighteen hand-copied numbers against a
 * photograph. A stroke index handed out twice is invisible in a table and
 * expensive afterwards: it misallocates strokes on both holes, for everyone
 * who plays that card.
 */

import { describe, it, expect } from 'vitest';
import {
  duplicateStrokeIndexes,
  holesMissingStrokeIndex,
  parseProposedCard,
  parTotal,
  scorecardProblems,
} from './scorecard-proposal';

const nine = Array.from({ length: 9 }, (_, i) => ({
  hole: i + 1,
  par: i % 3 === 2 ? 3 : 4,
  strokeIndex: i + 1,
}));

const card = (lines = nine) =>
  JSON.stringify({ name: 'A + B', segmentCourseIds: [21, 22], holes: lines });

describe('parseProposedCard', () => {
  it('reads a card the golfer sent', () => {
    const parsed = parseProposedCard(card());

    expect(parsed?.name).toBe('A + B');
    expect(parsed?.segmentCourseIds).toEqual([21, 22]);
    expect(parsed?.holes).toHaveLength(9);
  });

  it('returns nothing for a correction that carries no card', () => {
    expect(parseProposedCard(null)).toBeNull();
  });

  it('returns nothing rather than half a card when the payload is broken', () => {
    expect(parseProposedCard('{ not json')).toBeNull();
    expect(parseProposedCard('{"name":"A"}')).toBeNull();
  });
});

describe('what the reviewer is told', () => {
  it('adds the par up so nobody totals eighteen numbers by hand', () => {
    expect(parTotal(parseProposedCard(card()))).toBe(4 + 4 + 3 + 4 + 4 + 3 + 4 + 4 + 3);
  });

  it('names an index handed out twice', () => {
    const duplicated = nine.map((l) => (l.hole === 7 ? { ...l, strokeIndex: 2 } : l));

    const parsed = parseProposedCard(card(duplicated));

    expect([...duplicateStrokeIndexes(parsed)]).toEqual([2]);
    expect(scorecardProblems(parsed)[0]).toContain('Chỉ số bị trùng: 2');
  });

  it('names the holes with no index yet', () => {
    const missing = nine.map((l) => (l.hole === 5 ? { ...l, strokeIndex: null } : l));

    const parsed = parseProposedCard(card(missing));

    expect(holesMissingStrokeIndex(parsed)).toEqual([5]);
    expect(scorecardProblems(parsed)[0]).toContain('Hố chưa có chỉ số: 5');
  });

  it('says nothing about a card that is fine', () => {
    expect(scorecardProblems(parseProposedCard(card()))).toEqual([]);
  });
});
