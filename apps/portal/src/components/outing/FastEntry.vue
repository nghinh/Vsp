<script setup lang="ts">
import { golferLabel } from '@/lib/enum-labels';
/**
 * The whole field on one screen: one number each.
 *
 * The hole-by-hole grid is the accurate way and it is not always the right
 * one. Forty-four players is 792 numbers, and on the day nobody has time for
 * 792 numbers — what the organisers need first is +/- against handicap, which
 * needs exactly one: the round's gross.
 *
 * So this is every golfer at once, sorted the way the cards come in, with a
 * single input per row and the net computing as it is typed. Enter or ↓ drops
 * to the next player; that is the entire interaction. Forty-four keystrokes
 * and a tab key gets a full prize table.
 *
 * The two extra columns are there because the fast path loses something real.
 * Birdies and eagles can be counted from eighteen hole scores and from nothing
 * else, and the club gives prizes for them — so on this path the flight's own
 * count is typed. Both are optional and most rows leave them blank.
 */
import { computed, nextTick, ref, watch } from 'vue';

import type { OutingPlayer, OutingRules, ScoreEntry } from '@/api/outing';

const props = defineProps<{
  players: OutingPlayer[];
  rules: OutingRules;
  saving: boolean;
}>();

const emit = defineEmits<{ (e: 'save', entries: ScoreEntry[]): void }>();

const coursePar = computed(() => props.rules.holePars.reduce((a, b) => a + b, 0));

type Draft = { total: number | null; birdies: number | null; eagles: number | null };
const draft = ref<Record<string, Draft>>({});
const dirty = ref<Set<string>>(new Set());

function seed() {
  const next: Record<string, Draft> = {};
  for (const p of props.players) {
    // A row mid-edit keeps its keystrokes; re-seeding it would drop them.
    if (dirty.value.has(p.id) && draft.value[p.id]) {
      next[p.id] = draft.value[p.id];
      continue;
    }
    next[p.id] = {
      total: p.grossTotal ?? sumHoles(p),
      birdies: p.birdieCount ?? null,
      eagles: p.eagleCount ?? null,
    };
  }
  draft.value = next;
}

/** A card entered hole by hole still shows its total here, read-only. */
function sumHoles(p: OutingPlayer): number | null {
  const holes = p.holeScores;
  if (!holes || holes.length !== props.rules.holePars.length) return null;
  if (holes.some((h) => h == null || h === 0)) return null;
  return holes.reduce<number>((sum, h) => sum + (h ?? 0), 0);
}

watch(() => props.players, seed, { immediate: true });

/** True when this player's round came from the eighteen holes, not this screen. */
function fromHoles(p: OutingPlayer): boolean {
  return sumHoles(p) !== null;
}

// ─── Order ────────────────────────────────────────────────────────────────

const sortBy = ref<'flight' | 'name' | 'division'>('flight');

const ordered = computed(() => {
  const rows = [...props.players];
  if (sortBy.value === 'name') {
    return rows.sort((a, b) => (a.displayName ?? '').localeCompare(b.displayName ?? '', 'vi'));
  }
  if (sortBy.value === 'division') {
    return rows.sort(
      (a, b) =>
        (a.divisionCode ?? 'Z').localeCompare(b.divisionCode ?? 'Z') ||
        (a.playingHandicap ?? 99) - (b.playingHandicap ?? 99),
    );
  }
  return rows.sort(
    (a, b) =>
      (a.flightNumber ?? 99) - (b.flightNumber ?? 99) ||
      (a.displayName ?? '').localeCompare(b.displayName ?? '', 'vi'),
  );
});

// ─── Live arithmetic ──────────────────────────────────────────────────────

function net(p: OutingPlayer): number | null {
  const total = draft.value[p.id]?.total;
  if (total == null || p.playingHandicap == null) return null;
  return total - p.playingHandicap;
}

function toPar(p: OutingPlayer): number | null {
  const n = net(p);
  return n == null ? null : n - coursePar.value;
}

/** What the prize is judged on: to-par after the configured floor. */
function judging(p: OutingPlayer): number | null {
  const d = toPar(p);
  if (d == null) return null;
  return props.rules.judgingFloor == null ? d : Math.max(d, props.rules.judgingFloor);
}

/**
 * True when the floor is doing the work.
 *
 * Without this the column is a mystery: a net of 66 and a net of 72 both read
 * "−3" and there is nothing on screen to say why. Worse, the rules expect a
 * good part of the field to reach the floor — that is what the handicap
 * tie-break is for — so a column of identical −3s is the normal case and looks
 * exactly like a broken calculation.
 */
function floored(p: OutingPlayer): boolean {
  const raw = toPar(p);
  return raw != null && props.rules.judgingFloor != null && raw < props.rules.judgingFloor;
}

function signed(n: number | null): string {
  if (n == null) return '—';
  return n > 0 ? `+${n}` : String(n);
}

/**
 * A total that cannot be a round of golf.
 *
 * The bound used to be "at least one stroke per hole", which let 18, 20 and 33
 * through — and those float straight past the judging floor and print −3, so a
 * mistyped column looks like a full field of winners. Nobody goes fifteen under
 * par at a club outing, so anything below that is a typo, not a score.
 *
 * A transposed 89 typed as 98 is still invisible here and always will be; this
 * only catches what is impossible, not what is merely wrong.
 */
function implausible(p: OutingPlayer): boolean {
  const t = draft.value[p.id]?.total;
  if (t == null) return false;
  return t < coursePar.value - 15 || t > coursePar.value + 80;
}

// ─── Keyboard ─────────────────────────────────────────────────────────────

const rootRef = ref<HTMLElement | null>(null);

function move(index: number, delta: number) {
  const next = ordered.value[index + delta];
  if (!next) return;
  nextTick(() => {
    const el = rootRef.value?.querySelector<HTMLInputElement>(`#fast-${CSS.escape(next.id)}`);
    el?.focus();
    el?.select();
  });
}

function onKey(index: number, event: KeyboardEvent) {
  if (event.key === 'Enter' || event.key === 'ArrowDown') {
    event.preventDefault();
    move(index, 1);
  } else if (event.key === 'ArrowUp') {
    event.preventDefault();
    move(index, -1);
  }
}

function setNumber(id: string, field: keyof Draft, raw: string) {
  draft.value[id][field] = raw === '' ? null : Number(raw);
  dirty.value.add(id);
}

// ─── Saving ───────────────────────────────────────────────────────────────

const hasUnsaved = computed(() => dirty.value.size > 0);

function save() {
  const entries: ScoreEntry[] = [...dirty.value]
    .filter((id) => draft.value[id])
    .map((id) => ({
      tournamentPlayerId: id,
      grossTotal: draft.value[id].total,
      birdieCount: draft.value[id].birdies,
      eagleCount: draft.value[id].eagles,
    }));
  if (entries.length === 0) return;
  emit('save', entries);
  dirty.value = new Set();
}

const entered = computed(
  () => props.players.filter((p) => draft.value[p.id]?.total != null).length,
);
</script>

<template>
  <div ref="rootRef" class="fast">
    <div class="bar">
      <label class="sort">
        Sắp xếp
        <select v-model="sortBy" class="input input-sm">
          <option value="flight">Theo flight</option>
          <option value="name">Theo tên</option>
          <option value="division">Theo nhóm</option>
        </select>
      </label>

      <span class="progress">
        {{ entered }}/{{ players.length }} đã có tổng gậy
        <span v-if="hasUnsaved" class="unsaved">• chưa lưu</span>
        <span v-else-if="saving" class="muted">• đang lưu…</span>
      </span>
    </div>

    <p class="hint">
      Chỉ cần tổng gậy cả vòng. <kbd>Enter</kbd> hoặc <kbd>↓</kbd> xuống người
      kế tiếp. Birdie/Eagle chỉ nhập khi không có điểm từng hố — có đủ 18 hố thì
      hệ thống tự đếm.
    </p>

    <div class="table-scroll">
      <table class="table">
        <thead>
          <tr>
            <th class="num">FLY</th>
            <th>Golfer</th>
            <th>Nhóm</th>
            <th class="num">HDC</th>
            <th class="num">Tổng gậy</th>
            <th class="num">Net</th>
            <th class="num" title="Net so với par, chưa cắt sàn">So par</th>
            <th class="num" title="So par sau khi cắt sàn theo thể lệ — đây là số dùng xếp giải">Xét giải</th>
            <th class="num">Birdie</th>
            <th class="num">Eagle</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(p, i) in ordered" :key="p.id">
            <td class="num muted">{{ p.flightNumber ?? '—' }}</td>
            <td class="name">{{ golferLabel(p) }}</td>
            <td class="muted">{{ p.divisionCode ?? '—' }}</td>
            <td class="num muted">{{ p.playingHandicap ?? '—' }}</td>

            <td class="num">
              <!-- A card already entered hole by hole shows its own sum and is
                   not editable here: two ways to set one number is two ways to
                   disagree about it. -->
              <span v-if="fromHoles(p)" class="from-holes" title="Tính từ điểm 18 hố">
                {{ draft[p.id]?.total }}
              </span>
              <input
                v-else
                :id="`fast-${p.id}`"
                class="cell"
                :class="{ 'is-bad': implausible(p) }"
                inputmode="numeric"
                autocomplete="off"
                :value="draft[p.id]?.total ?? ''"
                :aria-label="`${golferLabel(p)} tổng gậy`"
                @keydown="onKey(i, $event)"
                @input="setNumber(p.id, 'total', ($event.target as HTMLInputElement).value)"
                @focus="($event.target as HTMLInputElement).select()"
              />
            </td>

            <td class="num strong">{{ net(p) ?? '—' }}</td>
            <td class="num" :class="{ muted: floored(p) }">{{ signed(toPar(p)) }}</td>
            <td class="num strong" :class="{ 'is-under': (judging(p) ?? 0) < 0 }">
              {{ signed(judging(p)) }}
              <span v-if="floored(p)" class="capped" title="Đã cắt sàn theo thể lệ">cắt</span>
            </td>

            <td class="num">
              <span v-if="fromHoles(p)" class="muted">tự đếm</span>
              <input
                v-else
                class="cell cell-xs"
                inputmode="numeric"
                autocomplete="off"
                :value="draft[p.id]?.birdies ?? ''"
                :aria-label="`${golferLabel(p)} số birdie`"
                @input="setNumber(p.id, 'birdies', ($event.target as HTMLInputElement).value)"
              />
            </td>
            <td class="num">
              <span v-if="fromHoles(p)" class="muted">tự đếm</span>
              <input
                v-else
                class="cell cell-xs"
                inputmode="numeric"
                autocomplete="off"
                :value="draft[p.id]?.eagles ?? ''"
                :aria-label="`${golferLabel(p)} số eagle`"
                @input="setNumber(p.id, 'eagles', ($event.target as HTMLInputElement).value)"
              />
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="actions">
      <button type="button" class="btn-primary" :disabled="!hasUnsaved || saving" @click="save">
        {{ saving ? 'Đang lưu…' : `Lưu ${dirty.size} thay đổi` }}
      </button>
      <span v-if="players.some(implausible)" class="warn">
        Có tổng gậy trông không hợp lý — ô viền đỏ.
      </span>
    </div>
  </div>
</template>

<style scoped>
.fast { display: flex; flex-direction: column; gap: 10px; }

.bar { display: flex; align-items: center; gap: 12px; }
.sort { display: flex; align-items: center; gap: 6px; font-size: 12px; color: var(--muted); }
.progress { margin-left: auto; font-size: 13px; color: var(--muted); }
.unsaved { color: #f0b429; font-weight: 600; }

.hint { margin: 0; font-size: 12px; color: var(--muted); }
.hint kbd {
  padding: 1px 5px;
  border: 1px solid var(--outline-variant);
  border-radius: 4px;
  background: var(--surface-container);
  font-family: inherit;
  font-size: 11px;
}

.table-scroll {
  max-height: 62vh;
  overflow: auto;
  border: 1px solid var(--outline-variant);
  border-radius: 8px;
}
.table { width: 100%; border-collapse: collapse; font-size: 13px; }
.table th, .table td { padding: 4px 10px; border-bottom: 1px solid var(--outline-variant); text-align: left; }
.table thead th {
  position: sticky;
  top: 0;
  background: var(--surface-container);
  color: var(--muted);
  font-size: 11px;
  font-weight: 600;
  z-index: 1;
}
.num { text-align: right; font-variant-numeric: tabular-nums; }
.name { font-weight: 600; color: var(--on-surface); white-space: nowrap; }
.muted { color: var(--muted); }
.strong { font-weight: 700; }
.is-under { color: #6ee7a8; }
.capped {
  margin-left: 4px;
  padding: 0 4px;
  border-radius: 3px;
  background: rgba(240, 180, 41, 0.18);
  color: #f0c869;
  font-size: 10px;
  font-weight: 600;
}

.cell {
  width: 62px;
  padding: 4px 6px;
  border: 1px solid var(--outline-variant);
  border-radius: 5px;
  background: var(--surface-container-lowest);
  color: var(--on-surface);
  text-align: right;
  font-size: 14px;
  font-variant-numeric: tabular-nums;
}
.cell-xs { width: 46px; font-size: 13px; }
.cell:focus {
  outline: none;
  border-color: var(--primary);
  box-shadow: 0 0 0 2px rgba(246, 96, 24, 0.25);
}
.cell.is-bad { border-color: #b91c1c; color: #fca5a5; }
.from-holes { color: var(--muted); font-weight: 600; }

.actions { display: flex; align-items: center; gap: 12px; }
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
.warn { font-size: 12px; color: #f0c869; }
</style>
