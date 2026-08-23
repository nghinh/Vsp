<template>
  <div class="package-history-page">

    <header class="page-header">
      <h1 class="page-title">Lịch sử đóng gói</h1>
      <p class="course-id-label">Mã sân: {{ courseId }}</p>
    </header>

    <!-- Loading state -->
    <div v-if="loading" class="loading-state">
      <div v-for="i in 3" :key="i" class="skeleton-row"></div>
    </div>

    <!-- Error state -->
    <div v-else-if="fetchError" class="error-state" role="alert">
      <span class="error-icon">⚠</span>
      <span>{{ fetchError }}</span>
      <button class="retry-btn" @click="() => loadJobs()">Thử lại</button>
    </div>

    <!-- Empty state -->
    <div v-else-if="jobs.length === 0" class="empty-state">
      <span class="empty-icon">📦</span>
      <p class="empty-title">Chưa có lần đóng gói nào.</p>
      <p class="empty-subtitle">Công bố một phiên bản để bắt đầu.</p>
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
          :aria-label="`Trạng thái: ${statusLabel(job.status)}`"
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
          <span v-else-if="isInProgress(job.status)" class="in-progress-label">Đang chạy…</span>
          <span v-else>—</span>
        </span>

        <!-- Error indicator -->
        <span v-if="job.status === 'FAILED'" class="error-indicator" aria-label="Đóng gói thất bại">
          ❌ {{ job.errorCode }}
        </span>
      </div>
    </div>

    <!-- Pagination -->
    <div v-if="totalPages > 1" class="pagination" role="navigation" aria-label="Phân trang">
      <button
        class="page-btn"
        :disabled="currentPage === 0"
        @click="goToPage(currentPage - 1)"
        aria-label="Trang trước"
      >
        ← Trước
      </button>
      <span class="page-info">Trang {{ currentPage + 1 }} / {{ totalPages }}</span>
      <button
        class="page-btn"
        :disabled="currentPage >= totalPages - 1"
        @click="goToPage(currentPage + 1)"
        aria-label="Trang sau"
      >
        Sau →
      </button>
    </div>

    <!-- Selected job detail panel -->
    <div v-if="selectedJob" class="job-detail-panel" aria-label="Chi tiết tác vụ đã chọn">
      <div class="detail-header">
        <h2 class="detail-title">Chi tiết tác vụ</h2>
        <button class="close-btn" @click="selectedJob = null" aria-label="Đóng bảng chi tiết">×</button>
      </div>

      <div class="detail-grid">
        <div class="detail-row">
          <span class="detail-label">Mã tác vụ</span>
          <span class="detail-value mono">{{ selectedJob.jobId }}</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">Mã sân</span>
          <span class="detail-value">{{ selectedJob.courseId }}</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">Mã phiên bản dữ liệu</span>
          <span class="detail-value">{{ selectedJob.dataVersionId }}</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">Phiên bản manifest</span>
          <span class="detail-value mono">{{ selectedJob.manifestVersion ?? '—' }}</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">Trạng thái</span>
          <span :class="['detail-badge', badgeClass(selectedJob.status)]">
            {{ statusLabel(selectedJob.status) }}
          </span>
        </div>
        <div class="detail-row">
          <span class="detail-label">Tạo lúc</span>
          <span class="detail-value">{{ formatInstant(selectedJob.createdAt) }}</span>
        </div>
        <div class="detail-row" v-if="selectedJob.startedAt">
          <span class="detail-label">Bắt đầu</span>
          <span class="detail-value">{{ formatInstant(selectedJob.startedAt) }}</span>
        </div>
        <div class="detail-row" v-if="selectedJob.completedAt">
          <span class="detail-label">{{ selectedJob.status === 'FAILED' ? 'Thất bại' : 'Hoàn tất' }}</span>
          <span class="detail-value">{{ formatInstant(selectedJob.completedAt) }}</span>
        </div>
        <div class="detail-row" v-if="selectedJob.buildDurationMs">
          <span class="detail-label">Thời lượng</span>
          <span class="detail-value">{{ formatDuration(selectedJob.buildDurationMs) }}</span>
        </div>
        <div class="detail-row" v-if="selectedJob.errorCode">
          <span class="detail-label">Mã lỗi</span>
          <span class="detail-value mono error-code">{{ selectedJob.errorCode }}</span>
        </div>
        <div class="detail-row" v-if="selectedJob.errorMessage">
          <span class="detail-label">Thông báo lỗi</span>
          <span class="detail-value error-message">{{ selectedJob.errorMessage }}</span>
        </div>
        <div class="detail-row" v-if="selectedJob.errorDetail">
          <span class="detail-label">Gợi ý khắc phục</span>
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
          {{ retrying ? 'Đang thử lại…' : 'Đóng gói lại' }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import type { PackageBuildJobDto, PackageBuildStatus } from '@/types/package-build';
import { packageBuildApi } from '@/api/package-build';
import { formatInstant } from '@/lib/datetime';

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
    fetchError.value = (err as { message?: string })?.message ?? 'Không tải được danh sách tác vụ';
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
    QUEUED: 'Đang chờ', VALIDATING: 'Đang kiểm tra', BUILDING: 'Đang dựng',
    ASSEMBLING: 'Đang ghép', UPLOADING: 'Đang tải lên', PUBLISHING: 'Đang publish',
    COMPLETED: 'Hoàn tất', FAILED: 'Thất bại',
  };
  return labels[status] ?? 'Không rõ';
}

function isInProgress(status: PackageBuildStatus): boolean {
  return !['COMPLETED', 'FAILED'].includes(status);
}

// ─── Formatting ───────────────────────────────────────────────────────────────


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
  border-bottom: 1px solid var(--surface-container-highest);
  padding-bottom: 1rem;
}
.page-title {
  font-size: 1.5rem;
  font-weight: 700;
  color: var(--on-surface);
  margin: 0;
}
.course-id-label {
  font-size: 0.875rem;
  color: var(--muted);
  margin: 0.25rem 0 0;
}

/* Loading skeleton */
.loading-state { display: flex; flex-direction: column; gap: 0.75rem; }
.skeleton-row {
  height: 3.5rem;
  border-radius: 6px;
  background: linear-gradient(90deg, var(--surface-container-highest) 25%, var(--surface-container-high) 50%, var(--surface-container-highest) 75%);
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
  color: var(--muted);
  text-align: center;
}
.error-state { color: #dc2626; }
.empty-icon, .error-icon { font-size: 2rem; }
.empty-title { font-size: 1.125rem; font-weight: 600; margin: 0; }
.empty-subtitle { font-size: 0.875rem; color: var(--muted); margin: 0; }
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
  border: 1px solid var(--surface-container-highest);
  background: var(--surface-container);
  cursor: pointer;
  transition: background 0.15s;
}
.job-row:hover { background: var(--surface-container); }
.job-row[aria-selected="true"] {
  border-color: #3b82f6;
  background: var(--surface-container-high);
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
.badge-queued   { color: var(--secondary-container); background: var(--surface-container-highest); }
.badge-in-progress { color: #92400e; background: #fef3c7; }

.job-version .version-badge {
  font-family: monospace;
  font-size: 0.75rem;
  background: var(--surface-container-high);
  padding: 0.1rem 0.35rem;
  border-radius: 3px;
}
.job-version .version-pending { color: var(--muted); }

.job-triggered-by { font-size: 0.875rem; color: #c5cde8; }
.job-created { font-size: 0.75rem; color: var(--muted); white-space: nowrap; }
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
  border: 1px solid var(--surface-container-highest);
  background: var(--surface-container);
  cursor: pointer;
  font-size: 0.875rem;
  min-height: 44px;
}
.page-btn:hover:not(:disabled) { background: var(--surface-container-high); }
.page-btn:disabled { opacity: 0.4; cursor: not-allowed; }
.page-info { font-size: 0.875rem; color: var(--muted); }

/* Job detail panel */
.job-detail-panel {
  margin-top: 1.5rem;
  border: 2px solid #3b82f6;
  border-radius: 10px;
  overflow: hidden;
  background: var(--surface-container);
}
.detail-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.75rem 1rem;
  background: var(--surface-container-high);
  border-bottom: 1px solid var(--surface-container-highest);
}
.detail-title { font-size: 1rem; font-weight: 600; margin: 0; color: var(--secondary-container); }
.close-btn {
  background: none;
  border: none;
  font-size: 1.5rem;
  cursor: pointer;
  color: var(--muted);
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
  color: var(--muted);
}
.detail-value { color: var(--on-surface); }
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
  border-top: 1px solid var(--surface-container-highest);
}
.action-btn {
  padding: 0.5rem 1rem;
  border-radius: 6px;
  border: 1px solid #3b82f6;
  background: var(--surface-container-high);
  color: var(--secondary-container);
  cursor: pointer;
  font-size: 0.875rem;
  font-weight: 500;
  min-height: 44px;
}
.action-btn:hover:not(:disabled) { background: var(--surface-container-highest); }
.action-btn:disabled { opacity: 0.5; cursor: not-allowed; }

@media (max-width: 640px) {
  .job-row {
    grid-template-columns: auto minmax(0, 1fr);
    gap: 0.5rem 0.75rem;
  }
  .job-row > :nth-child(n + 3) {
    grid-column: 2;
    justify-self: start;
  }
}
</style>
