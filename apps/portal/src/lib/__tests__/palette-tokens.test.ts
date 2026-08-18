import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { resolve, relative } from 'node:path';
import { globSync } from 'node:fs';

/**
 * One palette, named once.
 *
 * `styles.css` defines the operations theme as CSS custom properties — the
 * Material-3 dark tonal set from docs/mockup/DESIGN.md. Components then wrote
 * the same colours again as hex: on 18/8/2026 there were 1404 hex literals
 * outside styles.css and 803 of them were an exact copy of a token that
 * already existed. `#2d3449` appeared 207 times; it is `--surface-container-highest`.
 *
 * A copy is not merely untidy. It is a colour that will not move when the
 * token moves, so the first person to adjust the surface ramp changes a
 * quarter of the portal and leaves the rest behind, and nothing tells them.
 * The mobile app had the same defect and the same answer: a grep asserted in
 * a test, because the property is "nobody reintroduced a second palette",
 * which no rendered component can demonstrate.
 *
 * WHAT THIS DOES NOT BAN
 *   Hex that is *not* a token. Roughly 600 remain — `#dc2626`, `#c5cde8`,
 *   `#ea580c` — and mapping those onto the ramp changes what is on screen
 *   rather than how it is written. That is a design decision and it is not
 *   this test's to make, so it is left visible rather than quietly forced.
 *
 *   Hex outside <style>. Nineteen sit in <script>, mostly MapLibre paint
 *   properties, where a colour has to be a real value: `var(--x)` means
 *   nothing to a map layer.
 */

const SRC = resolve(__dirname, '../..');

/** Every token in styles.css that is defined as a plain hex colour. */
function tokensByValue(): Map<string, string> {
  const css = readFileSync(resolve(SRC, 'styles.css'), 'utf8');
  const byValue = new Map<string, string>();
  for (const m of css.matchAll(/--([a-z0-9-]+):\s*(#[0-9a-fA-F]{6})\b/g)) {
    byValue.set(m[2].toLowerCase(), m[1]);
  }
  return byValue;
}

/** The [start, end) ranges of every <style> block in a single-file component. */
function styleRanges(source: string): Array<[number, number]> {
  const ranges: Array<[number, number]> = [];
  for (const m of source.matchAll(/<style\b[^>]*>/g)) {
    const from = m.index! + m[0].length;
    const to = source.indexOf('</style>', from);
    ranges.push([from, to === -1 ? source.length : to]);
  }
  return ranges;
}

describe('the portal has one palette', () => {
  it('no component restates a colour the theme already names', () => {
    const tokens = tokensByValue();
    expect(tokens.size).toBeGreaterThan(10);

    const offenders: string[] = [];

    for (const file of globSync(`${SRC}/**/*.vue`)) {
      const source = readFileSync(file, 'utf8');
      const ranges = styleRanges(source);
      if (ranges.length === 0) continue;

      // Comments are allowed to name a colour — several explain a mapping.
      const comments = [...source.matchAll(/\/\*[\s\S]*?\*\//g)].map(
        (m) => [m.index!, m.index! + m[0].length] as [number, number],
      );
      const within = (i: number, rs: Array<[number, number]>) =>
        rs.some(([a, b]) => i >= a && i < b);

      for (const m of source.matchAll(/#[0-9a-fA-F]{6}\b/g)) {
        const at = m.index!;
        if (!within(at, ranges)) continue;
        if (within(at, comments)) continue;
        const token = tokens.get(m[0].toLowerCase());
        if (!token) continue;
        const line = source.slice(0, at).split('\n').length;
        offenders.push(`${relative(SRC, file)}:${line}  ${m[0]} is var(--${token})`);
      }
    }

    expect(
      offenders,
      `Use the token, not a copy of its value:\n${offenders.join('\n')}`,
    ).toEqual([]);
  });
});
