<script setup lang="ts">
/**
 * The prize table, as it will be read out.
 *
 * Two jobs, and the second is the one that matters. It shows the winners — but
 * it also shows every reason the list might not yet be safe to read out: cards
 * still missing, a tie no configured rule could break, a golfer whose handicap
 * fell outside every division. Those are exactly the things that are invisible
 * on a screen full of names, and exactly the things that turn into an argument
 * at the microphone.
 */
import { computed } from 'vue';

import type { OutingResults, OutingRules } from '@/api/outing';

const props = defineProps<{
  results: OutingResults | null;
  rules: OutingRules;
  publishing: boolean;
}>();

const emit = defineEmits<{ (e: 'publish'): void }>();

const divisionsInOrder = computed(() => {
  if (!props.results) return [];
  return props.rules.divisions
    .filter((d) => props.results!.divisions[d.code])
    .map((d) => ({ division: d, entries: props.results!.divisions[d.code] }));
});

const outstanding = computed(() => {
  if (!props.results) return 0;
  return props.results.rosterSize - props.results.scoresEntered;
});

/** Ties no rule could separate — the organisers have to choose. */
const unresolvedTies = computed(() => {
  if (!props.results) return [];
  return Object.values(props.results.divisions)
    .flat()
    .filter((e) => e.tiedAndUnresolved && e.prizeTitle !== null);
});

function signed(n: number | null): string {
  if (n == null) return '—';
  return n > 0 ? `+${n}` : String(n);
}

function awardsFor(code: string) {
  return props.results?.technicalAwards.filter((a) => a.prizeCode === code) ?? [];
}

function holesWithoutWinner(code: string): number[] {
  const spec = props.rules.technicalPrizes.find((p) => p.code === code);
  if (!spec) return [];
  const won = new Set(awardsFor(code).map((a) => a.holeNumber));
  return spec.holes.filter((h) => !won.has(h));
}
</script>

<template>
  <div v-if="results" class="board">
    <!-- ─── What is not safe to read out yet ───────────────────────── -->
    <div class="checks">
      <p v-if="outstanding > 0" class="check check-warn">
        Còn <strong>{{ outstanding }}</strong> golfer chưa có điểm. Bảng dưới
        vẫn xếp được, nhưng chưa nên công bố.
      </p>
      <p v-else class="check check-ok">Đủ {{ results.rosterSize }} golfer.</p>

      <p v-if="unresolvedTies.length > 0" class="check check-warn">
        <strong>{{ unresolvedTies.length }}</strong> golfer bằng nhau ở vị trí
        có giải và mọi tiêu chí đếm ngược đều hoà:
        {{ unresolvedTies.map((t) => t.displayName).join(', ') }}. BTC quyết
        định.
      </p>

      <p v-if="results.unplaced.length > 0" class="check check-warn">
        Không xếp được nhóm cho: {{ results.unplaced.join(', ') }}. Kiểm tra lại
        HDC hoặc dải nhóm ở tab “Thể lệ”.
      </p>

      <p v-if="results.publishedAt" class="check check-ok">
        Đã công bố lúc {{ new Date(results.publishedAt).toLocaleString('vi-VN') }}.
      </p>
    </div>

    <!-- ─── Group prizes ───────────────────────────────────────────── -->
    <section v-for="{ division, entries } in divisionsInOrder" :key="division.code" class="card">
      <h3 class="card-title">
        {{ division.name }}
        <span class="range">HDC {{ division.minHandicap }}–{{ division.maxHandicap }}</span>
      </h3>

      <table class="table">
        <thead>
          <tr>
            <th class="num">#</th>
            <th>Golfer</th>
            <th class="num">FLY</th>
            <th class="num">HDC</th>
            <th class="num">Gậy</th>
            <th class="num">Net</th>
            <th class="num" title="Net so với par, sau khi cắt">Xét giải</th>
            <th class="num" title="CAP ngày theo thang của CLB">CAP</th>
            <th class="num">Bir/Eag</th>
            <th>Giải</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="e in entries" :key="e.tournamentPlayerId" :class="{ 'has-prize': e.prizeTitle }">
            <td class="num">{{ e.rank }}</td>
            <td>
              {{ e.displayName }}
              <span v-if="e.tiedAndUnresolved" class="flag" title="Hoà, mọi tiêu chí đếm ngược đều bằng">
                hoà
              </span>
              <span
                v-else-if="e.gross !== null && !e.countbackAvailable"
                class="flag flag-quiet"
                title="Mới nhập tổng gậy — chưa đếm ngược được nếu phải phân định"
              >
                chưa có chi tiết hố
              </span>
            </td>
            <td class="num">{{ e.flightNumber ?? '—' }}</td>
            <td class="num">{{ e.playingHandicap }}</td>
            <td class="num">{{ e.gross ?? '—' }}</td>
            <td class="num">{{ e.net ?? '—' }}</td>
            <td class="num" :class="{ 'is-under': (e.judgingScore ?? 0) < 0 }">
              {{ signed(e.judgingScore) }}
            </td>
            <td class="num">{{ e.dailyCapAdjustment == null ? '—' : signed(e.dailyCapAdjustment) }}</td>
            <td class="num">{{ e.birdies }}/{{ e.eagles }}</td>
            <td class="prize">{{ e.prizeTitle ?? '' }}</td>
          </tr>
        </tbody>
      </table>
    </section>

    <!-- ─── Technical prizes ───────────────────────────────────────── -->
    <section v-for="spec in rules.technicalPrizes" :key="spec.code" class="card">
      <h3 class="card-title">
        {{ spec.label }}
        <span class="range">{{ spec.holes.length }} hố · toàn CLB</span>
      </h3>

      <table class="table">
        <thead>
          <tr>
            <th class="num">Hố</th>
            <th>Golfer</th>
            <th class="num">Thành tích</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="a in awardsFor(spec.code)" :key="`${a.prizeCode}-${a.holeNumber}`">
            <td class="num">{{ a.holeNumber }}</td>
            <td>{{ a.displayName }}</td>
            <td class="num">{{ a.measurement }} {{ a.unit }}</td>
          </tr>
          <tr v-for="h in holesWithoutWinner(spec.code)" :key="`empty-${spec.code}-${h}`" class="unawarded">
            <td class="num">{{ h }}</td>
            <td colspan="2">
              Chưa có người nhận — chưa ghi thành tích, hoặc người dẫn đầu đã
              có giải khác.
            </td>
          </tr>
        </tbody>
      </table>
    </section>

    <div class="actions">
      <button
        type="button"
        class="btn-primary"
        :disabled="publishing || results.scoresEntered === 0"
        @click="emit('publish')"
      >
        {{ publishing ? 'Đang công bố…' : results.publishedAt ? 'Công bố lại' : 'Công bố kết quả' }}
      </button>
      <span v-if="outstanding > 0" class="actions-note">
        Vẫn công bố được, nhưng còn {{ outstanding }} golfer chưa có điểm.
      </span>
    </div>
  </div>

  <p v-else class="empty">Chưa có kết quả.</p>
</template>

<style scoped>
.board {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.checks {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.check {
  margin: 0;
  padding: 8px 12px;
  border-radius: 6px;
  font-size: 13px;
}
.check-warn {
  background: rgba(240, 180, 41, 0.12);
  border: 1px solid #6b5620;
  color: #f0c869;
}
.check-ok {
  background: rgba(34, 197, 94, 0.1);
  border: 1px solid #2f6f4a;
  color: #6ee7a8;
}

.card {
  border: 1px solid var(--outline-variant);
  border-radius: 8px;
  padding: 14px 16px;
  background: var(--surface-container-lowest);
}
.card-title {
  margin: 0 0 10px;
  font-size: 14px;
  font-weight: 700;
  color: var(--on-surface);
}
.range {
  margin-left: 8px;
  font-size: 12px;
  font-weight: 400;
  color: var(--muted);
}

.table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}
.table th,
.table td {
  padding: 6px 8px;
  border-bottom: 1px solid var(--outline-variant);
  text-align: left;
}
.table thead th {
  color: var(--muted);
  font-size: 11px;
  font-weight: 600;
}
.num {
  text-align: right;
  font-variant-numeric: tabular-nums;
}
.is-under {
  color: #6ee7a8;
  font-weight: 700;
}
.has-prize {
  background: rgba(246, 96, 24, 0.08);
}
.prize {
  font-weight: 600;
  color: var(--primary);
}
.flag {
  margin-left: 6px;
  padding: 1px 6px;
  border-radius: 999px;
  background: rgba(240, 180, 41, 0.18);
  color: #f0c869;
  font-size: 10px;
}
.flag-quiet {
  background: var(--surface-container-high);
  color: var(--muted);
}
.unawarded td {
  color: var(--muted);
  font-style: italic;
}

.actions {
  display: flex;
  align-items: center;
  gap: 12px;
}
.btn-primary {
  padding: 10px 22px;
  border: none;
  border-radius: 6px;
  background: var(--primary);
  color: #fff;
  font-size: 14px;
  font-weight: 700;
  cursor: pointer;
}
.btn-primary:disabled {
  opacity: 0.45;
  cursor: default;
}
.actions-note,
.empty {
  font-size: 12px;
  color: var(--muted);
}
</style>
