<template>
  <div class="correction-detail-panel">
    <!-- Classification summary bar -->
    <div class="detail-summary-bar">
      <div class="summary-item">
        <span class="summary-label">Type</span>
        <span class="summary-value">{{ formatType(detail.correctionType) }}</span>
      </div>
      <div class="summary-item">
        <span class="summary-label">Status</span>
        <CorrectionStatusBadge :status="detail.status" />
      </div>
      <div v-if="detail.confidence != null" class="summary-item">
        <span class="summary-label">Confidence</span>
        <span class="confidence-val">{{ detail.confidence.toFixed(0) }}%</span>
      </div>
    </div>

    <!-- Reporter evidence -->
    <CorrectionEvidenceViewer :detail="detail" />

    <!-- Location map -->
    <CorrectionLocationMap
      :detail="detail"
      :map-context="mapContext"
    />

    <!-- Official data comparison -->
    <CorrectionOfficialDataPanel :detail="detail" />

    <!-- Review history -->
    <div v-if="detail.reviewedAt || detail.reviewNote" class="review-history">
      <h3 class="section-title">Review History</h3>
      <div class="review-body">
        <div v-if="detail.reviewedAt" class="review-row">
          <span class="review-label">Reviewed</span>
          <span class="review-value">{{ formatDate(detail.reviewedAt) }}</span>
        </div>
        <div v-if="detail.reviewedBy" class="review-row">
          <span class="review-label">Reviewer ID</span>
          <span class="review-value">{{ detail.reviewedBy }}</span>
        </div>
        <div v-if="detail.reviewNote" class="review-row review-note-row">
          <span class="review-label">Note</span>
          <p class="review-note">{{ detail.reviewNote }}</p>
        </div>
        <div v-if="detail.resolution" class="review-row review-note-row">
          <span class="review-label">Resolution</span>
          <p class="review-note">{{ detail.resolution }}</p>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import type { CorrectionDetailResponse, CorrectionMapContext, CorrectionTypeValue } from '@/types/correction';
import CorrectionStatusBadge from './CorrectionStatusBadge.vue';
import CorrectionEvidenceViewer from './CorrectionEvidenceViewer.vue';
import CorrectionLocationMap from './CorrectionLocationMap.vue';
import CorrectionOfficialDataPanel from './CorrectionOfficialDataPanel.vue';

const props = defineProps<{
  detail: CorrectionDetailResponse;
}>();

// Map context: starts empty, loaded by parent via emit
const mapContext = ref<CorrectionMapContext>({
  correctionId: props.detail.id,
});

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
.correction-detail-panel {
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
}

/* Summary bar */
.detail-summary-bar {
  display: flex;
  gap: 1.5rem;
  padding: 0.875rem 1rem;
  background: #f9fafb;
  border-radius: 8px;
  border: 1px solid #e5e7eb;
  flex-wrap: wrap;
}

.summary-item {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
}

.summary-label {
  font-size: 0.6875rem;
  font-weight: 600;
  color: #9ca3af;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.summary-value {
  font-size: 0.875rem;
  font-weight: 600;
  color: #111827;
}

.confidence-val {
  font-size: 0.875rem;
  font-weight: 700;
  color: #92400e;
}

/* Section titles shared pattern */
.section-title {
  font-size: 0.9375rem;
  font-weight: 700;
  color: #111827;
  margin: 0;
  padding-bottom: 0.5rem;
  border-bottom: 1px solid #e5e7eb;
}

/* Review history */
.review-history {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.review-body {
  background: #f9fafb;
  border-radius: 6px;
  border: 1px solid #e5e7eb;
  padding: 0.75rem;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.review-row {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  font-size: 0.8125rem;
  gap: 1rem;
}

.review-label {
  color: #6b7280;
  font-weight: 500;
  flex-shrink: 0;
}

.review-value {
  color: #111827;
  font-weight: 600;
  text-align: right;
}

.review-note-row {
  flex-direction: column;
  gap: 0.25rem;
}

.review-note {
  font-size: 0.8125rem;
  color: #374151;
  margin: 0;
  line-height: 1.5;
  white-space: pre-wrap;
}
</style>
