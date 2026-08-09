/**
 * useGeometryApi — Vue composable for geometry CRUD operations.
 *
 * Slice 8: Integration — Wire editor→API, draft indicator, audit log on save
 *
 * Endpoints (GeometryController):
 *   GET  /admin/courses/{courseId}/geometry/draft
 *   PUT  /admin/courses/{courseId}/geometry/draft
 *   POST /admin/courses/{courseId}/geometry/draft/features
 *   PUT  /admin/courses/{courseId}/geometry/draft/features/{id}
 *   DEL  /admin/courses/{courseId}/geometry/draft/features/{id}
 *   POST /admin/courses/{courseId}/geometry/validate
 */

import { ref } from 'vue';
import type {
  GeometryFeature,
  DraftGeometryResponse,
} from '@/types/geometry';
import { toClientFeatures } from '@/api/geometry-mapping';
import type { DraftFeatureOperation, ServerDraftGeometry } from '@/api/geometry-mapping';

/** What the validate endpoint actually answers with. */
export interface ServerValidationResult {
  courseId: number;
  valid: boolean;
  totalChecked: number;
  validCount: number;
  invalidCount: number;
  errors: Array<{
    featureUuid: string | null;
    errorCode: string | null;
    errorMessage: string | null;
    layerType: string | null;
  }>;
}

// ─── Audit log entry ─────────────────────────────────────────────────────────

export interface AuditLogEntry {
  timestamp: string;
  userId: string;
  action: 'fetch' | 'save' | 'validate' | 'add_feature' | 'update_feature' | 'delete_feature';
  courseId: number;
  detail: string;
  featureCount?: number;
}

export interface GeometryApiOptions {
  /** Base URL of the API (e.g., '/api'). */
  baseUrl?: string;
  /** Auth token injected by the portal shell. */
  authToken: string;
  /** Called after every API mutation to record an audit entry. */
  onAuditEntry?: (entry: AuditLogEntry) => void;
}

function buildHeaders(token: string): HeadersInit {
  return {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${token}`,
  };
}

/**
 * Headers for a write, including the idempotency key the server insists on.
 *
 * Every mutating geometry endpoint carries `@Idempotent`, and the filter in
 * front of them rejects a request with no `Idempotency-Key` outright. Nothing
 * here sent one, so *every* save failed with "Idempotency-Key header missing
 * on idempotent endpoint" — the editor could draw and could not save a single
 * feature.
 *
 * A fresh key per call is the right granularity: each press of Save is a new
 * intent, carrying whatever is on screen at that moment. Its value is the
 * network retry — if the response is lost after the server committed, sending
 * the same key again replays the cached result instead of applying the batch
 * twice.
 */
function buildWriteHeaders(token: string, idempotencyKey?: string): HeadersInit {
  return {
    ...buildHeaders(token),
    'Idempotency-Key': idempotencyKey ?? newIdempotencyKey(),
  };
}

function newIdempotencyKey(): string {
  // crypto.randomUUID needs a secure context; localhost counts, but a portal
  // served over plain HTTP on a LAN does not, and a save must not fail over
  // where the key came from.
  if (typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID();
  }
  return `geom-${Date.now()}-${Math.random().toString(36).slice(2, 12)}`;
}

function now(): string {
  return new Date().toISOString();
}

// ─── API composable ──────────────────────────────────────────────────────────

export function useGeometryApi(options: GeometryApiOptions) {
  const baseUrl = options.baseUrl ?? '/api';
  const authToken = options.authToken;

  const loading = ref(false);
  const saving = ref(false);
  const validating = ref(false);
  const error = ref<string | null>(null);

  function audit(entry: Omit<AuditLogEntry, 'timestamp'>) {
    options.onAuditEntry?.({
      ...entry,
      timestamp: now(),
    });
  }

  // ─── GET draft geometry ──────────────────────────────────────────────────

  async function fetchDraftGeometry(courseId: number): Promise<DraftGeometryResponse> {
    loading.value = true;
    error.value = null;
    try {
      const res = await fetch(
        `${baseUrl}/admin/courses/${courseId}/geometry/draft`,
        { headers: buildHeaders(authToken) }
      );
      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        throw new Error((body as { message?: string }).message ?? `HTTP ${res.status}`);
      }
      // The server's shape is not the editor's; see api/geometry-mapping.
      const raw = (await res.json()) as ServerDraftGeometry;
      const { features, skipped } = toClientFeatures(raw);
      if (skipped > 0) {
        console.warn(`[geometry] ${skipped} feature(s) had unreadable geometry and were skipped`);
      }
      audit({
        userId: 'current-user', // injected by server from session
        action: 'fetch',
        courseId,
        detail: `Loaded ${features.length} draft feature(s)`,
        featureCount: features.length,
      });
      return { courseId, state: 'draft', version: 0, features, updatedAt: '', updatedBy: '' };
    } catch (err: unknown) {
      error.value = (err as Error)?.message ?? 'Failed to load draft geometry';
      throw err;
    } finally {
      loading.value = false;
    }
  }

  // ─── PUT batch update draft geometry ─────────────────────────────────────

  /**
   * Save what changed.
   *
   * Takes the operations rather than the features, because only the caller
   * knows what the draft looked like when it was loaded — and the endpoint
   * wants a batch of CREATE/UPDATE/DELETE, not a pile of features.
   */
  async function saveDraftGeometry(
    courseId: number,
    operations: DraftFeatureOperation[]
  ): Promise<DraftGeometryResponse> {
    saving.value = true;
    error.value = null;
    try {
      const res = await fetch(
        `${baseUrl}/admin/courses/${courseId}/geometry/draft`,
        {
          method: 'PUT',
          headers: buildWriteHeaders(authToken),
          body: JSON.stringify({ features: operations }),
        }
      );
      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        throw new Error((body as { message?: string }).message ?? `HTTP ${res.status}`);
      }
      const raw = (await res.json()) as ServerDraftGeometry;
      const { features } = toClientFeatures(raw);
      const data: DraftGeometryResponse = {
        courseId, state: 'draft', version: 0, features, updatedAt: '', updatedBy: '',
      };
      audit({
        userId: 'current-user',
        action: 'save',
        courseId,
        detail: `Saved ${operations.length} change(s)`,
        featureCount: features.length,
      });
      return data;
    } catch (err: unknown) {
      error.value = (err as Error)?.message ?? 'Failed to save draft geometry';
      throw err;
    } finally {
      saving.value = false;
    }
  }

  // ─── POST create single feature ─────────────────────────────────────────

  async function createFeature(
    courseId: number,
    feature: GeometryFeature
  ): Promise<GeometryFeature> {
    saving.value = true;
    error.value = null;
    try {
      const res = await fetch(
        `${baseUrl}/admin/courses/${courseId}/geometry/draft/features`,
        {
          method: 'POST',
          headers: buildWriteHeaders(authToken),
          body: JSON.stringify(feature),
        }
      );
      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        throw new Error((body as { message?: string }).message ?? `HTTP ${res.status}`);
      }
      const created = (await res.json()) as GeometryFeature;
      audit({
        userId: 'current-user',
        action: 'add_feature',
        courseId,
        detail: `Added ${feature.properties.layerType} feature`,
      });
      return created;
    } catch (err: unknown) {
      error.value = (err as Error)?.message ?? 'Failed to create feature';
      throw err;
    } finally {
      saving.value = false;
    }
  }

  // ─── PUT update single feature ───────────────────────────────────────────

  async function updateFeature(
    courseId: number,
    featureId: string,
    feature: GeometryFeature
  ): Promise<GeometryFeature> {
    saving.value = true;
    error.value = null;
    try {
      const res = await fetch(
        `${baseUrl}/admin/courses/${courseId}/geometry/draft/features/${featureId}`,
        {
          method: 'PUT',
          headers: buildWriteHeaders(authToken),
          body: JSON.stringify(feature),
        }
      );
      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        throw new Error((body as { message?: string }).message ?? `HTTP ${res.status}`);
      }
      const updated = (await res.json()) as GeometryFeature;
      audit({
        userId: 'current-user',
        action: 'update_feature',
        courseId,
        detail: `Updated ${feature.properties.layerType} feature ${featureId}`,
      });
      return updated;
    } catch (err: unknown) {
      error.value = (err as Error)?.message ?? 'Failed to update feature';
      throw err;
    } finally {
      saving.value = false;
    }
  }

  // ─── DEL delete feature ──────────────────────────────────────────────────

  async function deleteFeature(
    courseId: number,
    featureId: string
  ): Promise<void> {
    saving.value = true;
    error.value = null;
    try {
      const res = await fetch(
        `${baseUrl}/admin/courses/${courseId}/geometry/draft/features/${featureId}`,
        {
          method: 'DELETE',
          headers: buildWriteHeaders(authToken),
        }
      );
      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        throw new Error((body as { message?: string }).message ?? `HTTP ${res.status}`);
      }
      audit({
        userId: 'current-user',
        action: 'delete_feature',
        courseId,
        detail: `Deleted feature ${featureId}`,
      });
    } catch (err: unknown) {
      error.value = (err as Error)?.message ?? 'Failed to delete feature';
      throw err;
    } finally {
      saving.value = false;
    }
  }

  // ─── POST validate ──────────────────────────────────────────────────────

  /**
   * Validate the course's *saved* draft.
   *
   * The endpoint takes `{layerType?, fullValidation}` and checks what is
   * stored — it never sees the browser's features. The client used to send
   * `{courseId, features}`, which Jackson quietly discarded, so the call
   * appeared to work while validating something other than what was on screen.
   * Unsaved edits are therefore not covered, and the caller has to say so.
   */
  async function validateGeometry(courseId: number): Promise<ServerValidationResult> {
    validating.value = true;
    error.value = null;
    try {
      const body = { fullValidation: true };
      const res = await fetch(
        `${baseUrl}/admin/courses/${courseId}/geometry/validate`,
        {
          method: 'POST',
          headers: buildWriteHeaders(authToken),
          body: JSON.stringify(body),
        }
      );
      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        throw new Error((body as { message?: string }).message ?? `HTTP ${res.status}`);
      }
      const data = (await res.json()) as ServerValidationResult;
      audit({
        userId: 'current-user',
        action: 'validate',
        courseId,
        detail: `Checked ${data.totalChecked} feature(s) — ${data.valid ? 'valid' : `${data.invalidCount} invalid`}`,
        featureCount: data.totalChecked,
      });
      return data;
    } catch (err: unknown) {
      error.value = (err as Error)?.message ?? 'Failed to validate geometry';
      throw err;
    } finally {
      validating.value = false;
    }
  }

  return {
    loading,
    saving,
    validating,
    error,
    fetchDraftGeometry,
    saveDraftGeometry,
    createFeature,
    updateFeature,
    deleteFeature,
    validateGeometry,
  };
}
