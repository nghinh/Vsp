<template>
  <div class="correction-queue-table">
    <!-- Loading state -->
    <div v-if="loading" class="loading-state" aria-busy="true" aria-label="Loading corrections">
      <div v-for="i in 3" :key="i" class="skeleton-row"></div>
    </div>

    <!-- Error state -->
    <div v-else-if="error" class="error-state" role="alert">
      <span class="error-icon" aria-hidden="true">⚠</span>
      <span>{{ error }}</span>
      <button class="retry-btn" @click="$emit('retry')">Retry</button>
    </div>

    <!-- Empty state -->
    <div v-else-if="corrections.length === 0" class="empty-state">
      <span class="empty-icon" aria-hidden="true">📋</span>
      <p class="empty-title">No corrections found.</p>
      <p class="empty-subtitle">Try adjusting your filters or check back later.</p>
    </div>

    <!-- Table -->
    <table v-else class="data-table" role="table" aria-label="Correction queue">
      <thead>
        <tr>
          <th scope="col">Status</th>
          <th scope="col">Course</th>
          <th scope="col">Hole</th>
          <th scope="col">Type</th>
          <th scope="col">Confidence</th>
          <th scope="col">Submitted</th>
          <th scope="col">Reporter</th>
          <th scope="col"><span class="sr-only">Actions</span></th>
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
              :aria-label="`Review correction ${correction.id}`"
            >
              Review →
            </button>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<script setup lang="ts">
import type { CorrectionSummary, CorrectionTypeValue } from '@/types/correction';
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
  const labels: Record<CorrectionTypeValue, string> = {
    GEOMETRY:          'Geometry',
    PIN_POSITION:      'Pin Position',
    BUNKER:            'Bunker',
    WATER:             'Water',
    OB:                'Out of Bounds',
    CART_PATH:         'Cart Path',
    LANDMARK:          'Landmark',
    COURSE_CONDITION:  'Course Condition',
    GREEN_SPEED:       'Green Speed',
    OTHER:             'Other',
  };
  return labels[type] ?? type;
}

function formatDate(iso: string): string {
  if (!iso) return '—';
  return new Date(iso).toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
}
</script>

<style scoped>
.correction-queue-table {
  width: 100%;
}

/* Loading skeleton */
.loading-state { display: flex; flex-direction: column; gap: 0.75rem; padding: 0.5rem 0; }
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

/* Table */
.data-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.8125rem;
}

.data-table thead {
  background: #171f33;
  border-bottom: 1px solid #2d3449;
}

.data-table th {
  padding: 0.6rem 0.75rem;
  text-align: left;
  font-size: 0.75rem;
  font-weight: 600;
  color: #97a2c0;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  white-space: nowrap;
}

.data-table td {
  padding: 0.75rem 0.75rem;
  border-bottom: 1px solid #222a3d;
  color: #dae2fd;
  vertical-align: middle;
}

.data-row {
  cursor: pointer;
  transition: background 0.15s;
}
.data-row:hover { background: #171f33; }
.row-selected { background: #222a3d !important; }

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
  background: #222a3d;
  padding: 0.1rem 0.4rem;
  border-radius: 3px;
}

.no-hole,
.no-confidence {
  color: #97a2c0;
}

.cell-confidence .confidence-value {
  font-variant-numeric: tabular-nums;
}

.cell-date {
  color: #97a2c0;
  font-size: 0.75rem;
  white-space: nowrap;
}

.cell-reporter {
  font-size: 0.75rem;
  color: #97a2c0;
  font-variant-numeric: tabular-nums;
}

.cell-actions {
  text-align: right;
}

.view-btn {
  padding: 0.3rem 0.75rem;
  border-radius: 6px;
  border: 1px solid #2d3449;
  background: #171f33;
  color: #ec6a06;
  font-size: 0.75rem;
  font-weight: 500;
  cursor: pointer;
  min-height: 32px;
  transition: background 0.15s;
}
.view-btn:hover { background: #222a3d; border-color: #2d3449; }

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
