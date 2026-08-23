<script setup lang="ts">
import { golferLabel } from '@/lib/enum-labels';
/**
 * Typing eleven scorecards before the buffet ends.
 *
 * This is the screen the whole outing feature exists for. The club's own
 * timetable puts prize-giving at 11h30 and the last flight in not long before
 * it, so the gap between "here are the cards" and "here are the winners" is a
 * few minutes. Forty-four players is up to 792 numbers.
 *
 * What that buys, in order of how much time it saves:
 *
 *  - **One flight on screen at a time.** Four rows against a paper card with
 *    four rows. The typist's eye never has to search, and two people can work
 *    two flights at once without touching each other's rows.
 *  - **A digit is a keystroke.** Type 4 and the cursor is already on the next
 *    hole. No Tab, no Enter, no mouse. A hole of 10 or more needs the second
 *    digit, so a leading 1 waits — see `onDigit`.
 *  - **The total is a column too.** A card that only has a total typed still
 *    ranks. Waiting for all eighteen numbers from all eleven flights before
 *    anything appears on the board is what makes this slow.
 *  - **Saving is automatic and per flight.** Nobody has to remember to press
 *    anything, and a save is one request rather than seventy-two.
 *
 * The running net is shown live because it is the number the organisers are
 * actually watching, and a typo of 7 for 4 is far easier to spot against a
 * plausible net than against a column of digits.
 */
import { computed, nextTick, ref, watch } from 'vue';

import type { OutingPlayer, OutingRules, ScoreEntry } from '@/api/outing';

const props = defineProps<{
  players: OutingPlayer[];
  rules: OutingRules;
  saving: boolean;
}>();

const emit = defineEmits<{
  (e: 'save', entries: ScoreEntry[]): void;
}>();

const holeCount = computed(() => props.rules.holePars.length);
const holes = computed(() => Array.from({ length: holeCount.value }, (_, i) => i + 1));

/** Flights in sheet order, with unassigned players last under a null key. */
const flights = computed(() => {
  const numbers = new Set<number | null>();
  props.players.forEach((p) => numbers.add(p.flightNumber));
  return [...numbers].sort((a, b) => {
    if (a === null) return 1;
    if (b === null) return -1;
    return a - b;
  });
});

const selectedFlight = ref<number | null>(flights.value[0] ?? null);

const flightPlayers = computed(() =>
  props.players.filter((p) => p.flightNumber === selectedFlight.value),
);

// ─── The editing buffer ──────────────────────────────────────────────────
//
// Kept separate from `props.players` so that a save round-trip cannot pull a
// digit out from under the person typing. Keyed by player id.

type Draft = { holes: (number | null)[]; total: number | null };
const draft = ref<Record<string, Draft>>({});
const dirty = ref<Set<string>>(new Set());

function seed() {
  const next: Record<string, Draft> = {};
  for (const p of props.players) {
    // A row being edited keeps what is in it; anything else takes the server's
    // version. Re-seeding a dirty row would discard unsaved keystrokes.
    if (dirty.value.has(p.id) && draft.value[p.id]) {
      next[p.id] = draft.value[p.id];
      continue;
    }
    const source = p.holeScores ?? [];
    next[p.id] = {
      holes: Array.from({ length: holeCount.value }, (_, i) => {
        const v = source[i];
        return v == null || v === 0 ? null : v;
      }),
      total: p.grossTotal ?? null,
    };
  }
  draft.value = next;
}

watch(() => props.players, seed, { immediate: true, deep: false });
watch(holeCount, seed);

// ─── Live arithmetic ─────────────────────────────────────────────────────

function holesFilled(id: string): number {
  return draft.value[id]?.holes.filter((h) => h != null).length ?? 0;
}

function holeSum(id: string): number {
  return (draft.value[id]?.holes ?? []).reduce<number>((sum, h) => sum + (h ?? 0), 0);
}

/** What this card would count as: the eighteen holes, else the typed total. */
function gross(id: string): number | null {
  if (holesFilled(id) === holeCount.value) return holeSum(id);
  return draft.value[id]?.total ?? null;
}

function net(player: OutingPlayer): number | null {
  const g = gross(player.id);
  if (g == null || player.playingHandicap == null) return null;
  return g - player.playingHandicap;
}

const coursePar = computed(() => props.rules.holePars.reduce((a, b) => a + b, 0));

/** Net against par, before the floor. */
function toPar(player: OutingPlayer): number | null {
  const n = net(player);
  if (n == null) return null;
  return n - coursePar.value;
}

/**
 * The number the prize is actually decided on.
 *
 * This screen used to show only the raw to-par figure while the fast list
 * showed the floored one, under different headings — so the same card read
 * differently depending on which screen you had open, and neither said which
 * number the prize used.
 */
function judging(player: OutingPlayer): number | null {
  const d = toPar(player);
  if (d == null) return null;
  return props.rules.judgingFloor == null ? d : Math.max(d, props.rules.judgingFloor);
}

/** True when the floor is doing the work, so the figure can say so. */
function floored(player: OutingPlayer): boolean {
  const raw = toPar(player);
  return raw != null && props.rules.judgingFloor != null && raw < props.rules.judgingFloor;
}

function signed(n: number | null): string {
  if (n == null) return '—';
  return n > 0 ? `+${n}` : String(n);
}

/** Colour a hole by how it played, so a mistyped 7 stands out from a 4. */
function holeClass(id: string, hole: number): string {
  const v = draft.value[id]?.holes[hole - 1];
  if (v == null) return '';
  const over = v - props.rules.holePars[hole - 1];
  if (over <= -2) return 'is-eagle';
  if (over === -1) return 'is-birdie';
  if (over === 0) return 'is-par';
  if (over >= 3) return 'is-blowup';
  return '';
}

// ─── Keyboard ────────────────────────────────────────────────────────────

const gridRef = ref<HTMLElement | null>(null);

function cellId(playerId: string, hole: number): string {
  return `sc-${playerId}-${hole}`;
}

function focusCell(playerId: string, hole: number) {
  const el = gridRef.value?.querySelector<HTMLInputElement>(`#${CSS.escape(cellId(playerId, hole))}`);
  el?.focus();
  el?.select();
}

function move(rowIndex: number, hole: number, dRow: number, dHole: number) {
  const rows = flightPlayers.value;
  let r = rowIndex + dRow;
  let h = hole + dHole;

  // Running off the end of a row drops to the next player's first hole; that
  // is the order a paper card is read in when one player's line is finished.
  if (h > holeCount.value) {
    h = 1;
    r += 1;
  } else if (h < 1) {
    h = holeCount.value;
    r -= 1;
  }
  if (r < 0 || r >= rows.length) return;

  nextTick(() => focusCell(rows[r].id, h));
}

/**
 * A digit lands and, usually, the cursor moves on.
 *
 * The exception is a leading 1: it could be the start of 10 through 19, so the
 * cursor waits for a second keystroke or an arrow. Every other digit ends the
 * hole immediately, because no golfer takes twenty strokes and pausing on all
 * nine of them would double the typing.
 *
 * A hole in one therefore needs one extra key. That is the right side of the
 * trade — there are four aces a decade and 792 numbers an outing.
 */
function onDigit(playerId: string, rowIndex: number, hole: number, event: KeyboardEvent) {
  const key = event.key;

  if (key >= '0' && key <= '9') {
    event.preventDefault();
    const d = draft.value[playerId];
    const current = d.holes[hole - 1];
    const digit = Number(key);

    // A second digit within the same cell extends the first: 1 then 2 is 12.
    const extended = current != null && current >= 1 && current <= 9 && justTyped.value === cellId(playerId, hole)
      ? current * 10 + digit
      : digit;

    d.holes[hole - 1] = extended === 0 ? null : extended;
    dirty.value.add(playerId);
    justTyped.value = cellId(playerId, hole);

    // Wait on a bare 1; anything else is finished.
    if (extended !== 1) {
      justTyped.value = null;
      move(rowIndex, hole, 0, 1);
    }
    return;
  }

  justTyped.value = null;

  switch (key) {
    case 'Backspace':
    case 'Xoá':
      event.preventDefault();
      draft.value[playerId].holes[hole - 1] = null;
      dirty.value.add(playerId);
      break;
    case 'ArrowRight':
    case 'Tab':
      if (!event.shiftKey) {
        event.preventDefault();
        move(rowIndex, hole, 0, 1);
      } else {
        event.preventDefault();
        move(rowIndex, hole, 0, -1);
      }
      break;
    case 'ArrowLeft':
      event.preventDefault();
      move(rowIndex, hole, 0, -1);
      break;
    case 'ArrowDown':
    case 'Enter':
      event.preventDefault();
      move(rowIndex, hole, 1, 0);
      break;
    case 'ArrowUp':
      event.preventDefault();
      move(rowIndex, hole, -1, 0);
      break;
    default:
      break;
  }
}

/** Tracks the cell whose digit could still be extended to two. */
const justTyped = ref<string | null>(null);

// ─── Saving ──────────────────────────────────────────────────────────────

function pending(): ScoreEntry[] {
  return [...dirty.value]
    .filter((id) => draft.value[id])
    .map((id) => ({
      tournamentPlayerId: id,
      grossTotal: draft.value[id].total,
      holeScores: draft.value[id].holes,
    }));
}

function save() {
  const entries = pending();
  if (entries.length === 0) return;
  emit('save', entries);
  dirty.value = new Set();
}

// Leaving a flight saves it. Nobody should have to remember a button while
// reading numbers off a card, and an unsaved flight is a flight that is not on
// the board.
watch(selectedFlight, (_next, previous) => {
  if (previous !== undefined) save();
});

/** True while this flight has keystrokes the server has not seen. */
const hasUnsaved = computed(() =>
  flightPlayers.value.some((p) => dirty.value.has(p.id)),
);

const flightProgress = computed(() => {
  const done = props.players.filter((p) => p.hasScore).length;
  return { done, total: props.players.length };
});

/** Flights with every card in, for the picker's tick marks. */
function flightComplete(flight: number | null): boolean {
  const inFlight = props.players.filter((p) => p.flightNumber === flight);
  return inFlight.length > 0 && inFlight.every((p) => p.hasScore);
}

defineExpose({ save });
</script>

<template>
  <div class="score-grid">
    <!-- ─── Flight picker ──────────────────────────────────────────── -->
    <div class="flight-bar">
      <button
        v-for="f in flights"
        :key="f ?? 'none'"
        type="button"
        class="flight-chip"
        :class="{ 'is-active': f === selectedFlight, 'is-done': flightComplete(f) }"
        @click="selectedFlight = f"
      >
        {{ f === null ? 'Chưa xếp' : `FLY ${f}` }}
        <span v-if="flightComplete(f)" aria-hidden="true">✓</span>
      </button>

      <span class="progress">
        {{ flightProgress.done }}/{{ flightProgress.total }} golfer đã nhập
        <span v-if="hasUnsaved" class="unsaved">• chưa lưu</span>
        <span v-else-if="saving" class="saving">• đang lưu…</span>
      </span>
    </div>

    <p class="hint">
      Gõ số là con trỏ tự sang hố kế tiếp. Số <kbd>1</kbd> dừng lại để gõ tiếp
      (10–19). <kbd>←</kbd> <kbd>→</kbd> đổi hố, <kbd>↑</kbd> <kbd>↓</kbd> đổi
      người, <kbd>Enter</kbd> xuống dòng. Chuyển flight là tự lưu.
    </p>

    <!-- ─── The card ───────────────────────────────────────────────── -->
    <div ref="gridRef" class="grid-scroll">
      <table class="grid">
        <thead>
          <tr>
            <th class="col-player">Golfer</th>
            <th class="col-hdc" title="Handicap xét giải">HDC</th>
            <th v-for="h in holes" :key="h" class="col-hole">
              {{ h }}
              <span class="par">{{ rules.holePars[h - 1] }}</span>
            </th>
            <th class="col-total" title="Tổng gậy — nhập trực tiếp nếu chưa có chi tiết từng hố">
              Tổng
            </th>
            <th class="col-net">Net</th>
            <th class="col-topar" title="Net so với par, chưa cắt sàn">So par</th>
            <th class="col-topar" title="Số dùng xếp giải, sau khi cắt sàn">Xét giải</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(p, rowIndex) in flightPlayers" :key="p.id">
            <th class="col-player" scope="row">
              {{ golferLabel(p) }}
              <span v-if="p.divisionCode" class="division">{{ p.divisionCode }}</span>
            </th>
            <td class="col-hdc">{{ p.playingHandicap ?? '—' }}</td>

            <td v-for="h in holes" :key="h" class="col-hole" :class="holeClass(p.id, h)">
              <input
                :id="cellId(p.id, h)"
                class="cell"
                inputmode="numeric"
                autocomplete="off"
                :value="draft[p.id]?.holes[h - 1] ?? ''"
                :aria-label="`${golferLabel(p)} hố ${h}`"
                @keydown="onDigit(p.id, rowIndex, h, $event)"
                @focus="($event.target as HTMLInputElement).select()"
              />
            </td>

            <td class="col-total">
              <input
                v-if="holesFilled(p.id) < holeCount"
                class="cell cell-total"
                inputmode="numeric"
                autocomplete="off"
                :value="draft[p.id]?.total ?? ''"
                :aria-label="`${golferLabel(p)} tổng gậy`"
                @input="
                  draft[p.id].total =
                    ($event.target as HTMLInputElement).value === ''
                      ? null
                      : Number(($event.target as HTMLInputElement).value);
                  dirty.add(p.id);
                "
              />
              <!-- Every hole is in, so the total is the card's own sum and
                   typing over it could only introduce a disagreement. -->
              <span v-else class="computed-total">{{ holeSum(p.id) }}</span>
            </td>

            <td class="col-net">{{ net(p) ?? '—' }}</td>
            <td class="col-topar">{{ signed(toPar(p)) }}</td>
            <td class="col-topar" :class="{ 'is-under': (judging(p) ?? 0) < 0 }">
              {{ signed(judging(p)) }}
              <span v-if="floored(p)" class="capped" title="Đã cắt sàn theo thể lệ">cắt</span>
            </td>
          </tr>

          <tr v-if="flightPlayers.length === 0">
            <td :colspan="holeCount + 6" class="empty">
              Flight này chưa có golfer nào. Nhập danh sách ở tab “Danh sách”.
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="actions">
      <button type="button" class="btn-primary" :disabled="!hasUnsaved || saving" @click="save">
        {{ saving ? 'Đang lưu…' : 'Lưu flight này' }}
      </button>
      <span class="actions-note">Hoặc chỉ cần chuyển sang flight khác — tự lưu.</span>
    </div>
  </div>
</template>

<style scoped>
.score-grid {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

/* ─── Flight picker ───────────────────────────────────────────────── */
.flight-bar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 6px;
}
.flight-chip {
  padding: 6px 12px;
  border: 1px solid var(--outline-variant);
  border-radius: 999px;
  background: var(--surface-container-lowest);
  color: var(--on-surface);
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
}
.flight-chip.is-active {
  background: var(--primary);
  border-color: var(--primary);
  color: #fff;
}
.flight-chip.is-done:not(.is-active) {
  border-color: #2f6f4a;
  color: #6ee7a8;
}
.progress {
  margin-left: auto;
  font-size: 13px;
  color: var(--muted);
}
.unsaved {
  color: #f0b429;
  font-weight: 600;
}
.saving {
  color: var(--muted);
}

.hint {
  margin: 0;
  font-size: 12px;
  color: var(--muted);
}
.hint kbd {
  padding: 1px 5px;
  border: 1px solid var(--outline-variant);
  border-radius: 4px;
  background: var(--surface-container);
  font-family: inherit;
  font-size: 11px;
}

/* ─── The card ────────────────────────────────────────────────────── */
.grid-scroll {
  overflow-x: auto;
  border: 1px solid var(--outline-variant);
  border-radius: 8px;
}
.grid {
  border-collapse: collapse;
  width: 100%;
  font-size: 13px;
}
.grid th,
.grid td {
  border-bottom: 1px solid var(--outline-variant);
  padding: 0;
  text-align: center;
}
.grid thead th {
  padding: 6px 4px;
  background: var(--surface-container);
  color: var(--muted);
  font-size: 11px;
  font-weight: 600;
  position: sticky;
  top: 0;
}
.par {
  display: block;
  font-weight: 400;
  opacity: 0.6;
}

.col-player {
  text-align: left;
  padding: 6px 10px;
  white-space: nowrap;
  font-weight: 600;
  color: var(--on-surface);
  /* The name stays visible while the eighteen holes scroll under it. */
  position: sticky;
  left: 0;
  background: var(--surface-container-lowest);
  z-index: 1;
}
.division {
  margin-left: 6px;
  padding: 1px 6px;
  border-radius: 999px;
  background: var(--surface-container-high);
  font-size: 10px;
  color: var(--muted);
}
.col-hdc {
  color: var(--muted);
  min-width: 34px;
}

.cell {
  width: 34px;
  height: 32px;
  border: none;
  background: transparent;
  color: var(--on-surface);
  text-align: center;
  font-size: 14px;
  font-variant-numeric: tabular-nums;
  outline: none;
}
.cell:focus {
  background: rgba(246, 96, 24, 0.22);
  box-shadow: inset 0 0 0 2px var(--primary);
}
.cell-total {
  width: 46px;
  font-weight: 600;
}
.computed-total {
  display: inline-block;
  width: 46px;
  font-weight: 600;
  font-variant-numeric: tabular-nums;
}

/* How the hole played, so a mistyped digit is visible at a glance. */
.is-birdie .cell { color: #6ee7a8; font-weight: 700; }
.is-eagle .cell { color: #ffd166; font-weight: 700; }
.is-par .cell { color: var(--on-surface); }
.is-blowup .cell { color: #fca5a5; }

.col-net,
.col-topar {
  min-width: 44px;
  font-weight: 600;
  font-variant-numeric: tabular-nums;
}
.col-topar.is-under {
  color: #6ee7a8;
}
.capped {
  margin-left: 3px;
  padding: 0 3px;
  border-radius: 3px;
  background: rgba(240, 180, 41, 0.18);
  color: #f0c869;
  font-size: 9px;
  font-weight: 600;
}

.empty {
  padding: 20px;
  color: var(--muted);
}

/* ─── Actions ─────────────────────────────────────────────────────── */
.actions {
  display: flex;
  align-items: center;
  gap: 12px;
}
.btn-primary {
  padding: 8px 18px;
  border: none;
  border-radius: 6px;
  background: var(--primary);
  color: #fff;
  font-weight: 600;
  cursor: pointer;
}
.btn-primary:disabled {
  opacity: 0.45;
  cursor: default;
}
.actions-note {
  font-size: 12px;
  color: var(--muted);
}
</style>
