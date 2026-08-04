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
  ValidateGeometryRequest,
  ValidateGeometryResponse,
} from '@/types/geometry';

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
      const data = (await res.json()) as DraftGeometryResponse;
      audit({
        userId: 'current-user', // injected by server from session
        action: 'fetch',
        courseId,
        detail: `Loaded draft geometry v${data.version}`,
        featureCount: data.features.length,
      });
      return data;
    } catch (err: unknown) {
      error.value = (err as Error)?.message ?? 'Failed to load draft geometry';
      throw err;
    } finally {
      loading.value = false;
    }
  }

  // ─── PUT batch update draft geometry ─────────────────────────────────────

  async function saveDraftGeometry(
    courseId: number,
    features: GeometryFeature[]
  ): Promise<DraftGeometryResponse> {
    saving.value = true;
    error.value = null;
    try {
      const res = await fetch(
        `${baseUrl}/admin/courses/${courseId}/geometry/draft`,
        {
          method: 'PUT',
          headers: buildHeaders(authToken),
          body: JSON.stringify({ features }),
        }
      );
      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        throw new Error((body as { message?: string }).message ?? `HTTP ${res.status}`);
      }
      const data = (await res.json()) as DraftGeometryResponse;
      audit({
        userId: 'current-user',
        action: 'save',
        courseId,
        detail: `Saved ${features.length} features as draft`,
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
          headers: buildHeaders(authToken),
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
          headers: buildHeaders(authToken),
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
          headers: buildHeaders(authToken),
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

  async function validateGeometry(
    courseId: number,
    features: GeometryFeature[]
  ): Promise<ValidateGeometryResponse> {
    validating.value = true;
    error.value = null;
    try {
      const body: ValidateGeometryRequest = { courseId, features };
      const res = await fetch(
        `${baseUrl}/admin/courses/${courseId}/geometry/validate`,
        {
          method: 'POST',
          headers: buildHeaders(authToken),
          body: JSON.stringify(body),
        }
      );
      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        throw new Error((body as { message?: string }).message ?? `HTTP ${res.status}`);
      }
      const data = (await res.json()) as ValidateGeometryResponse;
      audit({
        userId: 'current-user',
        action: 'validate',
        courseId,
        detail: `Validated ${features.length} features — ${data.valid ? 'valid' : `invalid (${data.errors.length} errors)`}`,
        featureCount: features.length,
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
