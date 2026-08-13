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

    <!--
      The ratings go above the table because they are two numbers per tee and
      they are what turns a round into a handicap — the same 82 is a different
      round off 7,311 yards than off 5,631. OUT, IN and the total sit beside
      them because the card prints those three, so they check all eighteen
      yardages at a glance before anyone reads the columns one by one.
    -->
    <div class="tee-section">
      <h4 class="subsection-title">Hàng tee</h4>

      <p v-if="!tees.length" class="tee-empty">
        Card này không chụp được hàng tee nào — duyệt sẽ chỉ lưu par và chỉ số gậy.
      </p>

      <div v-else class="tee-cards">
        <div
          v-for="tee in tees"
          :key="tee.key"
          class="tee-card"
          :class="{ 'tee-dropped': tee.dropped }"
        >
          <div class="tee-head">
            <span class="tee-name">{{ tee.name || '—' }}</span>
            <span v-if="tee.dropped" class="tee-drop-flag">sẽ không lưu</span>
          </div>

          <div class="tee-ratings">
            <div class="tee-rating">
              <span class="meta-label">Course Rating</span>
              <span class="rating-value">{{ tee.courseRating ?? '—' }}</span>
            </div>
            <div class="tee-rating">
              <span class="meta-label">Slope</span>
              <span class="rating-value">{{ tee.slopeRating ?? '—' }}</span>
            </div>
          </div>

          <div class="tee-totals">
            <span><span class="meta-label">OUT</span> {{ tee.totals.front ?? '—' }}</span>
            <span><span class="meta-label">IN</span> {{ tee.totals.back ?? '—' }}</span>
            <span><span class="meta-label">Tổng</span> {{ tee.totals.total ?? '—' }}</span>
          </div>
        </div>
      </div>
    </div>

    <!--
      The yardages are columns of this table rather than a table of their own
      per tee: eighteen rows already exist for the pars, and hanging each tee
      off them puts a hole's yardage next to that hole's par, which is how the
      club printed it and how the eye reads it back off the photograph. Par
      and index keep the left-hand columns, where reading starts.
    -->
    <div class="card-table-scroll">
      <table class="card-table">
        <thead>
          <tr>
            <th scope="col">Hố</th>
            <th scope="col">Par</th>
            <th scope="col">Chỉ số gậy</th>
            <th
              v-for="tee in tees"
              :key="tee.key"
              scope="col"
              class="yard-col"
              :class="{ 'tee-dropped': tee.dropped }"
            >
              {{ tee.name || '—' }}
            </th>
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
            <td
              v-for="tee in tees"
              :key="tee.key"
              class="yard-col"
              :class="{ 'tee-dropped': tee.dropped }"
            >
              {{ tee.yards.get(line.hole) ?? '—' }}
            </td>
          </tr>
        </tbody>
        <tfoot v-if="tees.length">
          <tr>
            <td>Tổng</td>
            <td>{{ parTotal }}</td>
            <td>—</td>
            <td
              v-for="tee in tees"
              :key="tee.key"
              class="yard-col"
              :class="{ 'tee-dropped': tee.dropped }"
            >
              {{ tee.totals.total ?? '—' }}
            </td>
          </tr>
        </tfoot>
      </table>
    </div>
  </section>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { CorrectionDetailResponse } from '@/types/correction';
import {
  droppedTeeIndexes,
  duplicateStrokeIndexes,
  parseProposedCard,
  parTotal as sumPar,
  scorecardProblems,
  teeRows,
  yardageTotals,
  yardsByHole,
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

/**
 * The tee rows, with everything the two views of them need worked out once.
 *
 * Keyed by position rather than by name because a card that read its GOLD
 * column twice is exactly the card this has to render, and two rows sharing a
 * key would collapse into one — hiding the duplicate the reviewer is being
 * warned about.
 */
const tees = computed(() => {
  const dropped = droppedTeeIndexes(card.value);
  return teeRows(card.value).map((tee, index) => ({
    key: index,
    name: tee.name,
    courseRating: tee.courseRating,
    slopeRating: tee.slopeRating,
    yards: yardsByHole(tee),
    totals: yardageTotals(tee),
    dropped: dropped.has(index),
  }));
});
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

.tee-section {
  margin-bottom: 0.75rem;
}

.subsection-title {
  font-size: 0.8rem;
  font-weight: 600;
  opacity: 0.7;
  margin: 0 0 0.4rem;
}

.tee-empty {
  margin: 0;
  font-size: 0.85rem;
  opacity: 0.6;
}

.tee-cards {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.tee-card {
  border: 1px solid rgba(127, 127, 127, 0.25);
  border-radius: 6px;
  padding: 0.5rem 0.75rem;
  min-width: 11rem;
}

.tee-head {
  display: flex;
  align-items: baseline;
  gap: 0.4rem;
  margin-bottom: 0.35rem;
}

.tee-name {
  font-weight: 700;
  font-size: 0.85rem;
  letter-spacing: 0.03em;
}

.tee-drop-flag {
  font-size: 0.7rem;
  color: #b91c1c;
}

.tee-ratings {
  display: flex;
  gap: 1rem;
  margin-bottom: 0.35rem;
}

/* The two numbers that decide a handicap, sized to be read first. */
.rating-value {
  font-size: 1.1rem;
  font-weight: 700;
  line-height: 1.2;
}

.tee-totals {
  display: flex;
  gap: 0.75rem;
  font-size: 0.8rem;
  font-variant-numeric: tabular-nums;
}

.tee-totals .meta-label {
  display: inline;
  margin-right: 0.2rem;
}

/* A dropped row is shown, not hidden — the reviewer has to see the column the
   photograph has and the database will not get. Struck through on the name it
   is dropped for, dimmed everywhere else so the numbers stay legible: they are
   still evidence about the card even when they are not going to be stored. */
.tee-dropped {
  opacity: 0.55;
}

.tee-dropped .tee-name,
th.tee-dropped {
  text-decoration: line-through;
}

.card-table-scroll {
  overflow-x: auto;
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

/* Yardages are bulk and are read as columns; lining the digits up is what
   makes an eye run down one against the printed card. */
.yard-col {
  text-align: right;
  font-variant-numeric: tabular-nums;
  opacity: 0.85;
}

.card-table tfoot td {
  font-weight: 700;
  border-bottom: none;
}

.row-flagged {
  background: rgba(220, 38, 38, 0.1);
}
</style>
