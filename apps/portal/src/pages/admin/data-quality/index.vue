<template>
  <div class="dq-page">

    <!-- ─── Page Header ─────────────────────────────────────────────────────── -->
    <header class="page-header">
      <div class="header-content">
        <h1 class="page-title">Data Quality Dashboard</h1>
        <p class="page-subtitle">Monitor geometry completeness, course verification, Class A/B coverage, corrections, and resolution times.</p>
      </div>
    </header>

    <!-- ─── Filter Bar ──────────────────────────────────────────────────────── -->
    <section class="filter-bar" aria-label="Data quality filters">
      <div class="filter-grid">
        <div class="filter-field">
          <label class="filter-label" for="facility-select">Facility</label>
          <select
            id="facility-select"
            v-model="filters.facilityId"
            class="filter-select"
            :disabled="loading"
            @change="onFacilityChange"
          >
            <option :value="undefined">All Facilities</option>
            <option v-for="f in facilities" :key="f.id" :value="f.id">{{ f.name }}</option>
          </select>
        </div>

        <div class="filter-field">
          <label class="filter-label" for="course-select">Course</label>
          <select
            id="course-select"
            v-model="filters.courseId"
            class="filter-select"
            :disabled="loading || !filters.facilityId"
          >
            <option :value="undefined">All Courses</option>
            <option v-for="c in filteredCourses" :key="c.id" :value="c.id">{{ c.name }}</option>
          </select>
        </div>

        <div class="filter-field">
          <label class="filter-label" for="date-from">From</label>
          <input
            id="date-from"
            v-model="filters.from"
            type="date"
            class="filter-input"
            :disabled="loading"
            :max="filters.to"
          />
        </div>

        <div class="filter-field">
          <label class="filter-label" for="date-to">To</label>
          <input
            id="date-to"
            v-model="filters.to"
            type="date"
            class="filter-input"
            :disabled="loading"
            :min="filters.from"
          />
        </div>

        <div class="filter-actions">
          <button
            class="btn btn-primary"
            :disabled="loading || !filters.from || !filters.to"
            @click="applyFilters"
          >
            {{ loading ? 'Loading…' : 'Apply Filters' }}
          </button>
          <button
            class="btn btn-secondary"
            :disabled="loading"
            @click="resetFilters"
          >
            Reset
          </button>
        </div>
      </div>
    </section>

    <!-- ─── Metric Cards ────────────────────────────────────────────────────── -->
    <section v-if="metrics" class="metrics-grid" aria-label="Data quality metrics">
      <div class="metric-card" :class="cardStatus(metrics.geometryCompleteness, 80)">
        <div class="metric-icon" aria-hidden="true">📐</div>
        <div class="metric-body">
          <span class="metric-label">Geometry Completeness</span>
          <span class="metric-value">
            <template v-if="metrics !== null">{{ fmtPct(metrics.geometryCompleteness) }}</template>
            <template v-else>—</template>
          </span>
          <span class="metric-sub">% of holes with all required layers</span>
        </div>
      </div>

      <div class="metric-card" :class="cardStatus(metrics.verifiedCoursesCount, 1)">
        <div class="metric-icon" aria-hidden="true">✓</div>
        <div class="metric-body">
          <span class="metric-label">Verified Courses</span>
          <span class="metric-value">
            <template v-if="metrics !== null">{{ metrics.verifiedCoursesCount }}<span class="metric-total"> / {{ metrics.totalCoursesCount }}</span></template>
            <template v-else>—</template>
          </span>
          <span class="metric-sub">published + verified courses</span>
        </div>
      </div>

      <div class="metric-card" :class="cardStatus(metrics.classABCoverage, 80)">
        <div class="metric-icon" aria-hidden="true">🏅</div>
        <div class="metric-body">
          <span class="metric-label">Class A/B Coverage</span>
          <span class="metric-value">
            <template v-if="metrics !== null">{{ fmtPct(metrics.classABCoverage) }}</template>
            <template v-else>—</template>
          </span>
          <span class="metric-sub">% of courses with accuracy class A or B</span>
        </div>
      </div>

      <div class="metric-card metric-card--neutral">
        <div class="metric-icon" aria-hidden="true">🔧</div>
        <div class="metric-body">
          <span class="metric-label">Correction Volume</span>
          <span class="metric-value">
            <template v-if="metrics !== null">{{ metrics.correctionVolume }}</template>
            <template v-else>—</template>
          </span>
          <span class="metric-sub">corrections in selected period</span>
        </div>
      </div>

      <div class="metric-card" :class="cardStatus(metrics.avgResolutionTimeHours, 48, true)">
        <div class="metric-icon" aria-hidden="true">⏱</div>
        <div class="metric-body">
          <span class="metric-label">Avg Resolution Time</span>
          <span class="metric-value">
            <template v-if="metrics !== null && metrics.avgResolutionTimeHours !== null">{{ fmtHours(metrics.avgResolutionTimeHours) }}</template>
            <template v-else-if="metrics !== null">pending</template>
            <template v-else>—</template>
          </span>
          <span class="metric-sub">avg · median: {{ fmtHours(metrics?.medianResolutionTimeHours ?? null) }}</span>
        </div>
      </div>
    </section>

    <!-- ─── Actions Row ──────────────────────────────────────────────────────── -->
    <div class="actions-row">
      <button
        class="btn btn-export"
        :disabled="loading || !metrics"
        @click="handleExport"
        aria-label="Export data quality report as CSV"
      >
        {{ exporting ? 'Exporting…' : 'Export CSV' }}
      </button>
    </div>

    <!-- ─── Loading ─────────────────────────────────────────────────────────── -->
    <div v-if="loading" class="loading-state" aria-busy="true" aria-label="Loading data quality metrics">
      <div v-for="i in 5" :key="i" class="skeleton-card" />
    </div>

    <!-- ─── Error ───────────────────────────────────────────────────────────── -->
    <div v-else-if="fetchError" class="error-state" role="alert">
      <span class="error-icon" aria-hidden="true">⚠</span>
      <span>{{ fetchError }}</span>
      <button class="btn btn-secondary" @click="applyFilters">Retry</button>
    </div>

    <!-- ─── Stale Records ───────────────────────────────────────────────────── -->
    <section v-if="!loading && !fetchError" class="stale-section" aria-labelledby="stale-heading">
      <header class="stale-header">
        <h2 id="stale-heading" class="section-title">Stale Records</h2>
        <span v-if="staleRecords.length > 0" class="stale-count" aria-live="polite">
          {{ staleRecords.length }} record{{ staleRecords.length !== 1 ? 's' : '' }} flagged
        </span>
      </header>

      <!-- Empty stale state -->
      <div v-if="staleRecords.length === 0" class="empty-stale">
        <span class="empty-icon" aria-hidden="true">✅</span>
        <p class="empty-title">No stale records</p>
        <p class="empty-subtitle">All pin positions, green speeds, and course conditions are current.</p>
      </div>

      <!-- Stale records table -->
      <div v-else class="table-wrapper" role="region" aria-label="Stale records table" tabindex="0">
        <table class="stale-table" aria-describedby="stale-heading">
          <thead>
            <tr>
              <th scope="col">Type</th>
              <th scope="col">Facility</th>
              <th scope="col">Course</th>
              <th scope="col">Hole</th>
              <th scope="col">Expired At</th>
              <th scope="col">Severity</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="record in staleRecords" :key="`${record.recordType}-${record.recordId}`">
              <td>
                <span class="record-type-badge" :class="`badge-${record.recordType.toLowerCase()}`">
                  {{ record.recordType.replace('_', ' ') }}
                </span>
              </td>
              <td>{{ record.facilityName }}</td>
              <td>{{ record.courseName ?? '—' }}</td>
              <td>{{ record.holeNumber ?? '—' }}</td>
              <td>{{ formatInstant(record.expiredAt) }}</td>
              <td>
                <span class="severity-badge" :class="`severity-${record.severity.toLowerCase()}`">
                  {{ record.severity }}
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue';
import type { DataQualityMetrics, StaleRecord, FacilityOption, CourseOption } from '@/types/admin/data-quality';
import { dataQualityAdminApi } from '@/api/admin/data-quality';
import { facilityAdminApi } from '@/api/admin/facilities';

// ─── Auth (passed via route or context; fallback to env token for demo) ────────
const DEMO_TOKEN = import.meta.env.VITE_AUTH_TOKEN ?? '';
const props = defineProps<{ authToken?: string }>();
const token = computed(() => props.authToken ?? DEMO_TOKEN);

// ─── State ────────────────────────────────────────────────────────────────────
const loading = ref(false);
const exporting = ref(false);
const fetchError = ref<string | null>(null);

const metrics = ref<DataQualityMetrics | null>(null);
const staleRecords = ref<StaleRecord[]>([]);

const facilities = ref<FacilityOption[]>([]);
const courses = ref<CourseOption[]>([]);

const today = new Date();
const thirtyDaysAgo = new Date(today);
thirtyDaysAgo.setDate(today.getDate() - 30);
const toDate = today.toISOString().split('T')[0];
const fromDate = thirtyDaysAgo.toISOString().split('T')[0];

const filters = reactive({
  facilityId: undefined as number | undefined,
  courseId: undefined as number | undefined,
  from: fromDate,
  to: toDate,
});

// ─── Computed ──────────────────────────────────────────────────────────────────
const filteredCourses = computed(() =>
  filters.facilityId
    ? courses.value.filter(c => c.facilityId === filters.facilityId)
    : courses.value
);

// ─── Helpers ───────────────────────────────────────────────────────────────────
function fmtPct(value: number | null): string {
  if (value == null) return '—';
  return `${Number(value).toFixed(1)}%`;
}

function fmtHours(value: number | null): string {
  if (value == null) return '—';
  if (value < 1) return `${Math.round(value * 60)}m`;
  if (value < 24) return `${Number(value).toFixed(1)}h`;
  return `${(value / 24).toFixed(1)}d`;
}

function formatInstant(iso: string | null): string {
  if (!iso) return '—';
  return new Date(iso).toLocaleString();
}

/**
 * Returns a status class for a metric card.
 * @param value - metric value (percentage or count)
 * @param threshold - green threshold
 * @param inverse - if true, lower is worse (e.g., resolution time)
 */
function cardStatus(value: number | null, threshold: number, inverse = false): string {
  if (value == null) return 'metric-card--neutral';
  if (inverse) {
    if (value <= threshold * 0.5) return 'metric-card--good';
    if (value <= threshold) return 'metric-card--warn';
    return 'metric-card--bad';
  }
  if (value >= threshold) return 'metric-card--good';
  if (value >= threshold * 0.6) return 'metric-card--warn';
  return 'metric-card--bad';
}

// ─── Load facilities & courses for filter dropdowns ────────────────────────────
async function loadFacilities() {
  try {
    const data = await facilityAdminApi.listFacilities(token.value);
    facilities.value = data.map((f: { id: number; name: string }) => ({ id: f.id, name: f.name }));
  } catch {
    facilities.value = [];
  }
}

async function loadCourses() {
  // Courses are loaded implicitly when a facility is selected.
  // For a full implementation, add a courses API endpoint.
  courses.value = [];
}

// ─── Fetch ─────────────────────────────────────────────────────────────────────
async function applyFilters() {
  if (!filters.from || !filters.to) {
    fetchError.value = 'Please select both From and To dates.';
    return;
  }
  if (filters.from > filters.to) {
    fetchError.value = 'From date must be before or equal to To date.';
    return;
  }

  loading.value = true;
  fetchError.value = null;

  try {
    const query = {
      facilityId: filters.facilityId,
      courseId: filters.courseId,
      from: filters.from,
      to: filters.to,
    };

    const [metricsData, staleData] = await Promise.all([
      dataQualityAdminApi.getMetrics(query, token.value),
      dataQualityAdminApi.getStaleRecords(filters.facilityId, filters.courseId, token.value),
    ]);

    metrics.value = metricsData;
    staleRecords.value = staleData;
  } catch (err: unknown) {
    const apiErr = err as { message?: string };
    fetchError.value = apiErr?.message ?? 'Failed to load data quality metrics.';
  } finally {
    loading.value = false;
  }
}

function resetFilters() {
  filters.facilityId = undefined;
  filters.courseId = undefined;
  filters.from = fromDate;
  filters.to = toDate;
  metrics.value = null;
  staleRecords.value = [];
  fetchError.value = null;
}

function onFacilityChange() {
  filters.courseId = undefined;
}

// ─── Export ────────────────────────────────────────────────────────────────────
async function handleExport() {
  if (!filters.from || !filters.to) return;
  exporting.value = true;
  try {
    const csv = await dataQualityAdminApi.exportDataQuality(
      {
        facilityId: filters.facilityId,
        courseId: filters.courseId,
        from: filters.from,
        to: filters.to,
      },
      'csv',
      token.value
    );

    // Trigger browser download
    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `data-quality-${filters.from}-to-${filters.to}.csv`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  } catch (err: unknown) {
    const apiErr = err as { message?: string };
    fetchError.value = apiErr?.message ?? 'Failed to export data.';
  } finally {
    exporting.value = false;
  }
}

// ─── Lifecycle ─────────────────────────────────────────────────────────────────
onMounted(async () => {
  await Promise.all([loadFacilities(), loadCourses()]);
  // Auto-load with default date range
  await applyFilters();
});
</script>

<style scoped>
/* ─── Page ────────────────────────────────────────────────────────────────────── */
.dq-page {
  font-family: system-ui, -apple-system, sans-serif;
  padding: 1.5rem;
  max-width: 1200px;
  margin: 0 auto;
}

/* ─── Header ──────────────────────────────────────────────────────────────────── */
.page-header {
  margin-bottom: 1.5rem;
  border-bottom: 1px solid #e5e7eb;
  padding-bottom: 1rem;
}
.page-title {
  font-size: 1.5rem;
  font-weight: 700;
  color: #111827;
  margin: 0;
}
.page-subtitle {
  font-size: 0.875rem;
  color: #6b7280;
  margin: 0.25rem 0 0;
}

/* ─── Filter Bar ─────────────────────────────────────────────────────────────── */
.filter-bar {
  background: #f9fafb;
  border: 1px solid #e5e7eb;
  border-radius: 10px;
  padding: 1rem 1.25rem;
  margin-bottom: 1.5rem;
}
.filter-grid {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr 1fr auto;
  gap: 0.75rem;
  align-items: end;
}
.filter-field {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}
.filter-label {
  font-size: 0.8125rem;
  font-weight: 600;
  color: #374151;
}
.filter-select,
.filter-input {
  padding: 0.5rem 0.75rem;
  border: 1px solid #d1d5db;
  border-radius: 6px;
  font-size: 0.875rem;
  min-height: 44px;
  background: white;
  color: #111827;
}
.filter-select:focus,
.filter-input:focus {
  outline: none;
  border-color: #2563eb;
  box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.1);
}
.filter-select:disabled,
.filter-input:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
.filter-actions {
  display: flex;
  gap: 0.5rem;
}

/* ─── Buttons ────────────────────────────────────────────────────────────────── */
.btn {
  padding: 0.5rem 1rem;
  border-radius: 6px;
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  border: 1px solid transparent;
  min-height: 44px;
  transition: background 0.15s;
}
.btn-primary {
  background: #2563eb;
  color: white;
  border-color: #2563eb;
}
.btn-primary:hover:not(:disabled) { background: #1d4ed8; }
.btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
.btn-secondary {
  background: white;
  color: #374151;
  border-color: #d1d5db;
}
.btn-secondary:hover:not(:disabled) { background: #f9fafb; }
.btn-secondary:disabled { opacity: 0.5; cursor: not-allowed; }
.btn-export {
  background: #059669;
  color: white;
  border-color: #059669;
  font-weight: 600;
}
.btn-export:hover:not(:disabled) { background: #047857; }
.btn-export:disabled { opacity: 0.5; cursor: not-allowed; }

/* ─── Metric Cards ────────────────────────────────────────────────────────────── */
.metrics-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: 1rem;
  margin-bottom: 1.5rem;
}
.metric-card {
  display: flex;
  align-items: flex-start;
  gap: 0.75rem;
  background: white;
  border: 1px solid #e5e7eb;
  border-radius: 10px;
  padding: 1rem;
  transition: border-color 0.15s;
}
.metric-icon {
  font-size: 1.5rem;
  line-height: 1;
  flex-shrink: 0;
}
.metric-body {
  display: flex;
  flex-direction: column;
  gap: 0.125rem;
}
.metric-label {
  font-size: 0.75rem;
  font-weight: 600;
  color: #6b7280;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}
.metric-value {
  font-size: 1.5rem;
  font-weight: 700;
  color: #111827;
  line-height: 1.2;
}
.metric-total {
  font-size: 1rem;
  font-weight: 400;
  color: #6b7280;
}
.metric-sub {
  font-size: 0.6875rem;
  color: #9ca3af;
  margin-top: 0.125rem;
}

/* Card status colors — meet 4.5:1 contrast on white background */
.metric-card--good    { border-color: #15803d; background: #f0fdf4; }
.metric-card--warn    { border-color: #b45309; background: #fffbeb; }
.metric-card--bad     { border-color: #dc2626; background: #fef2f2; }
.metric-card--neutral { border-color: #e5e7eb; }

/* ─── Actions Row ─────────────────────────────────────────────────────────────── */
.actions-row {
  display: flex;
  justify-content: flex-end;
  margin-bottom: 1.5rem;
}

/* ─── Loading ─────────────────────────────────────────────────────────────────── */
.loading-state {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: 1rem;
  margin-bottom: 1.5rem;
}
.skeleton-card {
  height: 5rem;
  border-radius: 8px;
  background: linear-gradient(90deg, #e5e7eb 25%, #f3f4f6 50%, #e5e7eb 75%);
  background-size: 200% 100%;
  animation: shimmer 1.5s infinite;
}
@keyframes shimmer {
  0%   { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}

/* ─── Error ──────────────────────────────────────────────────────────────────── */
.error-state,
.empty-stale {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.5rem;
  padding: 2rem 1rem;
  color: #6b7280;
  text-align: center;
  border-radius: 10px;
  border: 1px solid #e5e7eb;
  background: #f9fafb;
  margin-bottom: 1.5rem;
}
.error-state { color: #dc2626; border-color: #fca5a5; background: #fef2f2; }
.empty-icon, .error-icon { font-size: 2rem; }
.empty-title { font-size: 1.125rem; font-weight: 600; margin: 0; color: #374151; }
.empty-subtitle { font-size: 0.875rem; color: #9ca3af; margin: 0; }

/* ─── Stale Records ─────────────────────────────────────────────────────────── */
.stale-section { margin-top: 1rem; }
.stale-header {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 0.75rem;
}
.section-title {
  font-size: 1.125rem;
  font-weight: 700;
  color: #111827;
  margin: 0;
}
.stale-count {
  font-size: 0.8125rem;
  font-weight: 600;
  color: #dc2626;
  background: #fef2f2;
  border: 1px solid #fca5a5;
  border-radius: 9999px;
  padding: 0.15rem 0.6rem;
}

.table-wrapper {
  overflow-x: auto;
  border: 1px solid #e5e7eb;
  border-radius: 10px;
  background: white;
}
.table-wrapper:focus {
  outline: 2px solid #2563eb;
  outline-offset: 2px;
}
.stale-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.875rem;
}
.stale-table th {
  text-align: left;
  font-size: 0.75rem;
  font-weight: 600;
  color: #6b7280;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  padding: 0.75rem 1rem;
  border-bottom: 2px solid #e5e7eb;
  background: #f9fafb;
}
.stale-table td {
  padding: 0.75rem 1rem;
  border-bottom: 1px solid #f3f4f6;
  color: #374151;
  vertical-align: middle;
  min-height: 44px;
}
.stale-table tr:last-child td { border-bottom: none; }
.stale-table tr:hover td { background: #f9fafb; }

/* ─── Badges ─────────────────────────────────────────────────────────────────── */
.record-type-badge {
  display: inline-block;
  font-size: 0.6875rem;
  font-weight: 700;
  padding: 0.2rem 0.5rem;
  border-radius: 4px;
  border: 1px solid currentColor;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  min-height: 24px;
  line-height: 1.4;
}
.badge-pin            { color: #1d4ed8; background: #eff6ff; }
.badge-green_speed    { color: #047857; background: #ecfdf5; }
.badge-course_condition { color: #7c3aed; background: #f5f3ff; }

.severity-badge {
  display: inline-block;
  font-size: 0.6875rem;
  font-weight: 700;
  padding: 0.2rem 0.5rem;
  border-radius: 9999px;
  border: 1px solid currentColor;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  min-height: 24px;
  line-height: 1.4;
}
.severity-low       { color: #15803d; background: #f0fdf4; }
.severity-moderate  { color: #b45309; background: #fffbeb; }
.severity-high      { color: #c2410c; background: #fff7ed; }
.severity-critical  { color: #dc2626; background: #fef2f2; }

/* ─── Reduced Motion ─────────────────────────────────────────────────────────── */
@media (prefers-reduced-motion: reduce) {
  .skeleton-card { animation: none; }
  .btn, .metric-card { transition: none; }
}
</style>
