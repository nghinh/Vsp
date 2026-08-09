<script setup lang="ts">
/**
 * The on-course board, typed up.
 *
 * "BTC sẽ có bảng ghi thành tích trên sân. TẤT CẢ CÁC FLY GHI THÀNH TÍCH VÀO
 * BẢNG THÀNH TÍCH ĐỂ BTC XÉT GIẢI" — the nearest-to-pin and longest-drive
 * results are written by the players themselves, on a board by the tee, as
 * they pass. Somebody carries that board back and types it in.
 *
 * One block per hole, because that is how the board is laid out and how it
 * will be read out. The leader is highlighted as the numbers go in, but the
 * highlight is only the best measurement on the hole — it is not the winner.
 * Who actually collects the prize is decided at the end, once the group prizes
 * are settled, because a golfer who already has one steps aside and the hole
 * passes to the next best. That is the whole point of the rule and it cannot
 * be answered a hole at a time.
 */
import { computed, ref } from 'vue';

import type { OutingPlayer, OutingRules, TechnicalEntry } from '@/api/outing';

const props = defineProps<{
  players: OutingPlayer[];
  rules: OutingRules;
  /** Already-recorded measurements, so a re-measure replaces rather than adds. */
  existing: TechnicalEntry[];
  saving: boolean;
}>();

const emit = defineEmits<{ (e: 'save', entries: TechnicalEntry[]): void }>();

/** Rows being typed, keyed prize|hole|player. */
type Row = { prizeCode: string; holeNumber: number; playerId: string; measurement: string };
const rows = ref<Record<string, Row[]>>({});
const dirty = ref(false);

function key(prizeCode: string, hole: number): string {
  return `${prizeCode}|${hole}`;
}

function rowsFor(prizeCode: string, hole: number): Row[] {
  const k = key(prizeCode, hole);
  if (!rows.value[k]) {
    const seeded = props.existing
      .filter((e) => e.prizeCode === prizeCode && e.holeNumber === hole)
      .map((e) => ({
        prizeCode,
        holeNumber: hole,
        playerId: e.tournamentPlayerId,
        measurement: String(e.measurement),
      }));
    // Always one blank row at the bottom to type into.
    rows.value[k] = [...seeded, blank(prizeCode, hole)];
  }
  return rows.value[k];
}

function blank(prizeCode: string, hole: number): Row {
  return { prizeCode, holeNumber: hole, playerId: '', measurement: '' };
}

function onRowChange(prizeCode: string, hole: number, index: number) {
  dirty.value = true;
  const list = rows.value[key(prizeCode, hole)];
  // Typing into the last row grows the block, so a flight of four is four
  // keystrokes-and-tab, not four clicks on "add".
  if (index === list.length - 1 && (list[index].playerId || list[index].measurement)) {
    list.push(blank(prizeCode, hole));
  }
}

function removeRow(prizeCode: string, hole: number, index: number) {
  rows.value[key(prizeCode, hole)].splice(index, 1);
  dirty.value = true;
}

const playersById = computed(() => new Map(props.players.map((p) => [p.id, p])));

/** Best measurement on a hole so far — the leader, not the winner. */
function leader(prizeCode: string, hole: number): Row | null {
  const spec = props.rules.technicalPrizes.find((p) => p.code === prizeCode);
  const filled = rowsFor(prizeCode, hole).filter((r) => r.playerId && r.measurement !== '');
  if (filled.length === 0 || !spec) return null;
  return filled.reduce((best, r) =>
    spec.kind === 'NEAREST_TO_PIN'
      ? Number(r.measurement) < Number(best.measurement)
        ? r
        : best
      : Number(r.measurement) > Number(best.measurement)
        ? r
        : best,
  );
}

function isLeader(prizeCode: string, hole: number, row: Row): boolean {
  const best = leader(prizeCode, hole);
  return best !== null && best === row;
}

function save() {
  const entries: TechnicalEntry[] = Object.values(rows.value)
    .flat()
    .filter((r) => r.playerId && r.measurement !== '' && Number.isFinite(Number(r.measurement)))
    .map((r) => ({
      tournamentPlayerId: r.playerId,
      prizeCode: r.prizeCode,
      holeNumber: r.holeNumber,
      measurement: Number(r.measurement),
    }));
  emit('save', entries);
  dirty.value = false;
}
</script>

<template>
  <div class="tech">
    <p class="hint">
      Nhập thành tích từ bảng ghi ngoài sân. Ô sáng là người dẫn đầu hố đó —
      <strong>chưa phải người nhận giải</strong>: ai đã có giải nhóm hoặc giải
      kỹ thuật khác sẽ nhường lại, xét ở tab Kết quả.
    </p>

    <section v-for="spec in rules.technicalPrizes" :key="spec.code" class="card">
      <h3 class="card-title">
        {{ spec.label }}
        <span class="sub">
          {{ spec.kind === 'NEAREST_TO_PIN' ? 'gần cờ nhất' : 'phát xa nhất' }} ·
          đơn vị {{ spec.unit }}
        </span>
      </h3>

      <div class="holes">
        <div v-for="hole in spec.holes" :key="hole" class="hole">
          <h4 class="hole-title">
            Hố {{ hole }}
            <span class="par">par {{ rules.holePars[hole - 1] }}</span>
          </h4>

          <div
            v-for="(row, i) in rowsFor(spec.code, hole)"
            :key="i"
            class="row"
            :class="{ 'is-leader': isLeader(spec.code, hole, row) }"
          >
            <select
              v-model="row.playerId"
              class="input"
              :aria-label="`${spec.label} hố ${hole} golfer`"
              @change="onRowChange(spec.code, hole, i)"
            >
              <option value="">— Chọn golfer —</option>
              <option v-for="p in players" :key="p.id" :value="p.id">
                {{ p.displayName }}<span v-if="p.flightNumber"> (FLY {{ p.flightNumber }})</span>
              </option>
            </select>

            <input
              v-model="row.measurement"
              class="input input-sm"
              inputmode="decimal"
              :placeholder="spec.unit"
              :aria-label="`${spec.label} hố ${hole} thành tích`"
              @input="onRowChange(spec.code, hole, i)"
            />

            <button
              v-if="row.playerId || row.measurement"
              type="button"
              class="btn-link"
              @click="removeRow(spec.code, hole, i)"
            >
              ×
            </button>
            <span v-else class="spacer"></span>
          </div>

          <p v-if="leader(spec.code, hole)" class="leading">
            Dẫn đầu: {{ playersById.get(leader(spec.code, hole)!.playerId)?.displayName }} —
            {{ leader(spec.code, hole)!.measurement }} {{ spec.unit }}
          </p>
        </div>
      </div>
    </section>

    <div class="actions">
      <button type="button" class="btn-primary" :disabled="!dirty || saving" @click="save">
        {{ saving ? 'Đang lưu…' : 'Lưu thành tích' }}
      </button>
    </div>
  </div>
</template>

<style scoped>
.tech { display: flex; flex-direction: column; gap: 14px; }
.hint { margin: 0; font-size: 12px; color: var(--muted); }

.card {
  border: 1px solid var(--outline-variant);
  border-radius: 8px;
  padding: 14px 16px;
  background: var(--surface-container-lowest);
}
.card-title { margin: 0 0 12px; font-size: 14px; font-weight: 700; color: var(--on-surface); }
.sub { margin-left: 8px; font-size: 12px; font-weight: 400; color: var(--muted); }

.holes { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 14px; }
.hole { border: 1px solid var(--outline-variant); border-radius: 6px; padding: 10px; }
.hole-title { margin: 0 0 8px; font-size: 13px; font-weight: 700; color: var(--on-surface); }
.par { margin-left: 6px; font-size: 11px; font-weight: 400; color: var(--muted); }

.row {
  display: grid;
  grid-template-columns: 1fr 84px 22px;
  gap: 6px;
  align-items: center;
  padding: 3px 4px;
  border-radius: 5px;
}
.row.is-leader { background: rgba(110, 231, 168, 0.12); }
.spacer { display: block; }

.input {
  padding: 5px 7px;
  border: 1px solid var(--outline-variant);
  border-radius: 5px;
  background: var(--surface-container-lowest);
  color: var(--on-surface);
  color-scheme: dark;
  font-size: 12px;
  width: 100%;
}
.input-sm { text-align: right; font-variant-numeric: tabular-nums; }

.leading { margin: 8px 0 0; font-size: 11px; color: #6ee7a8; }

.btn-link {
  border: none;
  background: none;
  color: var(--muted);
  font-size: 15px;
  cursor: pointer;
  padding: 0;
}
.btn-link:hover { color: #fca5a5; }

.actions { display: flex; gap: 12px; }
.btn-primary {
  padding: 9px 20px;
  border: none;
  border-radius: 6px;
  background: var(--primary);
  color: #fff;
  font-weight: 600;
  cursor: pointer;
}
.btn-primary:disabled { opacity: 0.45; cursor: default; }
</style>
