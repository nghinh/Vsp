/**
 * Reading a golfer's proposed scorecard, and saying what is wrong with it.
 *
 * Kept out of the component so it can be tested without a DOM — this portal
 * has no jsdom — and because the two faults it looks for are what decide
 * whether an approved card allocates strokes correctly. A stroke index handed
 * out twice misallocates them on both holes, for everyone who plays that card
 * afterwards, and neither a table nor a photograph makes that obvious.
 */

export interface ProposedLine {
  hole: number;
  par: number;
  strokeIndex: number | null;
}

export interface ProposedCard {
  name: string;
  segmentCourseIds: number[];
  holes: ProposedLine[];
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
  return problems;
}
