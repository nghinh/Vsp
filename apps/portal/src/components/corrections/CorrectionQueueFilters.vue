<template>
  <aside class="correction-queue-filters" aria-label="Bộ lọc hàng đợi">
    <div class="filters-header">
      <h2 class="filters-title">Bộ lọc</h2>
      <button class="clear-btn" @click="clearFilters" :disabled="!hasActiveFilters">
        Xoá hết
      </button>
    </div>

    <form @submit.prevent="applyFilters" class="filters-form">
      <!-- Course ID -->
      <div class="form-field">
        <label for="filter-course-id" class="field-label">Mã sân</label>
        <input
          id="filter-course-id"
          v-model.number="localFilters.courseId"
          type="number"
          class="field-input"
          placeholder="ví dụ 42"
          min="1"
        />
      </div>

      <!-- Hole Number -->
      <div class="form-field">
        <label for="filter-hole" class="field-label">Số hố</label>
        <input
          id="filter-hole"
          v-model.number="localFilters.holeNumber"
          type="number"
          class="field-input"
          placeholder="1–18"
          min="1"
          max="18"
        />
      </div>

      <!-- Correction Type -->
      <div class="form-field">
        <label for="filter-type" class="field-label">Loại hiệu chỉnh</label>
        <select id="filter-type" v-model="localFilters.type" class="field-input">
          <option value="">Tất cả loại</option>
          <option v-for="t in correctionTypes" :key="t.value" :value="t.value">
            {{ t.label }}
          </option>
        </select>
      </div>

      <!-- Status -->
      <div class="form-field">
        <label for="filter-status" class="field-label">Trạng thái</label>
        <select id="filter-status" v-model="localFilters.status" class="field-input">
          <option value="">Tất cả trạng thái</option>
          <option v-for="s in statuses" :key="s.value" :value="s.value">
            {{ s.label }}
          </option>
        </select>
      </div>

      <!-- Confidence Range -->
      <fieldset class="form-field fieldset">
        <legend class="field-label">Khoảng độ tin cậy</legend>
        <div class="confidence-range">
          <div class="range-input">
            <label for="filter-conf-min" class="range-label">Tối thiểu %</label>
            <input
              id="filter-conf-min"
              v-model.number="localFilters.confidenceMin"
              type="number"
              class="field-input"
              placeholder="0"
              min="0"
              max="100"
            />
          </div>
          <span class="range-sep" aria-hidden="true">–</span>
          <div class="range-input">
            <label for="filter-conf-max" class="range-label">Tối đa %</label>
            <input
              id="filter-conf-max"
              v-model.number="localFilters.confidenceMax"
              type="number"
              class="field-input"
              placeholder="100"
              min="0"
              max="100"
            />
          </div>
        </div>
      </fieldset>

      <!-- Date Range -->
      <fieldset class="form-field fieldset">
        <legend class="field-label">Khoảng ngày gửi</legend>
        <div class="date-range">
          <div class="date-input">
            <label for="filter-from" class="range-label">Từ</label>
            <input
              id="filter-from"
              v-model="localFilters.from"
              type="date"
              class="field-input"
            />
          </div>
          <div class="date-input">
            <label for="filter-to" class="range-label">Đến</label>
            <input
              id="filter-to"
              v-model="localFilters.to"
              type="date"
              class="field-input"
            />
          </div>
        </div>
      </fieldset>

      <!-- Apply -->
      <button type="submit" class="apply-btn">
        Áp dụng lọc
      </button>
    </form>
  </aside>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { CORRECTION_TYPE_LABELS } from '@/lib/correction-labels';
import type { CorrectionQueueFilters, CorrectionTypeValue, CorrectionStatusValue } from '@/types/correction';

const props = defineProps<{
  modelValue: CorrectionQueueFilters;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', filters: CorrectionQueueFilters): void;
  (e: 'apply', filters: CorrectionQueueFilters): void;
}>();

const PAGE_SIZE = 20;

/**
 * `type` and `status` default to `''`, not `undefined`.
 *
 * `v-model` on a `<select>` selects the option whose value equals the model.
 * `undefined` equals nothing — not even the `<option value="">` placeholder —
 * so both dropdowns opened with `selectedIndex === -1`: two empty boxes with
 * no visible "Tất cả loại", which reads as a control that failed to load
 * rather than one showing no filter.
 */
const EMPTY_FILTERS: CorrectionQueueFilters = { page: 0, pageSize: PAGE_SIZE, type: '', status: '' };

const localFilters = ref<CorrectionQueueFilters>({
  ...EMPTY_FILTERS,
  ...props.modelValue,
  pageSize: PAGE_SIZE,
});

/**
 * Derived from `CORRECTION_TYPE_LABELS` rather than listed again here.
 *
 * The hand-written copy this replaces was missing `SCORECARD` — the one
 * correction type a reviewer most often wants to filter to, since a scorecard
 * photo report is the only kind that arrives with an image attached. It could
 * not be filtered for at all, and nothing said so.
 */
const correctionTypes: { value: CorrectionTypeValue; label: string }[] = (
  Object.keys(CORRECTION_TYPE_LABELS) as CorrectionTypeValue[]
).map((value) => ({ value, label: CORRECTION_TYPE_LABELS[value] }));

const statuses: { value: CorrectionStatusValue; label: string }[] = [
  { value: 'PENDING',            label: 'Chờ xử lý' },
  { value: 'IN_REVIEW',          label: 'Đang xem xét' },
  { value: 'APPROVED',           label: 'Đã duyệt' },
  { value: 'REJECTED',           label: 'Đã từ chối' },
  { value: 'INFO_REQUESTED',      label: 'Chờ bổ sung' },
  { value: 'CONVERTED_TO_DRAFT', label: 'Đã chuyển nháp' },
];

const hasActiveFilters = computed(() => {
  const f = localFilters.value;
  return !!(
    f.courseId ||
    f.holeNumber ||
    f.type ||
    f.status ||
    f.confidenceMin != null ||
    f.confidenceMax != null ||
    f.from ||
    f.to
  );
});

function applyFilters() {
  emit('update:modelValue', { ...localFilters.value });
  emit('apply', { ...localFilters.value });
}

function clearFilters() {
  localFilters.value = { ...EMPTY_FILTERS };
  emit('update:modelValue', { ...localFilters.value });
  emit('apply', { ...localFilters.value });
}
</script>

<style scoped>
.correction-queue-filters {
  background: var(--surface-container);
  border-right: 1px solid var(--surface-container-highest);
  padding: 1.25rem 1rem;
  min-width: 220px;
  max-width: 260px;
  width: 100%;
  display: flex;
  flex-direction: column;
  gap: 1rem;
  height: fit-content;
}

.filters-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.filters-title {
  font-size: 0.9375rem;
  font-weight: 700;
  color: var(--on-surface);
  margin: 0;
}

.clear-btn {
  background: none;
  border: none;
  font-size: 0.75rem;
  color: var(--primary-bright);
  cursor: pointer;
  padding: 0.25rem 0.5rem;
  border-radius: 4px;
  min-height: 32px;
}
.clear-btn:hover:not(:disabled) { background: var(--surface-container-high); }
.clear-btn:disabled { color: var(--muted); cursor: not-allowed; }

.filters-form {
  display: flex;
  flex-direction: column;
  gap: 0.875rem;
}

.form-field {
  display: flex;
  flex-direction: column;
  gap: 0.3rem;
}

.fieldset {
  border: none;
  padding: 0;
  margin: 0;
}

.field-label {
  font-size: 0.8125rem;
  font-weight: 600;
  color: #c5cde8;
}

.field-input {
  padding: 0.375rem 0.625rem;
  border: 1px solid var(--surface-container-highest);
  border-radius: 6px;
  font-size: 0.8125rem;
  font-family: inherit;
  color: var(--on-surface);
  background: var(--surface-container);
  min-height: 36px;
  transition: border-color 0.15s;
}
.field-input:focus {
  outline: none;
  border-color: var(--primary-container);
  box-shadow: 0 0 0 3px rgba(246, 96, 24, 0.15);
}

.confidence-range,
.date-range {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.range-input,
.date-input {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
  flex: 1;
}

.range-label {
  font-size: 0.6875rem;
  color: var(--muted);
}

.range-sep {
  color: var(--muted);
  padding-top: 1.2rem;
  flex-shrink: 0;
}

.apply-btn {
  margin-top: 0.25rem;
  padding: 0.5rem 1rem;
  border-radius: 6px;
  border: 1px solid var(--primary-container);
  background: var(--primary-container);
  color: white;
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
  min-height: 40px;
  transition: background 0.15s;
}
.apply-btn:hover { background: var(--secondary-container); }

@media (max-width: 768px) {
  .correction-queue-filters { max-width: none; border-right: 0; border-bottom: 1px solid var(--surface-container-highest); }
}
</style>
