<template>
  <div class="build-status-panel" role="region" aria-label="Package build status">

    <!-- Loading skeleton -->
    <div v-if="loading" class="status-skeleton" aria-busy="true" aria-label="Loading build status">
      <div class="skeleton-badge"></div>
      <div class="skeleton-meta"></div>
    </div>

    <!-- Error fetching status -->
    <div v-else-if="fetchError" class="status-error" role="alert">
      <span class="error-icon">⚠</span>
      <span>{{ fetchError }}</span>
      <button class="retry-btn" @click="loadCurrentJob">Retry</button>
    </div>

    <!-- No job known yet -->
    <div v-else-if="!currentJob" class="status-idle">
      <span class="idle-icon">📦</span>
      <span>No package build yet.</span>
      <span class="hint">Publish a course version to start.</span>
    </div>

    <!-- Job exists — show status -->
    <div v-else class="status-content">

      <!-- Status header row -->
      <div class="status-header">
        <span
          class="status-badge"
          :class="badgeClass"
          role="status"
          :aria-label="`Build status: ${currentJob.status}`"
        >
          <span class="badge-icon">{{ statusIcon }}</span>
          <span class="badge-text">{{ statusLabel }}</span>
        </span>

        <span class="job-meta">
          <span v-if="currentJob.manifestVersion" class="manifest-version">
            v{{ currentJob.manifestVersion }}
          </span>
          <span class="triggered-by">
            by {{ currentJob.triggeredBy }}
          </span>
        </span>
      </div>

      <!-- Progress bar (in-progress stages only) -->
      <div v-if="isInProgress" class="progress-container">
        <div
          class="progress-bar"
          :class="`progress-${currentJob.status.toLowerCase()}`"
          :style="{ width: progressPercent + '%' }"
          role="progressbar"
          :aria-valuenow="progressPercent"
          aria-valuemin="0"
          aria-valuemax="100"
          :aria-label="`Build progress: ${progressPercent}%`"
        ></div>
      </div>

      <!-- Timing row -->
      <div class="timing-row">
        <span class="timing-item">
          <span class="timing-label">Created</span>
          <span class="timing-value">{{ formatInstant(currentJob.createdAt) }}</span>
        </span>
        <span v-if="currentJob.startedAt" class="timing-item">
          <span class="timing-label">Started</span>
          <span class="timing-value">{{ formatInstant(currentJob.startedAt) }}</span>
        </span>
        <span v-if="currentJob.completedAt" class="timing-item">
          <span class="timing-label">{{ isFailed ? 'Failed' : 'Completed' }}</span>
          <span class="timing-value">{{ formatInstant(currentJob.completedAt) }}</span>
        </span>
        <span v-if="currentJob.buildDurationMs" class="timing-item">
          <span class="timing-label">Duration</span>
          <span class="timing-value">{{ formatDuration(currentJob.buildDurationMs) }}</span>
        </span>
      </div>

      <!-- Error display (failed jobs) -->
      <div v-if="isFailed" class="error-panel" role="alert">
        <div class="error-summary">
          <span class="error-code-badge">{{ currentJob.errorCode }}</span>
          <span class="error-message">{{ currentJob.errorMessage }}</span>
        </div>
        <div v-if="currentJob.errorDetail" class="error-detail">
          <strong>Fix:</strong> {{ currentJob.errorDetail }}
        </div>
      </div>

      <!-- Completed — manifest link -->
      <div v-if="isCompleted" class="completed-panel">
        <a
          :href="manifestUrl"
          class="manifest-link"
          target="_blank"
          rel="noopener noreferrer"
        >
          View manifest.json
          <span class="external-icon">↗</span>
        </a>
      </div>

      <!-- Actions row -->
      <div class="actions-row">
        <!-- Retry button: only shown for FAILED jobs -->
        <button
          v-if="isFailed"
          class="action-btn retry-action"
          :disabled="retrying"
          @click="handleRetry"
        >
          <span v-if="retrying">Retrying…</span>
          <span v-else>Retry Build</span>
        </button>

        <!-- Polling status -->
        <span v-if="isInProgress" class="polling-indicator">
          Auto-refreshing in {{ countdown }}s…
        </span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue';
import type { PackageBuildJobDto, PackageBuildStatus } from '@/types/package-build';
import { packageBuildApi } from '@/api/package-build';

const props = defineProps<{
  courseId: number;
  currentJobId?: string | null;
  authToken: string;
  /** Polling interval in ms (default 10s) */
  pollInterval?: number;
}>();

const emit = defineEmits<{
  (e: 'job-updated', job: PackageBuildJobDto): void;
}>();

const loading = ref(false);
const fetchError = ref<string | null>(null);
const currentJob = ref<PackageBuildJobDto | null>(null);
const retrying = ref(false);
const countdown = ref(10);

let pollTimer: ReturnType<typeof setInterval> | null = null;
let countdownTimer: ReturnType<typeof setInterval> | null = null;

const POLL_MS = computed(() => props.pollInterval ?? 10_000);

// ─── Computed ────────────────────────────────────────────────────────────────

const isInProgress = computed(() =>
  currentJob.value !== null &&
  !['COMPLETED', 'FAILED'].includes(currentJob.value.status)
);

const isCompleted = computed(() => currentJob.value?.status === 'COMPLETED');
const isFailed = computed(() => currentJob.value?.status === 'FAILED');

const badgeClass = computed(() => {
  switch (currentJob.value?.status) {
    case 'COMPLETED':    return 'badge-success';
    case 'FAILED':       return 'badge-error';
    case 'QUEUED':       return 'badge-queued';
    case 'VALIDATING':
    case 'BUILDING':
    case 'ASSEMBLING':
    case 'UPLOADING':
    case 'PUBLISHING':    return 'badge-in-progress';
    default:              return 'badge-unknown';
  }
});

const statusIcon = computed(() => {
  switch (currentJob.value?.status) {
    case 'QUEUED':       return '⏳';
    case 'VALIDATING':   return '🔍';
    case 'BUILDING':     return '🔨';
    case 'ASSEMBLING':   return '📋';
    case 'UPLOADING':    return '☁️';
    case 'PUBLISHING':   return '🌐';
    case 'COMPLETED':    return '✅';
    case 'FAILED':       return '❌';
    default:             return '❓';
  }
});

const statusLabel = computed(() => {
  const labels: Record<PackageBuildStatus, string> = {
    QUEUED:      'Queued',
    VALIDATING:  'Validating…',
    BUILDING:    'Building tiles…',
    ASSEMBLING:  'Assembling files…',
    UPLOADING:   'Uploading…',
    PUBLISHING:  'Publishing to CDN…',
    COMPLETED:   'Completed',
    FAILED:      'Failed',
  };
  return labels[currentJob.value?.status as PackageBuildStatus] ?? 'Unknown';
});

const progressPercent = computed(() => {
  const stageOrder: PackageBuildStatus[] = [
    'QUEUED', 'VALIDATING', 'BUILDING', 'ASSEMBLING', 'UPLOADING', 'PUBLISHING', 'COMPLETED',
  ];
  const status = currentJob.value?.status as PackageBuildStatus | undefined;
  if (!status || !stageOrder.includes(status)) return 0;
  const idx = stageOrder.indexOf(status);
  return Math.round((idx / (stageOrder.length - 1)) * 100);
});

const manifestUrl = computed(() => {
  if (!currentJob.value?.manifestVersion) return '#';
  return `https://cdn.vnptgolf.vn/packages/${props.courseId}/${currentJob.value.manifestVersion}/manifest.json`;
});

// ─── Methods ────────────────────────────────────────────────────────────────

async function loadCurrentJob() {
  if (!props.currentJobId) return;
  loading.value = true;
  fetchError.value = null;
  try {
    currentJob.value = await packageBuildApi.getBuildJob(
      props.courseId,
      props.currentJobId,
      props.authToken
    );
    emit('job-updated', currentJob.value);
  } catch (err: unknown) {
    fetchError.value = (err as { message?: string })?.message ?? 'Failed to load build status';
  } finally {
    loading.value = false;
  }
}

async function handleRetry() {
  if (!currentJob.value) return;
  retrying.value = true;
  try {
    // Get the dataVersionId from the failed job (stored on the job record)
    const job = currentJob.value;
    const triggerResp = await packageBuildApi.triggerBuild(
      props.courseId,
      { dataVersionId: job.dataVersionId, triggeredBy: job.triggeredBy },
      props.authToken
    );
    currentJob.value = await packageBuildApi.getBuildJob(
      props.courseId,
      triggerResp.jobId,
      props.authToken
    );
    emit('job-updated', currentJob.value);
    startPolling();
  } catch (err: unknown) {
    fetchError.value = (err as { message?: string })?.message ?? 'Retry failed';
  } finally {
    retrying.value = false;
  }
}

function startPolling() {
  stopPolling();
  if (!isInProgress.value) return;
  pollTimer = setInterval(loadCurrentJob, POLL_MS.value);
  countdown.value = Math.round(POLL_MS.value / 1000);
  countdownTimer = setInterval(() => {
    countdown.value = Math.max(0, countdown.value - 1);
  }, 1000);
}

function stopPolling() {
  if (pollTimer !== null) { clearInterval(pollTimer); pollTimer = null; }
  if (countdownTimer !== null) { clearInterval(countdownTimer); countdownTimer = null; }
}

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

// ─── Lifecycle ───────────────────────────────────────────────────────────────

onMounted(async () => {
  if (props.currentJobId) {
    await loadCurrentJob();
    if (isInProgress.value) startPolling();
  }
});

onUnmounted(() => {
  stopPolling();
});

// Watch for external jobId changes (e.g., from parent polling)
import { watch } from 'vue';
watch(() => props.currentJobId, async (newId) => {
  if (newId) {
    await loadCurrentJob();
    if (isInProgress.value) startPolling();
    else stopPolling();
  } else {
    currentJob.value = null;
    stopPolling();
  }
});
</script>

<style scoped>
.build-status-panel {
  font-family: system-ui, -apple-system, sans-serif;
  padding: 1rem;
  border-radius: 8px;
  background: #f9fafb;
  border: 1px solid #e5e7eb;
  min-width: 280px;
}

/* Loading skeleton */
.status-skeleton {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}
.skeleton-badge,
.skeleton-meta {
  height: 1.25rem;
  border-radius: 4px;
  background: linear-gradient(90deg, #e5e7eb 25%, #f3f4f6 50%, #e5e7eb 75%);
  background-size: 200% 100%;
  animation: shimmer 1.5s infinite;
}
.skeleton-meta { width: 60%; }
@keyframes shimmer {
  0%   { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}

/* Idle / error */
.status-idle,
.status-error {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  color: #6b7280;
  font-size: 0.875rem;
}
.status-error { color: #dc2626; }
.hint { color: #9ca3af; font-size: 0.75rem; }
.error-icon { font-size: 1rem; }
.retry-btn {
  margin-left: auto;
  padding: 0.25rem 0.75rem;
  border-radius: 4px;
  background: #dc2626;
  color: white;
  border: none;
  cursor: pointer;
  font-size: 0.75rem;
  min-height: 44px; /* Touch target ≥44pt */
  min-width: 44px;
}

/* Status header */
.status-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-bottom: 0.5rem;
}

/* Badges — icon + text, not color alone */
.status-badge {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  padding: 0.25rem 0.625rem;
  border-radius: 9999px;
  font-size: 0.8125rem;
  font-weight: 600;
  border: 1px solid currentColor;
}
.badge-success  { color: #15803d; background: #dcfce7; }
.badge-error    { color: #b91c1c; background: #fee2e2; }
.badge-queued   { color: #1d4ed8; background: #dbeafe; }
.badge-in-progress { color: #92400e; background: #fef3c7; }
.badge-unknown  { color: #6b7280; background: #f3f4f6; }

.badge-icon { font-size: 0.875rem; }

.job-meta {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.75rem;
  color: #6b7280;
}
.manifest-version {
  font-family: monospace;
  background: #f3f4f6;
  padding: 0.1rem 0.35rem;
  border-radius: 3px;
}

/* Progress bar */
.progress-container {
  height: 6px;
  border-radius: 3px;
  background: #e5e7eb;
  overflow: hidden;
  margin-bottom: 0.5rem;
}
.progress-bar {
  height: 100%;
  border-radius: 3px;
  transition: width 0.4s ease;
}
.progress-queued      { background: #60a5fa; }
.progress-validating  { background: #a78bfa; }
.progress-building   { background: #fbbf24; }
.progress-assembling { background: #fb923c; }
.progress-uploading  { background: #38bdf8; }
.progress-publishing  { background: #34d399; }

/* Timing row */
.timing-row {
  display: flex;
  flex-wrap: wrap;
  gap: 1rem;
  font-size: 0.75rem;
  color: #6b7280;
  margin-bottom: 0.5rem;
}
.timing-item {
  display: flex;
  flex-direction: column;
}
.timing-label {
  font-size: 0.6875rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: #9ca3af;
}
.timing-value { color: #374151; }

/* Error panel */
.error-panel {
  background: #fff5f5;
  border: 1px solid #fecaca;
  border-radius: 6px;
  padding: 0.75rem;
  margin-bottom: 0.5rem;
}
.error-summary {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-wrap: wrap;
  margin-bottom: 0.35rem;
}
.error-code-badge {
  font-family: monospace;
  font-size: 0.6875rem;
  background: #fee2e2;
  color: #b91c1c;
  border: 1px solid #fca5a5;
  padding: 0.1rem 0.35rem;
  border-radius: 3px;
}
.error-message { font-size: 0.875rem; font-weight: 600; color: #7f1d1d; }
.error-detail {
  font-size: 0.8125rem;
  color: #991b1b;
  background: #fee2e2;
  padding: 0.5rem;
  border-radius: 4px;
  margin-top: 0.35rem;
}

/* Completed panel */
.completed-panel {
  margin-bottom: 0.5rem;
}
.manifest-link {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  font-size: 0.875rem;
  color: #1d4ed8;
  text-decoration: underline;
  min-height: 44px; /* Touch target */
}
.external-icon { font-size: 0.75em; }

/* Actions */
.actions-row {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  flex-wrap: wrap;
}
.action-btn {
  padding: 0.5rem 1rem;
  border-radius: 6px;
  border: 1px solid currentColor;
  cursor: pointer;
  font-size: 0.875rem;
  font-weight: 500;
  min-height: 44px; /* Touch target ≥44pt */
  min-width: 44px;
}
.retry-action {
  color: #1d4ed8;
  background: #eff6ff;
}
.retry-action:hover:not(:disabled) { background: #dbeafe; }
.retry-action:disabled { opacity: 0.5; cursor: not-allowed; }

.polling-indicator {
  font-size: 0.75rem;
  color: #9ca3af;
  margin-left: auto;
}
</style>
