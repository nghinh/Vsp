<script setup lang="ts">
/**
 * Geometry review.
 *
 * Four courses now carry 18/18 holes of real OpenStreetMap coordinates, and the
 * mobile app treats every one of them exactly like the 831 holes a seed script
 * invented — because both are PENDING_REVIEW, and the app's provenance gate only
 * trusts VERIFIED. This page is the other side of that gate.
 *
 * Two things it deliberately does not do:
 *
 *   • No "verify all" button. Verifying eighteen holes in one click would make
 *     VERIFIED mean "somebody pressed a button" rather than "somebody looked",
 *     and VERIFIED is what puts a distance in front of a golfer choosing a club.
 *   • No way to tick a seeded hole. Those carry a tee that is the clubhouse pin
 *     walked along a fixed diagonal with the green placed due north of it. There
 *     is nothing there to confirm; the server refuses them too.
 */
import { computed, onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import {
  correctPar,
  fetchGeometryReview,
  verifyGeometry,
  type CorrectParResponse,
  type GeometryReviewSummary,
} from '../../../../api/geometry-review';

const route = useRoute();
const courseId = Number(route.params.courseId);

const summary = ref<GeometryReviewSummary | null>(null);
const loading = ref(false);
const fetchError = ref<string | null>(null);

const selected = ref<Set<number>>(new Set());
const note = ref('');
const submitting = ref(false);
const submitError = ref<string | null>(null);
const lastResult = ref<{ verified: number[]; refused: number[] } | null>(null);

/**
 * True when the hole pars do not add up to the course's advertised total.
 *
 * The strongest signal on this page, and the only one that catches a wrong par
 * sitting inside the plausible band.
 */
const parTotalMismatch = computed(
  () =>
    summary.value != null &&
    summary.value.courseParTotal != null &&
    summary.value.holeParTotal !== summary.value.courseParTotal,
);

const savingPar = ref(false);
const parResult = ref<CorrectParResponse | null>(null);

/**
 * Holes whose par cannot be true for their own length.
 *
 * Only those with a suggestion: a hole flagged with nothing to offer would give
 * a reviewer a warning and no way to act on it.
 */
const implausiblePar = computed(
  () =>
    summary.value?.holes.filter(
      (h) => !h.parMatchesLength && h.suggestedPar != null,
    ) ?? [],
);

/**
 * Applies the length-derived par to every flagged hole.
 *
 * The note records exactly what authority this carries, because it is not a
 * scorecard: it is a rule of thumb, and the audit trail should not let a later
 * reader mistake one for the other.
 */
async function applySuggestedPar() {
  const holes = implausiblePar.value.map((h) => ({
    holeNumber: h.holeNumber,
    par: h.suggestedPar as number,
  }));
  if (holes.length === 0) return;

  savingPar.value = true;
  parResult.value = null;
  try {
    parResult.value = await correctPar(
      courseId,
      holes,
      'Par suy ra từ độ dài đo được, chưa đối chiếu scorecard của sân',
    );
    await load();
  } catch (err: unknown) {
    fetchError.value =
      (err as { message?: string })?.message ?? 'Không lưu được par.';
  } finally {
    savingPar.value = false;
  }
}

const reviewableHoles = computed(
  () => summary.value?.holes.filter((h) => h.reviewable && h.verificationStatus !== 'VERIFIED') ?? [],
);

const canSubmit = computed(
  () => selected.value.size > 0 && note.value.trim().length >= 10 && !submitting.value,
);

function toggle(holeNumber: number) {
  const next = new Set(selected.value);
  if (next.has(holeNumber)) next.delete(holeNumber);
  else next.add(holeNumber);
  selected.value = next;
}

async function load() {
  loading.value = true;
  fetchError.value = null;
  try {
    summary.value = await fetchGeometryReview(courseId);
  } catch (err) {
    fetchError.value =
      (err as Error).message ?? 'Không tải được dữ liệu hình học từ máy chủ.';
    summary.value = null;
  } finally {
    loading.value = false;
  }
}

async function submit() {
  submitting.value = true;
  submitError.value = null;
  try {
    const result = await verifyGeometry(
      courseId,
      [...selected.value],
      note.value.trim(),
    );
    lastResult.value = {
      verified: result.verifiedHoleNumbers,
      refused: result.refusedHoleNumbers,
    };
    selected.value = new Set();
    note.value = '';
    await load();
  } catch (err) {
    submitError.value = (err as Error).message ?? 'Không xác nhận được.';
  } finally {
    submitting.value = false;
  }
}

onMounted(load);
</script>

<template>
  <div class="review">
    <header class="head">
      <h1>Duyệt hình học sân</h1>
      <p v-if="summary" class="sub">{{ summary.courseName }}</p>
    </header>

    <p class="explain">
      Hình học nhập từ OpenStreetMap là dữ liệu thật, nhưng chưa ai ở VSP kiểm.
      Ứng dụng chỉ vẽ bản đồ chiến thuật và tự chuyển hố cho những hố đã được xác
      nhận — nên tới khi bạn xác nhận, một hố có toạ độ thật vẫn bị đối xử y hệt
      một hố do script sinh ra. Hãy mở từng hố trên bản đồ trước khi tick.
    </p>

    <div v-if="loading" class="state">Đang tải…</div>

    <div v-else-if="fetchError" class="state error" role="alert">
      {{ fetchError }}
      <button type="button" @click="load">Thử lại</button>
    </div>

    <template v-else-if="summary">
      <div class="counts">
        <span class="count verified">{{ summary.verifiedHoles }} đã xác nhận</span>
        <span class="count pending">{{ summary.pendingHoles }} chờ duyệt</span>
        <span class="count unverified">{{ summary.unverifiedHoles }} chưa có dữ liệu thật</span>
      </div>

      <div
        v-if="lastResult"
        class="state result"
        role="status"
      >
        Đã xác nhận {{ lastResult.verified.length }} hố.
        <template v-if="lastResult.refused.length">
          Từ chối {{ lastResult.refused.length }} hố
          ({{ lastResult.refused.join(', ') }}) — những hố này chỉ có toạ độ do
          script sinh ra, không có gì để xác nhận.
        </template>
      </div>

      <div
        v-if="parTotalMismatch"
        class="state par-banner"
        role="status"
      >
        <strong>Tổng par không khớp</strong> — cộng par từng hố ra
        {{ summary.holeParTotal }}, sân công bố {{ summary.courseParTotal }}.
        Tổng par của một sân là con số đã công bố, nên chênh lệch nghĩa là còn ít
        nhất một hố sai par — kể cả hố mà par nhìn riêng vẫn hợp lý, nên không có
        cảnh báo nào khác bắt được. Cần scorecard thật của sân để xử lý nốt.
      </div>

      <!--
        Par came from the same seed script that invented the coordinates, and
        the OSM import replaced every length with a measured one while leaving
        par alone. Where the two contradict each other, one of them is wrong —
        and every over/under-par figure a golfer reads is arithmetic against par.
      -->
      <div v-if="implausiblePar.length" class="state par-banner" role="status">
        <strong>{{ implausiblePar.length }} hố có par không thể đúng với độ dài của chính nó</strong>
        — hố {{ implausiblePar.map((h) => h.holeNumber).join(', ') }}.
        Con số đề xuất bên dưới suy ra từ độ dài; nó chỉ là điểm khởi đầu, vì par
        là dữ liệu trên scorecard và không phép đo nào quyết định thay được.
        <button
          type="button"
          class="btn-apply-par"
          :disabled="savingPar"
          @click="applySuggestedPar"
        >
          {{ savingPar ? 'Đang lưu…' : 'Áp dụng đề xuất cho ' + implausiblePar.length + ' hố' }}
        </button>
      </div>

      <div v-if="parResult" class="state result" role="status">
        Đã sửa par {{ parResult.changedHoleNumbers.length }} hố.
        <template v-if="parResult.stillImplausible.length">
          {{ parResult.stillImplausible.length }} hố vẫn lệch với độ dài
          ({{ parResult.stillImplausible.join(', ') }}) — đã lưu theo bạn, nhưng
          scorecard và số đo đang mâu thuẫn.
        </template>
      </div>

      <table class="holes">
        <thead>
          <tr>
            <th scope="col"><span class="visually-hidden">Chọn</span></th>
            <th scope="col">Hố</th>
            <th scope="col">Par</th>
            <th scope="col">Dài (m)</th>
            <th scope="col">Nguồn</th>
            <th scope="col">Green</th>
            <th scope="col">Bẫy cát</th>
            <th scope="col">Tee box</th>
            <th scope="col">Trạng thái</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="hole in summary.holes"
            :key="hole.holeNumber"
            :class="{ unreviewable: !hole.reviewable }"
          >
            <td>
              <input
                type="checkbox"
                :checked="selected.has(hole.holeNumber)"
                :disabled="!hole.reviewable || hole.verificationStatus === 'VERIFIED'"
                :aria-label="`Xác nhận hố ${hole.holeNumber}`"
                @change="toggle(hole.holeNumber)"
              />
            </td>
            <td>{{ hole.holeNumber }}</td>
            <td :class="{ 'par-wrong': !hole.parMatchesLength }">
              <span v-if="!hole.parMatchesLength" class="warn-mark" aria-hidden="true">⚠</span>
              {{ hole.par ?? '—' }}
              <span v-if="hole.suggestedPar != null" class="suggest">
                → đề xuất {{ hole.suggestedPar }}
              </span>
            </td>
            <td>{{ hole.lengthMeters != null ? Math.round(hole.lengthMeters) : '—' }}</td>
            <td><code class="source">{{ hole.source ?? '—' }}</code></td>
            <td>{{ hole.greens }}</td>
            <td>{{ hole.bunkers }}</td>
            <td>{{ hole.teeBoxes }}</td>
            <td>
              <span class="status" :class="hole.verificationStatus?.toLowerCase()">
                {{ hole.verificationStatus ?? '—' }}
              </span>
            </td>
          </tr>
        </tbody>
      </table>

      <form class="confirm" @submit.prevent="submit">
        <label for="review-note">
          Ghi chú duyệt — bạn đã đối chiếu với gì?
        </label>
        <textarea
          id="review-note"
          v-model="note"
          rows="2"
          placeholder="Ví dụ: đối chiếu 18 hố với ảnh vệ tinh và scorecard công bố của sân"
        ></textarea>
        <p class="hint">
          Ghi chú đi vào nhật ký kiểm toán cùng tên bạn. Nhiều năm sau, câu hỏi
          “ai nói dữ liệu này đúng” phải trả lời được.
        </p>

        <p v-if="submitError" class="state error" role="alert">{{ submitError }}</p>

        <div class="actions">
          <span class="selected-count">
            Đã chọn {{ selected.size }} / {{ reviewableHoles.length }} hố duyệt được
          </span>
          <button type="submit" :disabled="!canSubmit">
            {{ submitting ? 'Đang xác nhận…' : 'Xác nhận các hố đã chọn' }}
          </button>
        </div>
      </form>
    </template>
  </div>
</template>

<style scoped>
.review {
  padding: 1.5rem;
  max-width: 70rem;
}

.head h1 {
  margin: 0;
  font-size: 1.5rem;
}

.sub,
.explain {
  color: var(--vsp-text-muted, #94a3b8);
}

.explain {
  margin: 0.75rem 0 1.25rem;
  font-size: 0.875rem;
  max-width: 60ch;
}

.counts {
  display: flex;
  gap: 0.75rem;
  margin-bottom: 1rem;
  flex-wrap: wrap;
}

.count {
  padding: 0.25rem 0.625rem;
  border-radius: 999px;
  font-size: 0.8125rem;
  border: 1px solid var(--vsp-border, #334155);
}

.count.verified {
  border-color: #22c55e;
  color: #22c55e;
}
.count.pending {
  border-color: #fbbf24;
  color: #fbbf24;
}
.count.unverified {
  color: var(--vsp-text-muted, #94a3b8);
}

.state {
  padding: 0.75rem 1rem;
  border-radius: 8px;
  border: 1px solid var(--vsp-border, #334155);
  margin-bottom: 1rem;
}

.state.error {
  border-color: #f87171;
  color: #f87171;
}

.holes {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.875rem;
}

.holes th,
.holes td {
  text-align: left;
  padding: 0.5rem;
  border-bottom: 1px solid var(--vsp-border, #334155);
}

.holes tr.unreviewable {
  opacity: 0.55;
}

.source {
  font-size: 0.75rem;
}

.status {
  font-size: 0.75rem;
  font-weight: 600;
}
.status.verified {
  color: #22c55e;
}
.status.pending_review {
  color: #fbbf24;
}

.confirm {
  margin-top: 1.5rem;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.confirm textarea {
  width: 100%;
  padding: 0.5rem;
  border-radius: 8px;
  border: 1px solid var(--vsp-border, #334155);
  background: transparent;
  color: inherit;
  font: inherit;
}

.hint {
  margin: 0;
  font-size: 0.8125rem;
  color: var(--vsp-text-muted, #94a3b8);
}

.actions {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  margin-top: 0.5rem;
}

.actions button {
  min-height: 44px;
  padding: 0 1.25rem;
  border-radius: 8px;
  border: none;
  background: var(--vsp-primary, #ea580c);
  color: #fff;
  font: inherit;
  font-weight: 600;
  cursor: pointer;
}

.actions button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.visually-hidden {
  position: absolute;
  width: 1px;
  height: 1px;
  overflow: hidden;
  clip: rect(0 0 0 0);
}

/* Par that its own hole contradicts. Amber, not red: the number is wrong, but
   which of par and length is wrong is exactly what the reviewer decides. */
.par-wrong { color: #b45309; font-weight: 600; }
.warn-mark { margin-right: 2px; }
.suggest { color: #6b7280; font-weight: 400; font-size: 0.85em; white-space: nowrap; }
.par-banner { border-left: 3px solid #b45309; }
.btn-apply-par { margin-left: 8px; }
</style>