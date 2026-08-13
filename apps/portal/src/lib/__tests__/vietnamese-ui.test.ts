import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { resolve, relative } from 'node:path';
import { globSync } from 'node:fs';
import { parseForESLint } from 'vue-eslint-parser';
import * as tsParser from '@typescript-eslint/parser';

/**
 * Keeps English out of a Vietnamese-only interface.
 *
 * The portal has no i18n catalogue — every string is written where it is
 * displayed — and that is a deliberate position for a single-language product,
 * not an oversight. What it costs is measurability: nobody can tell what is
 * still in English without reading forty files, and this session proved the
 * point the hard way. The count was reported as "3 remaining", then a better
 * scan found 130, then a broader one found more still, because each pass
 * looked in one place: first only text between tags, then attributes, then the
 * error messages sitting in <script> that a user meets at the worst moment.
 *
 * So: the measurement is the fix. If somebody adds an English label, this
 * fails, and the count stops being a matter of opinion.
 *
 * WHAT THIS CANNOT DO
 *   It is a heuristic over source text, not a translator. It cannot tell a
 *   Vietnamese word with no diacritics ("Sau", "Trang web") from an English
 *   one, and it cannot tell a golf term the club actually says in English
 *   ("Birdie", "Net", "HDC") from a lapse. Both cases live in ALLOWED below.
 *   Adding to that list is normal; adding to it without reading the string is
 *   how the check quietly becomes decoration.
 */

const SRC = resolve(__dirname, '../..');

/**
 * Strings that are correct in English, with the reason grouped.
 *
 * Golf vocabulary is the large group and it is not laziness: Vietnamese
 * golfers say birdie, eagle, net, par, flight and HDC, and "Nhóm bay" for
 * flight was tried in this codebase and reverted for reading as a translation
 * of a word nobody translates.
 */
const ALLOWED = new Set([
  // Golf vocabulary used untranslated by Vietnamese players
  'HDC', 'CAP', 'FLY', 'Net', 'Golfer', 'Birdie', 'Eagle', 'Par', 'Green',
  'Tee box', 'Flight', 'Handicap', 'So par', 'Theo flight', 'Bir/Eag',
  'Stableford', 'Stroke Play', 'Match Play', 'Stimpmeter', 'Yard', 'Bunker',
  // Printed on the club's card in English and said in English by the players
  // reading it. The mobile app's Vietnamese catalogue made the same call —
  // app_vi.arb has fieldCourseRating: "Course Rating" and fieldSlope: "Slope"
  // — and a reviewer comparing the portal against a photograph is matching
  // the words on that photograph.
  'Course Rating', 'Slope',
  // Product and provider names
  'GolfOps Portal', 'Course Operations', 'Vietnam Smart Golf',
  'CARTO', 'OpenStreetMap', 'Esri', 'Maxar', 'SPDX', 'SPDX ID',
  'CC BY 4.0', 'CC-BY-4.0',
  // Locale names, shown as the locale itself
  'English (US)', 'Thai (TH)', 'Japanese (JP)', 'Vietnamese (VN)',
  // Vietnamese that happens to carry no diacritics
  'Sau', 'Sau →', 'Trang sau', 'Trang web', 'Xem manifest.json', 'Trang § / §',
  // Jargon carrying an interpolated value; § is a blanked {{ expression }}
  'par §', 'Par §', 'HDC §–§', 'Flight §', 'Stimpmeter (§–§)', 'v§ (§)',
  'golfer, § flight.', 'v2.4.1', '(FLY §)', '· par §', '§ golfer', '§ tee box',
  // Fragments of a Vietnamese sentence, split by an interpolation in the AST
  '(FLY', 'Stimpmeter (', 'Trang', 'flight.', 'golfer ·', 'golfer,', 'golfer.',
  'tee box', '· par', '· par 3:', '· par 5:',
  // Not prose: a key name, a sample URL, an attribution glyph, a CSV header
  'Enter', 'https://example.com', 'contributors ©', 'playerId,handicap',
  'VN, TH', 'CURRENCY', 'TIMEZONE', 'Active', 'Valid', 'Website', 'Add',
]);

const DIACRITIC =
  /[àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ]/i;

/** A lone lowercase token is a Material Symbols ligature, not a sentence. */
const ICON = /^[a-z][a-z0-9_]*$/;

/**
 * Values that are code, not prose.
 *
 * The script-side scan reads maps keyed by an enum, and those maps hold labels
 * in some places and CSS classes or field names in others — statusClass()
 * returns 'badge-cancelled', a filter map returns 'courseId'. Same shape, and
 * only the value tells them apart.
 */
const CODEY = [
  /^[a-z][a-zA-Z0-9]*$/, // camelCase identifier: courseId, flightId
  /^[a-z0-9]+(-[a-z0-9]+)+$/, // kebab CSS class: badge-active
  /^(Point|LineString|Polygon|MultiPoint|MultiLineString|MultiPolygon|Feature|FeatureCollection)$/,
];

function vueFiles(): string[] {
  return globSync('**/*.vue', { cwd: SRC })
    .map((f) => resolve(SRC, f))
    .sort();
}

/**
 * Every string a template can show, taken from the parsed template rather than
 * matched out of the text.
 *
 * This used to be regular expressions, and the history of this file is the
 * history of their gaps. Text between tags, then attributes, then labels built
 * in <script>, then literals inside {{ ternaries }}, then anything beginning
 * with "+" because a filter demanded a leading letter, then a label written
 * with a backtick, then "&#8592; Back" written as an HTML entity. Each gap was
 * found by accident — twice by looking at a screenshot — and each fix was
 * another pattern that did not anticipate the next form.
 *
 * The parser does not have forms it has not anticipated. It reports the text
 * nodes, the attributes and the expressions because that is what the document
 * is made of, so the "what did I forget to match" question stops being asked.
 * What is left is a judgement about the string itself, which is a question
 * that has an answer.
 */
function templateStrings(source: string): string[] {
  // The script block is TypeScript, so the TS parser has to be handed in. It
  // was not, at first, and vue-eslint-parser threw on every component — into a
  // catch that returned an empty list. Sixty files then reported no findings
  // and the suite went green while checking nothing at all. A guard that
  // cannot read its input has to say so, so nothing here is caught.
  const ast = parseForESLint(source, {
    parser: tsParser,
    ecmaVersion: 'latest',
    sourceType: 'module',
  }).ast;

  const body = (ast as { templateBody?: unknown }).templateBody;
  if (!body) return [];

  const out: string[] = [];
  const READ_ATTR = new Set(['aria-label', 'title', 'placeholder', 'alt', 'aria-description']);

  const walk = (node: any): void => {
    if (!node || typeof node.type !== 'string') return;

    if (node.type === 'VText' && typeof node.value === 'string') out.push(node.value);

    if (node.type === 'VAttribute') {
      const name = node.key?.name;
      const plain = typeof name === 'string' ? name : name?.name;
      // Static attribute: value is a literal. Bound ones hold expressions and
      // are covered below, where the literals inside them are read.
      if (READ_ATTR.has(String(plain)) && node.value?.type === 'VLiteral') {
        out.push(String(node.value.value));
      }
    }

    // Any string literal appearing in an expression the template evaluates —
    // {{ saving ? 'Đang lưu…' : 'Save' }} and :title="cond ? 'A' : 'B'" alike.
    // Filtered, because an expression also holds routes and class-name pieces:
    // these are literals in the same position as labels and only the string
    // itself distinguishes them.
    if (node.type === 'Literal' && typeof node.value === 'string' && isProse(node.value)) {
      out.push(node.value);
    }
    // A template literal is one label, so join it before judging. Taking the
    // quasis one at a time splits `Course map showing ${n} features` into
    // single words, each of which fails the prose test on its own — the label
    // disappears precisely because it interpolates something.
    if (node.type === 'TemplateLiteral' && Array.isArray(node.quasis)) {
      const joined = node.quasis
        .map((q: any) => (typeof q.value?.cooked === 'string' ? q.value.cooked : ''))
        .join('§');
      if (isProse(joined.replace(/§/g, ' '))) out.push(joined);
    }

    for (const key of Object.keys(node)) {
      if (key === 'parent') continue;
      const child = node[key];
      if (Array.isArray(child)) child.forEach(walk);
      else if (child && typeof child === 'object') walk(child);
    }
  };
  walk(body);
  return out;
}

/**
 * Every string literal in the script block.
 *
 * Collected wholesale and judged by {@link isProse}, rather than guessed at by
 * variable name. Asking whether `createError` sounds user-facing missed
 * 'Failed to create course', which sat behind `?? '…'` rather than directly
 * after an `=`; each such miss produced another pattern and the next miss
 * produced another.
 */
function scriptStrings(source: string): string[] {
  const m = /<script[^>]*>([\s\S]*?)<\/script>/.exec(source);
  if (!m) return [];
  const body = m[1].replace(/\/\/[^\n]*/g, '').replace(/\/\*[\s\S]*?\*\//g, '');
  const out: string[] = [];
  for (const x of body.matchAll(/'([^'\\\n]{2,140})'|"([^"\\\n]{2,140})"|`([^`$\\\n]{2,140})`/g)) {
    out.push(x[1] ?? x[2] ?? x[3]);
  }
  return out;
}

/**
 * Is this a string a person reads, rather than one a machine acts on?
 *
 * Prose has words with spaces between them, or is a single word this app uses
 * as a button. Routes, CSS classes, enum values, MIME types and field names
 * all fail at least one of those.
 */
const UI_WORD = new Set([
  'Cancel', 'Confirm', 'Save', 'Delete', 'Edit', 'Close', 'Retry', 'Submit',
  'Discard', 'Back', 'Next', 'Prev', 'Search', 'Filter', 'Reset', 'Apply',
  'Loading', 'Saving', 'Deleting', 'Creating', 'Publishing', 'Failed',
  'Unknown', 'Queued', 'Building', 'Validating', 'Completed', 'Archived',
  'Published', 'Draft', 'Pending', 'Approved', 'Rejected',
]);

function isProse(t: string): boolean {
  // Fragments of code, caught when a match ran from one quote to the next
  // across an expression: ") + entry.scoreToPar :".
  if (/=>|\$\{|\)\.|\);|^\W*\)/.test(t)) return false;
  if (/^[/.#]|:\/\//.test(t)) return false;
  if (/^[a-z0-9-]+\/[a-z0-9+.-]+$/.test(t)) return false;
  if (/^[A-Za-z-]+:\s?[^ ]+$/.test(t)) return false;
  const words = t.trim().replace(/^[^\p{L}]+/u, '').split(/\s+/).filter((w) => /\p{L}{2}/u.test(w));
  if (words.length >= 2) return true;
  return UI_WORD.has(words[0]?.replace(/[^A-Za-z]/g, '') ?? '');
}

function offenders(source: string): string[] {
  const found = new Set<string>();
  for (const raw of [...templateStrings(source), ...scriptStrings(source).filter(isProse)]) {
    const t = raw.split(/\s+/).join(' ').trim();
    // Judge the words, not the first character. Requiring a leading letter is
    // what let "+ New Facility" and "+ New Tournament" through every scan in
    // this file's history — both were found by looking at a screenshot, which
    // is not a strategy. A label is prose if it contains prose.
    const words = t.replace(/^[^\p{L}]+/u, '');
    if (words.length < 3) continue;
    if (!/[A-Za-z]{3}/.test(words)) continue;
    if (DIACRITIC.test(t)) continue; // certainly Vietnamese
    if (ICON.test(t)) continue;
    if (ALLOWED.has(t)) continue;
    if (/^[A-Z_]{2,}$/.test(t)) continue; // enum value rendered raw
    if (CODEY.some((re) => re.test(t))) continue;
    if (/§/.test(t) && t.replace(/§/g, '').trim().length < 3) continue;
    found.add(t);
  }
  return [...found].sort();
}

describe('the portal speaks Vietnamese', () => {
  const files = vueFiles();

  it('finds components to check', () => {
    // Without this, a broken glob would report perfect health over nothing.
    expect(files.length).toBeGreaterThan(20);
  });

  it.each(vueFiles().map((f) => [relative(SRC, f), f] as const))(
    '%s has no untranslated user-facing text',
    (_name, file) => {
      const bad = offenders(readFileSync(file, 'utf8'));

      // If one of these is correct in English, add it to ALLOWED with the
      // reason — do not widen the heuristic to make it disappear.
      expect(bad).toEqual([]);
    }
  );
});
