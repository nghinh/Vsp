/**
 * Reading a golfer's proposed scorecard, and saying what is wrong with it.
 *
 * Kept out of the component so it can be tested without a DOM — this portal
 * has no jsdom — and because the faults it looks for are what decide whether
 * an approved card allocates strokes correctly. A stroke index handed out
 * twice misallocates them on both holes, for everyone who plays that card
 * afterwards, and neither a table nor a photograph makes that obvious.
 *
 * The card also carries its tee rows now, and approving it writes them. The
 * rule on the golfer's side is that nothing is saved without being displayed
 * first, and it holds here for the same reason: a reviewer cannot vouch for a
 * number they were never shown.
 */

export interface ProposedLine {
  hole: number;
  par: number;
  strokeIndex: number | null;
}

export interface ProposedYardage {
  hole: number;
  yards: number;
}

/**
 * One tee row of the printed card.
 *
 * Course rating and slope are nullable because plenty of cards print their
 * yardages and no ratings at all, and a card photographed with the rating
 * table outside the frame is still worth approving for its pars.
 */
export interface ProposedTee {
  name: string;
  courseRating: number | null;
  slopeRating: number | null;
  /** What the card prints in this row's OUT, IN and TOTAL columns. Absent on
   *  cards submitted before these were read, and on rows whose sums did not
   *  make it into the photograph. */
  yardsOut?: number | null;
  yardsIn?: number | null;
  yardsTotal?: number | null;
  yardages: ProposedYardage[];
}

export interface ProposedCard {
  name: string;
  segmentCourseIds: number[];
  holes: ProposedLine[];
  /** Absent on cards submitted before tee rows were read, and on cards whose
   *  rating table did not make it into the photograph. */
  tees?: ProposedTee[];
}

/** The stored payload, or null when it is absent or unreadable. */
export function parseProposedCard(json: string | null): ProposedCard | null {
  if (!json) {
    return null;
  }
  try {
    const parsed = JSON.parse(json) as ProposedCard;
    return Array.isArray(parsed?.holes) ? parsed : null;
  } catch {
    // Half a table is worse than none: the reviewer still has the photograph.
    return null;
  }
}

export function parTotal(card: ProposedCard | null): number {
  return (card?.holes ?? []).reduce((sum, line) => sum + (line.par ?? 0), 0);
}

/** Every stroke index this card hands out more than once. */
export function duplicateStrokeIndexes(card: ProposedCard | null): Set<number> {
  const seen = new Set<number>();
  const twice = new Set<number>();
  for (const line of card?.holes ?? []) {
    if (line.strokeIndex == null) {
      continue;
    }
    if (seen.has(line.strokeIndex)) {
      twice.add(line.strokeIndex);
    }
    seen.add(line.strokeIndex);
  }
  return twice;
}

/** Holes the golfer left without a stroke index. */
export function holesMissingStrokeIndex(card: ProposedCard | null): number[] {
  return (card?.holes ?? []).filter((l) => l.strokeIndex == null).map((l) => l.hole);
}

// ─── Tee rows ───────────────────────────────────────────────────────────────

/**
 * The tee rows on this card, and an empty list when it has none.
 *
 * A card with no tee rows is the ordinary case, not a fault, so the absent
 * key, an explicit null and something that is not a list at all all come back
 * the same way — as silence the component can render as a sentence instead of
 * as an empty table or a warning.
 */
export function teeRows(card: ProposedCard | null): ProposedTee[] {
  const tees = card?.tees;
  if (!Array.isArray(tees)) {
    return [];
  }
  return tees.map((tee) => ({
    ...tee,
    yardages: Array.isArray(tee?.yardages) ? tee.yardages : [],
  }));
}

/**
 * One tee row's yardages, keyed by hole, as approval will store them.
 *
 * The first reading of a hole wins, because that is what the server does: it
 * skips a hole it has already written rather than overwriting it. Showing the
 * last would show the reviewer a number that never reaches the database.
 */
export function yardsByHole(tee: ProposedTee): Map<number, number> {
  const byHole = new Map<number, number>();
  for (const yardage of tee.yardages ?? []) {
    if (yardage != null && !byHole.has(yardage.hole)) {
      byHole.set(yardage.hole, yardage.yards);
    }
  }
  return byHole;
}

export interface TeeTotals {
  /** Holes 1–9, added up from the yardages submitted. */
  front: number | null;
  /** Holes 10–18. */
  back: number | null;
  total: number | null;
  /** The same three as the club printed them, where the card showed them. */
  printedFront: number | null;
  printedBack: number | null;
  printedTotal: number | null;
  /** True where a printed sum disagrees with what was read — a digit is wrong
   *  somewhere in that row, and the reviewer has the photograph. */
  contradicted: boolean;
  /** False where the card printed no sums, so nothing here was checked. */
  checked: boolean;
}

/**
 * The three numbers a printed card totals its yardages into.
 *
 * Eighteen numbers per tee is more than anyone checks one at a time against a
 * photograph, but the card prints OUT, IN and the total beside them, so three
 * glances confirm all eighteen. Null rather than zero when a nine is missing:
 * a card that only carries a front nine should say so, not claim its back
 * nine measures nothing.
 */
export function yardageTotals(tee: ProposedTee): TeeTotals {
  const byHole = yardsByHole(tee);
  let front = 0;
  let back = 0;
  let hasFront = false;
  let hasBack = false;

  for (const [hole, yards] of byHole) {
    if (hole <= 9) {
      front += yards;
      hasFront = true;
    } else {
      back += yards;
      hasBack = true;
    }
  }

  const printedFront = numberOrNull(tee.yardsOut);
  const printedBack = numberOrNull(tee.yardsIn);
  const printedTotal = numberOrNull(tee.yardsTotal);

  // Only the halves the photograph shows are judged. A back nine outside the
  // frame is absent, not wrong, and calling it wrong would flag every
  // nine-hole card in the country.
  const frontWrong = hasFront && printedFront !== null && printedFront !== front;
  const backWrong = hasBack && printedBack !== null && printedBack !== back;
  const totalWrong =
    (hasFront || hasBack) &&
    printedTotal !== null &&
    printedTotal !== front + back;

  return {
    front: hasFront ? front : null,
    back: hasBack ? back : null,
    total: hasFront || hasBack ? front + back : null,
    printedFront,
    printedBack,
    printedTotal,
    contradicted: frontWrong || backWrong || totalWrong,
    checked: printedFront !== null || printedBack !== null || printedTotal !== null,
  };
}

function numberOrNull(value: number | null | undefined): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

/**
 * The tee rows approval will silently leave out, by position in the list.
 *
 * The server keeps one row per name and skips a row with no name at all, so a
 * card that reads its GOLD column twice publishes one GOLD and drops the
 * other — along with its ratings and its eighteen yardages. Nothing tells the
 * reviewer afterwards, so it has to be visible before they decide, and the
 * comparison is the server's: trimmed and case-insensitive.
 */
export function droppedTeeIndexes(card: ProposedCard | null): Set<number> {
  const seen = new Set<string>();
  const dropped = new Set<number>();

  teeRows(card).forEach((tee, index) => {
    const name = (tee.name ?? '').trim();
    if (!name || seen.has(name.toUpperCase())) {
      dropped.add(index);
      return;
    }
    seen.add(name.toUpperCase());
  });

  return dropped;
}

/** Holes this tee row measures more than once; only the first is written. */
export function duplicateYardageHoles(tee: ProposedTee): number[] {
  const seen = new Set<number>();
  const twice = new Set<number>();
  for (const yardage of tee.yardages ?? []) {
    if (yardage == null) {
      continue;
    }
    if (seen.has(yardage.hole)) {
      twice.add(yardage.hole);
    }
    seen.add(yardage.hole);
  }
  return [...twice];
}

/** What to tell the reviewer before they decide, in Vietnamese. */
export function scorecardProblems(card: ProposedCard | null): string[] {
  const problems: string[] = [];
  const duplicates = duplicateStrokeIndexes(card);
  const missing = holesMissingStrokeIndex(card);

  if (duplicates.size > 0) {
    problems.push(`Chỉ số bị trùng: ${[...duplicates].join(', ')}`);
  }
  if (missing.length > 0) {
    problems.push(`Hố chưa có chỉ số: ${missing.join(', ')}`);
  }

  // Tee faults come after the pars because the pars are why the item is in
  // the queue. They are listed at all because approval acts on them without
  // saying so: a dropped row leaves the reviewer believing they published a
  // tee that is not in the database. A missing yardage needs no line here —
  // it shows as a dash in its own cell, where the eye is already looking.
  const tees = teeRows(card);
  const dropped = droppedTeeIndexes(card);
  if (dropped.size > 0) {
    const names = [...dropped].map((i) => tees[i].name?.trim() || 'hàng chưa đặt tên');
    problems.push(`Hàng tee sẽ không được lưu: ${names.join(', ')}`);
  }
  for (const tee of tees) {
    const repeated = duplicateYardageHoles(tee);
    if (repeated.length > 0) {
      problems.push(`Tee ${tee.name} đo trùng hố: ${repeated.join(', ')}`);
    }
  }

  return problems;
}
