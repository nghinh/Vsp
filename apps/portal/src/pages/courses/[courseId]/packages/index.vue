<template>
  <div class="package-history-page">

    <header class="page-header">
      <h1 class="page-title">Package Build History</h1>
      <p class="course-id-label">Course ID: {{ courseId }}</p>
    </header>

    <!-- Loading state -->
    <div v-if="loading" class="loading-state">
      <div v-for="i in 3" :key="i" class="skeleton-row"></div>
    </div>

    <!-- Error state -->
    <div v-else-if="fetchError" class="error-state" role="alert">
      <span class="error-icon">⚠</span>
      <span>{{ fetchError }}</span>
      <button class="retry-btn" @click="() => loadJobs()">Retry</button>
    </div>

    <!-- Empty state -->
    <div v-else-if="jobs.length === 0" class="empty-state">
      <span class="empty-icon">📦</span>
      <p class="empty-title">No package builds yet.</p>
      <p class="empty-subtitle">Publish a course version to start.</p>
    </div>

    <!-- Job list -->
    <div v-else class="job-list" role="list">

      <div
        v-for="job in jobs"
        :key="job.jobId"
        class="job-row"
        role="listitem"
        @click="selectJob(job)"
        :aria-selected="selectedJob?.jobId === job.jobId"
        tabindex="0"
        @keydown.enter="selectJob(job)"
        @keydown.space.prevent="selectJob(job)"
      >
        <!-- Status badge (icon + text + color) -->
        <span
          class="job-status-badge"
          :class="badgeClass(job.status)"
          :aria-label="`Status: ${job.status}`"
        >
          <span aria-hidden="true">{{ statusIcon(job.status) }}</span>
          <span>{{ statusLabel(job.status) }}</span>
        </span>

        <!-- Manifest version -->
        <span class="job-version">
          <span v-if="job.manifestVersion" class="version-badge">
            v{{ job.manifestVersion }}
          </span>
          <span v-else class="version-pending">—</span>
        </span>

        <!-- Triggered by -->
        <span class="job-triggered-by">{{ job.triggeredBy }}</span>

        <!-- Created time -->
        <span class="job-created">{{ formatInstant(job.createdAt) }}</span>

        <!-- Duration -->
        <span class="job-duration">
          <span v-if="job.buildDurationMs">{{ formatDuration(job.buildDurationMs) }}</span>
          <span v-else-if="isInProgress(job.status)" class="in-progress-label">In progress…</span>
          <span v-else>—</span>
        </span>

        <!-- Error indicator -->
        <span v-if="job.status === 'FAILED'" class="error-indicator" aria-label="Build failed">
          ❌ {{ job.errorCode }}
        </span>
      </div>
    </div>

    <!-- Pagination -->
    <div v-if="totalPages > 1" class="pagination" role="navigation" aria-label="Pagination">
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

    <!-- Selected job detail panel -->
    <div v-if="selectedJob" class="job-detail-panel" aria-label="Selected job details">
      <div class="detail-header">
        <h2 class="detail-title">Job Detail</h2>
        <button class="close-btn" @click="selectedJob = null" aria-label="Close detail panel">×</button>
      </div>

      <div class="detail-grid">
        <div class="detail-row">
          <span class="detail-label">Job ID</span>
          <span class="detail-value mono">{{ selectedJob.jobId }}</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">Course ID</span>
          <span class="detail-value">{{ selectedJob.courseId }}</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">Data Version ID</span>
          <span class="detail-value">{{ selectedJob.dataVersionId }}</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">Manifest Version</span>
          <span class="detail-value mono">{{ selectedJob.manifestVersion ?? '—' }}</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">Status</span>
          <span :class="['detail-badge', badgeClass(selectedJob.status)]">
            {{ statusLabel(selectedJob.status) }}
          </span>
        </div>
        <div class="detail-row">
          <span class="detail-label">Created</span>
          <span class="detail-value">{{ formatInstant(selectedJob.createdAt) }}</span>
        </div>
        <div class="detail-row" v-if="selectedJob.startedAt">
          <span class="detail-label">Started</span>
          <span class="detail-value">{{ formatInstant(selectedJob.startedAt) }}</span>
        </div>
        <div class="detail-row" v-if="selectedJob.completedAt">
          <span class="detail-label">{{ selectedJob.status === 'FAILED' ? 'Failed' : 'Completed' }}</span>
          <span class="detail-value">{{ formatInstant(selectedJob.completedAt) }}</span>
        </div>
        <div class="detail-row" v-if="selectedJob.buildDurationMs">
          <span class="detail-label">Duration</span>
          <span class="detail-value">{{ formatDuration(selectedJob.buildDurationMs) }}</span>
        </div>
        <div class="detail-row" v-if="selectedJob.errorCode">
          <span class="detail-label">Error Code</span>
          <span class="detail-value mono error-code">{{ selectedJob.errorCode }}</span>
        </div>
        <div class="detail-row" v-if="selectedJob.errorMessage">
          <span class="detail-label">Error Message</span>
          <span class="detail-value error-message">{{ selectedJob.errorMessage }}</span>
        </div>
        <div class="detail-row" v-if="selectedJob.errorDetail">
          <span class="detail-label">Fix Hint</span>
          <span class="detail-value error-detail">{{ selectedJob.errorDetail }}</span>
        </div>
      </div>

      <!-- Retry for failed jobs -->
      <div v-if="selectedJob.status === 'FAILED'" class="detail-actions">
        <button
          class="action-btn retry-btn"
          :disabled="retrying"
          @click="handleRetry"
        >
          {{ retrying ? 'Retrying…' : 'Retry Build' }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import type { PackageBuildJobDto, PackageBuildStatus } from '@/types/package-build';
import { packageBuildApi } from '@/api/package-build';

const props = defineProps<{
  courseId: number;
  authToken: string;
}>();

const PAGE_SIZE = 20;

const jobs = ref<PackageBuildJobDto[]>([]);
const total = ref(0);
const currentPage = ref(0);
const loading = ref(false);
const fetchError = ref<string | null>(null);
const selectedJob = ref<PackageBuildJobDto | null>(null);
const retrying = ref(false);

const totalPages = computed(() => Math.ceil(total.value / PAGE_SIZE));

// ─── Data loading ─────────────────────────────────────────────────────────────

async function loadJobs(page = 0) {
  loading.value = true;
  fetchError.value = null;
  try {
    const resp = await packageBuildApi.listBuildJobs(
      props.courseId,
      props.authToken,
      page,
      PAGE_SIZE
    );
    jobs.value = resp.jobs;
    total.value = resp.total;
    currentPage.value = page;
  } catch (err: unknown) {
    fetchError.value = (err as { message?: string })?.message ?? 'Failed to load jobs';
  } finally {
    loading.value = false;
  }
}

function goToPage(page: number) {
  loadJobs(page);
}

function selectJob(job: PackageBuildJobDto) {
  selectedJob.value = selectedJob.value?.jobId === job.jobId ? null : job;
}

// ─── Retry ───────────────────────────────────────────────────────────────────

async function handleRetry() {
  if (!selectedJob.value) return;
  const job = selectedJob.value;
  retrying.value = true;
  try {
    const resp = await packageBuildApi.triggerBuild(
      props.courseId,
      { dataVersionId: job.dataVersionId, triggeredBy: job.triggeredBy },
      props.authToken
    );
    // Refresh the job detail
    selectedJob.value = await packageBuildApi.getBuildJob(props.courseId, resp.jobId, props.authToken);
    await loadJobs(currentPage.value);
  } catch {
    // keep current error
  } finally {
    retrying.value = false;
  }
}

// ─── Status helpers ────────────────────────────────────────────────────────────

function badgeClass(status: PackageBuildStatus): string {
  switch (status) {
    case 'COMPLETED':   return 'badge-success';
    case 'FAILED':     return 'badge-error';
    case 'QUEUED':     return 'badge-queued';
    default:           return 'badge-in-progress';
  }
}

function statusIcon(status: PackageBuildStatus): string {
  const icons: Record<PackageBuildStatus, string> = {
    QUEUED: '⏳', VALIDATING: '🔍', BUILDING: '🔨', ASSEMBLING: '📋',
    UPLOADING: '☁️', PUBLISHING: '🌐', COMPLETED: '✅', FAILED: '❌',
  };
  return icons[status] ?? '❓';
}

function statusLabel(status: PackageBuildStatus): string {
  const labels: Record<PackageBuildStatus, string> = {
    QUEUED: 'Queued', VALIDATING: 'Validating', BUILDING: 'Building',
    ASSEMBLING: 'Assembling', UPLOADING: 'Uploading', PUBLISHING: 'Publishing',
    COMPLETED: 'Completed', FAILED: 'Failed',
  };
  return labels[status] ?? 'Unknown';
}

function isInProgress(status: PackageBuildStatus): boolean {
  return !['COMPLETED', 'FAILED'].includes(status);
}

// ─── Formatting ───────────────────────────────────────────────────────────────

function formatInstant(iso: string): string {
  return new Date(iso).toLocaleString();
}

function formatDuration(ms: number): string {
  if (ms < 1000) return `${ms}ms`;
  const sec = Math.floor(ms / 1000);
  if (sec < 60) return `${sec}s`;
  const min = Math.floor(sec / 60);
  return `${min}m ${sec % 60}s`;
}

onMounted(() => loadJobs(0));
</script>

<style scoped>
.package-history-page {
  font-family: system-ui, -apple-system, sans-serif;
  padding: 1.5rem;
  max-width: 900px;
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

/* Job list */
.job-list { display: flex; flex-direction: column; gap: 0.5rem; }

.job-row {
  display: grid;
  grid-template-columns: auto 1fr auto auto auto;
  align-items: center;
  gap: 1rem;
  padding: 0.75rem 1rem;
  border-radius: 8px;
  border: 1px solid #2d3449;
  background: #171f33;
  cursor: pointer;
  transition: background 0.15s;
}
.job-row:hover { background: #171f33; }
.job-row[aria-selected="true"] {
  border-color: #3b82f6;
  background: #222a3d;
}

/* Status badge — icon + text, not color alone */
.job-status-badge {
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
.badge-success  { color: #15803d; background: #dcfce7; }
.badge-error    { color: #b91c1c; background: #fee2e2; }
.badge-queued   { color: #ec6a06; background: #2d3449; }
.badge-in-progress { color: #92400e; background: #fef3c7; }

.job-version .version-badge {
  font-family: monospace;
  font-size: 0.75rem;
  background: #222a3d;
  padding: 0.1rem 0.35rem;
  border-radius: 3px;
}
.job-version .version-pending { color: #97a2c0; }

.job-triggered-by { font-size: 0.875rem; color: #c5cde8; }
.job-created { font-size: 0.75rem; color: #97a2c0; white-space: nowrap; }
.job-duration { font-size: 0.75rem; color: #c5cde8; min-width: 4rem; text-align: right; }
.in-progress-label { color: #92400e; }

.error-indicator {
  font-size: 0.75rem;
  color: #b91c1c;
  white-space: nowrap;
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

/* Job detail panel */
.job-detail-panel {
  margin-top: 1.5rem;
  border: 2px solid #3b82f6;
  border-radius: 10px;
  overflow: hidden;
  background: #171f33;
}
.detail-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.75rem 1rem;
  background: #222a3d;
  border-bottom: 1px solid #2d3449;
}
.detail-title { font-size: 1rem; font-weight: 600; margin: 0; color: #ec6a06; }
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
}

.detail-grid { padding: 1rem; display: flex; flex-direction: column; gap: 0.5rem; }
.detail-row {
  display: grid;
  grid-template-columns: 12rem 1fr;
  gap: 0.5rem;
  font-size: 0.875rem;
  align-items: baseline;
}
.detail-label {
  font-size: 0.75rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: #97a2c0;
}
.detail-value { color: #dae2fd; }
.detail-value.mono { font-family: monospace; font-size: 0.8125rem; }
.detail-badge {
  display: inline-flex;
  padding: 0.15rem 0.5rem;
  border-radius: 9999px;
  font-size: 0.75rem;
  font-weight: 600;
  border: 1px solid currentColor;
}

.error-code { color: #b91c1c; }
.error-message { font-weight: 600; color: #7f1d1d; }
.error-detail {
  background: #fff5f5;
  border: 1px solid #fecaca;
  padding: 0.5rem;
  border-radius: 4px;
  color: #991b1b;
  font-size: 0.8125rem;
}

.detail-actions {
  padding: 0.75rem 1rem;
  border-top: 1px solid #2d3449;
}
.action-btn {
  padding: 0.5rem 1rem;
  border-radius: 6px;
  border: 1px solid #3b82f6;
  background: #222a3d;
  color: #ec6a06;
  cursor: pointer;
  font-size: 0.875rem;
  font-weight: 500;
  min-height: 44px;
}
.action-btn:hover:not(:disabled) { background: #2d3449; }
.action-btn:disabled { opacity: 0.5; cursor: not-allowed; }
</style>
