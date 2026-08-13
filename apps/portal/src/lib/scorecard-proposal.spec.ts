/**
 * Reading a golfer's proposed card, and what the reviewer is warned about.
 *
 * The reviewer's job is to check hand-copied numbers against a photograph. A
 * stroke index handed out twice is invisible in a table and expensive
 * afterwards: it misallocates strokes on both holes, for everyone who plays
 * that card.
 *
 * Approving a card now also writes its tee rows — their ratings and their
 * yardages — so those have to survive the trip from the payload to the screen
 * intact. Everything below exists because of something a reviewer would
 * otherwise approve without having seen it, or would believe they had
 * published when they had not.
 */

import { describe, it, expect } from 'vitest';
import type { ProposedLine } from './scorecard-proposal';
import {
  droppedTeeIndexes,
  duplicateStrokeIndexes,
  duplicateYardageHoles,
  hasLadiesIndex,
  holesMissingStrokeIndex,
  parComparison,
  parseProposedCard,
  parTotal,
  scorecardProblems,
  teeRows,
  yardageTotals,
  yardsByHole,
} from './scorecard-proposal';

// Typed rather than inferred: the cases below blank a stroke index, and an
// inferred `strokeIndex: number` makes writing the case the code exists for
// a type error.
const nine: ProposedLine[] = Array.from({ length: 9 }, (_, i) => ({
  hole: i + 1,
  par: i % 3 === 2 ? 3 : 4,
  strokeIndex: i + 1,
}));

const card = (lines = nine) =>
  JSON.stringify({ name: 'A + B', segmentCourseIds: [21, 22], holes: lines });

/** A tee row as the scan sends it: a name, two ratings, and its yardages. */
const tee = (name: string, extra: Record<string, unknown> = {}) => ({
  name,
  courseRating: 75.5,
  slopeRating: 138,
  yardages: Array.from({ length: 18 }, (_, i) => ({ hole: i + 1, yards: 400 })),
  ...extra,
});

const cardWithTees = (tees: unknown[], lines = nine) =>
  JSON.stringify({ name: 'A + B', segmentCourseIds: [21, 22], holes: lines, tees });

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

describe('the tee rows approval writes', () => {
  it('keeps the ratings and yardages the payload carries', () => {
    // Without this the tee rows could vanish between the payload and the
    // screen and nothing would notice, which is the whole failure: approval
    // writes a course rating and a slope the reviewer was never shown, and
    // those two numbers are what a round's handicap is computed from.
    const parsed = parseProposedCard(cardWithTees([tee('GOLD'), tee('BLUE')]));

    const rows = teeRows(parsed);

    expect(rows.map((r) => r.name)).toEqual(['GOLD', 'BLUE']);
    expect(rows[0].courseRating).toBe(75.5);
    expect(rows[0].slopeRating).toBe(138);
    expect(rows[0].yardages).toHaveLength(18);
  });

  it('reads a card with no tee rows as silence, not as a fault', () => {
    // A card photographed with its rating table outside the frame is still
    // worth approving for its pars. If this threw, or produced a problem
    // line, the reviewer would be pushed to reject a good submission.
    for (const payload of [card(), cardWithTees([]), cardWithTees(null as never)]) {
      const parsed = parseProposedCard(payload);

      expect(teeRows(parsed)).toEqual([]);
      expect(scorecardProblems(parsed)).toEqual([]);
    }
  });

  it('survives a tee row whose yardages never made it', () => {
    // The scan can read a rating table and no yardage row at all. Treating
    // the missing list as absent rather than as a crash is what keeps the
    // ratings — the part worth approving — on the screen.
    const parsed = parseProposedCard(cardWithTees([tee('GOLD', { yardages: undefined })]));

    expect(teeRows(parsed)[0].yardages).toEqual([]);
    expect(yardageTotals(teeRows(parsed)[0])).toEqual({
      front: null,
      back: null,
      total: null,
      printedFront: null,
      printedBack: null,
      printedTotal: null,
      contradicted: false,
      checked: false,
    });
  });
});

describe('the two ratings a card prints for one tee', () => {
  it('keeps both rows when the card rates a tee for men and for women', () => {
    // A course is rated separately for men and for women, and a card that
    // prints ratings prints both — two rows against the same colour. Keying
    // the drop check on the name alone marked the second as doomed, which was
    // right until the server learned to keep it and wrong afterwards.
    const card = parseProposedCard(
      cardWithTees([
        tee('RED', { gender: 'MEN', courseRating: 68.2, slopeRating: 118 }),
        tee('RED', { gender: 'LADIES', courseRating: 72.4, slopeRating: 128 }),
      ]),
    );

    expect(droppedTeeIndexes(card).size).toBe(0);
  });

  it('still drops the same row read twice', () => {
    // The original problem has not gone away: a card whose GOLD column was
    // read twice publishes one GOLD, and the reviewer has to see which.
    const card = parseProposedCard(
      cardWithTees([tee('GOLD', { gender: 'MEN' }), tee('GOLD', { gender: 'MEN' })]),
    );

    expect([...droppedTeeIndexes(card)]).toEqual([1]);
  });

  it('treats an unlabelled row as unspecified, not as the men\'s', () => {
    // Reading a rating nobody labelled as the men's would be a guess that
    // looks like data: a woman playing off it gets a differential computed
    // against the wrong number with nothing on screen to say so.
    const card = parseProposedCard(
      cardWithTees([tee('BLUE'), tee('BLUE', { gender: 'MEN' })]),
    );

    expect(droppedTeeIndexes(card).size).toBe(0);
  });
});

describe('the ladies index row', () => {
  it('is shown only when the card printed one', () => {
    const one = parseProposedCard(
      JSON.stringify({
        name: 'A',
        segmentCourseIds: [1],
        holes: [{ hole: 1, par: 4, strokeIndex: 7 }],
      }),
    );
    const two = parseProposedCard(
      JSON.stringify({
        name: 'A',
        segmentCourseIds: [1],
        holes: [{ hole: 1, par: 4, strokeIndex: 7, strokeIndexLadies: 9 }],
      }),
    );

    expect(hasLadiesIndex(one)).toBe(false);
    expect(hasLadiesIndex(two)).toBe(true);
  });
});

describe('checking eighteen yardages against a photograph', () => {
  it('totals the nines the way the card prints them', () => {
    // Nobody adds eighteen numbers per tee by hand, so nobody would check
    // them. The card prints OUT, IN and the total; matching those three is
    // the check that actually gets done.
    const rows = teeRows(parseProposedCard(cardWithTees([tee('GOLD')])));

    expect(yardageTotals(rows[0])).toEqual({
      front: 9 * 400,
      back: 9 * 400,
      total: 18 * 400,
      printedFront: null,
      printedBack: null,
      printedTotal: null,
      contradicted: false,
      checked: false,
    });
  });

  it('calls out a row that does not add up to the sum printed beside it', () => {
    // The point of asking the card for its own sums. Until this, the totals
    // were added up from the very yardages in question, so a 3 misread as an
    // 8 produced a total in perfect agreement with itself — and there are
    // ninety of those cells on a five-tee card against par's eighteen.
    const misread = tee('GOLD', {
      yardages: Array.from({ length: 18 }, (_, i) => ({
        hole: i + 1,
        yards: i === 0 ? 450 : 400,
      })),
      yardsOut: 3600,
      yardsIn: 3600,
      yardsTotal: 7200,
    });

    const totals = yardageTotals(teeRows(parseProposedCard(cardWithTees([misread])))[0]);

    expect(totals.front).toBe(3650);
    expect(totals.printedFront).toBe(3600);
    expect(totals.contradicted).toBe(true);
    expect(totals.checked).toBe(true);
  });

  it('agrees quietly when the row adds up', () => {
    const clean = tee('GOLD', { yardsOut: 3600, yardsIn: 3600, yardsTotal: 7200 });

    const totals = yardageTotals(teeRows(parseProposedCard(cardWithTees([clean])))[0]);

    expect(totals.contradicted).toBe(false);
    expect(totals.checked).toBe(true);
  });

  it('does not call a nine outside the frame a contradiction', () => {
    // A card photographed front-nine-only prints a TOTAL for eighteen. The
    // back nine is absent, not wrong, and flagging it would put a warning on
    // every such card.
    const frontOnly = tee('GOLD', {
      yardages: Array.from({ length: 9 }, (_, i) => ({ hole: i + 1, yards: 400 })),
      yardsOut: 3600,
    });

    const totals = yardageTotals(teeRows(parseProposedCard(cardWithTees([frontOnly])))[0]);

    expect(totals.contradicted).toBe(false);
    expect(totals.checked).toBe(true);
  });

  it('reports no back nine for a card that only carries a front one', () => {
    // Zero would read as "this nine measures nothing", which is a claim the
    // card never made. A reviewer comparing an IN of 0 against a photograph
    // that has none would have to work out which it was.
    const front = tee('GOLD', {
      yardages: Array.from({ length: 9 }, (_, i) => ({ hole: i + 1, yards: 400 })),
    });

    const rows = teeRows(parseProposedCard(cardWithTees([front])));

    expect(yardageTotals(rows[0])).toEqual({
      front: 3600,
      back: null,
      total: 3600,
      printedFront: null,
      printedBack: null,
      printedTotal: null,
      contradicted: false,
      checked: false,
    });
  });

  it('shows the reading that will be stored when a hole is measured twice', () => {
    // The server keeps the first reading of a hole and skips the rest. If the
    // table showed the last, the reviewer would approve against a number that
    // never reaches the database.
    const twice = tee('GOLD', {
      yardages: [
        { hole: 1, yards: 416 },
        { hole: 1, yards: 461 },
        { hole: 2, yards: 380 },
      ],
    });

    const parsed = parseProposedCard(cardWithTees([twice]));
    const row = teeRows(parsed)[0];

    expect(yardsByHole(row).get(1)).toBe(416);
    expect(duplicateYardageHoles(row)).toEqual([1]);
    expect(scorecardProblems(parsed)).toContain('Tee GOLD đo trùng hố: 1');
  });
});

describe('tee rows approval will quietly leave out', () => {
  it('marks the second row of a name the card only has once', () => {
    // One column read twice publishes one tee and drops the other, with its
    // ratings and its eighteen yardages, and nothing says so afterwards. A
    // reviewer would sign off believing both were saved.
    const parsed = parseProposedCard(cardWithTees([tee('GOLD'), tee('gold'), tee('BLUE')]));

    expect([...droppedTeeIndexes(parsed)]).toEqual([1]);
    expect(scorecardProblems(parsed)).toContain('Hàng tee sẽ không được lưu: gold');
  });

  it('marks a row with no name, which is dropped whole', () => {
    // The server skips a nameless row entirely. Its course rating and slope
    // look approved on screen and are never written.
    const parsed = parseProposedCard(cardWithTees([tee('  '), tee('BLUE')]));

    expect([...droppedTeeIndexes(parsed)]).toEqual([0]);
    expect(scorecardProblems(parsed)).toContain(
      'Hàng tee sẽ không được lưu: hàng chưa đặt tên',
    );
  });

  it('leaves the pars first in the list of problems', () => {
    // Stroke indexes are why the item is in the queue; a tee warning must not
    // push the reason for the review below the fold.
    const duplicated = nine.map((l) => (l.hole === 7 ? { ...l, strokeIndex: 2 } : l));

    const parsed = parseProposedCard(cardWithTees([tee('GOLD'), tee('GOLD')], duplicated));

    expect(scorecardProblems(parsed)[0]).toContain('Chỉ số bị trùng');
    expect(scorecardProblems(parsed)[1]).toContain('Hàng tee');
  });
});

describe('the par row against what the club printed beside it', () => {
  // Every other check here compares the card to itself. The printed sums are
  // the one independent fact a photograph carries, and until the submission
  // could carry them there was nothing to compare the pars against at all.
  const eighteen = (): ProposedLine[] =>
    Array.from({ length: 18 }, (_, i) => ({
      hole: i + 1,
      par: i % 3 === 2 ? 3 : 4,
      strokeIndex: i + 1,
    }));

  const card = (extra: Record<string, unknown>) =>
    parseProposedCard(
      JSON.stringify({ name: 'A + B', segmentCourseIds: [1], holes: eighteen(), ...extra }),
    );

  it('reports each nine as well as the whole card', () => {
    const par = parComparison(card({ parOut: 33, parIn: 33, parTotal: 66 }));

    expect(par.out.read).toBe(33);
    expect(par.in.read).toBe(33);
    expect(par.total.read).toBe(66);
    expect(par.out.off || par.in.off || par.total.off).toBe(false);
  });

  it('catches a total the pars do not reach', () => {
    const par = parComparison(card({ parTotal: 72 }));

    expect(par.total.off).toBe(true);
    expect(scorecardProblems(card({ parTotal: 72 }))).toContainEqual(
      expect.stringContaining('66'),
    );
  });

  // A total alone cannot see this: reading the front nine's par onto the back
  // and the back's onto the front leaves the total exactly where it was.
  it('catches a swap between the nines that the total hides', () => {
    const par = parComparison(card({ parOut: 30, parIn: 36, parTotal: 66 }));

    expect(par.total.off).toBe(false);
    expect(par.out.off).toBe(true);
    expect(par.in.off).toBe(true);
  });

  // Most cards ever submitted carry none of these, and a photograph can cut
  // the sums off. Absent is not wrong.
  it('says nothing about sums the card does not carry', () => {
    const par = parComparison(card({}));

    expect(par.out.printed).toBeNull();
    expect(par.out.off).toBe(false);
    expect(scorecardProblems(card({}))).toEqual([]);
  });
});
