/**
 * The translation between the editor and the server.
 *
 * Worth testing hard, because the two halves failed silently and in opposite
 * directions: reading produced features grouped under `undefined` that simply
 * never drew, and writing produced a payload the server rejected on the first
 * element. Neither showed up on a course with no geometry, and every course in
 * the database has no geometry.
 */

import { describe, expect, it } from 'vitest';

import {
  snapshot,
  toBatchOperations,
  toClientFeature,
  toClientFeatures,
} from './geometry-mapping';
import type { DraftFeatureResponse, ServerDraftGeometry } from './geometry-mapping';
import type { GeometryFeature } from '@/types/geometry';

const UUID_A = '11111111-1111-4111-8111-111111111111';
const UUID_B = '22222222-2222-4222-8222-222222222222';

const GREEN = {
  type: 'Polygon',
  coordinates: [[[106.8955, 10.8615], [106.896, 10.8615], [106.896, 10.8611], [106.8955, 10.8615]]],
};

function serverFeature(over: Partial<DraftFeatureResponse> = {}): DraftFeatureResponse {
  return {
    id: 1,
    featureUuid: UUID_A,
    courseId: 8,
    holeId: 310,
    layerType: 'green',
    geometry: JSON.stringify(GREEN),
    valid: true,
    validityMessage: null,
    externalFeatureId: null,
    featureName: 'Green hố 1',
    publisher: 'VSP',
    version: 1,
    createdAt: null,
    updatedAt: '2026-08-09T00:00:00Z',
    ...over,
  };
}

function clientFeature(over: {
  id?: string;
  uuid?: string | null;
  geometry?: unknown;
  layerType?: string;
  holeId?: number | null;
} = {}): GeometryFeature {
  return {
    type: 'Feature',
    id: over.id ?? over.uuid ?? UUID_A,
    geometry: (over.geometry ?? GREEN) as GeometryFeature['geometry'],
    properties: {
      layerType: over.layerType ?? 'green',
      courseId: 8,
      state: 'draft',
      featureUuid: over.uuid === null ? undefined : (over.uuid ?? UUID_A),
      holeId: over.holeId === undefined ? 310 : over.holeId,
    },
  } as unknown as GeometryFeature;
}

// ═══════════════════════════════════════════════════════════════════════════
// Server → client
// ═══════════════════════════════════════════════════════════════════════════

describe('toClientFeature', () => {
  it('parses the geometry the server sends as a string', () => {
    const f = toClientFeature(serverFeature(), 8)!;
    expect(f.type).toBe('Feature');
    expect(f.geometry).toEqual(GREEN);
  });

  it('lifts layerType into properties, where the editor groups on it', () => {
    // This is the read-side bug: the editor reads
    // `feature.properties.layerType`, the server puts it at the top level, so
    // every feature landed in a bucket called `undefined` and none drew.
    const f = toClientFeature(serverFeature(), 8)!;
    expect(f.properties.layerType).toBe('green');
  });

  it('uses the server UUID as the feature id', () => {
    // The editor keys hit-tests and edits off `id`; anything else is unstable
    // across a reload, so an edit would target a feature that no longer has
    // that id.
    expect(toClientFeature(serverFeature(), 8)!.id).toBe(UUID_A);
  });

  it('keeps the hole and the name for a later update', () => {
    const props = toClientFeature(serverFeature(), 8)!.properties as unknown as {
      holeId: number;
      featureName: string;
    };
    expect(props.holeId).toBe(310);
    expect(props.featureName).toBe('Green hố 1');
  });

  it('lowercases the server\'s enum spelling', () => {
    // The server answers "GREEN"; every style, toggle and grouping in the
    // editor is keyed on "green".
    const f = toClientFeature(serverFeature({ layerType: 'GREEN' as never }), 8)!;
    expect(f.properties.layerType).toBe('green');
  });

  it('returns null for geometry that will not parse', () => {
    expect(toClientFeature(serverFeature({ geometry: 'not json' }), 8)).toBeNull();
    expect(toClientFeature(serverFeature({ geometry: '{}' }), 8)).toBeNull();
  });
});

describe('toClientFeatures', () => {
  it('reports what it skipped rather than dropping it quietly', () => {
    // A course that silently loses a fairway is worse than one that says so.
    const draft: ServerDraftGeometry = {
      courseId: 8,
      totalFeatures: 2,
      validFeatures: 2,
      invalidFeatures: 0,
      features: [serverFeature(), serverFeature({ featureUuid: UUID_B, geometry: 'broken' })],
    };

    const { features, skipped } = toClientFeatures(draft);
    expect(features).toHaveLength(1);
    expect(skipped).toBe(1);
  });

  it('accepts the bare array the PUT answers with', () => {
    // GET returns {courseId, features: […]}; PUT returns just […]. Reading
    // only `.features` meant a successful save came back empty and the editor
    // blanked itself right after storing the work.
    const { features } = toClientFeatures([serverFeature()]);
    expect(features).toHaveLength(1);
    expect(features[0].properties.layerType).toBe('green');
  });

  it('handles a null body without throwing', () => {
    expect(toClientFeatures(null).features).toEqual([]);
  });

  it('handles a course with no geometry at all', () => {
    const { features, skipped } = toClientFeatures({
      courseId: 8, totalFeatures: 0, validFeatures: 0, invalidFeatures: 0, features: [],
    });
    expect(features).toEqual([]);
    expect(skipped).toBe(0);
  });
});

// ═══════════════════════════════════════════════════════════════════════════
// Client → server
// ═══════════════════════════════════════════════════════════════════════════

describe('toBatchOperations', () => {
  it('sends a feature with no server UUID as CREATE', () => {
    const ops = toBatchOperations(new Map(), [clientFeature({ id: 'local-1', uuid: null })]);

    expect(ops).toHaveLength(1);
    expect(ops[0].operation).toBe('CREATE');
    // Sent uppercase, because that is what the Java enum accepts.
    expect(ops[0].create?.layerType).toBe('GREEN');
    expect(JSON.parse(ops[0].create!.geometry)).toEqual(GREEN);
  });

  it('sends nothing at all when nothing changed', () => {
    // The editor saves the whole board every time; without a real diff every
    // save would rewrite all eighteen holes.
    const loaded = [clientFeature()];
    expect(toBatchOperations(snapshot(loaded), loaded)).toEqual([]);
  });

  it('sends a moved feature as UPDATE, keyed by its server UUID', () => {
    const base = snapshot([clientFeature()]);
    const moved = clientFeature({
      geometry: { type: 'Polygon', coordinates: [[[1, 1], [2, 2], [3, 1], [1, 1]]] },
    });

    const ops = toBatchOperations(base, [moved]);
    expect(ops).toHaveLength(1);
    expect(ops[0].operation).toBe('UPDATE');
    expect(ops[0].featureUuid).toBe(UUID_A);
  });

  it('notices a layer change even when the shape is identical', () => {
    // Re-tagging a mis-drawn bunker as a green moves no vertices.
    const base = snapshot([clientFeature()]);
    const ops = toBatchOperations(base, [clientFeature({ layerType: 'bunker' })]);

    expect(ops[0]).toMatchObject({ operation: 'UPDATE', featureUuid: UUID_A });
    expect(ops[0].update?.layerType).toBe('BUNKER');
  });

  it('notices a hole reassignment', () => {
    const base = snapshot([clientFeature()]);
    const ops = toBatchOperations(base, [clientFeature({ holeId: 311 })]);
    expect(ops[0].update?.holeId).toBe(311);
  });

  it('sends a feature that vanished as DELETE', () => {
    const base = snapshot([clientFeature(), clientFeature({ id: UUID_B, uuid: UUID_B })]);
    const ops = toBatchOperations(base, [clientFeature()]);

    expect(ops).toEqual([{ operation: 'DELETE', featureUuid: UUID_B }]);
  });

  it('handles a create, an update and a delete in one batch', () => {
    const base = snapshot([clientFeature(), clientFeature({ id: UUID_B, uuid: UUID_B })]);
    const ops = toBatchOperations(base, [
      clientFeature({ geometry: { type: 'Polygon', coordinates: [[[9, 9], [8, 8], [7, 9], [9, 9]]] } }),
      clientFeature({ id: 'local-new', uuid: null }),
    ]);

    expect(ops.map((o) => o.operation).sort()).toEqual(['CREATE', 'DELETE', 'UPDATE']);
  });

  it('does not report a vertex nudged and put back', () => {
    // Compared by value, not by a dirty flag: an undo should leave nothing to
    // save, and an editor that resends unchanged holes rewrites their history.
    const original = clientFeature();
    const base = snapshot([original]);
    const moved = clientFeature({ geometry: { type: 'Polygon', coordinates: [[[5, 5]]] } });

    expect(toBatchOperations(base, [moved])).toHaveLength(1);
    expect(toBatchOperations(base, [clientFeature()])).toHaveLength(0);
  });

  it('treats a non-UUID id as a new feature', () => {
    // The draw tools mint local ids like "feat-3". Sending one as a
    // featureUuid would have the server look for a row that does not exist.
    const ops = toBatchOperations(new Map(), [clientFeature({ id: 'feat-3', uuid: null })]);
    expect(ops[0].operation).toBe('CREATE');
    expect(ops[0].featureUuid).toBeUndefined();
  });

  it('produces an empty batch for an empty course left empty', () => {
    expect(toBatchOperations(new Map(), [])).toEqual([]);
  });
});
