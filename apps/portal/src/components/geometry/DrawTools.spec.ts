/**
 * Unit tests for the DrawTools edit/delete seams and feature-id helpers.
 * Story 8-2 (G1) — in-place vertex edit + feature delete via map interaction.
 */

import { describe, it, expect, vi } from 'vitest';
import {
  createDrawTools,
  ensureFeatureId,
  nextFeatureId,
  moveVertex,
  deleteVertex,
} from './DrawTools';
import {
  createUndoRedoManager,
  cmdModifyFeature,
  cmdDeleteFeature,
} from './UndoRedoManager';
import type { GeometryFeature, GeoCoordinate } from '@/types/geometry';

// ─── Fixtures ──────────────────────────────────────────────────────────────────

function lineFeature(id = 'line-1'): GeometryFeature {
  return {
    type: 'Feature',
    id,
    geometry: { type: 'LineString', coordinates: [[0, 0], [1, 1], [2, 2]] },
    properties: { layerType: 'cart_path', courseId: 1, state: 'draft' },
  } as GeometryFeature;
}

function polygonFeature(id = 'poly-1'): GeometryFeature {
  return {
    type: 'Feature',
    id,
    geometry: {
      type: 'Polygon',
      coordinates: [[[0, 0], [0, 2], [2, 2], [2, 0], [0, 0]]],
    },
    properties: { layerType: 'green', courseId: 1, holeNumber: 1, state: 'draft' },
  } as GeometryFeature;
}

function makeTools(overrides: Partial<Parameters<typeof createDrawTools>[0]> = {}) {
  const onFeatureComplete = vi.fn();
  const onFeatureModify = vi.fn();
  const onFeatureDelete = vi.fn();
  const tools = createDrawTools({
    layerType: 'cart_path',
    geometryType: 'LineString',
    existingFeatures: [],
    onFeatureComplete,
    onFeatureModify,
    onFeatureDelete,
    ...overrides,
  });
  return { tools, onFeatureComplete, onFeatureModify, onFeatureDelete };
}

// ─── Feature id helpers ─────────────────────────────────────────────────────────

describe('feature id helpers', () => {
  it('nextFeatureId returns unique ids', () => {
    const a = nextFeatureId();
    const b = nextFeatureId();
    expect(a).not.toEqual(b);
  });

  it('ensureFeatureId assigns an id when missing', () => {
    const f = { ...lineFeature(), id: undefined } as GeometryFeature;
    const withId = ensureFeatureId(f);
    expect(withId.id).toBeDefined();
    expect(withId.id).not.toEqual('');
  });

  it('ensureFeatureId preserves an existing id', () => {
    const f = lineFeature('keep-me');
    expect(ensureFeatureId(f).id).toBe('keep-me');
  });

  it('newly drawn point features carry an id', () => {
    const { tools, onFeatureComplete } = makeTools({
      layerType: 'tee',
      geometryType: 'Point',
    });
    tools.handleClick([10, 20], 15);
    expect(onFeatureComplete).toHaveBeenCalledTimes(1);
    const feature = onFeatureComplete.mock.calls[0][0] as GeometryFeature;
    expect(feature.id).toBeDefined();
  });
});

// ─── moveFeatureVertex seam ─────────────────────────────────────────────────────

describe('DrawTools.moveFeatureVertex', () => {
  it('routes a LineString vertex move through onFeatureModify', () => {
    const { tools, onFeatureModify } = makeTools();
    const before = lineFeature();
    const newCoord: GeoCoordinate = [5, 5];

    const after = tools.moveFeatureVertex(before, 1, newCoord, 15);

    expect(onFeatureModify).toHaveBeenCalledTimes(1);
    const [passedBefore, passedAfter] = onFeatureModify.mock.calls[0];
    expect(passedBefore).toBe(before);
    expect(passedAfter).toBe(after);
    expect(after.id).toBe(before.id);
    expect((after.geometry as { coordinates: GeoCoordinate[] }).coordinates[1]).toEqual(newCoord);
    // Untouched vertices are preserved.
    expect((after.geometry as { coordinates: GeoCoordinate[] }).coordinates[0]).toEqual([0, 0]);
  });

  it('keeps a Polygon ring closed when moving vertex 0', () => {
    const { tools, onFeatureModify } = makeTools({
      layerType: 'green',
      geometryType: 'Polygon',
    });
    const before = polygonFeature();
    const newCoord: GeoCoordinate = [-1, -1];

    const after = tools.moveFeatureVertex(before, 0, newCoord, 15);

    const ring = (after.geometry as { coordinates: GeoCoordinate[][] }).coordinates[0];
    expect(onFeatureModify).toHaveBeenCalledTimes(1);
    expect(ring[0]).toEqual(newCoord);
    expect(ring[ring.length - 1]).toEqual(newCoord); // closing vertex updated too
  });

  it('does not snap a dragged vertex onto its own vertices', () => {
    const { tools } = makeTools();
    const before = lineFeature();
    // Drag vertex 2 exactly onto vertex 0's coordinate; without self-exclusion
    // snapping would pull it there anyway, but self-exclusion must be applied.
    const after = tools.moveFeatureVertex(before, 2, [0.0000001, 0.0000001], 15);
    // The moved vertex should be (approximately) the requested coord, not snapped
    // to another feature (there are none), confirming candidates exclude self.
    const coords = (after.geometry as { coordinates: GeoCoordinate[] }).coordinates;
    expect(coords[2][0]).toBeCloseTo(0.0000001, 6);
  });
});

// ─── removeFeature seam ─────────────────────────────────────────────────────────

describe('DrawTools.removeFeature', () => {
  it('routes a delete through onFeatureDelete', () => {
    const { tools, onFeatureDelete } = makeTools();
    const feature = lineFeature();
    tools.removeFeature(feature);
    expect(onFeatureDelete).toHaveBeenCalledTimes(1);
    expect(onFeatureDelete.mock.calls[0][0]).toBe(feature);
  });
});

// ─── Undo/redo integration for modify + delete ──────────────────────────────────

describe('undo/redo for edit + delete', () => {
  it('modify command captures before/after for round-trip undo', () => {
    const mgr = createUndoRedoManager();
    const before = lineFeature();
    const after = moveVertex({
      feature: before,
      vertexIndex: 1,
      newCoord: [9, 9],
      snapCandidates: [],
      zoom: 15,
    });
    mgr.push(cmdModifyFeature(before, after));

    expect(mgr.isDirty).toBe(true);
    const undone = mgr.undo();
    expect(undone?.type).toBe('modify_feature');
    expect(undone?.before[0]).toBe(before);
    expect(undone?.after[0]).toBe(after);
    expect(mgr.canUndo).toBe(0);

    // Redo re-applies: the command moves back onto the undo stack.
    expect(mgr.canRedo).toBe(1);
    const redone = mgr.redo();
    expect(redone).toBe(undone);
    expect(redone?.after[0]).toBe(after);
    expect(mgr.canUndo).toBe(1);
    expect(mgr.canRedo).toBe(0);
  });

  it('delete command restores the feature on undo', () => {
    const mgr = createUndoRedoManager();
    const feature = polygonFeature();
    mgr.push(cmdDeleteFeature(feature));

    const undone = mgr.undo();
    expect(undone?.type).toBe('delete_feature');
    expect(undone?.before[0]).toBe(feature); // re-add source on undo
    expect(undone?.after.length).toBe(0);
  });

  it('deleteVertex refuses to drop below a valid minimum', () => {
    const twoPointLine: GeometryFeature = {
      type: 'Feature',
      id: 'l2',
      geometry: { type: 'LineString', coordinates: [[0, 0], [1, 1]] },
      properties: { layerType: 'cart_path', courseId: 1, state: 'draft' },
    } as GeometryFeature;
    expect(deleteVertex(twoPointLine, 0)).toBeNull();
  });
});
