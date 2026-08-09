/**
 * Between the geometry editor's model and the server's.
 *
 * These are two different shapes, and nothing translated between them, so the
 * editor could neither read the course's geometry nor write its own:
 *
 *   server → client   `DraftFeatureResponse` carries `featureUuid`, a
 *                     `layerType`, and `geometry` as a *string* of GeoJSON.
 *                     The editor expected an array of GeoJSON Features with
 *                     `properties.layerType`, so every feature grouped under
 *                     `undefined` and none of them drew.
 *
 *   client → server   The editor PUT `{features: [<GeoJSON Feature>…]}`. The
 *                     endpoint takes a batch of *operations* —
 *                     `{operation: CREATE|UPDATE|DELETE, featureUuid, create,
 *                     update}` — and rejected the payload on the first
 *                     feature, "Operation type is required".
 *
 * Neither failure was visible on a course with no geometry, which is every
 * course in the database today.
 *
 * The diff below is the interesting half. A save has to say what *changed*,
 * and the editor only knows the current state, so this compares it against the
 * snapshot taken when the draft was loaded.
 */

import type { GeometryFeature, GeoJSONGeometry, LayerType } from '@/types/geometry';

// ─── The server's shapes ──────────────────────────────────────────────────

/** One feature as the server returns it. */
export interface DraftFeatureResponse {
  id: number;
  featureUuid: string;
  courseId: number;
  holeId: number | null;
  layerType: LayerType;
  /** GeoJSON geometry, as a JSON string. */
  geometry: string;
  valid: boolean;
  validityMessage: string | null;
  externalFeatureId: string | null;
  featureName: string | null;
  publisher: string | null;
  version: number | null;
  createdAt: string | null;
  updatedAt: string | null;
}

/** The draft as the server returns it. */
export interface ServerDraftGeometry {
  courseId: number;
  totalFeatures: number;
  validFeatures: number;
  invalidFeatures: number;
  features: DraftFeatureResponse[];
}

export type OperationType = 'CREATE' | 'UPDATE' | 'DELETE';

/** One entry of the batch the PUT endpoint expects. */
export interface DraftFeatureOperation {
  operation: OperationType;
  featureUuid?: string;
  create?: {
    featureUuid?: string;
    layerType: LayerType;
    holeId?: number | null;
    geometry: string;
    featureName?: string | null;
  };
  update?: {
    geometry: string;
    layerType?: LayerType;
    holeId?: number | null;
    featureName?: string | null;
  };
}

// ─── Server → client ──────────────────────────────────────────────────────

/**
 * The server's enum spelling, in the editor's.
 *
 * `LayerType` is lowercase here and an uppercase Java enum there — the same
 * green comes back as "GREEN" and would then match no layer, no style and no
 * visibility toggle. Neither side is wrong; the translation has to happen
 * somewhere, and this is the somewhere.
 */
function toClientLayerType(raw: string): LayerType {
  return raw.toLowerCase() as LayerType;
}

/** And back, for anything sent to the server. */
function toServerLayerType(raw: LayerType): string {
  return raw.toUpperCase();
}

/**
 * One server feature as a GeoJSON Feature the editor can draw.
 *
 * Returns null for a feature whose geometry will not parse rather than
 * throwing: one corrupt row should cost that row, not the whole course.
 */
export function toClientFeature(raw: DraftFeatureResponse, courseId: number): GeometryFeature | null {
  let geometry: GeoJSONGeometry;
  try {
    geometry = JSON.parse(raw.geometry) as GeoJSONGeometry;
  } catch {
    return null;
  }
  if (!geometry || typeof geometry !== 'object' || !('type' in geometry)) return null;

  return {
    type: 'Feature',
    // The editor keys hit-tests and edits off `id`; the server's UUID is the
    // only identifier stable across a reload, so it is the one to use.
    id: raw.featureUuid,
    geometry,
    properties: {
      layerType: toClientLayerType(raw.layerType),
      courseId: raw.courseId ?? courseId,
      state: 'draft',
      updatedAt: raw.updatedAt ?? undefined,
      updatedBy: raw.publisher ?? undefined,
      // Carried so an update can send them back unchanged.
      featureUuid: raw.featureUuid,
      holeId: raw.holeId,
      featureName: raw.featureName,
    } as GeometryFeature['properties'],
  } as GeometryFeature;
}

/**
 * The whole draft, with unparseable features reported rather than hidden.
 *
 * Accepts either shape the server sends: GET answers with a wrapper carrying
 * counts, PUT answers with a bare array of the features it wrote. Reading only
 * `draft.features` meant a successful save came back as zero features and the
 * editor blanked itself the moment the work was safely stored.
 */
export function toClientFeatures(
  draft: ServerDraftGeometry | DraftFeatureResponse[] | null | undefined,
): { features: GeometryFeature[]; skipped: number } {
  const list = Array.isArray(draft) ? draft : (draft?.features ?? []);
  const courseId = Array.isArray(draft) ? (draft[0]?.courseId ?? 0) : (draft?.courseId ?? 0);

  const features: GeometryFeature[] = [];
  let skipped = 0;
  for (const raw of list) {
    const f = toClientFeature(raw, courseId);
    if (f) features.push(f);
    else skipped++;
  }
  return { features, skipped };
}

// ─── Client → server ──────────────────────────────────────────────────────

/** What a feature looked like when the draft was loaded. */
export interface Baseline {
  featureUuid: string;
  /** Serialised geometry, for cheap comparison. */
  geometry: string;
  layerType: LayerType;
  holeId: number | null;
}

/** The snapshot to diff the next save against. */
export function snapshot(features: GeometryFeature[]): Map<string, Baseline> {
  const out = new Map<string, Baseline>();
  for (const f of features) {
    const uuid = featureUuidOf(f);
    if (!uuid) continue;
    out.set(uuid, {
      featureUuid: uuid,
      geometry: JSON.stringify(f.geometry),
      layerType: f.properties.layerType,
      holeId: holeIdOf(f),
    });
  }
  return out;
}

/**
 * What changed since the snapshot, as the batch the server expects.
 *
 * A feature with no server UUID is new. One whose geometry, layer or hole
 * differs from the snapshot is an update — compared by value, so nudging a
 * vertex and putting it back sends nothing. One in the snapshot and no longer
 * on screen is a delete.
 */
export function toBatchOperations(
  baseline: Map<string, Baseline>,
  current: GeometryFeature[],
): DraftFeatureOperation[] {
  const ops: DraftFeatureOperation[] = [];
  const seen = new Set<string>();

  for (const f of current) {
    const uuid = featureUuidOf(f);
    const geometry = JSON.stringify(f.geometry);
    const layerType = f.properties.layerType;
    const holeId = holeIdOf(f);

    if (!uuid || !baseline.has(uuid)) {
      ops.push({
        operation: 'CREATE',
        create: {
          // A client-assigned UUID makes the create idempotent in its own
          // right: a retried batch cannot produce two of the same green.
          featureUuid: uuid ?? undefined,
          layerType: toServerLayerType(layerType) as LayerType,
          holeId,
          geometry,
          featureName: featureNameOf(f),
        },
      });
      continue;
    }

    seen.add(uuid);
    const was = baseline.get(uuid)!;
    if (was.geometry !== geometry || was.layerType !== layerType || was.holeId !== holeId) {
      ops.push({
        operation: 'UPDATE',
        featureUuid: uuid,
        update: {
          geometry,
          layerType: toServerLayerType(layerType) as LayerType,
          holeId,
          featureName: featureNameOf(f),
        },
      });
    }
  }

  for (const uuid of baseline.keys()) {
    if (!seen.has(uuid)) {
      ops.push({ operation: 'DELETE', featureUuid: uuid });
    }
  }

  return ops;
}

// ─── Reading the bits the editor stores loosely ───────────────────────────

/** A UUID looks like one; the editor also mints local ids that do not. */
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function featureUuidOf(f: GeometryFeature): string | null {
  const props = f.properties as unknown as { featureUuid?: string };
  if (props.featureUuid && UUID.test(props.featureUuid)) return props.featureUuid;
  if (typeof f.id === 'string' && UUID.test(f.id)) return f.id;
  return null;
}

function holeIdOf(f: GeometryFeature): number | null {
  const props = f.properties as unknown as { holeId?: number | null };
  return props.holeId ?? null;
}

function featureNameOf(f: GeometryFeature): string | null {
  const props = f.properties as unknown as { featureName?: string | null };
  return props.featureName ?? null;
}
