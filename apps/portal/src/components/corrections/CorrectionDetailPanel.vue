<template>
  <div class="correction-detail-panel">
    <!-- Classification summary bar -->
    <div class="detail-summary-bar">
      <div class="summary-item">
        <span class="summary-label">Loại</span>
        <span class="summary-value">{{ formatType(detail.correctionType) }}</span>
      </div>
      <div class="summary-item">
        <span class="summary-label">Trạng thái</span>
        <CorrectionStatusBadge :status="detail.status" />
      </div>
      <div v-if="detail.confidence != null" class="summary-item">
        <span class="summary-label">Độ tin cậy</span>
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
      <h3 class="section-title">Lịch sử xử lý</h3>
      <div class="review-body">
        <div v-if="detail.reviewedAt" class="review-row">
          <span class="review-label">Đã xử lý</span>
          <span class="review-value">{{ formatDate(detail.reviewedAt) }}</span>
        </div>
        <div v-if="detail.reviewedBy" class="review-row">
          <span class="review-label">Mã người xử lý</span>
          <span class="review-value">{{ detail.reviewedBy }}</span>
        </div>
        <div v-if="detail.reviewNote" class="review-row review-note-row">
          <span class="review-label">Ghi chú</span>
          <p class="review-note">{{ detail.reviewNote }}</p>
        </div>
        <div v-if="detail.resolution" class="review-row review-note-row">
          <span class="review-label">Kết luận</span>
          <p class="review-note">{{ detail.resolution }}</p>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { formatInstant } from '@/lib/datetime';
import type { CorrectionDetailResponse, CorrectionMapContext, CorrectionTypeValue } from '@/types/correction';
import { correctionTypeLabel } from '@/lib/correction-labels';
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
  return correctionTypeLabel(type);
}

function formatDate(iso: string | null): string {
  if (!iso) return '—';
  return formatInstant(iso);
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
  background: #171f33;
  border-radius: 8px;
  border: 1px solid #2d3449;
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
  color: #97a2c0;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.summary-value {
  font-size: 0.875rem;
  font-weight: 600;
  color: #dae2fd;
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
  color: #dae2fd;
  margin: 0;
  padding-bottom: 0.5rem;
  border-bottom: 1px solid #2d3449;
}

/* Review history */
.review-history {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.review-body {
  background: #171f33;
  border-radius: 6px;
  border: 1px solid #2d3449;
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
  color: #97a2c0;
  font-weight: 500;
  flex-shrink: 0;
}

.review-value {
  color: #dae2fd;
  font-weight: 600;
  text-align: right;
}

.review-note-row {
  flex-direction: column;
  gap: 0.25rem;
}

.review-note {
  font-size: 0.8125rem;
  color: #c5cde8;
  margin: 0;
  line-height: 1.5;
  white-space: pre-wrap;
}
</style>
