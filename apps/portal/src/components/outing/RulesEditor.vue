<script setup lang="ts">
/**
 * The outing's rules, as a form.
 *
 * Every number on the club's "Thể lệ thi đấu" sheet is editable here and none
 * of it is compiled in. That is not gold-plating: the club's own two sheets
 * already disagree about where nhóm A ends, the handicap cap is a house rule,
 * the daily-CAP scale is the club's own invention and matches no standard, and
 * the previous outing ran seven flights on a different course. A rule that
 * needs a release to change is a rule that gets overridden by hand in a
 * spreadsheet instead.
 */
import { computed, ref, watch } from 'vue';

import type { CapBand, Division, OutingRules, TechnicalPrizeSpec } from '@/api/outing';

const props = defineProps<{ rules: OutingRules; saving: boolean }>();
const emit = defineEmits<{ (e: 'save', rules: OutingRules): void }>();

/** Edited locally, so a half-finished change never reaches the server. */
const draft = ref<OutingRules>(clone(props.rules));
watch(() => props.rules, (r) => (draft.value = clone(r)));

function clone(r: OutingRules): OutingRules {
  return JSON.parse(JSON.stringify(r)) as OutingRules;
}

const coursePar = computed(() => draft.value.holePars.reduce((a, b) => a + b, 0));

/** Pars as an editable line, because typing 18 boxes is worse than one field. */
const parsText = ref(props.rules.holePars.join(' '));
watch(() => props.rules, (r) => (parsText.value = r.holePars.join(' ')));

function applyPars() {
  const parsed = parsText.value
    .split(/[\s,]+/)
    .filter((s) => s !== '')
    .map((s) => Number.parseInt(s, 10))
    .filter((n) => Number.isFinite(n));
  if (parsed.length > 0) draft.value.holePars = parsed;
}

const capEnabled = computed({
  get: () => draft.value.handicapCap !== null,
  set: (on: boolean) => {
    draft.value.handicapCap = on ? { above: 36, playOff: 35 } : null;
  },
});

const floorEnabled = computed({
  get: () => draft.value.judgingFloor !== null,
  set: (on: boolean) => {
    draft.value.judgingFloor = on ? -3 : null;
  },
});

const countbackText = computed({
  get: () => draft.value.countbackWindows.join(', '),
  set: (v: string) => {
    draft.value.countbackWindows = v
      .split(/[\s,]+/)
      .filter((s) => s !== '')
      .map((s) => Number.parseInt(s, 10))
      .filter((n) => Number.isFinite(n) && n > 0);
  },
});

function addDivision() {
  const last = draft.value.divisions[draft.value.divisions.length - 1];
  draft.value.divisions.push({
    code: '',
    name: '',
    minHandicap: last ? last.maxHandicap + 1 : 0,
    maxHandicap: 54,
    prizeTitles: ['Nhất', 'Nhì', 'Ba'],
  });
}

function prizeTitlesText(d: Division): string {
  return d.prizeTitles.join(' | ');
}

function setPrizeTitles(d: Division, v: string) {
  d.prizeTitles = v.split('|').map((s) => s.trim()).filter((s) => s !== '');
}

function holesText(spec: TechnicalPrizeSpec): string {
  return spec.holes.join(', ');
}

function setHoles(spec: TechnicalPrizeSpec, v: string) {
  spec.holes = v
    .split(/[\s,]+/)
    .filter((s) => s !== '')
    .map((s) => Number.parseInt(s, 10))
    .filter((n) => Number.isFinite(n));
}

function bandLabel(b: CapBand): string {
  if (b.minOverPar === null) return `≤ ${b.maxOverPar}`;
  if (b.maxOverPar === null) return `≥ +${b.minOverPar}`;
  if (b.minOverPar === b.maxOverPar) {
    return b.minOverPar === 0 ? 'Par' : b.minOverPar > 0 ? `+${b.minOverPar}` : `${b.minOverPar}`;
  }
  return `${b.minOverPar >= 0 ? '+' : ''}${b.minOverPar} … +${b.maxOverPar}`;
}

/**
 * Problems the server would refuse, said here instead.
 *
 * The alternative is finding out at prize-giving that a technical prize points
 * at a hole the course does not have.
 */
const problems = computed(() => {
  const out: string[] = [];
  const holes = draft.value.holePars.length;

  if (holes === 0) out.push('Chưa có par cho hố nào.');
  draft.value.countbackWindows.forEach((w) => {
    if (w > holes) out.push(`Đếm ngược ${w} hố nhưng vòng chỉ có ${holes} hố.`);
  });
  draft.value.technicalPrizes.forEach((spec) => {
    spec.holes.forEach((h) => {
      if (h < 1 || h > holes) out.push(`${spec.label}: hố ${h} không có trên sân.`);
    });
  });
  draft.value.divisions.forEach((d) => {
    if (!d.code.trim()) out.push('Có nhóm chưa đặt mã.');
    if (d.minHandicap > d.maxHandicap) out.push(`Nhóm ${d.code}: HDC từ lớn hơn HDC đến.`);
  });

  // A gap between divisions is legal but silent: a golfer landing in it never
  // appears on any board.
  const sorted = [...draft.value.divisions].sort((a, b) => a.minHandicap - b.minHandicap);
  for (let i = 1; i < sorted.length; i++) {
    if (sorted[i].minHandicap > sorted[i - 1].maxHandicap + 1) {
      out.push(
        `HDC ${sorted[i - 1].maxHandicap + 1}–${sorted[i].minHandicap - 1} không thuộc nhóm nào.`,
      );
    }
  }
  return out;
});

function save() {
  applyPars();
  emit('save', clone(draft.value));
}
</script>

<template>
  <div class="rules">
    <p v-if="problems.length" class="problems">
      <span v-for="p in problems" :key="p" class="problem">{{ p }}</span>
    </p>

    <!-- ─── Course ─────────────────────────────────────────────────── -->
    <section class="card">
      <h3 class="card-title">Sân đấu</h3>
      <label class="label" for="r-pars">Par từng hố (cách nhau bởi dấu cách)</label>
      <input id="r-pars" v-model="parsText" class="input mono" @change="applyPars" />
      <p class="note">
        {{ draft.holePars.length }} hố · tổng par {{ coursePar }} ·
        par 3: {{ draft.holePars.filter((p) => p === 3).length }} ·
        par 5: {{ draft.holePars.filter((p) => p === 5).length }}
      </p>
    </section>

    <!-- ─── Divisions ──────────────────────────────────────────────── -->
    <section class="card">
      <h3 class="card-title">Chia nhóm &amp; giải nhóm</h3>
      <div class="table-scroll">
      <table class="table">
        <thead>
          <tr>
            <th>Mã</th>
            <th>Tên</th>
            <th class="num">HDC từ</th>
            <th class="num">đến</th>
            <th>Các giải (ngăn bằng “|”)</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(d, i) in draft.divisions" :key="i">
            <td><input v-model="d.code" class="input input-xs" /></td>
            <td><input v-model="d.name" class="input" /></td>
            <td><input v-model.number="d.minHandicap" type="number" class="input input-sm" /></td>
            <td><input v-model.number="d.maxHandicap" type="number" class="input input-sm" /></td>
            <td>
              <input
                :value="prizeTitlesText(d)"
                class="input"
                @change="setPrizeTitles(d, ($event.target as HTMLInputElement).value)"
              />
            </td>
            <td>
              <button type="button" class="btn-link" @click="draft.divisions.splice(i, 1)">Xoá</button>
            </td>
          </tr>
        </tbody>
      </table>
      </div>
      <button type="button" class="btn-link" @click="addDivision">+ Thêm nhóm</button>
    </section>

    <!-- ─── Judging ────────────────────────────────────────────────── -->
    <section class="card">
      <h3 class="card-title">Cách xét giải</h3>

      <div class="row">
        <label class="check">
          <input v-model="capEnabled" type="checkbox" />
          Cắt handicap
        </label>
        <template v-if="draft.handicapCap">
          <span class="inline">HDC trên</span>
          <input v-model.number="draft.handicapCap.above" type="number" class="input input-sm" />
          <span class="inline">tính là</span>
          <input v-model.number="draft.handicapCap.playOff" type="number" class="input input-sm" />
        </template>
      </div>

      <div class="row">
        <label class="check">
          <input v-model="floorEnabled" type="checkbox" />
          Cắt thành tích tối đa dưới HDC
        </label>
        <input
          v-if="draft.judgingFloor !== null"
          v-model.number="draft.judgingFloor"
          type="number"
          class="input input-sm"
        />
        <span v-if="draft.judgingFloor !== null" class="note inline">
          (−3 = “cắt đến âm 3”)
        </span>
      </div>

      <div class="row">
        <label class="label" for="r-cb">Đếm ngược — số hố cuối, theo thứ tự ưu tiên</label>
        <input id="r-cb" v-model="countbackText" class="input input-md mono" />
        <span class="note inline">9, 6, 3, 1 = 9 hố sau → 6 hố cuối → 3 hố cuối → hố cuối</span>
      </div>

      <div class="row">
        <label class="check">
          <input v-model="draft.onePrizePerPlayer" type="checkbox" />
          Mỗi golfer chỉ nhận tối đa 1 giải
        </label>
      </div>
    </section>

    <!-- ─── Daily CAP ──────────────────────────────────────────────── -->
    <section class="card">
      <h3 class="card-title">CAP ngày</h3>
      <div class="table-scroll">
      <table class="table">
        <thead>
          <tr>
            <th>Kết quả hố (so với par)</th>
            <th class="num">Từ</th>
            <th class="num">Đến</th>
            <th class="num">CAP</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(b, i) in draft.dailyCapBands" :key="i">
            <td class="mono">{{ bandLabel(b) }}</td>
            <td>
              <input
                :value="b.minOverPar ?? ''"
                type="number"
                class="input input-sm"
                placeholder="−∞"
                @input="b.minOverPar = ($event.target as HTMLInputElement).value === '' ? null : Number(($event.target as HTMLInputElement).value)"
              />
            </td>
            <td>
              <input
                :value="b.maxOverPar ?? ''"
                type="number"
                class="input input-sm"
                placeholder="+∞"
                @input="b.maxOverPar = ($event.target as HTMLInputElement).value === '' ? null : Number(($event.target as HTMLInputElement).value)"
              />
            </td>
            <td><input v-model.number="b.adjustment" type="number" class="input input-sm" /></td>
            <td>
              <button type="button" class="btn-link" @click="draft.dailyCapBands.splice(i, 1)">Xoá</button>
            </td>
          </tr>
        </tbody>
      </table>
      </div>
      <button
        type="button"
        class="btn-link"
        @click="draft.dailyCapBands.push({ minOverPar: 0, maxOverPar: 0, adjustment: 0 })"
      >
        + Thêm mức
      </button>
      <p class="note">Bỏ trống “Từ” hoặc “Đến” nghĩa là không giới hạn phía đó.</p>
    </section>

    <!-- ─── Technical prizes ───────────────────────────────────────── -->
    <section class="card">
      <h3 class="card-title">Giải kỹ thuật</h3>
      <div class="table-scroll">
      <table class="table">
        <thead>
          <tr>
            <th>Mã</th>
            <th>Tên giải</th>
            <th>Loại</th>
            <th>Các hố</th>
            <th>Đơn vị</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(spec, i) in draft.technicalPrizes" :key="i">
            <td><input v-model="spec.code" class="input input-xs" /></td>
            <td><input v-model="spec.label" class="input" /></td>
            <td>
              <select v-model="spec.kind" class="input">
                <option value="NEAREST_TO_PIN">Gần cờ nhất</option>
                <option value="LONGEST_DRIVE">Phát xa nhất</option>
              </select>
            </td>
            <td>
              <input
                :value="holesText(spec)"
                class="input input-md mono"
                @change="setHoles(spec, ($event.target as HTMLInputElement).value)"
              />
            </td>
            <td><input v-model="spec.unit" class="input input-xs" /></td>
            <td>
              <button type="button" class="btn-link" @click="draft.technicalPrizes.splice(i, 1)">Xoá</button>
            </td>
          </tr>
        </tbody>
      </table>
      </div>
      <button
        type="button"
        class="btn-link"
        @click="draft.technicalPrizes.push({ code: '', label: '', kind: 'NEAREST_TO_PIN', holes: [], unit: 'm' })"
      >
        + Thêm giải
      </button>
    </section>

    <div class="actions">
      <button type="button" class="btn-primary" :disabled="saving || problems.length > 0" @click="save">
        {{ saving ? 'Đang lưu…' : 'Lưu thể lệ' }}
      </button>
      <span class="note">Lưu xong sẽ xếp lại nhóm cho toàn bộ danh sách theo dải HDC mới.</span>
    </div>
  </div>
</template>

<style scoped>
.rules { display: flex; flex-direction: column; gap: 14px; }

.problems { display: flex; flex-direction: column; gap: 4px; margin: 0; }
.problem {
  padding: 6px 10px;
  border: 1px solid #7a3838;
  border-radius: 6px;
  background: rgba(239, 68, 68, 0.12);
  color: #fca5a5;
  font-size: 13px;
}

.card {
  border: 1px solid var(--outline-variant);
  border-radius: 8px;
  padding: 14px 16px;
  background: var(--surface-container-lowest);
}
.card-title { margin: 0 0 10px; font-size: 14px; font-weight: 700; color: var(--on-surface); }

.row { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; margin-bottom: 10px; }
.label { display: block; font-size: 12px; font-weight: 600; color: var(--muted); margin-bottom: 4px; }
.inline { font-size: 13px; color: var(--muted); }
.check { display: flex; align-items: center; gap: 6px; font-size: 13px; color: var(--on-surface); }

.input {
  padding: 6px 8px;
  border: 1px solid var(--outline-variant);
  border-radius: 6px;
  background: var(--surface-container-lowest);
  color: var(--on-surface);
  color-scheme: dark;
  font-size: 13px;
  width: 100%;
}
.input-xs { width: 68px; }
.input-sm { width: 84px; }
.input-md { width: 200px; }
.mono { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }

.table { width: 100%; border-collapse: collapse; font-size: 13px; }
.table th, .table td { padding: 4px 6px; border-bottom: 1px solid var(--outline-variant); text-align: left; }
.table thead th { color: var(--muted); font-size: 11px; font-weight: 600; }
.num { text-align: right; }

.note { margin: 6px 0 0; font-size: 12px; color: var(--muted); }
.btn-link {
  border: none;
  background: none;
  color: var(--primary);
  font-size: 12px;
  cursor: pointer;
  padding: 4px 0;
}
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
</style>
