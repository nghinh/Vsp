<template>
  <section v-if="card" class="scorecard-proposal">
    <h3 class="section-title">Bảng điểm đề xuất</h3>

    <div class="card-meta">
      <div class="meta-item">
        <span class="meta-label">Tên card</span>
        <span class="meta-value">{{ card.name }}</span>
      </div>
      <div class="meta-item">
        <span class="meta-label">Đường</span>
        <span class="meta-value">{{ card.segmentCourseIds.join(' + ') }}</span>
      </div>
      <div class="meta-item">
        <span class="meta-label">Tổng par</span>
        <span class="meta-value">{{ parTotal }}</span>
      </div>
    </div>

    <!--
      The reviewer is checking eighteen numbers against a photograph, so the
      two mistakes that hand-copying makes are called out rather than left to
      be spotted: an index handed out twice misallocates strokes on both holes
      for everyone who plays that card afterwards.
    -->
    <p v-if="problems.length" class="card-problems">
      {{ problems.join(' · ') }}
    </p>

    <table class="card-table">
      <thead>
        <tr>
          <th scope="col">Hố</th>
          <th scope="col">Par</th>
          <th scope="col">Chỉ số gậy</th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="line in card.holes"
          :key="line.hole"
          :class="{ 'row-flagged': duplicateIndexes.has(line.strokeIndex ?? -1) }"
        >
          <td>{{ line.hole }}</td>
          <td>{{ line.par }}</td>
          <td>{{ line.strokeIndex ?? '—' }}</td>
        </tr>
      </tbody>
    </table>
  </section>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { CorrectionDetailResponse } from '@/types/correction';
import {
  duplicateStrokeIndexes,
  parseProposedCard,
  parTotal as sumPar,
  scorecardProblems,
} from '@/lib/scorecard-proposal';

const props = defineProps<{ detail: CorrectionDetailResponse }>();

/** The stored payload, or null when this correction is not a scorecard. */
const card = computed(() =>
  props.detail.correctionType === 'SCORECARD'
    ? parseProposedCard(props.detail.proposedScorecard)
    : null,
);

const parTotal = computed(() => sumPar(card.value));
const duplicateIndexes = computed(() => duplicateStrokeIndexes(card.value));
const problems = computed(() => scorecardProblems(card.value));
</script>

<style scoped>
.scorecard-proposal {
  margin-top: 1.5rem;
}

.section-title {
  font-size: 0.95rem;
  font-weight: 600;
  margin-bottom: 0.75rem;
}

.card-meta {
  display: flex;
  flex-wrap: wrap;
  gap: 1.5rem;
  margin-bottom: 0.75rem;
}

.meta-label {
  display: block;
  font-size: 0.75rem;
  opacity: 0.7;
}

.meta-value {
  font-weight: 600;
}

.card-problems {
  margin: 0 0 0.75rem;
  padding: 0.5rem 0.75rem;
  border-radius: 6px;
  background: rgba(220, 38, 38, 0.12);
  color: #b91c1c;
  font-size: 0.85rem;
}

.card-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.9rem;
}

.card-table th,
.card-table td {
  text-align: left;
  padding: 0.35rem 0.5rem;
  border-bottom: 1px solid rgba(127, 127, 127, 0.2);
}

.row-flagged {
  background: rgba(220, 38, 38, 0.1);
}
</style>
