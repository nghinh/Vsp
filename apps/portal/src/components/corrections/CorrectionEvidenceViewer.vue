<template>
  <section class="correction-evidence-viewer" aria-label="Reporter evidence">
    <h3 class="section-title">Reporter Evidence</h3>

    <!-- Photo evidence -->
    <div class="evidence-photo">
      <div v-if="!detail.reporterEvidenceUrl" class="no-photo">
        <span aria-hidden="true">📷</span>
        <span>No photo evidence submitted</span>
      </div>
      <figure v-else class="photo-figure">
        <img
          :src="detail.reporterEvidenceUrl"
          :alt="`Photo evidence for correction #${detail.id}`"
          class="evidence-img"
          loading="lazy"
        />
        <figcaption class="photo-caption">Photo evidence submitted by reporter</figcaption>
      </figure>
    </div>

    <!-- Reporter note -->
    <div class="evidence-note">
      <h4 class="subsection-title">Reporter Note</h4>
      <p v-if="detail.reporterNote" class="note-text">{{ detail.reporterNote }}</p>
      <p v-else class="no-note">No note provided.</p>
    </div>

    <!-- Reporter metadata -->
    <div class="reporter-meta">
      <div class="meta-row">
        <span class="meta-label">Reporter ID</span>
        <span class="meta-value">{{ detail.reporterId }}</span>
      </div>
      <div class="meta-row">
        <span class="meta-label">Submitted</span>
        <span class="meta-value">{{ formatDate(detail.submittedAt) }}</span>
      </div>
      <div v-if="detail.confidence != null" class="meta-row">
        <span class="meta-label">Reporter Confidence</span>
        <span class="meta-value confidence-badge">
          {{ detail.confidence.toFixed(0) }}%
        </span>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import type { CorrectionDetailResponse } from '@/types/correction';

defineProps<{
  detail: CorrectionDetailResponse;
}>();

function formatDate(iso: string): string {
  if (!iso) return '—';
  return new Date(iso).toLocaleString();
}
</script>

<style scoped>
.correction-evidence-viewer {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.section-title {
  font-size: 0.9375rem;
  font-weight: 700;
  color: #dae2fd;
  margin: 0;
  padding-bottom: 0.5rem;
  border-bottom: 1px solid #2d3449;
}

/* Photo */
.evidence-photo {
  border-radius: 8px;
  overflow: hidden;
  background: #171f33;
  border: 1px solid #2d3449;
}

.no-photo {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 1.5rem;
  color: #97a2c0;
  font-size: 0.875rem;
  justify-content: center;
}

.photo-figure {
  margin: 0;
}

.evidence-img {
  width: 100%;
  max-height: 280px;
  object-fit: cover;
  display: block;
}

.photo-caption {
  font-size: 0.75rem;
  color: #97a2c0;
  padding: 0.5rem 0.75rem;
  background: #171f33;
  border-top: 1px solid #2d3449;
  margin: 0;
}

/* Note */
.note-text {
  font-size: 0.875rem;
  color: #c5cde8;
  margin: 0;
  padding: 0.75rem;
  background: #171f33;
  border-radius: 6px;
  line-height: 1.5;
  white-space: pre-wrap;
}

.no-note {
  font-size: 0.875rem;
  color: #97a2c0;
  font-style: italic;
  margin: 0;
}

/* Reporter metadata */
.reporter-meta {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  padding: 0.75rem;
  background: #171f33;
  border-radius: 6px;
  border: 1px solid #2d3449;
}

.meta-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 0.8125rem;
}

.meta-label {
  color: #97a2c0;
  font-weight: 500;
}

.meta-value {
  color: #dae2fd;
  font-weight: 600;
}

.confidence-badge {
  background: #fef3c7;
  color: #92400e;
  padding: 0.1rem 0.5rem;
  border-radius: 9999px;
  font-size: 0.75rem;
}
</style>
