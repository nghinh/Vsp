<template>
  <div class="correction-queue-table">
    <!-- Loading state -->
    <div v-if="loading" class="loading-state" aria-busy="true" aria-label="Đang tải báo lỗi">
      <div v-for="i in 3" :key="i" class="skeleton-row"></div>
    </div>

    <!-- Error state -->
    <div v-else-if="error" class="error-state" role="alert">
      <span class="error-icon" aria-hidden="true">⚠</span>
      <span>{{ error }}</span>
      <button class="retry-btn" @click="$emit('retry')">Thử lại</button>
    </div>

    <!-- Empty state -->
    <div v-else-if="corrections.length === 0" class="empty-state">
      <span class="empty-icon" aria-hidden="true">📋</span>
      <p class="empty-title">Không có báo lỗi nào.</p>
      <p class="empty-subtitle">Thử đổi bộ lọc hoặc quay lại sau.</p>
    </div>

    <!-- Table -->
    <!-- The reporter column was falling off the right edge: nine columns in a
         panel that does not scroll. Its own scroller keeps the page from
         scrolling sideways while making the last column reachable. -->
    <div v-else class="table-scroll">
      <table class="data-table" role="table" aria-label="Hàng đợi hiệu chỉnh">
      <thead>
        <tr>
          <th scope="col">Trạng thái</th>
          <th scope="col">Sân</th>
          <th scope="col">Hố</th>
          <th scope="col">Loại</th>
          <th scope="col">Độ tin cậy</th>
          <th scope="col">Gửi lúc</th>
          <th scope="col">Người báo</th>
          <th scope="col"><span class="sr-only">Thao tác</span></th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="correction in corrections"
          :key="correction.id"
          class="data-row"
          :class="{ 'row-selected': selectedId === correction.id }"
          @click="$emit('select', correction.id)"
        >
          <td>
            <CorrectionStatusBadge :status="correction.status" />
          </td>
          <td class="cell-course">
            <span class="course-name" :title="correction.courseName">
              {{ correction.courseName || `Course #${correction.courseId}` }}
            </span>
          </td>
          <td class="cell-hole">
            <span v-if="correction.holeNumber != null" class="hole-badge">
              #{{ correction.holeNumber }}
            </span>
            <span v-else class="no-hole">—</span>
          </td>
          <td class="cell-type">{{ formatType(correction.correctionType) }}</td>
          <td class="cell-confidence">
            <span v-if="correction.confidence != null" class="confidence-value">
              {{ correction.confidence.toFixed(0) }}%
            </span>
            <span v-else class="no-confidence">—</span>
          </td>
          <td class="cell-date">{{ formatDate(correction.submittedAt) }}</td>
          <td class="cell-reporter">{{ correction.reporterId }}</td>
          <td class="cell-actions">
            <button
              class="view-btn"
              @click.stop="$emit('select', correction.id)"
              :aria-label="`Xem xét hiệu chỉnh ${correction.id}`"
            >
              Xem xét →
            </button>
          </td>
        </tr>
      </tbody>
      </table>
    </div>
  </div>
</template>

<script setup lang="ts">
import type { CorrectionSummary, CorrectionTypeValue } from '@/types/correction';
import { formatDay } from '@/lib/datetime';
import { correctionTypeLabel } from '@/lib/correction-labels';
import CorrectionStatusBadge from './CorrectionStatusBadge.vue';

withDefaults(defineProps<{
  corrections: CorrectionSummary[];
  loading?: boolean;
  error?: string | null;
  selectedId?: number | null;
}>(), {
  loading: false,
  error: null,
  selectedId: null,
});

defineEmits<{
  (e: 'select', id: number): void;
  (e: 'retry'): void;
}>();

function formatType(type: CorrectionTypeValue): string {
  return correctionTypeLabel(type);
}

function formatDate(iso: string): string {
  return formatDay(iso);
}
</script>

<style scoped>
.correction-queue-table {
  width: 100%;
}

.table-scroll {
  /* See the same rule in styles.css: `position: relative` keeps the `.sr-only`
     span in the last header cell from escaping this scroller and widening the
     page. Repeated here because this scoped rule is the one that wins. */
  position: relative;
  overflow-x: auto;
}
.table-scroll .data-table {
  min-width: 46rem;
}

/* Loading skeleton */
.loading-state { display: flex; flex-direction: column; gap: 0.75rem; padding: 0.5rem 0; }
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

/* Table */
.data-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.8125rem;
}

.data-table thead {
  background: var(--surface-container);
  border-bottom: 1px solid var(--surface-container-highest);
}

.data-table th {
  padding: 0.6rem 0.75rem;
  text-align: left;
  font-size: 0.75rem;
  font-weight: 600;
  color: var(--muted);
  text-transform: uppercase;
  letter-spacing: 0.04em;
  white-space: nowrap;
}

.data-table td {
  padding: 0.75rem 0.75rem;
  border-bottom: 1px solid var(--surface-container-high);
  color: var(--on-surface);
  vertical-align: middle;
}

.data-row {
  cursor: pointer;
  transition: background 0.15s;
}
.data-row:hover { background: var(--surface-container); }
.row-selected { background: var(--surface-container-high) !important; }

.cell-course .course-name {
  font-weight: 500;
  max-width: 14rem;
  display: block;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.hole-badge {
  font-family: monospace;
  font-weight: 600;
  font-size: 0.75rem;
  background: var(--surface-container-high);
  padding: 0.1rem 0.4rem;
  border-radius: 3px;
}

.no-hole,
.no-confidence {
  color: var(--muted);
}

.cell-confidence .confidence-value {
  font-variant-numeric: tabular-nums;
}

.cell-date {
  color: var(--muted);
  font-size: 0.75rem;
  white-space: nowrap;
}

.cell-reporter {
  font-size: 0.75rem;
  color: var(--muted);
  font-variant-numeric: tabular-nums;
}

.cell-actions {
  text-align: right;
}

.view-btn {
  padding: 0.3rem 0.75rem;
  border-radius: 6px;
  border: 1px solid var(--surface-container-highest);
  background: var(--surface-container);
  color: var(--secondary-container);
  font-size: 0.75rem;
  font-weight: 500;
  cursor: pointer;
  min-height: 32px;
  transition: background 0.15s;
}
.view-btn:hover { background: var(--surface-container-high); border-color: var(--surface-container-highest); }

.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border-width: 0;
}
</style>
