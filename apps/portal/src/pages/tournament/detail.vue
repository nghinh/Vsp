<template>
  <div class="tournament-detail-page">

    <header class="page-header">
      <div class="header-left">
        <button class="btn-back" @click="$router.push('/tournament')" aria-label="Back to tournaments">
          ← Back
        </button>
        <div class="header-content">
          <h1 class="page-title">{{ tournament?.name ?? 'Tournament' }}</h1>
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
          @click="showEditForm = !showEditForm"
        >
          Edit
        </button>
        <button
          v-if="tournament?.status === 'DRAFT'"
          class="btn btn-primary"
          @click="handleOpenRegistration"
          :disabled="actionLoading"
        >
          Open Registration
        </button>
        <button
          v-if="tournament?.status === 'REGISTRATION_OPEN'"
          class="btn btn-primary"
          @click="handleStartTournament"
          :disabled="actionLoading"
        >
          Start Tournament
        </button>
        <button
          v-if="tournament?.status === 'IN_PROGRESS'"
          class="btn btn-primary"
          @click="handleCompleteTournament"
          :disabled="actionLoading || !allFlightsConfirmed"
        >
          Complete Tournament
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

    <!-- ─── Loading / Error ─────────────────────────────────────────────── -->
    <div v-if="loading" class="loading-state" aria-busy="true">
      <div class="skeleton-block" />
    </div>
    <div v-else-if="error" class="error-state" role="alert">
      <span>{{ error }}</span>
      <button class="btn btn-secondary" @click="loadTournament">Retry</button>
    </div>

    <!-- ─── Tab: Overview ─────────────────────────────────────────────── -->
    <div v-else-if="activeTab === 'overview'" class="tab-panel">
      <div class="overview-grid">
        <div class="info-card">
          <h3 class="card-title">Tournament Info</h3>
          <dl class="info-list">
            <dt>Format</dt><dd>{{ formatLabel(tournament?.format) }}</dd>
            <dt>Start Date</dt><dd>{{ formatDate(tournament?.startDate) }}</dd>
            <dt>End Date</dt><dd>{{ formatDate(tournament?.endDate) }}</dd>
            <dt>Max Players</dt><dd>{{ tournament?.maxPlayers ?? 'Unlimited' }}</dd>
            <dt>Reg. Deadline</dt><dd>{{ formatDate(tournament?.registrationDeadline) }}</dd>
          </dl>
        </div>

        <div class="info-card">
          <h3 class="card-title">Registration</h3>
          <dl class="info-list">
            <dt>Registered</dt><dd>{{ players.length }} players</dd>
            <dt v-if="tournament?.maxPlayers">Available Slots</dt>
            <dd v-if="tournament?.maxPlayers">
              {{ (tournament.maxPlayers - players.length) }} remaining
            </dd>
          </dl>
        </div>

        <div class="info-card">
          <h3 class="card-title">Flights</h3>
          <dl class="info-list">
            <dt>Total Flights</dt><dd>{{ flights.length }}</dd>
            <dt>Confirmed</dt><dd>{{ confirmedFlightsCount }} / {{ flights.length }}</dd>
          </dl>
        </div>
      </div>

      <div v-if="tournament?.description" class="description-block">
        <h3 class="card-title">Description</h3>
        <p class="description-text">{{ tournament.description }}</p>
      </div>
    </div>

    <!-- ─── Tab: Players ──────────────────────────────────────────────── -->
    <div v-else-if="activeTab === 'players'" class="tab-panel">
      <div class="section-actions">
        <button class="btn btn-primary" @click="showAddPlayer = !showAddPlayer">
          + Add Player
        </button>
        <button class="btn btn-secondary" @click="showImportForm = !showImportForm">
          Bulk Import
        </button>
      </div>

      <!-- Add player form -->
      <div v-if="showAddPlayer" class="inline-form">
        <input v-model="newPlayerId" type="number" placeholder="Player ID" class="form-input" />
        <input v-model="newPlayerHandicap" type="number" step="0.1" placeholder="Handicap" class="form-input" />
        <button class="btn btn-primary" @click="handleAddPlayer" :disabled="addLoading">Add</button>
        <button class="btn btn-secondary" @click="showAddPlayer = false">Cancel</button>
      </div>

      <div v-if="players.length === 0" class="empty-state">
        <p>No players registered yet.</p>
      </div>
      <div v-else class="data-table">
        <table>
          <thead>
            <tr>
              <th>Player ID</th>
              <th>Handicap</th>
              <th>Flight</th>
              <th>Status</th>
              <th>Actions</th>
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
                  Withdraw
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
        <button class="btn btn-primary" @click="handleCreateFlight">+ Create Flight</button>
      </div>

      <div v-if="flights.length === 0" class="empty-state">
        <p>No flights created yet.</p>
      </div>
      <div v-else class="flights-grid">
        <div v-for="flight in flights" :key="flight.id" class="flight-card">
          <div class="flight-header">
            <strong>Flight {{ flight.flightNumber }}</strong>
            <span class="starting-tee-badge">{{ flight.startingTee }}</span>
          </div>
          <div class="flight-players">
            <span v-for="pid in flight.playerIds" :key="pid" class="player-chip">
              Player {{ pid }}
            </span>
            <span v-if="flight.playerIds.length === 0" class="no-players">No players assigned</span>
          </div>
          <div class="flight-tee-time">
            <span v-if="flight.teeTimeId">Tee Time: {{ flight.teeTimeId }}</span>
            <span v-else class="unassigned">Not scheduled</span>
          </div>
          <div v-if="flight.confirmedAt" class="confirmed-badge">
            ✓ Confirmed
          </div>
        </div>
      </div>
    </div>

    <!-- ─── Tab: Tee Times ────────────────────────────────────────────── -->
    <div v-else-if="activeTab === 'tee-times'" class="tab-panel">
      <div class="section-actions">
        <button class="btn btn-primary" @click="showCreateTeeTime = !showCreateTeeTime">
          + Add Tee Time Slot
        </button>
      </div>

      <div v-if="showCreateTeeTime" class="inline-form">
        <input v-model="newTeeTime" type="datetime-local" class="form-input" />
        <button class="btn btn-primary" @click="handleCreateTeeTime">Add</button>
        <button class="btn btn-secondary" @click="showCreateTeeTime = false">Cancel</button>
      </div>

      <div v-if="teeTimes.length === 0" class="empty-state">
        <p>No tee times scheduled.</p>
      </div>
      <div v-else class="data-table">
        <table>
          <thead>
            <tr><th>Tee Time</th><th>Starting Tee</th><th>Flight</th><th>Assign</th></tr>
          </thead>
          <tbody>
            <tr v-for="tt in teeTimes" :key="tt.id">
              <td>{{ formatDateTime(tt.teeTime) }}</td>
              <td>{{ tt.startingTee }}</td>
              <td>{{ tt.flightId ? `Flight ${flightNumber(tt.flightId)}` : '—' }}</td>
              <td>
                <select v-if="!tt.flightId" @change="e => handleAssignFlight(tt.id, (e.target as HTMLSelectElement).value)">
                  <option value="">Select flight...</option>
                  <option v-for="f in unassignedFlights" :key="f.id" :value="f.id">
                    Flight {{ f.flightNumber }}
                  </option>
                </select>
                <span v-else>Assigned</span>
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
        <button class="btn btn-secondary" @click="loadLeaderboard">Refresh</button>
      </div>

      <div v-if="leaderboardLoading" class="loading-state">
        <div class="skeleton-block" />
      </div>
      <div v-else-if="leaderboardEntries.length === 0" class="empty-state">
        <p>No leaderboard data available.</p>
      </div>
      <div v-else class="leaderboard-table">
        <table>
          <thead>
            <tr>
              <th>Rank</th>
              <th>Player</th>
              <th>Flight</th>
              <th>Score</th>
              <th>To Par</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="entry in leaderboardEntries" :key="entry.playerId">
              <td>
                <span class="rank-cell">{{ entry.rank }}</span>
                <span v-if="entry.tied" class="tied-badge">T</span>
              </td>
              <td>Player {{ entry.playerId }}</td>
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
        <button class="btn btn-primary" @click="loadTournament">Refresh</button>
      </div>

      <div v-if="unconfirmedFlights.length === 0" class="empty-state">
        <p>✓ All flights have been confirmed.</p>
      </div>
      <div v-else class="confirm-list">
        <div v-for="flight in unconfirmedFlights" :key="flight.id" class="confirm-card">
          <div class="confirm-header">
            <strong>Flight {{ flight.flightNumber }}</strong>
            <span class="starting-tee-badge">{{ flight.startingTee }}</span>
          </div>
          <div class="flight-players">
            <span v-for="pid in flight.playerIds" :key="pid" class="player-chip">
              Player {{ pid }}
            </span>
          </div>
          <button
            class="btn btn-primary"
            @click="handleConfirmFlight(flight.id)"
            :disabled="confirmLoading"
          >
            Confirm Scores
          </button>
        </div>
      </div>
    </div>

    <!-- ─── Tab: Results ──────────────────────────────────────────────── -->
    <div v-else-if="activeTab === 'results'" class="tab-panel">
      <div v-if="tournament?.status !== 'COMPLETED'" class="info-banner">
        Complete the tournament to generate and publish results.
      </div>
      <div v-else-if="results.length === 0" class="empty-state">
        <p>No results published yet.</p>
        <button class="btn btn-primary" @click="handlePublishResults">Publish Results</button>
      </div>
      <div v-else class="results-table">
        <table>
          <thead>
            <tr><th>Rank</th><th>Player</th><th>Score</th><th>To Par</th><th>Tie Break</th></tr>
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
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { useRoute } from 'vue-router';
import { tournamentApi } from '@/api/tournament';
import type {
  TournamentDetail,
  FlightResponse,
  TeeTimeResponse,
  TournamentPlayerResponse,
  TournamentResultResponse,
  LeaderboardEntryResponse,
} from '@/types/tournament';

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

let sseSource: EventSource | null = null;

// ─── Computed ────────────────────────────────────────────────────────────

const tabs = computed(() => [
  { id: 'overview', label: 'Overview' },
  { id: 'players', label: 'Players', count: players.value.length },
  { id: 'flights', label: 'Flights', count: flights.value.length },
  { id: 'tee-times', label: 'Tee Times', count: teeTimes.value.length },
  { id: 'leaderboard', label: 'Leaderboard' },
  { id: 'confirm', label: 'Confirm', count: unconfirmedFlights.value.length || undefined },
  { id: 'results', label: 'Results' },
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
    error.value = apiErr?.message ?? 'Failed to load tournament';
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
  } catch (_) {
    // Silently fail — leaderboard is non-critical
  } finally {
    leaderboardLoading.value = false;
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
    } catch (_) {}
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
});

onUnmounted(() => {
  disconnectLeaderboardSSE();
});

// ─── Actions ────────────────────────────────────────────────────────────

async function handleOpenRegistration() {
  actionLoading.value = true;
  try {
    await tournamentApi.openRegistration(props.authToken, tournamentId);
    await loadTournament();
  } catch (e: unknown) {
    const apiErr = e as { message?: string };
    error.value = apiErr?.message ?? 'Failed to open registration';
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
    error.value = apiErr?.message ?? 'Failed to start tournament';
  } finally {
    actionLoading.value = false;
  }
}

async function handleCompleteTournament() {
  if (!allFlightsConfirmed.value) {
    error.value = 'All flights must be confirmed before completing';
    return;
  }
  actionLoading.value = true;
  try {
    await tournamentApi.completeTournament(props.authToken, tournamentId);
    await loadTournament();
  } catch (e: unknown) {
    const apiErr = e as { message?: string };
    error.value = apiErr?.message ?? 'Failed to complete tournament';
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
  } catch (_) {
    // Silently fail
  } finally {
    addLoading.value = false;
  }
}

async function handleWithdrawPlayer(playerId: number) {
  try {
    await tournamentApi.withdrawPlayer(props.authToken, tournamentId, playerId);
    await loadTournament();
  } catch (_) {}
}

async function handleCreateFlight() {
  const nextNumber = flights.value.length + 1;
  try {
    await tournamentApi.createFlight(props.authToken, tournamentId, {
      flightNumber: nextNumber,
      startingTee: 'front',
    });
    await loadTournament();
  } catch (_) {}
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
  } catch (_) {}
}

async function handleAssignFlight(teeTimeId: string, flightId: string) {
  if (!flightId) return;
  try {
    await tournamentApi.updateTeeTime(props.authToken, tournamentId, teeTimeId, { flightId });
    await loadTournament();
  } catch (_) {}
}

async function handleConfirmFlight(_flightId: string) {
  confirmLoading.value = true;
  try {
    // Score confirmation would call a dedicated endpoint
    // For now, we reload the data
    await loadTournament();
  } finally {
    confirmLoading.value = false;
  }
}

async function handlePublishResults() {
  try {
    await tournamentApi.publishResults(props.authToken, tournamentId);
    results.value = await tournamentApi.getResults(props.authToken, tournamentId);
  } catch (_) {}
}

// ─── Helpers ────────────────────────────────────────────────────────────

function flightNumber(flightId: string): number | string {
  return flights.value.find(f => f.id === flightId)?.flightNumber ?? '?';
}

function statusLabel(status?: string): string {
  const labels: Record<string, string> = {
    DRAFT: 'Draft',
    REGISTRATION_OPEN: 'Reg. Open',
    IN_PROGRESS: 'In Progress',
    COMPLETED: 'Completed',
    CANCELLED: 'Cancelled',
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
  return new Date(iso).toLocaleDateString();
}

function formatDateTime(iso?: string): string {
  if (!iso) return '—';
  return new Date(iso).toLocaleString();
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
  border-bottom: 1px solid #e5e7eb;
  padding-bottom: 1rem;
}
.header-left { display: flex; align-items: flex-start; gap: 0.75rem; }
.btn-back {
  background: none;
  border: none;
  color: #2563eb;
  font-size: 0.875rem;
  cursor: pointer;
  padding: 0.5rem;
  min-height: 44px;
}
.page-title { font-size: 1.375rem; font-weight: 700; color: #111827; margin: 0; }
.page-subtitle { font-size: 0.875rem; color: #6b7280; margin: 0.25rem 0 0; display: flex; align-items: center; gap: 0.4rem; }
.header-actions { display: flex; gap: 0.5rem; }
.status-badge {
  font-size: 0.6875rem;
  font-weight: 600;
  padding: 0.2rem 0.6rem;
  border-radius: 9999px;
}
.badge-draft { background: #f3f4f6; color: #6b7280; }
.badge-open { background: #dbeafe; color: #1e40af; }
.badge-active { background: #d1fae5; color: #065f46; }
.badge-done { background: #dcfce7; color: #15803d; }
.badge-cancelled { background: #fee2e2; color: #991b1b; }

/* Tabs */
.tab-nav {
  display: flex;
  gap: 0.25rem;
  border-bottom: 1px solid #e5e7eb;
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
  color: #6b7280;
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  white-space: nowrap;
  min-height: 44px;
}
.tab-btn:hover { color: #111827; }
.tab-btn.active { color: #2563eb; border-bottom-color: #2563eb; }
.tab-count {
  background: #e5e7eb;
  color: #374151;
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
  background: #f9fafb;
  border: 1px solid #e5e7eb;
  border-radius: 10px;
  padding: 1rem;
}
.card-title { font-size: 0.875rem; font-weight: 600; color: #374151; margin: 0 0 0.75rem; }
.info-list { display: grid; grid-template-columns: auto 1fr; gap: 0.35rem 1rem; font-size: 0.8125rem; }
.info-list dt { color: #6b7280; }
.info-list dd { color: #111827; font-weight: 500; margin: 0; }
.description-block { background: white; border: 1px solid #e5e7eb; border-radius: 10px; padding: 1rem; }
.description-text { font-size: 0.875rem; color: #374151; margin: 0; line-height: 1.5; }

/* Section actions */
.section-actions { display: flex; gap: 0.5rem; align-items: center; margin-bottom: 1rem; }

/* Inline form */
.inline-form { display: flex; gap: 0.5rem; margin-bottom: 1rem; align-items: center; }

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
.btn-primary { background: #2563eb; color: white; border-color: #2563eb; }
.btn-primary:hover:not(:disabled) { background: #1d4ed8; }
.btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
.btn-secondary { background: white; color: #374151; border-color: #d1d5db; }
.btn-secondary:hover:not(:disabled) { background: #f9fafb; }
.btn-link { background: none; border: none; color: #dc2626; cursor: pointer; font-size: 0.875rem; padding: 0.25rem; }
.btn-link:hover { text-decoration: underline; }

/* Form inputs */
.form-input {
  padding: 0.5rem 0.75rem;
  border: 1px solid #d1d5db;
  border-radius: 6px;
  font-size: 0.875rem;
  min-height: 44px;
  background: white;
  color: #111827;
}
.form-input:focus { outline: none; border-color: #2563eb; box-shadow: 0 0 0 3px rgba(37,99,235,0.1); }

/* Loading / Error */
.loading-state { display: flex; flex-direction: column; gap: 0.75rem; }
.skeleton-block { height: 6rem; border-radius: 10px; background: linear-gradient(90deg,#e5e7eb 25%,#f3f4f6 50%,#e5e7eb 75%); background-size: 200% 100%; animation: shimmer 1.5s infinite; }
.skeleton-card { height: 5rem; border-radius: 8px; background: linear-gradient(90deg,#e5e7eb 25%,#f3f4f6 50%,#e5e7eb 75%); background-size: 200% 100%; animation: shimmer 1.5s infinite; }
@keyframes shimmer { 0% { background-position: 200% 0; } 100% { background-position: -200% 0; } }
.error-state { display: flex; flex-direction: column; align-items: center; gap: 0.5rem; padding: 2rem; color: #dc2626; }
.empty-state { display: flex; flex-direction: column; align-items: center; gap: 0.5rem; padding: 2rem; color: #6b7280; font-size: 0.875rem; }
.info-banner { background: #fef3c7; color: #92400e; padding: 0.75rem 1rem; border-radius: 8px; font-size: 0.875rem; margin-bottom: 1rem; }

/* Flights grid */
.flights-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 0.75rem; }
.flight-card {
  border: 1px solid #e5e7eb;
  border-radius: 10px;
  padding: 0.875rem;
  background: white;
}
.flight-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.5rem; font-size: 0.875rem; }
.starting-tee-badge { font-size: 0.6875rem; padding: 0.15rem 0.5rem; border-radius: 9999px; background: #e5e7eb; color: #374151; }
.flight-players { display: flex; flex-wrap: wrap; gap: 0.25rem; margin-bottom: 0.5rem; min-height: 1.5rem; }
.player-chip { font-size: 0.6875rem; padding: 0.2rem 0.5rem; border-radius: 9999px; background: #dbeafe; color: #1e40af; }
.no-players { font-size: 0.75rem; color: #9ca3af; }
.flight-tee-time { font-size: 0.75rem; color: #6b7280; }
.unassigned { color: #dc2626; }
.confirmed-badge { font-size: 0.75rem; color: #15803d; margin-top: 0.35rem; }

/* Leaderboard */
.leaderboard-version { font-size: 0.75rem; color: #6b7280; background: #f3f4f6; padding: 0.25rem 0.6rem; border-radius: 9999px; }
.rank-cell { font-weight: 700; color: #111827; }

/* Confirm list */
.confirm-list { display: flex; flex-direction: column; gap: 0.75rem; }
.confirm-card {
  border: 1px solid #e5e7eb;
  border-radius: 10px;
  padding: 1rem;
  background: white;
}
.confirm-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.5rem; }
.confirmed-badge { font-size: 0.75rem; color: #15803d; }

/* Tables */
.data-table { overflow-x: auto; }
table { width: 100%; border-collapse: collapse; font-size: 0.875rem; }
th { text-align: left; padding: 0.6rem 0.75rem; background: #f9fafb; border-bottom: 1px solid #e5e7eb; font-weight: 600; color: #374151; white-space: nowrap; }
td { padding: 0.6rem 0.75rem; border-bottom: 1px solid #f3f4f6; color: #111827; }
tr:last-child td { border-bottom: none; }
tr:hover td { background: #f9fafb; }

.meta-sep { color: #d1d5db; }
</style>
