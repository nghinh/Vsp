<template>
  <div class="versions-page">

    <header class="page-header">
      <h1 class="page-title">Version History</h1>
      <p class="course-id-label">Course ID: {{ courseId }}</p>
    </header>

    <!-- Loading state -->
    <div v-if="loading" class="loading-state" aria-busy="true" aria-label="Loading versions">
      <div v-for="i in 3" :key="i" class="skeleton-row"></div>
    </div>

    <!-- Error state -->
    <div v-else-if="fetchError" class="error-state" role="alert">
      <span class="error-icon" aria-hidden="true">⚠</span>
      <span>{{ fetchError }}</span>
      <button class="retry-btn" @click="loadVersions(0)">Retry</button>
    </div>

    <!-- Empty state -->
    <div v-else-if="versions.length === 0" class="empty-state">
      <span class="empty-icon" aria-hidden="true">📋</span>
      <p class="empty-title">No versions yet.</p>
      <p class="empty-subtitle">Publish a course version to see it here.</p>
    </div>

    <!-- Version list -->
    <div v-else class="version-list" role="list">

      <div
        v-for="version in versions"
        :key="version.id"
        class="version-row"
        role="listitem"
      >
        <!-- Status badge (icon + text, not color alone) -->
        <span
          class="version-status-badge"
          :class="badgeClass(version.status)"
          :aria-label="`Status: ${statusLabel(version.status)}`"
        >
          <span aria-hidden="true">{{ statusIcon(version.status) }}</span>
          <span>{{ statusLabel(version.status) }}</span>
        </span>

        <!-- Version number -->
        <span class="version-number">
          <span class="version-badge">v{{ version.versionNumber }}</span>
        </span>

        <!-- Published by -->
        <span class="version-published-by">
          <span v-if="version.publishedBy" class="actor">{{ version.publishedBy }}</span>
          <span v-else class="no-actor">—</span>
        </span>

        <!-- Published at -->
        <span class="version-published-at">
          <span v-if="version.publishedAt" class="timestamp">{{ formatInstant(version.publishedAt) }}</span>
          <span v-else class="no-date">—</span>
        </span>

        <!-- Rollback note (if rolled back) -->
        <span v-if="version.rollbackNote" class="rollback-note" :title="version.rollbackNote">
          ↩ {{ version.rollbackNote }}
        </span>

        <!-- Actions -->
        <span class="version-actions">
          <!-- View Impact: available for any version -->
          <button
            class="action-btn impact-btn"
            :disabled="impactLoading[version.id] || rollbackLoading"
            @click="viewImpact(version)"
            :aria-label="`View impact of rolling back to v${version.versionNumber}`"
          >
            {{ impactLoading[version.id] ? '…' : 'View Impact' }}
          </button>

          <!-- Roll Back: only for ARCHIVED versions (when there is a current published version) -->
          <button
            v-if="version.status === 'ARCHIVED' && hasPublishedVersion"
            class="action-btn rollback-btn"
            :disabled="rollbackLoading"
            @click="openRollbackModal(version)"
            :aria-label="`Roll back to v${version.versionNumber}`"
          >
            Roll Back
          </button>
        </span>
      </div>
    </div>

    <!-- Pagination -->
    <div v-if="totalPages > 1" class="pagination" role="navigation" aria-label="Version list pagination">
      <button
        class="page-btn"
        :disabled="currentPage === 0"
        @click="goToPage(currentPage - 1)"
        aria-label="Previous page"
      >
        ← Prev
      </button>
      <span class="page-info">Page {{ currentPage + 1 }} of {{ totalPages }}</span>
      <button
        class="page-btn"
        :disabled="currentPage >= totalPages - 1"
        @click="goToPage(currentPage + 1)"
        aria-label="Next page"
      >
        Next →
      </button>
    </div>

    <!-- ─── Impact Preview Modal ─────────────────────────────────────────── -->
    <div v-if="showImpactModal" class="modal-overlay" role="dialog" aria-modal="true" aria-labelledby="impact-title">
      <div class="modal-panel">
        <div class="modal-header">
          <h2 id="impact-title" class="modal-title">Rollback Impact</h2>
          <button class="close-btn" @click="closeImpactModal" aria-label="Close impact preview">×</button>
        </div>

        <div v-if="impactError" class="modal-error">
          <span>⚠</span> {{ impactError }}
        </div>

        <div v-else-if="impactLoadingModal" class="modal-loading">
          <span>Loading impact preview…</span>
        </div>

        <div v-else-if="impactData" class="impact-body">
          <!-- Current published version -->
          <div v-if="impactData.currentVersion" class="impact-row impact-archive">
            <span class="impact-label">Will be archived:</span>
            <span class="impact-version">
              v{{ impactData.currentVersion.versionNumber }}
              ({{ statusLabel(impactData.currentVersion.status) }})
            </span>
            <span class="impact-meta">
              Published by {{ impactData.currentVersion.publishedBy }} on
              {{ formatInstant(impactData.currentVersion.publishedAt) }}
            </span>
          </div>
          <div v-else class="impact-row impact-no-current">
            <span class="impact-label">No currently published version.</span>
            <span class="impact-meta">This will be the first published version.</span>
          </div>

          <!-- Target version -->
          <div class="impact-row impact-activate">
            <span class="impact-label">Will be re-activated as published:</span>
            <span class="impact-version">
              v{{ impactData.targetVersion.versionNumber }}
              ({{ statusLabel(impactData.targetVersion.status) }})
            </span>
            <span v-if="impactData.targetVersion.publishedBy" class="impact-meta">
              Originally published by {{ impactData.targetVersion.publishedBy }} on
              {{ formatInstant(impactData.targetVersion.publishedAt) }}
            </span>
          </div>

          <!-- Summary text -->
          <div class="impact-summary">
            <p>{{ impactData.changesSummary }}</p>
          </div>
        </div>

        <div class="modal-footer">
          <button class="action-btn cancel-btn" @click="closeImpactModal">Close</button>
          <button
            v-if="impactData && impactData.targetVersion.status === 'ARCHIVED'"
            class="action-btn rollback-btn"
            @click="confirmRollbackFromImpact(impactData.targetVersion)"
          >
            Roll Back to v{{ impactData.targetVersion.versionNumber }}
          </button>
        </div>
      </div>
    </div>

    <!-- ─── Rollback Confirmation Modal ────────────────────────────────── -->
    <div v-if="showRollbackModal" class="modal-overlay" role="dialog" aria-modal="true" aria-labelledby="rollback-title">
      <div class="modal-panel">
        <div class="modal-header">
          <h2 id="rollback-title" class="modal-title">Confirm Rollback</h2>
          <button class="close-btn" @click="closeRollbackModal" aria-label="Close rollback confirmation">×</button>
        </div>

        <div class="rollback-body">
          <p class="rollback-warning">
            You are about to roll back <strong>v{{ selectedVersionForRollback?.versionNumber }}</strong> to
            the published state. This cannot be undone.
          </p>

          <!-- Impact summary from preview if available -->
          <div v-if="impactData" class="impact-summary">
            <p>{{ impactData.changesSummary }}</p>
          </div>

          <!-- Rollback note input -->
          <div class="form-field">
            <label for="rollback-note" class="field-label">
              Rollback reason <span class="required" aria-hidden="true">*</span>
            </label>
            <textarea
              id="rollback-note"
              v-model="rollbackNote"
              class="field-input"
              rows="3"
              placeholder="Explain why this rollback is necessary…"
              :aria-invalid="rollbackNoteError ? 'true' : undefined"
              :aria-describedby="rollbackNoteError ? 'rollback-note-error' : undefined"
              maxlength="500"
            ></textarea>
            <span v-if="rollbackNoteError" id="rollback-note-error" class="field-error" role="alert">
              {{ rollbackNoteError }}
            </span>
            <span class="field-hint">{{ rollbackNote.length }}/500 characters</span>
          </div>
        </div>

        <div class="modal-footer">
          <button class="action-btn cancel-btn" @click="closeRollbackModal" :disabled="rollbackLoading">
            Cancel
          </button>
          <button
            class="action-btn confirm-rollback-btn"
            :disabled="rollbackLoading || !rollbackNote.trim()"
            @click="executeRollback"
          >
            {{ rollbackLoading ? 'Rolling back…' : 'Confirm Rollback' }}
          </button>
        </div>
      </div>
    </div>

    <!-- ─── Success Toast ───────────────────────────────────────────────── -->
    <div v-if="showSuccessToast" class="toast toast-success" role="status" aria-live="polite">
      <span aria-hidden="true">✅</span>
      <span>
        Rollback triggered — v{{ successToastVersion }} is now being published.
        <span v-if="successToastJobId"> Job ID: {{ successToastJobId }}</span>
      </span>
      <button class="toast-close" @click="showSuccessToast = false" aria-label="Dismiss success message">×</button>
    </div>

  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import type { CourseVersionDto, RollbackImpactDto } from '@/types/course-version';
import { courseVersionApi } from '@/api/course-version';

const props = defineProps<{
  courseId: number;
  authToken: string;
}>();

const PAGE_SIZE = 20;

// ─── State ────────────────────────────────────────────────────────────────────

const versions = ref<CourseVersionDto[]>([]);
const totalElements = ref(0);
const currentPage = ref(0);
const loading = ref(false);
const fetchError = ref<string | null>(null);

// Impact modal
const showImpactModal = ref(false);
const impactLoadingModal = ref(false);
const impactLoading = ref<Record<number, boolean>>({});
const impactData = ref<RollbackImpactDto | null>(null);
const impactError = ref<string | null>(null);

// Rollback modal
const showRollbackModal = ref(false);
const selectedVersionForRollback = ref<CourseVersionDto | null>(null);
const rollbackNote = ref('');
const rollbackNoteError = ref<string | null>(null);
const rollbackLoading = ref(false);

// Success toast
const showSuccessToast = ref(false);
const successToastVersion = ref<number | null>(null);
const successToastJobId = ref<string | null>(null);

// ─── Computed ─────────────────────────────────────────────────────────────────

const totalPages = computed(() => Math.ceil(totalElements.value / PAGE_SIZE));
const hasPublishedVersion = computed(() => versions.value.some(v => v.status === 'PUBLISHED'));

// ─── Data loading ─────────────────────────────────────────────────────────────

async function loadVersions(page = 0) {
  loading.value = true;
  fetchError.value = null;
  try {
    const resp = await courseVersionApi.listVersions(props.courseId, props.authToken, page, PAGE_SIZE);
    versions.value = resp.content;
    totalElements.value = resp.totalElements;
    currentPage.value = page;
  } catch (err: unknown) {
    const apiErr = err as { message?: string };
    fetchError.value = apiErr?.message ?? 'Failed to load versions';
  } finally {
    loading.value = false;
  }
}

function goToPage(page: number) {
  loadVersions(page);
}

// ─── Impact preview ────────────────────────────────────────────────────────────

async function viewImpact(version: CourseVersionDto) {
  impactLoading.value[version.id] = true;
  impactError.value = null;
  impactData.value = null;
  showImpactModal.value = true;
  impactLoadingModal.value = true;

  try {
    impactData.value = await courseVersionApi.getRollbackImpact(props.courseId, version.id, props.authToken);
  } catch (err: unknown) {
    const apiErr = err as { message?: string };
    impactError.value = apiErr?.message ?? 'Failed to load impact preview';
  } finally {
    impactLoading.value[version.id] = false;
    impactLoadingModal.value = false;
  }
}

function closeImpactModal() {
  showImpactModal.value = false;
  impactData.value = null;
  impactError.value = null;
}

function confirmRollbackFromImpact(targetVersion: CourseVersionDto) {
  closeImpactModal();
  openRollbackModal(targetVersion);
}

// ─── Rollback ─────────────────────────────────────────────────────────────────

function openRollbackModal(version: CourseVersionDto) {
  selectedVersionForRollback.value = version;
  rollbackNote.value = '';
  rollbackNoteError.value = null;
  showRollbackModal.value = true;

  // Pre-fetch impact if not already loaded
  if (!impactData.value || impactData.value.targetVersion.id !== version.id) {
    impactLoadingModal.value = true;
    impactData.value = null;
    impactError.value = null;
    courseVersionApi.getRollbackImpact(props.courseId, version.id, props.authToken)
      .then(data => { impactData.value = data; })
      .catch((err: unknown) => {
        const apiErr = err as { message?: string };
        impactError.value = apiErr?.message ?? 'Failed to load impact';
      })
      .finally(() => { impactLoadingModal.value = false; });
  }
}

function closeRollbackModal() {
  showRollbackModal.value = false;
  selectedVersionForRollback.value = null;
  rollbackNote.value = '';
  rollbackNoteError.value = null;
}

async function executeRollback() {
  rollbackNoteError.value = null;

  if (!rollbackNote.value.trim()) {
    rollbackNoteError.value = 'Rollback reason is required.';
    return;
  }

  if (!selectedVersionForRollback.value) return;

  rollbackLoading.value = true;
  try {
    const resp = await courseVersionApi.executeRollback(
      props.courseId,
      selectedVersionForRollback.value.id,
      { rollbackNote: rollbackNote.value.trim() },
      props.authToken
    );

    closeRollbackModal();
    showSuccessToast.value = true;
    successToastVersion.value = resp.versionNumber;
    successToastJobId.value = resp.newJobId;
    // Refresh version list
    await loadVersions(currentPage.value);

    // Auto-dismiss toast after 8s
    setTimeout(() => { showSuccessToast.value = false; }, 8000);
  } catch (err: unknown) {
    const apiErr = err as { message?: string };
    rollbackNoteError.value = apiErr?.message ?? 'Rollback failed. Please try again.';
  } finally {
    rollbackLoading.value = false;
  }
}

// ─── Status helpers ────────────────────────────────────────────────────────────

function badgeClass(status: string): string {
  switch (status) {
    case 'PUBLISHED': return 'badge-published';
    case 'ARCHIVED':  return 'badge-archived';
    case 'DRAFT':     return 'badge-draft';
    default:          return 'badge-unknown';
  }
}

function statusIcon(status: string): string {
  switch (status) {
    case 'PUBLISHED': return '✅';
    case 'ARCHIVED':  return '📁';
    case 'DRAFT':    return '📝';
    default:         return '❓';
  }
}

function statusLabel(status: string): string {
  switch (status) {
    case 'PUBLISHED': return 'Published';
    case 'ARCHIVED':  return 'Archived';
    case 'DRAFT':     return 'Draft';
    default:          return 'Unknown';
  }
}

// ─── Formatting ───────────────────────────────────────────────────────────────

function formatInstant(iso: string | null): string {
  if (!iso) return '—';
  return new Date(iso).toLocaleString();
}

// ─── Lifecycle ───────────────────────────────────────────────────────────────

onMounted(() => loadVersions(0));
</script>

<style scoped>
.versions-page {
  font-family: system-ui, -apple-system, sans-serif;
  padding: 1.5rem;
  max-width: 960px;
}

.page-header {
  margin-bottom: 1.5rem;
  border-bottom: 1px solid #2d3449;
  padding-bottom: 1rem;
}
.page-title {
  font-size: 1.5rem;
  font-weight: 700;
  color: #dae2fd;
  margin: 0;
}
.course-id-label {
  font-size: 0.875rem;
  color: #97a2c0;
  margin: 0.25rem 0 0;
}

/* Loading skeleton */
.loading-state { display: flex; flex-direction: column; gap: 0.75rem; }
.skeleton-row {
  height: 3.5rem;
  border-radius: 6px;
  background: linear-gradient(90deg, #2d3449 25%, #222a3d 50%, #2d3449 75%);
  background-size: 200% 100%;
  animation: shimmer 1.5s infinite;
}
@keyframes shimmer {
  0%   { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}

/* Error / Empty */
.error-state,
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.5rem;
  padding: 3rem 1rem;
  color: #97a2c0;
  text-align: center;
}
.error-state { color: #dc2626; }
.empty-icon, .error-icon { font-size: 2rem; }
.empty-title { font-size: 1.125rem; font-weight: 600; margin: 0; }
.empty-subtitle { font-size: 0.875rem; color: #97a2c0; margin: 0; }
.retry-btn {
  margin-top: 0.5rem;
  padding: 0.5rem 1.25rem;
  border-radius: 6px;
  background: #dc2626;
  color: white;
  border: none;
  cursor: pointer;
  font-size: 0.875rem;
  min-height: 44px;
}

/* Version list */
.version-list { display: flex; flex-direction: column; gap: 0.5rem; }

.version-row {
  display: grid;
  grid-template-columns: auto auto 1fr auto auto;
  align-items: center;
  gap: 0.75rem;
  padding: 0.75rem 1rem;
  border-radius: 8px;
  border: 1px solid #2d3449;
  background: #171f33;
  transition: background 0.15s;
}
.version-row:hover { background: #171f33; }

/* Status badge — icon + text, not color alone */
.version-status-badge {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  padding: 0.2rem 0.5rem;
  border-radius: 9999px;
  font-size: 0.75rem;
  font-weight: 600;
  border: 1px solid currentColor;
  white-space: nowrap;
}
.badge-published { color: #15803d; background: #dcfce7; }
.badge-archived  { color: #ec6a06; background: #2d3449; }
.badge-draft     { color: #92400e; background: #fef3c7; }
.badge-unknown   { color: #97a2c0; background: #222a3d; }

.version-number .version-badge {
  font-family: monospace;
  font-size: 0.8125rem;
  font-weight: 600;
  background: #222a3d;
  padding: 0.1rem 0.4rem;
  border-radius: 3px;
}

.version-published-by {
  font-size: 0.875rem;
  color: #c5cde8;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.version-published-by .no-actor { color: #97a2c0; }

.version-published-at {
  font-size: 0.75rem;
  color: #97a2c0;
  white-space: nowrap;
}
.version-published-at .no-date { color: #97a2c0; }

.rollback-note {
  font-size: 0.75rem;
  color: #92400e;
  background: #fef3c7;
  padding: 0.1rem 0.4rem;
  border-radius: 3px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  max-width: 12rem;
}

.version-actions {
  display: flex;
  gap: 0.5rem;
  align-items: center;
  flex-shrink: 0;
}

/* Action buttons */
.action-btn {
  padding: 0.4rem 0.75rem;
  border-radius: 6px;
  border: 1px solid #2d3449;
  background: #171f33;
  cursor: pointer;
  font-size: 0.8125rem;
  font-weight: 500;
  min-height: 36px;
  transition: background 0.15s;
}
.action-btn:hover:not(:disabled) { background: #222a3d; }
.action-btn:disabled { opacity: 0.5; cursor: not-allowed; }

.impact-btn {
  color: #ec6a06;
  border-color: #2d3449;
  background: #222a3d;
}
.impact-btn:hover:not(:disabled) { background: #2d3449; }

.rollback-btn {
  color: #b45309;
  border-color: #fde68a;
  background: #171f33eb;
}
.rollback-btn:hover:not(:disabled) { background: #fef3c7; }

.confirm-rollback-btn {
  background: #b45309;
  color: white;
  border-color: #b45309;
}
.confirm-rollback-btn:hover:not(:disabled) { background: #92400e; }
.confirm-rollback-btn:disabled { background: #2d3449; border-color: #2d3449; cursor: not-allowed; }

.cancel-btn {
  color: #c5cde8;
  border-color: #2d3449;
}

/* Pagination */
.pagination {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 1rem;
  margin-top: 1.5rem;
}
.page-btn {
  padding: 0.5rem 1rem;
  border-radius: 6px;
  border: 1px solid #2d3449;
  background: #171f33;
  cursor: pointer;
  font-size: 0.875rem;
  min-height: 44px;
}
.page-btn:hover:not(:disabled) { background: #222a3d; }
.page-btn:disabled { opacity: 0.4; cursor: not-allowed; }
.page-info { font-size: 0.875rem; color: #97a2c0; }

/* ─── Modals ──────────────────────────────────────────────────────────────── */
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 50;
  padding: 1rem;
}

.modal-panel {
  background: #171f33;
  border-radius: 12px;
  max-width: 520px;
  width: 100%;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.2);
  overflow: hidden;
}

.modal-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1rem 1.25rem;
  border-bottom: 1px solid #2d3449;
  background: #171f33;
}
.modal-title { font-size: 1.0625rem; font-weight: 700; color: #dae2fd; margin: 0; }
.close-btn {
  background: none;
  border: none;
  font-size: 1.5rem;
  cursor: pointer;
  color: #97a2c0;
  min-height: 44px;
  min-width: 44px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 6px;
}
.close-btn:hover { background: #222a3d; }

.modal-footer {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 0.75rem;
  padding: 0.875rem 1.25rem;
  border-top: 1px solid #2d3449;
  background: #171f33;
}

.modal-loading,
.modal-error {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 1.5rem;
  font-size: 0.875rem;
  color: #97a2c0;
}
.modal-error { color: #dc2626; }

/* Impact body */
.impact-body {
  padding: 1.25rem;
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.impact-row {
  display: grid;
  grid-template-columns: auto 1fr;
  gap: 0.5rem 0.75rem;
  font-size: 0.875rem;
  align-items: baseline;
  padding: 0.75rem;
  border-radius: 6px;
}
.impact-archive { background: #fee2e2; }
.impact-activate { background: #dcfce7; }
.impact-no-current { background: #fef3c7; }

.impact-label {
  grid-column: 1 / -1;
  font-size: 0.75rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: #97a2c0;
  font-weight: 600;
}
.impact-version {
  font-family: monospace;
  font-weight: 600;
  color: #dae2fd;
}
.impact-meta {
  grid-column: 1 / -1;
  font-size: 0.8125rem;
  color: #97a2c0;
}

.impact-summary {
  background: #222a3d;
  border-radius: 6px;
  padding: 0.75rem;
  font-size: 0.875rem;
  color: #c5cde8;
}
.impact-summary p { margin: 0; }

/* Rollback body */
.rollback-body {
  padding: 1.25rem;
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.rollback-warning {
  font-size: 0.875rem;
  color: #c5cde8;
  margin: 0;
  padding: 0.75rem;
  background: #fef3c7;
  border: 1px solid #fde68a;
  border-radius: 6px;
}

.form-field {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}
.field-label {
  font-size: 0.875rem;
  font-weight: 600;
  color: #c5cde8;
}
.required { color: #dc2626; }
.field-input {
  padding: 0.5rem 0.75rem;
  border: 1px solid #2d3449;
  border-radius: 6px;
  font-size: 0.875rem;
  font-family: inherit;
  resize: vertical;
  min-height: 80px;
  transition: border-color 0.15s;
}
.field-input:focus {
  outline: none;
  border-color: #3b82f6;
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.15);
}
.field-input[aria-invalid="true"] { border-color: #dc2626; }
.field-error { font-size: 0.75rem; color: #dc2626; }
.field-hint { font-size: 0.75rem; color: #97a2c0; }

/* ─── Toast ──────────────────────────────────────────────────────────────── */
.toast {
  position: fixed;
  bottom: 1.5rem;
  right: 1.5rem;
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.875rem 1rem;
  border-radius: 8px;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.15);
  font-size: 0.875rem;
  max-width: 400px;
  z-index: 100;
  animation: slide-up 0.2s ease-out;
}
@keyframes slide-up {
  from { transform: translateY(1rem); opacity: 0; }
  to   { transform: translateY(0); opacity: 1; }
}
.toast-success {
  background: #f0fdf4;
  border: 1px solid #86efac;
  color: #166534;
}
.toast-close {
  background: none;
  border: none;
  cursor: pointer;
  font-size: 1rem;
  color: #97a2c0;
  min-height: 44px;
  min-width: 44px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 4px;
  flex-shrink: 0;
}
.toast-close:hover { background: rgba(0,0,0,0.05); }

/* Responsive: stack on small screens */
@media (max-width: 640px) {
  .version-row {
    grid-template-columns: auto 1fr;
    grid-template-rows: auto auto;
  }
  .version-actions {
    grid-column: 1 / -1;
    justify-content: flex-end;
  }
}
</style>
