<template>
  <div class="tournament-detail-page">

    <header class="page-header">
      <div class="header-left">
        <button class="btn-back" @click="$router.push('/tournaments')" aria-label="Về danh sách giải">
          ← Quay lại
        </button>
        <div class="header-content">
          <h1 class="page-title">{{ tournament?.name ?? 'Giải đấu' }}</h1>
          <p class="page-subtitle">
            <span class="status-badge" :class="statusClass(tournament?.status)">
              {{ statusLabel(tournament?.status) }}
            </span>
            <span class="meta-sep">·</span>
            <span>{{ formatLabel(tournament?.format) }}</span>
            <span v-if="tournament?.courseName" class="meta-sep">·</span>
            <span v-if="tournament?.courseName">📍 {{ tournament.courseName }}</span>
          </p>
        </div>
      </div>
      <div class="header-actions">
        <button
          v-if="canEdit"
          class="btn btn-secondary"
          @click="toggleEdit"
        >
          Sửa
        </button>
        <button
          v-if="tournament?.status === 'DRAFT'"
          class="btn btn-primary"
          @click="handleOpenRegistration"
          :disabled="actionLoading"
        >
          Mở đăng ký
        </button>
        <button
          v-if="tournament?.status === 'REGISTRATION_OPEN'"
          class="btn btn-primary"
          @click="handleStartTournament"
          :disabled="actionLoading"
        >
          Bắt đầu giải
        </button>
        <button
          v-if="tournament?.status === 'IN_PROGRESS'"
          class="btn btn-primary"
          @click="handleCompleteTournament"
          :disabled="actionLoading || !allFlightsConfirmed"
        >
          Kết thúc giải
        </button>
      </div>
    </header>

    <!-- ─── Tab navigation ─────────────────────────────────────────────── -->
    <nav class="tab-nav" role="tablist">
      <button
        v-for="tab in tabs"
        :key="tab.id"
        class="tab-btn"
        :class="{ active: activeTab === tab.id }"
        role="tab"
        :aria-selected="activeTab === tab.id"
        @click="activeTab = tab.id"
      >
        {{ tab.label }}
        <span v-if="tab.count !== undefined" class="tab-count">{{ tab.count }}</span>
      </button>
    </nav>

    <!-- ─── Edit form (overlay, independent of tab chain) ───────────────── -->
    <div v-if="showEditForm && canEdit && !loading && !error" class="edit-form">
      <h3 class="card-title">Sửa giải đấu</h3>
      <div class="edit-grid">
        <div class="form-field">
          <label class="form-label">Tên</label>
          <input v-model="editForm.name" class="form-input" type="text" />
        </div>
        <div class="form-field">
          <label class="form-label">Thể thức</label>
          <select v-model="editForm.format" class="form-input">
            <option value="strokePlay">Đấu gậy</option>
            <option value="matchPlay">Đấu đối kháng</option>
            <option value="stableford">Stableford</option>
          </select>
        </div>
        <div class="form-field">
          <label class="form-label">Số golfer tối đa</label>
          <input v-model.number="editForm.maxPlayers" class="form-input" type="number" min="2" />
        </div>
        <div class="form-field full-width">
          <label class="form-label">Mô tả</label>
          <textarea v-model="editForm.description" class="form-input" rows="2" />
        </div>
      </div>
      <div class="edit-actions">
        <button class="btn btn-secondary" @click="showEditForm = false">Huỷ</button>
        <button class="btn btn-primary" :disabled="actionLoading" @click="handleSaveEdit">Lưu</button>
      </div>
    </div>

    <!-- ─── Loading / Error ─────────────────────────────────────────────── -->
    <div v-if="loading" class="loading-state" aria-busy="true">
      <div class="skeleton-block" />
    </div>
    <div v-else-if="error" class="error-state" role="alert">
      <span>{{ error }}</span>
      <button class="btn btn-secondary" @click="loadTournament">Thử lại</button>
    </div>

    <!-- ─── Tab: Overview ─────────────────────────────────────────────── -->
    <div v-else-if="activeTab === 'overview'" class="tab-panel">
      <div class="overview-grid">
        <div class="info-card">
          <h3 class="card-title">Thông tin giải</h3>
          <dl class="info-list">
            <dt>Thể thức</dt><dd>{{ formatLabel(tournament?.format) }}</dd>
            <dt>Ngày bắt đầu</dt><dd>{{ formatDate(tournament?.startDate) }}</dd>
            <dt>Ngày kết thúc</dt><dd>{{ formatDate(tournament?.endDate) }}</dd>
            <dt>Số golfer tối đa</dt><dd>{{ tournament?.maxPlayers ?? 'Không giới hạn' }}</dd>
            <dt>Hạn đăng ký</dt><dd>{{ formatDate(tournament?.registrationDeadline) }}</dd>
          </dl>
        </div>

        <div class="info-card">
          <h3 class="card-title">Đăng ký</h3>
          <dl class="info-list">
            <dt>Đã đăng ký</dt><dd>{{ players.length }} golfer</dd>
            <dt v-if="tournament?.maxPlayers">Chỗ còn lại</dt>
            <dd v-if="tournament?.maxPlayers">
              còn {{ (tournament.maxPlayers - players.length) }} suất
            </dd>
          </dl>
        </div>

        <div class="info-card">
          <h3 class="card-title">Flight</h3>
          <dl class="info-list">
            <dt>Tổng số flight</dt><dd>{{ flights.length }}</dd>
            <dt>Đã chốt</dt><dd>{{ confirmedFlightsCount }} / {{ flights.length }}</dd>
          </dl>
        </div>
      </div>

      <div v-if="tournament?.description" class="description-block">
        <h3 class="card-title">Mô tả</h3>
        <p class="description-text">{{ tournament.description }}</p>
      </div>
    </div>

    <!-- ─── Tab: Players ──────────────────────────────────────────────── -->
    <div v-else-if="activeTab === 'players'" class="tab-panel">
      <div class="section-actions">
        <button class="btn btn-primary" @click="showAddPlayer = !showAddPlayer">
          + Thêm người chơi
        </button>
        <button class="btn btn-secondary" @click="showImportForm = !showImportForm">
          Nhập hàng loạt
        </button>
      </div>

      <!-- Add player form -->
      <div v-if="showAddPlayer" class="inline-form">
        <input v-model="newPlayerId" type="number" placeholder="Mã golfer" class="form-input" />
        <input v-model="newPlayerHandicap" type="number" step="0.1" placeholder="Handicap" class="form-input" />
        <button class="btn btn-primary" @click="handleAddPlayer" :disabled="addLoading">Thêm</button>
        <button class="btn btn-secondary" @click="showAddPlayer = false">Huỷ</button>
      </div>

      <!-- Bulk import form -->
      <div v-if="showImportForm" class="import-form">
        <label class="form-label">
          Dán mỗi dòng một golfer theo dạng <code>playerId,handicap</code> (handicap không bắt buộc)
        </label>
        <textarea
          v-model="importText"
          class="form-input import-textarea"
          rows="5"
          placeholder="101,12.4&#10;102,8.0&#10;103"
        />
        <span v-if="importError" class="field-error">{{ importError }}</span>
        <div class="import-actions">
          <button class="btn btn-primary" :disabled="importLoading" @click="handleBulkImport">
            {{ importLoading ? 'Đang nhập…' : 'Nhập danh sách người chơi' }}
          </button>
          <button class="btn btn-secondary" @click="showImportForm = false">Huỷ</button>
        </div>
      </div>

      <div v-if="players.length === 0" class="empty-state">
        <p>Chưa có golfer nào đăng ký.</p>
      </div>
      <div v-else class="data-table">
        <table>
          <thead>
            <tr>
              <th>Mã golfer</th>
              <th>Handicap</th>
              <th>Flight</th>
              <th>Trạng thái</th>
              <th>Thao tác</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="p in players" :key="p.id">
              <td>{{ p.playerId }}</td>
              <td>{{ p.handicap ?? '—' }}</td>
              <td>{{ p.flightId ? `Flight ${flightNumber(p.flightId)}` : '—' }}</td>
              <td><span class="status-badge" :class="playerStatusClass(p.status)">{{ p.status }}</span></td>
              <td>
                <button
                  v-if="p.status !== 'WITHDRAWN'"
                  class="btn-link"
                  @click="handleWithdrawPlayer(p.playerId)"
                >
                  Rút tên
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- ─── Tab: Flights ──────────────────────────────────────────────── -->
    <div v-else-if="activeTab === 'flights'" class="tab-panel">
      <div class="section-actions">
        <button class="btn btn-primary" @click="handleCreateFlight">+ Tạo flight</button>
      </div>

      <div v-if="flights.length === 0" class="empty-state">
        <p>Chưa tạo flight nào.</p>
      </div>
      <div v-else class="flights-grid">
        <div v-for="flight in flights" :key="flight.id" class="flight-card">
          <div class="flight-header">
            <strong>Flight {{ flight.flightNumber }}</strong>
            <span class="starting-tee-badge">{{ flight.startingTee }}</span>
          </div>
          <div class="flight-players">
            <span v-for="pid in flight.playerIds" :key="pid" class="player-chip">
              Người chơi {{ pid }}
            </span>
            <span v-if="flight.playerIds.length === 0" class="no-players">Chưa gán golfer</span>
          </div>
          <div class="flight-tee-time">
            <span v-if="flight.teeTimeId">Giờ phát bóng: {{ flight.teeTimeId }}</span>
            <span v-else class="unassigned">Chưa xếp giờ</span>
          </div>
          <div v-if="flight.confirmedAt" class="confirmed-badge">
            ✓ Đã xác nhận
          </div>
        </div>
      </div>
    </div>

    <!-- ─── Tab: Tee Times ────────────────────────────────────────────── -->
    <div v-else-if="activeTab === 'tee-times'" class="tab-panel">
      <div class="section-actions">
        <button class="btn btn-primary" @click="showCreateTeeTime = !showCreateTeeTime">
          + Thêm giờ phát bóng
        </button>
      </div>

      <div v-if="showCreateTeeTime" class="inline-form">
        <input v-model="newTeeTime" type="datetime-local" class="form-input" />
        <button class="btn btn-primary" @click="handleCreateTeeTime">Thêm</button>
        <button class="btn btn-secondary" @click="showCreateTeeTime = false">Huỷ</button>
      </div>

      <div v-if="teeTimes.length === 0" class="empty-state">
        <p>Chưa xếp giờ tee.</p>
      </div>
      <div v-else class="data-table">
        <table>
          <thead>
            <tr><th>Giờ tee</th><th>Tee xuất phát</th><th>Flight</th><th>Gán</th></tr>
          </thead>
          <tbody>
            <tr v-for="tt in teeTimes" :key="tt.id">
              <td>{{ formatDateTime(tt.teeTime) }}</td>
              <td>{{ tt.startingTee }}</td>
              <td>{{ tt.flightId ? `Flight ${flightNumber(tt.flightId)}` : '—' }}</td>
              <td>
                <select v-if="!tt.flightId" @change="e => handleAssignFlight(tt.id, (e.target as HTMLSelectElement).value)">
                  <option value="">Chọn flight…</option>
                  <option v-for="f in unassignedFlights" :key="f.id" :value="f.id">
                    Flight {{ f.flightNumber }}
                  </option>
                </select>
                <span v-else>Đã gán</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- ─── Tab: Leaderboard ──────────────────────────────────────────── -->
    <div v-else-if="activeTab === 'leaderboard'" class="tab-panel">
      <div class="section-actions">
        <span class="leaderboard-version">v{{ leaderboardVersion }}</span>
        <button class="btn btn-secondary" @click="loadLeaderboard">Tải lại</button>
      </div>

      <div v-if="leaderboardLoading" class="loading-state">
        <div class="skeleton-block" />
      </div>
      <div v-else-if="leaderboardEntries.length === 0" class="empty-state">
        <p>Chưa có dữ liệu bảng xếp hạng.</p>
      </div>
      <div v-else class="leaderboard-table">
        <table>
          <thead>
            <tr>
              <th>Hạng</th>
              <th>Golfer</th>
              <th>Flight</th>
              <th>Điểm</th>
              <th>So par</th>
              <th>Trạng thái</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="entry in leaderboardEntries" :key="entry.playerId">
              <td>
                <span class="rank-cell">{{ entry.rank }}</span>
                <span v-if="entry.tied" class="tied-badge">T</span>
              </td>
              <td>Người chơi {{ entry.playerId }}</td>
              <td>{{ entry.flightId ? `Flight ${flightNumber(entry.flightId)}` : '—' }}</td>
              <td>{{ entry.score ?? '—' }}</td>
              <td>{{ entry.scoreToPar != null ? (entry.scoreToPar > 0 ? '+' : '') + entry.scoreToPar : '—' }}</td>
              <td>{{ entry.status }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- ─── Tab: Score Confirmation ───────────────────────────────────── -->
    <div v-else-if="activeTab === 'confirm'" class="tab-panel">
      <div class="section-actions">
        <button class="btn btn-primary" @click="loadTournament">Tải lại</button>
      </div>

      <div v-if="unconfirmedFlights.length === 0" class="empty-state">
        <p>✓ Tất cả các flight đã được xác nhận.</p>
      </div>
      <div v-else class="confirm-list">
        <div v-for="flight in unconfirmedFlights" :key="flight.id" class="confirm-card">
          <div class="confirm-header">
            <strong>Flight {{ flight.flightNumber }}</strong>
            <span class="starting-tee-badge">{{ flight.startingTee }}</span>
          </div>
          <div class="flight-players">
            <span v-for="pid in flight.playerIds" :key="pid" class="player-chip">
              Người chơi {{ pid }}
            </span>
          </div>
          <button
            class="btn btn-primary"
            @click="handleConfirmFlight(flight.id)"
            :disabled="confirmLoading"
          >
            Chốt điểm
          </button>
        </div>
      </div>
    </div>

    <!-- ─── Tab: Results ──────────────────────────────────────────────── -->
    <div v-else-if="activeTab === 'results'" class="tab-panel">
      <div v-if="tournament?.status !== 'COMPLETED'" class="info-banner">
        Kết thúc giải để tạo và công bố kết quả.
      </div>
      <div v-else-if="results.length === 0" class="empty-state">
        <p>Chưa công bố kết quả.</p>
        <button class="btn btn-primary" @click="handlePublishResults">Công bố kết quả</button>
      </div>
      <div v-else class="results-table">
        <table>
          <thead>
            <tr><th>Hạng</th><th>Golfer</th><th>Điểm</th><th>So par</th><th>Phân định hoà</th></tr>
          </thead>
          <tbody>
            <tr v-for="r in results" :key="r.playerId">
              <td>{{ r.rank }}</td>
              <td>{{ r.playerName ?? `Player ${r.playerId}` }}</td>
              <td>{{ r.score ?? '—' }}</td>
              <td>{{ r.scoreToPar != null ? (r.scoreToPar > 0 ? '+' : '') + r.scoreToPar : '—' }}</td>
              <td>{{ r.tieBreakApplied ? '✓' : '—' }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, watch } from 'vue';
import { formatDay, formatInstant } from '@/lib/datetime';
import { useRoute } from 'vue-router';
import { tournamentApi } from '@/api/tournament';
import type {
  TournamentDetail,
  FlightResponse,
  TeeTimeResponse,
  TournamentPlayerResponse,
  TournamentResultResponse,
  LeaderboardEntryResponse,
  TournamentUpdateRequest,
  TournamentBulkImportRequest,
} from '@/types/tournament';
import { parseBulkImport } from '@/pages/tournament/bulk-import';

const route = useRoute();

const tournamentId = route.params.id as string;
const props = defineProps<{ authToken: string }>();

// ─── State ────────────────────────────────────────────────────────────────
const tournament = ref<TournamentDetail | null>(null);
const players = ref<TournamentPlayerResponse[]>([]);
const flights = ref<FlightResponse[]>([]);
const teeTimes = ref<TeeTimeResponse[]>([]);
const results = ref<TournamentResultResponse[]>([]);
const leaderboardEntries = ref<LeaderboardEntryResponse[]>([]);
const leaderboardVersion = ref(0);

const loading = ref(false);
const error = ref<string | null>(null);
const actionLoading = ref(false);
const confirmLoading = ref(false);
const addLoading = ref(false);
const leaderboardLoading = ref(false);

const activeTab = ref('overview');
const showAddPlayer = ref(false);
const showImportForm = ref(false);
const showEditForm = ref(false);
const showCreateTeeTime = ref(false);
const newPlayerId = ref('');
const newPlayerHandicap = ref('');
const newTeeTime = ref('');

const editForm = ref<TournamentUpdateRequest>({});
const importText = ref('');
const importError = ref<string | null>(null);
const importLoading = ref(false);

let sseSource: EventSource | null = null;

// ─── Computed ────────────────────────────────────────────────────────────

const tabs = computed(() => [
  { id: 'overview', label: 'Tổng quan' },
  { id: 'players', label: 'Người chơi', count: players.value.length },
  { id: 'flights', label: 'Flight', count: flights.value.length },
  { id: 'tee-times', label: 'Giờ phát bóng', count: teeTimes.value.length },
  { id: 'leaderboard', label: 'Bảng xếp hạng' },
  { id: 'confirm', label: 'Xác nhận', count: unconfirmedFlights.value.length || undefined },
  { id: 'results', label: 'Kết quả' },
]);

const canEdit = computed(() =>
  tournament.value?.status === 'DRAFT' || tournament.value?.status === 'REGISTRATION_OPEN'
);

const confirmedFlightsCount = computed(() =>
  flights.value.filter(f => f.confirmedAt).length
);

const allFlightsConfirmed = computed(() =>
  flights.value.length > 0 && confirmedFlightsCount.value === flights.value.length
);

const unconfirmedFlights = computed(() =>
  flights.value.filter(f => !f.confirmedAt)
);

const unassignedFlights = computed(() =>
  flights.value.filter(f => !f.teeTimeId)
);

// ─── Load ────────────────────────────────────────────────────────────────

async function loadTournament() {
  loading.value = true;
  error.value = null;
  try {
    const detail = await tournamentApi.getTournament(props.authToken, tournamentId);
    tournament.value = detail;
    players.value = detail.players ?? [];
    flights.value = detail.flights ?? [];
    teeTimes.value = detail.teeTimes ?? [];
  } catch (e: unknown) {
    const apiErr = e as { message?: string };
    error.value = apiErr?.message ?? 'Không tải được giải đấu';
  } finally {
    loading.value = false;
  }
}

async function loadLeaderboard() {
  leaderboardLoading.value = true;
  try {
    const lb = await tournamentApi.getLeaderboard(props.authToken, tournamentId);
    leaderboardEntries.value = lb.entries ?? [];
    leaderboardVersion.value = lb.version;
  } catch {
    // Deliberately quiet: the leaderboard refreshes on a timer and over SSE,
    // so one failed poll is followed by another in seconds. An error banner
    // here would flicker on every dropped request.
  } finally {
    leaderboardLoading.value = false;
  }
}

async function loadResults() {
  try {
    results.value = await tournamentApi.getResults(props.authToken, tournamentId);
  } catch {
    // Deliberately quiet: results 404 until they are published, which is the
    // normal state for most of a tournament, not a failure to report.
  }
}

// ─── SSE ────────────────────────────────────────────────────────────────

function connectLeaderboardSSE() {
  if (sseSource) return;
  const url = tournamentApi.leaderboardSseUrl(props.authToken, tournamentId);
  sseSource = new EventSource(url);
  sseSource.onmessage = (event) => {
    try {
      const data = JSON.parse(event.data);
      if (data.entries) {
        leaderboardEntries.value = data.entries;
        leaderboardVersion.value = data.version ?? leaderboardVersion.value + 1;
      }
    } catch {
      // A malformed SSE frame is not worth a banner; the next frame replaces
      // whatever this one would have said.
    }
  };
  sseSource.onerror = () => {
    sseSource?.close();
    sseSource = null;
  };
}

function disconnectLeaderboardSSE() {
  sseSource?.close();
  sseSource = null;
}

// ─── Lifecycle ─────────────────────────────────────────────────────────

onMounted(async () => {
  await loadTournament();
  if (tournament.value?.status === 'IN_PROGRESS') {
    await loadLeaderboard();
    connectLeaderboardSSE();
  }
  if (tournament.value?.status === 'COMPLETED') {
    await loadResults();
  }
});

onUnmounted(() => {
  disconnectLeaderboardSSE();
});

// Lazy-load tab data when the user switches tabs.
watch(activeTab, (tab) => {
  if (tab === 'leaderboard') loadLeaderboard();
  if (tab === 'results' && tournament.value?.status === 'COMPLETED') loadResults();
});

// ─── Actions ────────────────────────────────────────────────────────────

async function handleOpenRegistration() {
  actionLoading.value = true;
  try {
    await tournamentApi.openRegistration(props.authToken, tournamentId);
    await loadTournament();
  } catch (e: unknown) {
    const apiErr = e as { message?: string };
    error.value = apiErr?.message ?? 'Không mở được đăng ký';
  } finally {
    actionLoading.value = false;
  }
}

async function handleStartTournament() {
  actionLoading.value = true;
  try {
    await tournamentApi.startTournament(props.authToken, tournamentId);
    await loadTournament();
  } catch (e: unknown) {
    const apiErr = e as { message?: string };
    error.value = apiErr?.message ?? 'Không bắt đầu được giải';
  } finally {
    actionLoading.value = false;
  }
}

async function handleCompleteTournament() {
  if (!allFlightsConfirmed.value) {
    error.value = 'Phải xác nhận hết các nhóm bay trước khi kết thúc';
    return;
  }
  actionLoading.value = true;
  try {
    await tournamentApi.completeTournament(props.authToken, tournamentId);
    await loadTournament();
  } catch (e: unknown) {
    const apiErr = e as { message?: string };
    error.value = apiErr?.message ?? 'Không kết thúc được giải';
  } finally {
    actionLoading.value = false;
  }
}

async function handleAddPlayer() {
  if (!newPlayerId.value) return;
  addLoading.value = true;
  try {
    await tournamentApi.registerPlayer(props.authToken, tournamentId, {
      playerId: parseInt(newPlayerId.value),
      handicap: newPlayerHandicap.value ? parseFloat(newPlayerHandicap.value) : undefined,
    });
    newPlayerId.value = '';
    newPlayerHandicap.value = '';
    showAddPlayer.value = false;
    await loadTournament();
  } catch (e: unknown) {
    const apiErr = e as { message?: string };
    error.value = apiErr?.message ?? 'Không thêm được người chơi';
  } finally {
    addLoading.value = false;
  }
}

function toggleEdit() {
  showEditForm.value = !showEditForm.value;
  if (showEditForm.value && tournament.value) {
    editForm.value = {
      name: tournament.value.name,
      format: tournament.value.format,
      maxPlayers: tournament.value.maxPlayers,
      description: tournament.value.description,
    };
  }
}

async function handleSaveEdit() {
  if (!tournament.value) return;
  actionLoading.value = true;
  try {
    await tournamentApi.updateTournament(props.authToken, tournamentId, editForm.value);
    showEditForm.value = false;
    await loadTournament();
  } catch (e: unknown) {
    const apiErr = e as { message?: string };
    error.value = apiErr?.message ?? 'Không cập nhật được giải';
  } finally {
    actionLoading.value = false;
  }
}

async function handleBulkImport() {
  importError.value = null;
  let request: TournamentBulkImportRequest;
  try {
    request = parseBulkImport(importText.value);
  } catch (e: unknown) {
    importError.value = (e as Error).message;
    return;
  }
  importLoading.value = true;
  try {
    await tournamentApi.bulkImportPlayers(props.authToken, tournamentId, request);
    importText.value = '';
    showImportForm.value = false;
    await loadTournament();
  } catch (e: unknown) {
    const apiErr = e as { message?: string };
    importError.value = apiErr?.message ?? 'Không nhập được danh sách người chơi';
  } finally {
    importLoading.value = false;
  }
}

async function handleWithdrawPlayer(playerId: number) {
  try {
    await tournamentApi.withdrawPlayer(props.authToken, tournamentId, playerId);
    await loadTournament();
  } catch (e: unknown) {
    const apiErr = e as { message?: string };
    error.value = apiErr?.message ?? 'Không rút được người chơi';
  }
}

async function handleCreateFlight() {
  const nextNumber = flights.value.length + 1;
  try {
    await tournamentApi.createFlight(props.authToken, tournamentId, {
      flightNumber: nextNumber,
      startingTee: 'front',
    });
    await loadTournament();
  } catch (e: unknown) {
    const apiErr = e as { message?: string };
    error.value = apiErr?.message ?? 'Không tạo được flight';
  }
}

async function handleCreateTeeTime() {
  if (!newTeeTime.value) return;
  try {
    await tournamentApi.createTeeTime(props.authToken, tournamentId, {
      teeTime: new Date(newTeeTime.value).toISOString(),
      courseId: tournament.value?.courseId ?? 0,
      startingTee: 'front',
    });
    newTeeTime.value = '';
    showCreateTeeTime.value = false;
    await loadTournament();
  } catch (e: unknown) {
    const apiErr = e as { message?: string };
    error.value = apiErr?.message ?? 'Không tạo được giờ phát bóng';
  }
}

async function handleAssignFlight(teeTimeId: string, flightId: string) {
  if (!flightId) return;
  try {
    await tournamentApi.updateTeeTime(props.authToken, tournamentId, teeTimeId, { flightId });
    await loadTournament();
  } catch (e: unknown) {
    const apiErr = e as { message?: string };
    error.value = apiErr?.message ?? 'Không gán được flight vào giờ phát bóng';
  }
}

async function handleConfirmFlight(flightId: string) {
  confirmLoading.value = true;
  try {
    await tournamentApi.confirmFlight(props.authToken, tournamentId, flightId);
    await loadTournament();
  } catch (e: unknown) {
    const apiErr = e as { message?: string };
    error.value = apiErr?.message ?? 'Không xác nhận được điểm của flight';
  } finally {
    confirmLoading.value = false;
  }
}

async function handlePublishResults() {
  try {
    await tournamentApi.publishResults(props.authToken, tournamentId);
    await loadResults();
  } catch (e: unknown) {
    const apiErr = e as { message?: string };
    error.value = apiErr?.message ?? 'Không công bố được kết quả';
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────

function flightNumber(flightId: string): number | string {
  return flights.value.find(f => f.id === flightId)?.flightNumber ?? '?';
}

function statusLabel(status?: string): string {
  const labels: Record<string, string> = {
    DRAFT: 'Bản nháp',
    REGISTRATION_OPEN: 'Đang mở đăng ký',
    IN_PROGRESS: 'Đang diễn ra',
    COMPLETED: 'Đã kết thúc',
    CANCELLED: 'Đã huỷ',
  };
  return labels[status ?? ''] ?? status ?? '';
}

function statusClass(status?: string): string {
  const classes: Record<string, string> = {
    DRAFT: 'badge-draft',
    REGISTRATION_OPEN: 'badge-open',
    IN_PROGRESS: 'badge-active',
    COMPLETED: 'badge-done',
    CANCELLED: 'badge-cancelled',
  };
  return classes[status ?? ''] ?? '';
}

function formatLabel(format?: string): string {
  const labels: Record<string, string> = {
    strokePlay: 'Stroke Play',
    matchPlay: 'Match Play',
    stableford: 'Stableford',
  };
  return labels[format ?? ''] ?? format ?? '';
}

function formatDate(iso?: string): string {
  if (!iso) return '—';
  return formatDay(iso);
}

function formatDateTime(iso?: string): string {
  if (!iso) return '—';
  return formatInstant(iso);
}

function playerStatusClass(status?: string): string {
  if (status === 'CONFIRMED') return 'badge-done';
  if (status === 'WITHDRAWN' || status === 'DISQUALIFIED') return 'badge-cancelled';
  return 'badge-open';
}
</script>

<style scoped>
.tournament-detail-page {
  font-family: system-ui, -apple-system, sans-serif;
  padding: 1.5rem;
  max-width: 1000px;
  margin: 0 auto;
}

/* Header */
.page-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 1.25rem;
  border-bottom: 1px solid #2d3449;
  padding-bottom: 1rem;
}
.header-left { display: flex; align-items: flex-start; gap: 0.75rem; }
.btn-back {
  background: none;
  border: none;
  color: #f66018;
  font-size: 0.875rem;
  cursor: pointer;
  padding: 0.5rem;
  min-height: 44px;
}
.page-title { font-size: 1.375rem; font-weight: 700; color: #dae2fd; margin: 0; }
.page-subtitle { font-size: 0.875rem; color: #97a2c0; margin: 0.25rem 0 0; display: flex; align-items: center; gap: 0.4rem; }
.header-actions { display: flex; gap: 0.5rem; }
.status-badge {
  font-size: 0.6875rem;
  font-weight: 600;
  padding: 0.2rem 0.6rem;
  border-radius: 9999px;
}
.badge-draft { background: #222a3d; color: #97a2c0; }
.badge-open { background: #2d3449; color: #ec6a06; }
.badge-active { background: #d1fae5; color: #065f46; }
.badge-done { background: #dcfce7; color: #15803d; }
.badge-cancelled { background: #fee2e2; color: #991b1b; }

/* Tabs */
.tab-nav {
  display: flex;
  gap: 0.25rem;
  border-bottom: 1px solid #2d3449;
  margin-bottom: 1.25rem;
  overflow-x: auto;
}
.tab-btn {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.6rem 1rem;
  background: none;
  border: none;
  border-bottom: 2px solid transparent;
  color: #97a2c0;
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  white-space: nowrap;
  min-height: 44px;
}
.tab-btn:hover { color: #dae2fd; }
.tab-btn.active { color: #f66018; border-bottom-color: #f66018; }
.tab-count {
  background: #2d3449;
  color: #c5cde8;
  border-radius: 9999px;
  padding: 0.1rem 0.4rem;
  font-size: 0.6875rem;
  font-weight: 600;
}
.tab-panel { animation: fadeIn 0.15s ease; }
@keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }

/* Overview */
.overview-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 1rem;
  margin-bottom: 1.5rem;
}
.info-card {
  background: #171f33;
  border: 1px solid #2d3449;
  border-radius: 10px;
  padding: 1rem;
}
.card-title { font-size: 0.875rem; font-weight: 600; color: #c5cde8; margin: 0 0 0.75rem; }
.info-list { display: grid; grid-template-columns: auto 1fr; gap: 0.35rem 1rem; font-size: 0.8125rem; }
.info-list dt { color: #97a2c0; }
.info-list dd { color: #dae2fd; font-weight: 500; margin: 0; }
.description-block { background: #171f33; border: 1px solid #2d3449; border-radius: 10px; padding: 1rem; }
.description-text { font-size: 0.875rem; color: #c5cde8; margin: 0; line-height: 1.5; }

/* Section actions */
.section-actions { display: flex; gap: 0.5rem; align-items: center; margin-bottom: 1rem; }

/* Inline form */
.inline-form { display: flex; gap: 0.5rem; margin-bottom: 1rem; align-items: center; }

/* Edit form */
.edit-form {
  background: #171f33;
  border: 1px solid #2d3449;
  border-radius: 10px;
  padding: 1rem;
  margin-bottom: 1.25rem;
}
.edit-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem; margin: 0.75rem 0; }
.edit-grid .full-width { grid-column: 1 / -1; }
.edit-actions { display: flex; gap: 0.5rem; justify-content: flex-end; }
.form-field { display: flex; flex-direction: column; gap: 0.3rem; }
.form-label { font-size: 0.8125rem; font-weight: 600; color: #c5cde8; }
.field-error { font-size: 0.75rem; color: #ffb4ab; }

/* Import form */
.import-form {
  background: #171f33;
  border: 1px solid #2d3449;
  border-radius: 10px;
  padding: 1rem;
  margin-bottom: 1rem;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}
.import-textarea { font-family: 'Fira Code', ui-monospace, monospace; }
.import-form code {
  font-family: 'Fira Code', ui-monospace, monospace;
  background: #222a3d;
  color: #ffb599;
  padding: 0.05rem 0.3rem;
  border-radius: 4px;
}
.import-actions { display: flex; gap: 0.5rem; }
textarea.form-input { resize: vertical; }

/* Buttons */
.btn {
  padding: 0.5rem 1rem;
  border-radius: 6px;
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  border: 1px solid transparent;
  min-height: 44px;
  transition: background 0.15s;
}
.btn-primary { background: #f66018; color: white; border-color: #f66018; }
.btn-primary:hover:not(:disabled) { background: #ec6a06; }
.btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
.btn-secondary { background: #171f33; color: #c5cde8; border-color: #2d3449; }
.btn-secondary:hover:not(:disabled) { background: #171f33; }
.btn-link { background: none; border: none; color: #dc2626; cursor: pointer; font-size: 0.875rem; padding: 0.25rem; }
.btn-link:hover { text-decoration: underline; }

/* Form inputs */
.form-input {
  padding: 0.5rem 0.75rem;
  border: 1px solid #2d3449;
  border-radius: 6px;
  font-size: 0.875rem;
  min-height: 44px;
  background: #171f33;
  color: #dae2fd;
}
.form-input:focus { outline: none; border-color: #f66018; box-shadow: 0 0 0 3px rgba(246,96,24,0.1); }

/* Loading / Error */
.loading-state { display: flex; flex-direction: column; gap: 0.75rem; }
.skeleton-block { height: 6rem; border-radius: 10px; background: linear-gradient(90deg,#2d3449 25%,#222a3d 50%,#2d3449 75%); background-size: 200% 100%; animation: shimmer 1.5s infinite; }
.skeleton-card { height: 5rem; border-radius: 8px; background: linear-gradient(90deg,#2d3449 25%,#222a3d 50%,#2d3449 75%); background-size: 200% 100%; animation: shimmer 1.5s infinite; }
@keyframes shimmer { 0% { background-position: 200% 0; } 100% { background-position: -200% 0; } }
.error-state { display: flex; flex-direction: column; align-items: center; gap: 0.5rem; padding: 2rem; color: #dc2626; }
.empty-state { display: flex; flex-direction: column; align-items: center; gap: 0.5rem; padding: 2rem; color: #97a2c0; font-size: 0.875rem; }
.info-banner { background: #fef3c7; color: #92400e; padding: 0.75rem 1rem; border-radius: 8px; font-size: 0.875rem; margin-bottom: 1rem; }

/* Flights grid */
.flights-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 0.75rem; }
.flight-card {
  border: 1px solid #2d3449;
  border-radius: 10px;
  padding: 0.875rem;
  background: #171f33;
}
.flight-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.5rem; font-size: 0.875rem; }
.starting-tee-badge { font-size: 0.6875rem; padding: 0.15rem 0.5rem; border-radius: 9999px; background: #2d3449; color: #c5cde8; }
.flight-players { display: flex; flex-wrap: wrap; gap: 0.25rem; margin-bottom: 0.5rem; min-height: 1.5rem; }
.player-chip { font-size: 0.6875rem; padding: 0.2rem 0.5rem; border-radius: 9999px; background: #2d3449; color: #ec6a06; }
.no-players { font-size: 0.75rem; color: #97a2c0; }
.flight-tee-time { font-size: 0.75rem; color: #97a2c0; }
.unassigned { color: #dc2626; }
.confirmed-badge { font-size: 0.75rem; color: #15803d; margin-top: 0.35rem; }

/* Leaderboard */
.leaderboard-version { font-size: 0.75rem; color: #97a2c0; background: #222a3d; padding: 0.25rem 0.6rem; border-radius: 9999px; }
.rank-cell { font-weight: 700; color: #dae2fd; }

/* Confirm list */
.confirm-list { display: flex; flex-direction: column; gap: 0.75rem; }
.confirm-card {
  border: 1px solid #2d3449;
  border-radius: 10px;
  padding: 1rem;
  background: #171f33;
}
.confirm-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.5rem; }
.confirmed-badge { font-size: 0.75rem; color: #15803d; }

/* Tables */
.data-table { overflow-x: auto; }
table { width: 100%; border-collapse: collapse; font-size: 0.875rem; }
th { text-align: left; padding: 0.6rem 0.75rem; background: #171f33; border-bottom: 1px solid #2d3449; font-weight: 600; color: #c5cde8; white-space: nowrap; }
td { padding: 0.6rem 0.75rem; border-bottom: 1px solid #222a3d; color: #dae2fd; }
tr:last-child td { border-bottom: none; }
tr:hover td { background: #171f33; }

.meta-sep { color: #2d3449; }
</style>
