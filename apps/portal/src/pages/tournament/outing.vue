<script setup lang="ts">
import { golferLabel } from '@/lib/enum-labels';
/**
 * Running one club outing, start to finish.
 *
 * Four tabs in the order the work happens: set the rules, import the field,
 * type the scores, read out the prizes. The first two are done in the week
 * before; the last two are the few minutes between the final flight coming in
 * and the prize-giving, which is what the whole screen is shaped around.
 *
 * The results tab polls while scores are being entered, so a second person can
 * watch the board fill in on the club-house screen while the first is typing.
 */
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';

import { outingApi } from '@/api/outing';
import type {
  OutingPlayer,
  OutingResults,
  OutingRules,
  RosterEntry,
  ScoreEntry,
  TechnicalEntry,
} from '@/api/outing';
import { getAuthToken } from '@/auth';
import { tournamentApi } from '@/api/tournament';
import FastEntry from '@/components/outing/FastEntry.vue';
import RulesEditor from '@/components/outing/RulesEditor.vue';
import ResultsBoard from '@/components/outing/ResultsBoard.vue';
import ScoreGrid from '@/components/outing/ScoreGrid.vue';
import TechnicalEntryBoard from '@/components/outing/TechnicalEntryBoard.vue';
import { parseRosterPaste } from './roster-paste';
import type { ParsedRoster } from './roster-paste';

const route = useRoute();
const tournamentId = computed(() => String(route.params.id));

type Tab = 'rules' | 'roster' | 'scores' | 'technical' | 'results';
const tab = ref<Tab>('scores');

/**
 * How scores are being typed.
 *
 * Fast is the default because it is what the day actually needs: one number
 * per golfer gives every group prize, and 44 numbers fit in the minutes
 * available where 792 do not. Detailed is there for the cards that matter —
 * a countback needs the back nine, and the daily CAP needs all eighteen.
 */
type Mode = 'fast' | 'detailed';
const mode = ref<Mode>('fast');

const tournamentName = ref('');
const rules = ref<OutingRules | null>(null);
const players = ref<OutingPlayer[]>([]);
const results = ref<OutingResults | null>(null);
const technical = ref<TechnicalEntry[]>([]);
const savingTechnical = ref(false);

const loading = ref(false);
const savingRules = ref(false);
const savingRoster = ref(false);
const savingScores = ref(false);
const publishing = ref(false);
const error = ref<string | null>(null);
const notice = ref<string | null>(null);

function fail(e: unknown, fallback: string) {
  const err = e as { message?: string };
  error.value = err?.message ?? fallback;
}

async function load() {
  loading.value = true;
  error.value = null;
  try {
    const [t, r, roster, tech] = await Promise.all([
      tournamentApi.getTournament(getAuthToken(), tournamentId.value),
      outingApi.getRules(tournamentId.value),
      outingApi.getRoster(tournamentId.value),
      outingApi.getTechnical(tournamentId.value),
    ]);
    tournamentName.value = t.name;
    rules.value = r;
    players.value = roster;
    technical.value = tech;
    await refreshResults();
  } catch (e: unknown) {
    fail(e, 'Không tải được giải đấu');
  } finally {
    loading.value = false;
  }
}

async function refreshResults() {
  try {
    results.value = await outingApi.getResults(tournamentId.value);
  } catch (e: unknown) {
    fail(e, 'Không tính được kết quả');
  }
}

// ─── Rules ────────────────────────────────────────────────────────────────

async function saveRules(next: OutingRules) {
  savingRules.value = true;
  error.value = null;
  try {
    rules.value = await outingApi.saveRules(tournamentId.value, next);
    // Divisions may have moved, so the roster and the board both change.
    players.value = await outingApi.getRoster(tournamentId.value);
    await refreshResults();
    notice.value = 'Đã lưu thể lệ.';
  } catch (e: unknown) {
    fail(e, 'Không lưu được thể lệ');
  } finally {
    savingRules.value = false;
  }
}

// ─── Roster ───────────────────────────────────────────────────────────────

const pasteText = ref('');
const parsed = computed<ParsedRoster>(() => parseRosterPaste(pasteText.value));

async function importRoster(entries: RosterEntry[]) {
  savingRoster.value = true;
  error.value = null;
  try {
    players.value = await outingApi.importRoster(tournamentId.value, entries);
    await refreshResults();
    notice.value = `Đã nhập ${entries.length} golfer.`;
    pasteText.value = '';
  } catch (e: unknown) {
    fail(e, 'Không nhập được danh sách');
  } finally {
    savingRoster.value = false;
  }
}

// ─── Scores ───────────────────────────────────────────────────────────────

async function saveScores(entries: ScoreEntry[]) {
  savingScores.value = true;
  error.value = null;
  try {
    const updated = await outingApi.saveScores(tournamentId.value, entries);
    // Patch in place rather than refetching the roster: the typist may already
    // be on the next flight, and swapping the whole array under them would
    // reset the grid mid-keystroke.
    const byId = new Map(updated.map((u) => [u.id, u]));
    players.value = players.value.map((p) => byId.get(p.id) ?? p);
    await refreshResults();
  } catch (e: unknown) {
    fail(e, 'Không lưu được điểm');
  } finally {
    savingScores.value = false;
  }
}

async function saveTechnical(entries: TechnicalEntry[]) {
  savingTechnical.value = true;
  error.value = null;
  try {
    await outingApi.saveTechnical(tournamentId.value, entries);
    technical.value = await outingApi.getTechnical(tournamentId.value);
    await refreshResults();
    notice.value = `Đã lưu ${entries.length} thành tích.`;
  } catch (e: unknown) {
    fail(e, 'Không lưu được thành tích');
  } finally {
    savingTechnical.value = false;
  }
}

async function publish() {
  publishing.value = true;
  error.value = null;
  try {
    results.value = await outingApi.publish(tournamentId.value);
    notice.value = 'Đã công bố kết quả.';
  } catch (e: unknown) {
    fail(e, 'Không công bố được kết quả');
  } finally {
    publishing.value = false;
  }
}

// ─── Live board ───────────────────────────────────────────────────────────

let poll: ReturnType<typeof setInterval> | null = null;

watch(tab, (next) => {
  if (poll) clearInterval(poll);
  poll = null;
  // Only while somebody is looking at the board — a poll behind a hidden tab
  // is a request nobody reads.
  if (next === 'results') {
    poll = setInterval(refreshResults, 10_000);
  }
});

onMounted(load);
onBeforeUnmount(() => {
  if (poll) clearInterval(poll);
});

const entered = computed(() => players.value.filter((p) => p.hasScore).length);
</script>

<template>
  <div class="outing">
    <header class="head">
      <div>
        <p class="eyebrow">Điều hành giải đấu</p>
        <h2 class="title">{{ tournamentName || 'Giải đấu' }}</h2>
      </div>
      <p class="counts">
        {{ players.length }} golfer · {{ entered }} đã có điểm
      </p>
    </header>

    <p v-if="error" class="banner banner-error" role="alert">{{ error }}</p>
    <p v-else-if="notice" class="banner banner-ok">{{ notice }}</p>

    <nav class="tabs">
      <button type="button" :class="{ active: tab === 'scores' }" @click="tab = 'scores'">
        Nhập điểm
      </button>
      <button type="button" :class="{ active: tab === 'technical' }" @click="tab = 'technical'">
        Giải kỹ thuật
      </button>
      <button type="button" :class="{ active: tab === 'results' }" @click="tab = 'results'">
        Kết quả
      </button>
      <button type="button" :class="{ active: tab === 'roster' }" @click="tab = 'roster'">
        Danh sách
      </button>
      <button type="button" :class="{ active: tab === 'rules' }" @click="tab = 'rules'">
        Thể lệ
      </button>
    </nav>

    <p v-if="loading" class="muted">Đang tải…</p>

    <template v-else-if="rules">
      <template v-if="tab === 'scores'">
        <div class="modes">
          <button
            type="button"
            class="mode"
            :class="{ active: mode === 'fast' }"
            @click="mode = 'fast'"
          >
            Nhanh — chỉ tổng gậy
          </button>
          <button
            type="button"
            class="mode"
            :class="{ active: mode === 'detailed' }"
            @click="mode = 'detailed'"
          >
            Chi tiết — từng hố
          </button>
          <span class="mode-note">
            {{
              mode === 'fast'
                ? '44 số là đủ xếp giải nhóm. Chỉ cần chi tiết hố khi có người bằng điểm phải đếm ngược.'
                : 'Đủ 18 hố mới đếm ngược, tính CAP ngày và tự đếm birdie/eagle được.'
            }}
          </span>
        </div>

        <FastEntry
          v-if="mode === 'fast'"
          :players="players"
          :rules="rules"
          :saving="savingScores"
          @save="saveScores"
        />
        <ScoreGrid
          v-else
          :players="players"
          :rules="rules"
          :saving="savingScores"
          @save="saveScores"
        />
      </template>

      <TechnicalEntryBoard
        v-else-if="tab === 'technical'"
        :players="players"
        :rules="rules"
        :existing="technical"
        :saving="savingTechnical"
        @save="saveTechnical"
      />

      <ResultsBoard
        v-else-if="tab === 'results'"
        :results="results"
        :rules="rules"
        :publishing="publishing"
        @publish="publish"
      />

      <!-- ─── Roster ─────────────────────────────────────────────── -->
      <section v-else-if="tab === 'roster'" class="card">
        <h3 class="card-title">Nhập danh sách từ file sắp flight</h3>
        <p class="note">
          Bôi đen khối dữ liệu trong Excel (cột Họ và tên, Handicap xét giải,
          Nhóm, Mã VGA — kể cả ô FLY gộp) rồi dán vào đây. Ô FLY chỉ cần điền ở
          dòng đầu mỗi flight.
        </p>

        <textarea
          v-model="pasteText"
          class="paste"
          rows="10"
          placeholder="FLY 1&#9;06h30.&#9;Phạm Đức Long&#9;27&#9;B&#9;38632"
        ></textarea>

        <div v-if="pasteText.trim()" class="preview">
          <p class="note">
            Đọc được <strong>{{ parsed.entries.length }}</strong> golfer,
            {{ new Set(parsed.entries.map((e) => e.flightNumber)).size }} flight.
          </p>
          <p v-if="parsed.skipped.length" class="note warn">
            Bỏ qua {{ parsed.skipped.length }} dòng:
            {{ parsed.skipped.map((s) => `dòng ${s.line} (${s.reason})`).join(', ') }}
          </p>

          <table class="table">
            <thead>
              <tr>
                <th class="num">FLY</th>
                <th>Họ và tên</th>
                <th class="num">HDC</th>
                <th>Nhóm</th>
                <th>Mã VGA</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(e, i) in parsed.entries" :key="i">
                <td class="num">{{ e.flightNumber ?? '—' }}</td>
                <td>{{ golferLabel(e) }}</td>
                <td class="num">{{ e.handicap ?? '—' }}</td>
                <td>{{ e.divisionCode ?? '(theo dải HDC)' }}</td>
                <td>{{ e.vgaCode ?? '—' }}</td>
              </tr>
            </tbody>
          </table>

          <button
            type="button"
            class="btn-primary"
            :disabled="savingRoster || parsed.entries.length === 0"
            @click="importRoster(parsed.entries)"
          >
            {{ savingRoster ? 'Đang nhập…' : `Nhập ${parsed.entries.length} golfer` }}
          </button>
          <p class="note warn">
            Thao tác này thay thế toàn bộ danh sách hiện tại. Golfer không có
            trong danh sách mới sẽ bị xoá cùng điểm đã nhập.
          </p>
        </div>

        <h3 class="card-title spaced">Danh sách hiện tại ({{ players.length }})</h3>
        <table class="table">
          <thead>
            <tr>
              <th class="num">FLY</th>
              <th>Họ và tên</th>
              <th class="num">HDC</th>
              <th>Nhóm</th>
              <th>Mã VGA</th>
              <th>Điểm</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="p in players" :key="p.id">
              <td class="num">{{ p.flightNumber ?? '—' }}</td>
              <td>{{ golferLabel(p) }}</td>
              <td class="num">{{ p.playingHandicap ?? '—' }}</td>
              <td>{{ p.divisionCode ?? '—' }}</td>
              <td>{{ p.vgaCode ?? '—' }}</td>
              <td>{{ p.hasScore ? '✓' : '' }}</td>
            </tr>
          </tbody>
        </table>
      </section>

      <RulesEditor
        v-else-if="tab === 'rules'"
        :rules="rules"
        :saving="savingRules"
        @save="saveRules"
      />
    </template>
  </div>
</template>

<style scoped>
.modes { display: flex; flex-wrap: wrap; align-items: center; gap: 6px; margin-bottom: 4px; }
.mode {
  padding: 6px 14px;
  border: 1px solid var(--outline-variant);
  border-radius: 999px;
  background: var(--surface-container-lowest);
  color: var(--muted);
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
}
.mode.active { background: var(--primary); border-color: var(--primary); color: #fff; }
.mode-note { font-size: 12px; color: var(--muted); }

.outing { display: flex; flex-direction: column; gap: 14px; }

.head { display: flex; align-items: flex-end; justify-content: space-between; gap: 16px; }
.eyebrow { margin: 0; font-size: 11px; font-weight: 700; letter-spacing: 0.08em; color: var(--primary); text-transform: uppercase; }
.title { margin: 2px 0 0; font-size: 22px; font-weight: 700; color: var(--on-surface); }
.counts { margin: 0; font-size: 13px; color: var(--muted); }

.banner { margin: 0; padding: 8px 12px; border-radius: 6px; font-size: 13px; }
.banner-error { background: rgba(239, 68, 68, 0.12); border: 1px solid #7a3838; color: #fca5a5; }
.banner-ok { background: rgba(34, 197, 94, 0.1); border: 1px solid #2f6f4a; color: #6ee7a8; }

.tabs { display: flex; gap: 4px; border-bottom: 1px solid var(--outline-variant); }
.tabs button {
  padding: 8px 16px;
  border: none;
  border-bottom: 2px solid transparent;
  background: none;
  color: var(--muted);
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
}
.tabs button.active { color: var(--primary); border-bottom-color: var(--primary); }

.card {
  border: 1px solid var(--outline-variant);
  border-radius: 8px;
  padding: 14px 16px;
  background: var(--surface-container-lowest);
}
.card-title { margin: 0 0 8px; font-size: 14px; font-weight: 700; color: var(--on-surface); }
.card-title.spaced { margin-top: 22px; }

.paste {
  width: 100%;
  padding: 8px 10px;
  border: 1px solid var(--outline-variant);
  border-radius: 6px;
  background: var(--surface-container-lowest);
  color: var(--on-surface);
  color-scheme: dark;
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 12px;
  resize: vertical;
}
.preview { margin-top: 12px; }

.table { width: 100%; border-collapse: collapse; font-size: 13px; margin: 8px 0; }
.table th, .table td { padding: 5px 8px; border-bottom: 1px solid var(--outline-variant); text-align: left; }
.table thead th { color: var(--muted); font-size: 11px; font-weight: 600; }
.num { text-align: right; font-variant-numeric: tabular-nums; }

.note { margin: 6px 0; font-size: 12px; color: var(--muted); }
.note.warn { color: #f0c869; }
.muted { color: var(--muted); font-size: 13px; }

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
