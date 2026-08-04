<template>
  <section class="correction-official-data" aria-label="Official data comparison">
    <h3 class="section-title">Official Data</h3>

    <div class="official-data-body">
      <!-- Classification info -->
      <div class="data-row">
        <span class="data-label">Correction Type</span>
        <span class="data-value type-badge">{{ formatType(detail.correctionType) }}</span>
      </div>

      <div v-if="detail.holeNumber != null" class="data-row">
        <span class="data-label">Hole</span>
        <span class="data-value hole-badge">#{{ detail.holeNumber }}</span>
      </div>

      <div class="data-row">
        <span class="data-label">Course</span>
        <span class="data-value">{{ detail.courseName || `Course #${detail.courseId}` }}</span>
      </div>

      <!-- Data quality metadata -->
      <div class="data-quality-section">
        <h4 class="subsection-title">Data Quality</h4>

        <div class="data-row">
          <span class="data-label">Source</span>
          <span class="data-value">{{ detail.source ?? '—' }}</span>
        </div>

        <div class="data-row">
          <span class="data-label">License</span>
          <span class="data-value">{{ detail.license ?? '—' }}</span>
        </div>

        <div class="data-row">
          <span class="data-label">Accuracy Class</span>
          <span class="data-value">
            <span v-if="detail.accuracyClass" class="accuracy-badge">
              {{ detail.accuracyClass }}
            </span>
            <span v-else>—</span>
          </span>
        </div>

        <div class="data-row">
          <span class="data-label">Data Confidence</span>
          <span class="data-value">
            <span v-if="detail.dataConfidence != null" class="confidence-pill">
              {{ detail.dataConfidence.toFixed(0) }}%
            </span>
            <span v-else>—</span>
          </span>
        </div>

        <div class="data-row">
          <span class="data-label">Verification</span>
          <span class="data-value">{{ detail.verificationStatus ?? '—' }}</span>
        </div>
      </div>

      <!-- Version info -->
      <div class="data-quality-section">
        <h4 class="subsection-title">Record Info</h4>
        <div class="data-row">
          <span class="data-label">Created</span>
          <span class="data-value">{{ formatDate(detail.createdAt) }}</span>
        </div>
        <div class="data-row">
          <span class="data-label">Updated</span>
          <span class="data-value">{{ formatDate(detail.updatedAt) }}</span>
        </div>
        <div v-if="detail.version != null" class="data-row">
          <span class="data-label">Version</span>
          <span class="data-value version-badge">v{{ detail.version }}</span>
        </div>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import type { CorrectionDetailResponse, CorrectionTypeValue } from '@/types/correction';

defineProps<{
  detail: CorrectionDetailResponse;
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

function formatDate(iso: string | null): string {
  if (!iso) return '—';
  return new Date(iso).toLocaleString();
}
</script>

<style scoped>
.correction-official-data {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.section-title {
  font-size: 0.9375rem;
  font-weight: 700;
  color: #111827;
  margin: 0;
  padding-bottom: 0.5rem;
  border-bottom: 1px solid #e5e7eb;
}

.official-data-body {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.data-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 0.8125rem;
  padding: 0.4rem 0;
}

.data-label {
  color: #6b7280;
  font-weight: 500;
}

.data-value {
  color: #111827;
  font-weight: 600;
  text-align: right;
  max-width: 60%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.type-badge {
  background: #ede9fe;
  color: #5b21b6;
  padding: 0.15rem 0.5rem;
  border-radius: 4px;
  font-size: 0.75rem;
}

.hole-badge {
  font-family: monospace;
  font-size: 0.75rem;
  background: #f3f4f6;
  padding: 0.1rem 0.4rem;
  border-radius: 3px;
}

.data-quality-section {
  background: #f9fafb;
  border-radius: 6px;
  padding: 0.75rem;
  border: 1px solid #e5e7eb;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.subsection-title {
  font-size: 0.75rem;
  font-weight: 600;
  color: #6b7280;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  margin: 0 0 0.25rem;
}

.accuracy-badge {
  background: #dbeafe;
  color: #1e40af;
  padding: 0.1rem 0.4rem;
  border-radius: 3px;
  font-size: 0.75rem;
}

.confidence-pill {
  background: #fef3c7;
  color: #92400e;
  padding: 0.1rem 0.5rem;
  border-radius: 9999px;
  font-size: 0.75rem;
  font-weight: 600;
}

.version-badge {
  font-family: monospace;
  font-size: 0.75rem;
  background: #f3f4f6;
  padding: 0.1rem 0.4rem;
  border-radius: 3px;
}
</style>
