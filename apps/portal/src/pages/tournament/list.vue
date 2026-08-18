<template>
  <div class="tournament-list-page">

    <header class="page-header">
      <div class="header-content">
        <h1 class="page-title">Giải đấu</h1>
        <p class="page-subtitle">Cấu hình và quản lý các giải đấu.</p>
      </div>
      <button class="btn btn-primary" @click="$router.push('/tournament/create')">
        + Tạo giải đấu
      </button>
    </header>

    <!-- ─── Filters ──────────────────────────────────────────────────────── -->
    <div class="filters-bar">
      <select v-model="statusFilter" class="filter-select" aria-label="Lọc theo trạng thái">
        <option value="">Tất cả trạng thái</option>
        <option value="DRAFT">Bản nháp</option>
        <option value="REGISTRATION_OPEN">Đang mở đăng ký</option>
        <option value="IN_PROGRESS">Đang diễn ra</option>
        <option value="COMPLETED">Đã kết thúc</option>
        <option value="CANCELLED">Đã huỷ</option>
      </select>
      <button class="btn btn-secondary" @click="loadTournaments" :disabled="loading">
        Tải lại
      </button>
    </div>

    <!-- ─── Loading ─────────────────────────────────────────────────────── -->
    <div v-if="loading" class="loading-state" aria-busy="true">
      <div v-for="i in 3" :key="i" class="skeleton-card" />
    </div>

    <!-- ─── Error ───────────────────────────────────────────────────────── -->
    <div v-else-if="error" class="error-state" role="alert">
      <span class="error-icon">⚠</span>
      <span>{{ error }}</span>
      <button class="btn btn-secondary" @click="loadTournaments">Thử lại</button>
    </div>

    <!-- ─── Empty ───────────────────────────────────────────────────────── -->
    <div v-else-if="tournaments.length === 0" class="empty-state">
      <span class="empty-icon">🏌️</span>
      <p class="empty-title">Không có giải đấu nào.</p>
      <p class="empty-subtitle">
        {{ statusFilter ? 'Không có giải nào khớp bộ lọc đã chọn.' : 'Tạo giải đầu tiên để bắt đầu.' }}
      </p>
      <button v-if="!statusFilter" class="btn btn-primary" @click="$router.push('/tournament/create')">
        Tạo giải đấu
      </button>
    </div>

    <!-- ─── Tournament list ─────────────────────────────────────────────── -->
    <div v-else class="tournament-list" role="list">
      <div
        v-for="t in tournaments"
        :key="t.id"
        class="tournament-card"
        role="listitem"
        @click="$router.push(`/tournament/${t.id}`)"
      >
        <div class="card-header">
          <div class="card-title-row">
            <span class="tournament-name">{{ t.name }}</span>
            <span class="status-badge" :class="statusClass(t.status)">
              {{ statusLabel(t.status) }}
            </span>
          </div>
          <div class="card-meta">
            <span class="meta-item">{{ formatLabel(t.format) }}</span>
            <span class="meta-sep">·</span>
            <span class="meta-item">{{ formatDate(t.startDate) }}</span>
          </div>
          <!-- The day-of screen, one click from the list rather than two:
               on the day this is the only page anyone opens. -->
          <button
            type="button"
            class="run-outing"
            @click.stop="$router.push(`/tournament/${t.id}/outing`)"
          >
            Nhập điểm &amp; kết quả →
          </button>
        </div>

        <div v-if="t.courseName" class="card-course">
          📍 {{ t.courseName }}
        </div>

        <div class="card-footer">
          <span v-if="t.maxPlayers" class="footer-stat">
            👥 Tối đa {{ t.maxPlayers }} golfer
          </span>
          <span v-if="t.registrationDeadline" class="footer-stat">
            📅 Hạn đăng ký: {{ formatDate(t.registrationDeadline) }}
          </span>
        </div>
      </div>
    </div>

  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { formatDay } from '@/lib/datetime';
import { tournamentApi } from '@/api/tournament';
import type { TournamentSummary } from '@/types/tournament';


const tournaments = ref<TournamentSummary[]>([]);
const loading = ref(false);
const error = ref<string | null>(null);
const statusFilter = ref('');

// Props — in a real app, auth token would come from auth store
const props = defineProps<{ authToken: string }>();

async function loadTournaments() {
  loading.value = true;
  error.value = null;
  try {
    tournaments.value = await tournamentApi.listTournaments(props.authToken, {
      status: statusFilter.value || undefined,
    });
  } catch (e: unknown) {
    const apiErr = e as { message?: string };
    error.value = apiErr?.message ?? 'Không tải được danh sách giải đấu';
  } finally {
    loading.value = false;
  }
}

function statusLabel(status: string): string {
  const labels: Record<string, string> = {
    DRAFT: 'Bản nháp',
    REGISTRATION_OPEN: 'Đang mở đăng ký',
    IN_PROGRESS: 'Đang diễn ra',
    COMPLETED: 'Đã kết thúc',
    CANCELLED: 'Đã huỷ',
  };
  return labels[status] ?? status;
}

function statusClass(status: string): string {
  const classes: Record<string, string> = {
    DRAFT: 'badge-draft',
    REGISTRATION_OPEN: 'badge-open',
    IN_PROGRESS: 'badge-active',
    COMPLETED: 'badge-done',
    CANCELLED: 'badge-cancelled',
  };
  return classes[status] ?? '';
}

function formatLabel(format: string): string {
  const labels: Record<string, string> = {
    strokePlay: 'Stroke Play',
    matchPlay: 'Match Play',
    stableford: 'Stableford',
  };
  return labels[format] ?? format;
}

function formatDate(iso: string): string {
  return formatDay(iso);
}

onMounted(() => loadTournaments());
</script>

<style scoped>
.run-outing {
  margin-top: 8px;
  padding: 5px 12px;
  border: 1px solid var(--primary, var(--primary-container));
  border-radius: 6px;
  background: transparent;
  color: var(--primary, var(--primary-container));
  font-size: 12px;
  font-weight: 600;
  cursor: pointer;
}
.run-outing:hover {
  background: rgba(246, 96, 24, 0.12);
}

.tournament-list-page {
  font-family: system-ui, -apple-system, sans-serif;
  padding: 1.5rem;
  max-width: 900px;
  margin: 0 auto;
}

/* Header */
.page-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 1.5rem;
  border-bottom: 1px solid var(--surface-container-highest);
  padding-bottom: 1rem;
}
.page-title {
  font-size: 1.5rem;
  font-weight: 700;
  color: var(--on-surface);
  margin: 0;
}
.page-subtitle {
  font-size: 0.875rem;
  color: var(--muted);
  margin: 0.25rem 0 0;
}

/* Filters */
.filters-bar {
  display: flex;
  gap: 0.75rem;
  margin-bottom: 1.25rem;
  align-items: center;
}
.filter-select {
  padding: 0.5rem 0.75rem;
  border: 1px solid var(--surface-container-highest);
  border-radius: 6px;
  font-size: 0.875rem;
  min-height: 44px;
  background: var(--surface-container);
  color: var(--on-surface);
}

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
.btn-primary {
  background: var(--primary-container);
  color: white;
  border-color: var(--primary-container);
}
.btn-primary:hover:not(:disabled) { background: var(--secondary-container); }
.btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }
.btn-secondary {
  background: var(--surface-container);
  color: #c5cde8;
  border-color: var(--surface-container-highest);
}
.btn-secondary:hover:not(:disabled) { background: var(--surface-container); }
.btn-secondary:disabled { opacity: 0.5; cursor: not-allowed; }

/* Loading */
.loading-state { display: flex; flex-direction: column; gap: 0.75rem; }
.skeleton-card {
  height: 6rem;
  border-radius: 10px;
  background: linear-gradient(90deg, var(--surface-container-highest) 25%, var(--surface-container-high) 50%, var(--surface-container-highest) 75%);
  background-size: 200% 100%;
  animation: shimmer 1.5s infinite;
}
@keyframes shimmer {
  0%   { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}

/* Error / Empty */
.error-state,
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.5rem;
  padding: 3rem 1rem;
  color: var(--muted);
  text-align: center;
}
.error-state { color: #dc2626; }
.empty-icon, .error-icon { font-size: 2rem; }
.empty-title { font-size: 1.125rem; font-weight: 600; margin: 0; }
.empty-subtitle { font-size: 0.875rem; color: var(--muted); margin: 0; }

/* Tournament list */
.tournament-list { display: flex; flex-direction: column; gap: 0.75rem; }
.tournament-card {
  border: 1px solid var(--surface-container-highest);
  border-radius: 10px;
  padding: 1rem;
  background: var(--surface-container);
  cursor: pointer;
  transition: background 0.15s, border-color 0.15s;
}
.tournament-card:hover {
  background: var(--surface-container);
  border-color: var(--primary-container);
}

.card-header { margin-bottom: 0.5rem; }
.card-title-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
  margin-bottom: 0.25rem;
}
.tournament-name {
  font-size: 1rem;
  font-weight: 600;
  color: var(--on-surface);
}
.status-badge {
  font-size: 0.6875rem;
  font-weight: 600;
  padding: 0.2rem 0.6rem;
  border-radius: 9999px;
  white-space: nowrap;
}
.badge-draft { background: var(--surface-container-high); color: var(--muted); }
.badge-open { background: var(--surface-container-highest); color: var(--secondary-container); }
.badge-active { background: #d1fae5; color: #065f46; }
.badge-done { background: #dcfce7; color: #15803d; }
.badge-cancelled { background: #fee2e2; color: #991b1b; }

.card-meta {
  display: flex;
  align-items: center;
  gap: 0.25rem;
  font-size: 0.8125rem;
  color: var(--muted);
}
.meta-sep { color: var(--surface-container-highest); }

.card-course {
  font-size: 0.8125rem;
  color: var(--muted);
  margin-bottom: 0.5rem;
}

.card-footer {
  display: flex;
  gap: 1rem;
  font-size: 0.75rem;
  color: var(--muted);
}
</style>
