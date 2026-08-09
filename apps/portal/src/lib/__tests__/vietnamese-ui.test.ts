import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { resolve, relative } from 'node:path';
import { globSync } from 'node:fs';

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

/** Text a user reads, from a template with script, style and comments removed. */
function userVisibleStrings(source: string): string[] {
  let tpl = source
    .replace(/<script[\s\S]*?<\/script>/g, '')
    .replace(/<style[\s\S]*?<\/style>/g, '')
    .replace(/<!--[\s\S]*?-->/g, '');
  // An interpolation is a value, not a label; blank it so surrounding prose
  // still reads as one string.
  tpl = tpl.replace(/\{\{[^}]*\}\}/g, '§');

  const out: string[] = [];
  for (const m of tpl.matchAll(/>([^<>{}]+)</g)) out.push(m[1]);
  // Static attributes only. A bound one (:aria-label="mapAriaLabel") holds an
  // expression, and reporting the variable's name as untranslated English is
  // how a check earns its reputation for crying wolf.
  for (const m of tpl.matchAll(/(?<![:@\w-])(?:aria-label|title|placeholder)="([^"{}]+)"/g)) {
    out.push(m[1]);
  }
  // Literals inside interpolations. Blanking {{ … }} above hid an entire
  // idiom this codebase uses constantly — {{ saving ? 'Đang lưu…' : 'Save' }}
  // — where half the label is Vietnamese and half was never translated.
  for (const m of source.matchAll(/\{\{([^}]*)\}\}/g)) {
    for (const s of m[1].matchAll(/'([^']{2,120})'|"([^"]{2,120})"/g)) {
      const lit = s[1] ?? s[2];
      // Same prose test as the script side: an interpolation is an expression,
      // so a quote-to-quote match can straddle code rather than a label.
      if (isProse(lit)) out.push(lit);
    }
  }
  return out;
}

/**
 * Every string literal in the script block.
 *
 * The earlier version of this asked "is the variable name one that sounds
 * user-facing?" — errorMessage, statusLabel, and so on. That question is
 * unanswerable and it kept being answered wrong: 'Failed to create course'
 * hid behind `createError.value = apiErr?.message ?? '…'` because the literal
 * did not sit directly after the `=`, and two validation strings hid behind
 * `validationErrors.name = '…'` because of the property access in between.
 * Each miss produced another pattern, and the next miss produced another.
 *
 * So this collects everything and lets {@link isProse} decide. Judging the
 * string is a question with an answer; guessing its context is not.
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
 * Is this string something a person reads, rather than something a machine does?
 *
 * Prose has words with spaces between them, or is a single word this app uses
 * as a button. Everything else the codebase keeps in strings — routes, CSS
 * classes, enum values, MIME types, field names, format tokens — fails at
 * least one of those.
 */
const UI_WORD = new Set([
  'Cancel', 'Confirm', 'Save', 'Delete', 'Edit', 'Close', 'Retry', 'Submit',
  'Discard', 'Back', 'Next', 'Prev', 'Search', 'Filter', 'Reset', 'Apply',
  'Loading', 'Saving', 'Deleting', 'Creating', 'Publishing', 'Failed',
  'Unknown', 'Queued', 'Building', 'Validating', 'Completed', 'Archived',
  'Published', 'Draft', 'Pending', 'Approved', 'Rejected',
]);

function isProse(t: string): boolean {
  // Fragments of code, caught when a regex ran from one quote to the next
  // across an expression: ") + entry.scoreToPar :".
  if (/=>|\$\{|\)\.|\);|^\W*\)/.test(t)) return false;
  if (/^[/.#]|:\/\//.test(t)) return false;            // route, path, url
  if (/^[a-z0-9-]+\/[a-z0-9+.-]+$/.test(t)) return false; // mime type
  if (/^[A-Za-z-]+:\s?[^ ]+$/.test(t)) return false;     // css declaration
  const words = t.trim().replace(/^[^\p{L}]+/u, '').split(/\s+/).filter((w) => /\p{L}{2}/u.test(w));
  if (words.length >= 2) return true;
  return UI_WORD.has(words[0]?.replace(/[^A-Za-z]/g, '') ?? '');
}

function offenders(source: string): string[] {
  const found = new Set<string>();
  for (const raw of [...userVisibleStrings(source), ...scriptStrings(source).filter(isProse)]) {
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
