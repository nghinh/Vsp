<template>
  <aside class="correction-queue-filters" aria-label="Correction queue filters">
    <div class="filters-header">
      <h2 class="filters-title">Filters</h2>
      <button class="clear-btn" @click="clearFilters" :disabled="!hasActiveFilters">
        Clear all
      </button>
    </div>

    <form @submit.prevent="applyFilters" class="filters-form">
      <!-- Course ID -->
      <div class="form-field">
        <label for="filter-course-id" class="field-label">Course ID</label>
        <input
          id="filter-course-id"
          v-model.number="localFilters.courseId"
          type="number"
          class="field-input"
          placeholder="e.g. 42"
          min="1"
        />
      </div>

      <!-- Hole Number -->
      <div class="form-field">
        <label for="filter-hole" class="field-label">Hole Number</label>
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
        <label for="filter-type" class="field-label">Correction Type</label>
        <select id="filter-type" v-model="localFilters.type" class="field-input">
          <option value="">All types</option>
          <option v-for="t in correctionTypes" :key="t.value" :value="t.value">
            {{ t.label }}
          </option>
        </select>
      </div>

      <!-- Status -->
      <div class="form-field">
        <label for="filter-status" class="field-label">Status</label>
        <select id="filter-status" v-model="localFilters.status" class="field-input">
          <option value="">All statuses</option>
          <option v-for="s in statuses" :key="s.value" :value="s.value">
            {{ s.label }}
          </option>
        </select>
      </div>

      <!-- Confidence Range -->
      <fieldset class="form-field fieldset">
        <legend class="field-label">Confidence Range</legend>
        <div class="confidence-range">
          <div class="range-input">
            <label for="filter-conf-min" class="range-label">Min %</label>
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
            <label for="filter-conf-max" class="range-label">Max %</label>
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
        <legend class="field-label">Submitted Date Range</legend>
        <div class="date-range">
          <div class="date-input">
            <label for="filter-from" class="range-label">From</label>
            <input
              id="filter-from"
              v-model="localFilters.from"
              type="date"
              class="field-input"
            />
          </div>
          <div class="date-input">
            <label for="filter-to" class="range-label">To</label>
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
        Apply Filters
      </button>
    </form>
  </aside>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import type { CorrectionQueueFilters, CorrectionTypeValue, CorrectionStatusValue } from '@/types/correction';

const props = defineProps<{
  modelValue: CorrectionQueueFilters;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', filters: CorrectionQueueFilters): void;
  (e: 'apply', filters: CorrectionQueueFilters): void;
}>();

const PAGE_SIZE = 20;

const localFilters = ref<CorrectionQueueFilters>({ ...props.modelValue, pageSize: PAGE_SIZE });

const correctionTypes: { value: CorrectionTypeValue; label: string }[] = [
  { value: 'GEOMETRY',          label: 'Geometry' },
  { value: 'PIN_POSITION',      label: 'Pin Position' },
  { value: 'BUNKER',            label: 'Bunker' },
  { value: 'WATER',             label: 'Water' },
  { value: 'OB',                label: 'Out of Bounds' },
  { value: 'CART_PATH',         label: 'Cart Path' },
  { value: 'LANDMARK',          label: 'Landmark' },
  { value: 'COURSE_CONDITION',  label: 'Course Condition' },
  { value: 'GREEN_SPEED',       label: 'Green Speed' },
  { value: 'OTHER',             label: 'Other' },
];

const statuses: { value: CorrectionStatusValue; label: string }[] = [
  { value: 'PENDING',            label: 'Pending' },
  { value: 'IN_REVIEW',          label: 'In Review' },
  { value: 'APPROVED',           label: 'Approved' },
  { value: 'REJECTED',           label: 'Rejected' },
  { value: 'INFO_REQUESTED',      label: 'Info Requested' },
  { value: 'CONVERTED_TO_DRAFT', label: 'Converted to Draft' },
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
  localFilters.value = { page: 0, pageSize: PAGE_SIZE };
  emit('update:modelValue', { ...localFilters.value });
  emit('apply', { ...localFilters.value });
}
</script>

<style scoped>
.correction-queue-filters {
  background: #171f33;
  border-right: 1px solid #2d3449;
  padding: 1.25rem 1rem;
  min-width: 220px;
  max-width: 260px;
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
  color: #dae2fd;
  margin: 0;
}

.clear-btn {
  background: none;
  border: none;
  font-size: 0.75rem;
  color: #3b82f6;
  cursor: pointer;
  padding: 0.25rem 0.5rem;
  border-radius: 4px;
  min-height: 32px;
}
.clear-btn:hover:not(:disabled) { background: #222a3d; }
.clear-btn:disabled { color: #97a2c0; cursor: not-allowed; }

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
  border: 1px solid #2d3449;
  border-radius: 6px;
  font-size: 0.8125rem;
  font-family: inherit;
  color: #dae2fd;
  background: #171f33;
  min-height: 36px;
  transition: border-color 0.15s;
}
.field-input:focus {
  outline: none;
  border-color: #3b82f6;
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.15);
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
  color: #97a2c0;
}

.range-sep {
  color: #97a2c0;
  padding-top: 1.2rem;
  flex-shrink: 0;
}

.apply-btn {
  margin-top: 0.25rem;
  padding: 0.5rem 1rem;
  border-radius: 6px;
  border: 1px solid #3b82f6;
  background: #3b82f6;
  color: white;
  font-size: 0.8125rem;
  font-weight: 600;
  cursor: pointer;
  min-height: 40px;
  transition: background 0.15s;
}
.apply-btn:hover { background: #f66018; }
</style>
