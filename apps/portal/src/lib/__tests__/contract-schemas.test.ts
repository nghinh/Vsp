import { describe, it, expect } from 'vitest';
import { readdirSync, readFileSync, existsSync } from 'node:fs';
import { join, resolve } from 'node:path';

/**
 * Integrity guard over packages/contracts/schemas.
 *
 * This lives in the portal's suite for a dull reason: it is the fastest
 * harness in the repo that can read an arbitrary file, and the schemas are
 * shared property with no test runner of their own. It asserts nothing about
 * the portal.
 *
 * It exists because of two defects found by reading, not by failing:
 *
 *   course.yaml defined ValidationError twice — once shaped for GeoJSON import
 *   errors (featureIndex, geometryType, severity) and once for entity-level
 *   publish validation (entity, entityId). YAML keeps the last definition, so
 *   the import response documented fields that no generated client would ever
 *   carry. The server had kept the two types apart all along; only the
 *   contract had collapsed them.
 *
 *   score.yaml defined ScoreCorrectionRequest, FieldCorrection and
 *   ScoreCorrectionResponse twice each, verbatim apart from wording. Harmless
 *   in effect, but half of what was written there was dead, and an edit to the
 *   dead half would vanish without a word.
 *
 * Neither failed anything. A duplicate key is legal YAML, and a contract that
 * quietly describes the wrong type is worse than one that will not parse.
 */

const SCHEMA_DIR = resolve(__dirname, '../../../../../packages/contracts/schemas');

function schemaFiles(): string[] {
  if (!existsSync(SCHEMA_DIR)) {
    throw new Error(
      `Contract schemas not found at ${SCHEMA_DIR}. This guard is monorepo-relative; ` +
        `if the layout moved, move the path with it rather than deleting the check.`
    );
  }
  return readdirSync(SCHEMA_DIR).filter((f) => f.endsWith('.yaml') || f.endsWith('.yml'));
}

/** Top-level keys, i.e. schema definitions: a name in column zero. */
function topLevelKeys(text: string): string[] {
  const keys: string[] = [];
  for (const line of text.split('\n')) {
    const m = /^([A-Za-z_][A-Za-z0-9_]*):/.exec(line);
    if (m) keys.push(m[1]);
  }
  return keys;
}

/**
 * Definition names inside an OpenAPI document's components/schemas.
 *
 * Checking only column-zero keys left openapi.yaml unguarded, and that is
 * where the worst instance was: PublishRequest was aliased twice in the same
 * block, once to course.yaml and once to admin.yaml. Both files defined it,
 * differently, and YAML kept whichever alias came last — so which contract a
 * reader got depended on line order. Indentation is the only thing that makes
 * these keys different in kind from the ones above; it is not a reason to
 * check them less.
 */
function componentSchemaKeys(text: string): string[] {
  const lines = text.split('\n');
  const start = lines.findIndex((l) => /^\s{2}schemas:\s*$/.test(l));
  if (start === -1) return [];
  const keys: string[] = [];
  for (const line of lines.slice(start + 1)) {
    if (/^\s{0,2}\S/.test(line)) break; // dedented out of components/schemas
    const m = /^ {4}([A-Za-z_][A-Za-z0-9_]*):/.exec(line);
    if (m) keys.push(m[1]);
  }
  return keys;
}

describe('contract schemas', () => {
  const files = schemaFiles();

  it('there are schemas to check', () => {
    // Guards the guard: a bad path would otherwise make every case below pass
    // over an empty list and report success for work it never did.
    expect(files.length).toBeGreaterThan(0);
  });

  it.each(files)('%s defines each schema exactly once', (file) => {
    const keys = topLevelKeys(readFileSync(join(SCHEMA_DIR, file), 'utf8'));

    const counts = new Map<string, number>();
    for (const k of keys) counts.set(k, (counts.get(k) ?? 0) + 1);
    const duplicated = [...counts.entries()].filter(([, n]) => n > 1).map(([k, n]) => `${k} ×${n}`);

    // A duplicate is not a style problem. The later definition silently wins,
    // so the loser is text that looks authoritative and governs nothing.
    expect(duplicated).toEqual([]);
  });

  it.each(files)('%s resolves every local $ref it makes', (file) => {
    const text = readFileSync(join(SCHEMA_DIR, file), 'utf8');
    const defined = new Set(topLevelKeys(text));

    const dangling = [...text.matchAll(/\$ref:\s*['"]#\/([A-Za-z0-9_]+)['"]/g)]
      .map((m) => m[1])
      .filter((name) => !defined.has(name));

    expect([...new Set(dangling)]).toEqual([]);
  });

  it('openapi.yaml aliases each schema name exactly once', () => {
    const openapi = resolve(SCHEMA_DIR, '..', 'openapi.yaml');
    expect(existsSync(openapi)).toBe(true);

    const keys = componentSchemaKeys(readFileSync(openapi, 'utf8'));
    expect(keys.length).toBeGreaterThan(0);

    const counts = new Map<string, number>();
    for (const k of keys) counts.set(k, (counts.get(k) ?? 0) + 1);
    const duplicated = [...counts.entries()].filter(([, n]) => n > 1).map(([k, n]) => `${k} ×${n}`);

    expect(duplicated).toEqual([]);
  });

  it('openapi.yaml points every cross-file $ref at a file that exists', () => {
    const openapi = resolve(SCHEMA_DIR, '..', 'openapi.yaml');
    const text = readFileSync(openapi, 'utf8');

    const broken = [...text.matchAll(/\$ref:\s*['"]\.\/schemas\/([A-Za-z0-9_.-]+\.yaml)#\/([A-Za-z0-9_]+)['"]/g)]
      .filter(([, file, name]) => {
        const path = join(SCHEMA_DIR, file);
        if (!existsSync(path)) return true;
        return !topLevelKeys(readFileSync(path, 'utf8')).includes(name);
      })
      .map(([, file, name]) => `${file}#/${name}`);

    // Moving a definition between schema files is exactly the edit that leaves
    // one of these behind, and a stale alias resolves to nothing at all.
    expect([...new Set(broken)]).toEqual([]);
  });
});
