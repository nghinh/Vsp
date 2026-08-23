<template>
  <div class="dq-page">

    <!-- ─── Page Header ─────────────────────────────────────────────────────── -->
    <header class="page-header">
      <div class="header-content">
        <h1 class="page-title">Bảng chất lượng dữ liệu</h1>
        <p class="page-subtitle">Theo dõi độ đầy đủ hình học, mức xác minh sân, tỷ lệ hạng A/B, lượng hiệu chỉnh và thời gian xử lý.</p>
      </div>
    </header>

    <!-- ─── Filter Bar ──────────────────────────────────────────────────────── -->
    <section class="filter-bar" aria-label="Bộ lọc chất lượng dữ liệu">
      <div class="filter-grid">
        <div class="filter-field">
          <label class="filter-label" for="facility-select">Cơ sở</label>
          <select
            id="facility-select"
            v-model="filters.facilityId"
            class="filter-select"
            :disabled="loading"
            @change="onFacilityChange"
          >
            <option :value="undefined">Tất cả cơ sở</option>
            <option v-for="f in facilities" :key="f.id" :value="f.id">{{ f.name }}</option>
          </select>
        </div>

        <div class="filter-field">
          <label class="filter-label" for="course-select">Sân</label>
          <select
            id="course-select"
            v-model="filters.courseId"
            class="filter-select"
            :disabled="loading || !filters.facilityId"
          >
            <option :value="undefined">Tất cả sân</option>
            <option v-for="c in filteredCourses" :key="c.id" :value="c.id">{{ c.name }}</option>
          </select>
        </div>

        <div class="filter-field">
          <label class="filter-label" for="date-from">Từ</label>
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
          <label class="filter-label" for="date-to">Đến</label>
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
            {{ loading ? 'Đang tải…' : 'Áp dụng' }}
          </button>
          <button
            class="btn btn-secondary"
            :disabled="loading"
            @click="resetFilters"
          >
            Đặt lại
          </button>
        </div>
      </div>
    </section>

    <!-- ─── Metric Cards ────────────────────────────────────────────────────── -->
    <section v-if="metrics" class="metrics-grid" aria-label="Chỉ số chất lượng dữ liệu">
      <div class="metric-card" :class="cardStatus(metrics.geometryCompleteness, 80)">
        <div class="metric-icon" aria-hidden="true">📐</div>
        <div class="metric-body">
          <span class="metric-label">Độ đầy đủ hình học</span>
          <span class="metric-value">
            <template v-if="metrics !== null">{{ fmtPct(metrics.geometryCompleteness) }}</template>
            <template v-else>—</template>
          </span>
          <span class="metric-sub">% số hố có đủ các lớp bắt buộc</span>
        </div>
      </div>

      <div class="metric-card" :class="cardStatus(metrics.verifiedCoursesCount, 1)">
        <div class="metric-icon" aria-hidden="true">✓</div>
        <div class="metric-body">
          <span class="metric-label">Sân đã xác minh</span>
          <span class="metric-value">
            <template v-if="metrics !== null">{{ metrics.verifiedCoursesCount }}<span class="metric-total"> / {{ metrics.totalCoursesCount }}</span></template>
            <template v-else>—</template>
          </span>
          <span class="metric-sub">sân đã publish và đã xác minh</span>
        </div>
      </div>

      <div class="metric-card" :class="cardStatus(metrics.classABCoverage, 80)">
        <div class="metric-icon" aria-hidden="true">🏅</div>
        <div class="metric-body">
          <span class="metric-label">Tỷ lệ hạng A/B</span>
          <span class="metric-value">
            <template v-if="metrics !== null">{{ fmtPct(metrics.classABCoverage) }}</template>
            <template v-else>—</template>
          </span>
          <span class="metric-sub">% sân đạt hạng độ chính xác A hoặc B</span>
        </div>
      </div>

      <div class="metric-card metric-card--neutral">
        <div class="metric-icon" aria-hidden="true">🔧</div>
        <div class="metric-body">
          <span class="metric-label">Lượng hiệu chỉnh</span>
          <span class="metric-value">
            <template v-if="metrics !== null">{{ metrics.correctionVolume }}</template>
            <template v-else>—</template>
          </span>
          <span class="metric-sub">lượt hiệu chỉnh trong kỳ đã chọn</span>
        </div>
      </div>

      <div class="metric-card" :class="cardStatus(metrics.avgResolutionTimeHours, 48, true)">
        <div class="metric-icon" aria-hidden="true">⏱</div>
        <div class="metric-body">
          <span class="metric-label">Thời gian xử lý trung bình</span>
          <span class="metric-value">
            <template v-if="metrics !== null && metrics.avgResolutionTimeHours !== null">{{ fmtHours(metrics.avgResolutionTimeHours) }}</template>
            <template v-else-if="metrics !== null">chưa có</template>
            <template v-else>—</template>
          </span>
          <span class="metric-sub">trung bình · trung vị: {{ fmtHours(metrics?.medianResolutionTimeHours ?? null) }}</span>
        </div>
      </div>
    </section>

    <!-- ─── Actions Row ──────────────────────────────────────────────────────── -->
    <div class="actions-row">
      <button
        class="btn btn-export"
        :disabled="loading || !metrics"
        @click="handleExport"
        aria-label="Xuất báo cáo chất lượng dữ liệu ra CSV"
      >
        {{ exporting ? 'Đang xuất…' : 'Xuất CSV' }}
      </button>
    </div>

    <!-- ─── Loading ─────────────────────────────────────────────────────────── -->
    <div v-if="loading" class="loading-state" aria-busy="true" aria-label="Đang tải chỉ số chất lượng dữ liệu">
      <div v-for="i in 5" :key="i" class="skeleton-card" />
    </div>

    <!-- ─── Error ───────────────────────────────────────────────────────────── -->
    <div v-else-if="fetchError" class="error-state" role="alert">
      <span class="error-icon" aria-hidden="true">⚠</span>
      <span>{{ fetchError }}</span>
      <button class="btn btn-secondary" @click="applyFilters">Thử lại</button>
    </div>

    <!-- ─── Stale Records ───────────────────────────────────────────────────── -->
    <section v-if="!loading && !fetchError" class="stale-section" aria-labelledby="stale-heading">
      <header class="stale-header">
        <h2 id="stale-heading" class="section-title">Dữ liệu quá hạn</h2>
        <span v-if="staleRecords.length > 0" class="stale-count" aria-live="polite">
          {{ staleRecords.length }} bản ghi bị đánh dấu
        </span>
      </header>

      <!-- Empty stale state -->
      <div v-if="staleRecords.length === 0" class="empty-stale">
        <span class="empty-icon" aria-hidden="true">✅</span>
        <p class="empty-title">Không có dữ liệu quá hạn</p>
        <p class="empty-subtitle">Mọi vị trí cắm cờ, tốc độ green và tình trạng sân đều còn hiệu lực.</p>
      </div>

      <!-- Stale records table -->
      <div v-else class="table-wrapper" role="region" aria-label="Bảng dữ liệu quá hạn" tabindex="0">
        <table class="stale-table" aria-describedby="stale-heading">
          <thead>
            <tr>
              <th scope="col">Loại</th>
              <th scope="col">Cơ sở</th>
              <th scope="col">Sân</th>
              <th scope="col">Hố</th>
              <th scope="col">Hết hạn lúc</th>
              <th scope="col">Mức độ</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="record in staleRecords" :key="`${record.recordType}-${record.recordId}`">
              <td>
                <span class="record-type-badge" :class="`badge-${record.recordType.toLowerCase()}`">
                  {{ recordTypeLabel(record.recordType) }}
                </span>
              </td>
              <td>{{ record.facilityName }}</td>
              <td>{{ record.courseName ?? '—' }}</td>
              <td>{{ record.holeNumber ?? '—' }}</td>
              <td>{{ formatInstant(record.expiredAt) }}</td>
              <td>
                <span class="severity-badge" :class="`severity-${record.severity.toLowerCase()}`">
                  {{ severityLabel(record.severity) }}
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
import { recordTypeLabel, severityLabel } from '@/lib/enum-labels';
import { ref, reactive, computed, onMounted } from 'vue';
import { formatInstant } from '@/lib/datetime';
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

// Units in Vietnamese, because they are read as words rather than symbols:
// "1.9 ngày", not "1.9d". A guard over template text cannot catch this one —
// the string is built here and only ever exists at runtime.
function fmtHours(value: number | null): string {
  if (value == null) return '—';
  if (value < 1) return `${Math.round(value * 60)} phút`;
  if (value < 24) return `${Number(value).toFixed(1)} giờ`;
  return `${(value / 24).toFixed(1)} ngày`;
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
    fetchError.value = 'Hãy chọn cả ngày Từ và ngày Đến.';
    return;
  }
  if (filters.from > filters.to) {
    fetchError.value = 'Ngày Từ phải trước hoặc bằng ngày Đến.';
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
    fetchError.value = apiErr?.message ?? 'Không tải được chỉ số chất lượng dữ liệu.';
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
    fetchError.value = apiErr?.message ?? 'Không xuất được dữ liệu.';
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
  border-bottom: 1px solid var(--surface-container-highest);
  padding-bottom: 1rem;
}
.page-title {
  font-size: 1.5rem;
  font-weight: 700;
  color: var(--on-surface);
  margin: 0;
}
.page-subtitle {
  font-size: 0.875rem;
  color: var(--muted);
  margin: 0.25rem 0 0;
}

/* ─── Filter Bar ─────────────────────────────────────────────────────────────── */
.filter-bar {
  background: var(--surface-container);
  border: 1px solid var(--surface-container-highest);
  border-radius: 10px;
  padding: 1rem 1.25rem;
  margin-bottom: 1.5rem;
}
.filter-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
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
  color: #c5cde8;
}
.filter-select,
.filter-input {
  padding: 0.5rem 0.75rem;
  border: 1px solid var(--surface-container-highest);
  border-radius: 6px;
  font-size: 0.875rem;
  min-height: 44px;
  background: var(--surface-container);
  color: var(--on-surface);
}
.filter-select:focus,
.filter-input:focus {
  outline: none;
  border-color: var(--primary-container);
  box-shadow: 0 0 0 3px rgba(246, 96, 24, 0.1);
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
.filter-actions .btn { flex: 1 1 auto; }

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
  background: var(--primary-container);
  color: white;
  border-color: var(--primary-container);
}
.btn-primary:hover:not(:disabled) { background: var(--secondary-container); }
.btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
.btn-secondary {
  background: var(--surface-container);
  color: #c5cde8;
  border-color: var(--surface-container-highest);
}
.btn-secondary:hover:not(:disabled) { background: var(--surface-container); }
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
  background: var(--surface-container);
  border: 1px solid var(--surface-container-highest);
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
  color: var(--muted);
  text-transform: uppercase;
  letter-spacing: 0.05em;
}
.metric-value {
  font-size: 1.5rem;
  font-weight: 700;
  color: var(--on-surface);
  line-height: 1.2;
}
.metric-total {
  font-size: 1rem;
  font-weight: 400;
  color: var(--muted);
}
.metric-sub {
  font-size: 0.6875rem;
  color: var(--muted);
  margin-top: 0.125rem;
}

/* Card status colours. These were light-theme fills (#f0fdf4, #fef2f2) left
   over from before the dark palette, which put the card's light text on a
   near-white background: the KPI numbers were unreadable. A tint of the status
   colour over the dark surface keeps the signal and the contrast. */
.metric-card--good    { border-color: var(--tertiary-container); background: rgba(37, 164, 117, 0.14); }
.metric-card--warn    { border-color: #d97706; background: rgba(217, 119, 6, 0.14); }
.metric-card--bad     { border-color: #ef4444; background: rgba(239, 68, 68, 0.14); }
.metric-card--neutral { border-color: var(--surface-container-highest); }

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
  background: linear-gradient(90deg, var(--surface-container-highest) 25%, var(--surface-container-high) 50%, var(--surface-container-highest) 75%);
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
  color: var(--muted);
  text-align: center;
  border-radius: 10px;
  border: 1px solid var(--surface-container-highest);
  background: var(--surface-container);
  margin-bottom: 1.5rem;
}
.error-state { color: #dc2626; border-color: #fca5a5; background: #fef2f2; }
.empty-icon, .error-icon { font-size: 2rem; }
.empty-title { font-size: 1.125rem; font-weight: 600; margin: 0; color: #c5cde8; }
.empty-subtitle { font-size: 0.875rem; color: var(--muted); margin: 0; }

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
  color: var(--on-surface);
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
  border: 1px solid var(--surface-container-highest);
  border-radius: 10px;
  background: var(--surface-container);
}
.table-wrapper:focus {
  outline: 2px solid var(--primary-container);
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
  color: var(--muted);
  text-transform: uppercase;
  letter-spacing: 0.05em;
  padding: 0.75rem 1rem;
  border-bottom: 2px solid var(--surface-container-highest);
  background: var(--surface-container);
}
.stale-table td {
  padding: 0.75rem 1rem;
  border-bottom: 1px solid var(--surface-container-high);
  color: #c5cde8;
  vertical-align: middle;
  min-height: 44px;
}
.stale-table tr:last-child td { border-bottom: none; }
.stale-table tr:hover td { background: var(--surface-container); }

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
.badge-pin            { color: var(--secondary-container); background: var(--surface-container-high); }
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
.severity-moderate  { color: #b45309; background: #171f33eb; }
.severity-high      { color: #c2410c; background: #fff7ed; }
.severity-critical  { color: #dc2626; background: #fef2f2; }

/* ─── Reduced Motion ─────────────────────────────────────────────────────────── */
@media (prefers-reduced-motion: reduce) {
  .skeleton-card { animation: none; }
  .btn, .metric-card { transition: none; }
}
</style>
