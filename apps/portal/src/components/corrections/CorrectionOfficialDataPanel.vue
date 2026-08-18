<template>
  <section class="correction-official-data" aria-label="So sánh với dữ liệu chính thức">
    <h3 class="section-title">Dữ liệu chính thức</h3>

    <div class="official-data-body">
      <!-- Classification info -->
      <div class="data-row">
        <span class="data-label">Loại hiệu chỉnh</span>
        <span class="data-value type-badge">{{ formatType(detail.correctionType) }}</span>
      </div>

      <div v-if="detail.holeNumber != null" class="data-row">
        <span class="data-label">Hố</span>
        <span class="data-value hole-badge">#{{ detail.holeNumber }}</span>
      </div>

      <div class="data-row">
        <span class="data-label">Sân</span>
        <span class="data-value">{{ detail.courseName || `Course #${detail.courseId}` }}</span>
      </div>

      <!-- Data quality metadata -->
      <div class="data-quality-section">
        <h4 class="subsection-title">Chất lượng dữ liệu</h4>

        <div class="data-row">
          <span class="data-label">Nguồn</span>
          <span class="data-value">{{ detail.source ?? '—' }}</span>
        </div>

        <div class="data-row">
          <span class="data-label">Giấy phép</span>
          <span class="data-value">{{ detail.license ?? '—' }}</span>
        </div>

        <div class="data-row">
          <span class="data-label">Hạng độ chính xác</span>
          <span class="data-value">
            <span v-if="detail.accuracyClass" class="accuracy-badge">
              {{ detail.accuracyClass }}
            </span>
            <span v-else>—</span>
          </span>
        </div>

        <div class="data-row">
          <span class="data-label">Độ tin cậy dữ liệu</span>
          <span class="data-value">
            <span v-if="detail.dataConfidence != null" class="confidence-pill">
              {{ detail.dataConfidence.toFixed(0) }}%
            </span>
            <span v-else>—</span>
          </span>
        </div>

        <div class="data-row">
          <span class="data-label">Xác minh</span>
          <span class="data-value">{{ detail.verificationStatus ?? '—' }}</span>
        </div>
      </div>

      <!-- Version info -->
      <div class="data-quality-section">
        <h4 class="subsection-title">Thông tin bản ghi</h4>
        <div class="data-row">
          <span class="data-label">Tạo lúc</span>
          <span class="data-value">{{ formatDate(detail.createdAt) }}</span>
        </div>
        <div class="data-row">
          <span class="data-label">Cập nhật</span>
          <span class="data-value">{{ formatDate(detail.updatedAt) }}</span>
        </div>
        <div v-if="detail.version != null" class="data-row">
          <span class="data-label">Phiên bản</span>
          <span class="data-value version-badge">v{{ detail.version }}</span>
        </div>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import type { CorrectionDetailResponse, CorrectionTypeValue } from '@/types/correction';
import { formatInstant } from '@/lib/datetime';
import { correctionTypeLabel } from '@/lib/correction-labels';

defineProps<{
  detail: CorrectionDetailResponse;
}>();

function formatType(type: CorrectionTypeValue): string {
  return correctionTypeLabel(type);
}

function formatDate(iso: string | null): string {
  if (!iso) return '—';
  return formatInstant(iso);
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
  color: var(--on-surface);
  margin: 0;
  padding-bottom: 0.5rem;
  border-bottom: 1px solid var(--surface-container-highest);
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
  color: var(--muted);
  font-weight: 500;
}

.data-value {
  color: var(--on-surface);
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
  background: var(--surface-container-high);
  padding: 0.1rem 0.4rem;
  border-radius: 3px;
}

.data-quality-section {
  background: var(--surface-container);
  border-radius: 6px;
  padding: 0.75rem;
  border: 1px solid var(--surface-container-highest);
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.subsection-title {
  font-size: 0.75rem;
  font-weight: 600;
  color: var(--muted);
  text-transform: uppercase;
  letter-spacing: 0.05em;
  margin: 0 0 0.25rem;
}

.accuracy-badge {
  background: var(--surface-container-highest);
  color: var(--secondary-container);
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
  background: var(--surface-container-high);
  padding: 0.1rem 0.4rem;
  border-radius: 3px;
}
</style>
