<template>
  <div class="corrections-page">
    <!-- Page header -->
    <header class="page-header">
      <h1 class="page-title">Hàng đợi hiệu chỉnh</h1>
      <p class="page-subtitle">
        Xem và xử lý các báo lỗi dữ liệu sân do golfer gửi.
      </p>
    </header>

    <div class="page-layout">
      <!-- Filters sidebar -->
      <CorrectionQueueFiltersComponent
        v-model="filters"
        @apply="applyFilters"
        class="filters-panel"
      />

      <!-- Main content -->
      <main class="queue-main">
        <!-- Queue toolbar -->
        <div class="queue-toolbar">
          <span class="result-count">
            <span v-if="!loading && !fetchError">
              {{ total }} báo lỗi
            </span>
          </span>
        </div>

        <!-- Queue table -->
        <CorrectionQueueTable
          :corrections="corrections"
          :loading="loading"
          :error="fetchError"
          :selected-id="selectedCorrectionId"
          @select="openDetail"
          @retry="loadQueue"
        />

        <!-- Pagination -->
        <div v-if="totalPages > 1" class="pagination" role="navigation" aria-label="Phân trang hàng đợi">
          <button
            class="page-btn"
            :disabled="currentPage === 0"
            @click="goToPage(currentPage - 1)"
            aria-label="Trang trước"
          >
            ← Trước
          </button>
          <span class="page-info">Trang {{ currentPage + 1 }} / {{ totalPages }}</span>
          <button
            class="page-btn"
            :disabled="currentPage >= totalPages - 1"
            @click="goToPage(currentPage + 1)"
            aria-label="Trang sau"
          >
            Sau →
          </button>
        </div>
      </main>
    </div>

    <!-- ─── Correction Detail Panel ─────────────────────────────────────── -->
    <div v-if="showDetail" class="detail-overlay" @click.self="closeDetail">
      <div class="detail-panel" role="dialog" aria-modal="true" aria-label="Chi tiết báo lỗi">
        <div class="detail-header">
          <h2 class="detail-title">
            Hiệu chỉnh #{{ selectedCorrectionId }}
          </h2>
          <button class="close-btn" @click="closeDetail" aria-label="Đóng bảng chi tiết">×</button>
        </div>

        <!-- Loading detail -->
        <div v-if="detailLoading" class="detail-loading">
          <span>Đang tải chi tiết hiệu chỉnh…</span>
        </div>

        <!-- Detail error -->
        <div v-else-if="detailError" class="detail-error">
          <span>⚠ {{ detailError }}</span>
          <button class="retry-btn" @click="loadDetail">Thử lại</button>
        </div>

        <!-- Detail content -->
        <div v-else-if="detail" class="detail-body">
          <!-- Detail panel sub-components (Slice C) -->
          <CorrectionDetailPanel
            :detail="detail"
            class="detail-section"
          />

          <!-- Review actions (Slice D) -->
          <CorrectionReviewActions
            v-if="detail.status !== 'APPROVED' && detail.status !== 'REJECTED' && detail.status !== 'INFO_REQUESTED' && detail.status !== 'CONVERTED_TO_DRAFT'"
            :correction-id="detail.id"
            :current-status="detail.status"
            :auth-token="authToken"
            @reviewed="onReviewed"
            @error="onReviewError"
            class="detail-section"
          />

          <!-- Terminal state notice -->
          <div v-else class="terminal-notice">
            <span>Báo lỗi này đã được xử lý: <strong>{{ detail.status }}</strong></span>
          </div>
        </div>
      </div>
    </div>

    <!-- ─── Success Toast ─────────────────────────────────────────────── -->
    <div v-if="showSuccessToast" class="toast toast-success" role="status" aria-live="polite">
      <span aria-hidden="true">✅</span>
      <span>{{ successToastMessage }}</span>
      <button class="toast-close" @click="showSuccessToast = false" aria-label="Đóng thông báo thành công">×</button>
    </div>

    <!-- ─── Error Toast ───────────────────────────────────────────────── -->
    <div v-if="showErrorToast" class="toast toast-error" role="alert" aria-live="assertive">
      <span aria-hidden="true">⚠</span>
      <span>{{ errorToastMessage }}</span>
      <button class="toast-close" @click="showErrorToast = false" aria-label="Đóng thông báo lỗi">×</button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import type { CorrectionSummary, CorrectionQueueFilters, CorrectionDetailResponse } from '@/types/correction';
import { correctionApi } from '@/api/correction';
import CorrectionQueueFiltersComponent from '@/components/corrections/CorrectionQueueFilters.vue';
import CorrectionQueueTable from '@/components/corrections/CorrectionQueueTable.vue';
import CorrectionDetailPanel from '@/components/corrections/CorrectionDetailPanel.vue';
import CorrectionReviewActions from '@/components/corrections/CorrectionReviewActions.vue';

const props = defineProps<{
  authToken: string;
}>();

const PAGE_SIZE = 20;

// ─── State ─────────────────────────────────────────────────────────────────

const corrections = ref<CorrectionSummary[]>([]);
const total = ref(0);
const currentPage = ref(0);
const loading = ref(false);
const fetchError = ref<string | null>(null);

const filters = ref<CorrectionQueueFilters>({ page: 0, pageSize: PAGE_SIZE });

// Detail panel
const showDetail = ref(false);
const selectedCorrectionId = ref<number | null>(null);
const detail = ref<CorrectionDetailResponse | null>(null);
const detailLoading = ref(false);
const detailError = ref<string | null>(null);

// Toasts
const showSuccessToast = ref(false);
const successToastMessage = ref('');
const showErrorToast = ref(false);
const errorToastMessage = ref('');

// ─── Computed ─────────────────────────────────────────────────────────────

const totalPages = computed(() => Math.ceil(total.value / PAGE_SIZE));

// ─── Queue loading ─────────────────────────────────────────────────────────

async function loadQueue(page = 0) {
  loading.value = true;
  fetchError.value = null;
  try {
    const resp = await correctionApi.getQueue(props.authToken, filters.value, page, PAGE_SIZE);
    corrections.value = resp.corrections;
    total.value = resp.total;
    currentPage.value = page;
  } catch (err: unknown) {
    const apiErr = err as { message?: string };
    fetchError.value = apiErr?.message ?? 'Không tải được danh sách hiệu chỉnh';
  } finally {
    loading.value = false;
  }
}

function applyFilters() {
  // `filters` is two-way bound via v-model; reload from the first page.
  loadQueue(0);
}

function goToPage(page: number) {
  loadQueue(page);
}

// ─── Detail panel ──────────────────────────────────────────────────────────

async function openDetail(id: number) {
  selectedCorrectionId.value = id;
  showDetail.value = true;
  detailLoading.value = true;
  detailError.value = null;
  detail.value = null;

  try {
    detail.value = await correctionApi.getDetail(props.authToken, id);
  } catch (err: unknown) {
    const apiErr = err as { message?: string };
    detailError.value = apiErr?.message ?? 'Không tải được chi tiết hiệu chỉnh';
  } finally {
    detailLoading.value = false;
  }
}

async function loadDetail() {
  if (selectedCorrectionId.value !== null) {
    await openDetail(selectedCorrectionId.value);
  }
}

function closeDetail() {
  showDetail.value = false;
  selectedCorrectionId.value = null;
  detail.value = null;
  detailError.value = null;
}

// ─── Review event handlers ─────────────────────────────────────────────────

function onReviewed(action: string) {
  closeDetail();
  showToast(`Correction ${action.toLowerCase()}d successfully.`);
  // Refresh queue to reflect new status
  loadQueue(currentPage.value);
}

function onReviewError(message: string) {
  showErrorToastMessage(message);
  showErrorToast.value = true;
  setTimeout(() => { showErrorToast.value = false; }, 8000);
}

// ─── Toasts ────────────────────────────────────────────────────────────────

function showToast(message: string) {
  successToastMessage.value = message;
  showSuccessToast.value = true;
  setTimeout(() => { showSuccessToast.value = false; }, 6000);
}

function showErrorToastMessage(message: string) {
  errorToastMessage.value = message;
}

// ─── Lifecycle ─────────────────────────────────────────────────────────────

onMounted(() => loadQueue(0));
</script>

<style scoped>
.corrections-page {
  font-family: system-ui, -apple-system, sans-serif;
  padding: 1.5rem;
  min-height: 100vh;
  background: var(--surface-container);
}

/* Header */
.page-header {
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

/* Layout */
.page-layout {
  display: flex;
  gap: 1.5rem;
  align-items: flex-start;
}

.filters-panel {
  position: sticky;
  top: 1rem;
  flex-shrink: 0;
}

.queue-main {
  flex: 1;
  min-width: 0;
  background: var(--surface-container);
  border: 1px solid var(--surface-container-highest);
  border-radius: 8px;
  overflow: hidden;
}

/* Toolbar */
.queue-toolbar {
  padding: 0.75rem 1rem;
  border-bottom: 1px solid var(--surface-container-high);
  font-size: 0.8125rem;
  color: var(--muted);
  display: flex;
  align-items: center;
  justify-content: space-between;
}

/* Pagination */
.pagination {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 1rem;
  padding: 1rem;
  border-top: 1px solid var(--surface-container-high);
}
.page-btn {
  padding: 0.5rem 1rem;
  border-radius: 6px;
  border: 1px solid var(--surface-container-highest);
  background: var(--surface-container);
  cursor: pointer;
  font-size: 0.875rem;
  min-height: 44px;
}
.page-btn:hover:not(:disabled) { background: var(--surface-container-high); }
.page-btn:disabled { opacity: 0.4; cursor: not-allowed; }
.page-info { font-size: 0.875rem; color: var(--muted); }

/* ─── Detail Panel ──────────────────────────────────────────────────────── */
.detail-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.4);
  display: flex;
  align-items: stretch;
  justify-content: flex-end;
  z-index: 50;
}

.detail-panel {
  background: var(--surface-container);
  width: 100%;
  max-width: 560px;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  animation: slide-in 0.2s ease-out;
}

@keyframes slide-in {
  from { transform: translateX(100%); opacity: 0; }
  to   { transform: translateX(0); opacity: 1; }
}

.detail-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1rem 1.25rem;
  border-bottom: 1px solid var(--surface-container-highest);
  background: var(--surface-container);
  flex-shrink: 0;
}
.detail-title {
  font-size: 1rem;
  font-weight: 700;
  color: var(--on-surface);
  margin: 0;
}
.close-btn {
  background: none;
  border: none;
  font-size: 1.5rem;
  cursor: pointer;
  color: var(--muted);
  min-height: 44px;
  min-width: 44px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 6px;
}
.close-btn:hover { background: var(--surface-container-high); }

.detail-body {
  flex: 1;
  overflow-y: auto;
  padding: 1.25rem;
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.detail-section {
  /* sections stack vertically */
}

.detail-loading,
.detail-error {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 2rem 1.25rem;
  font-size: 0.875rem;
  color: var(--muted);
}
.detail-error { color: #dc2626; }
.retry-btn {
  padding: 0.4rem 0.75rem;
  border-radius: 6px;
  border: 1px solid var(--surface-container-highest);
  background: var(--surface-container);
  cursor: pointer;
  font-size: 0.8125rem;
  min-height: 36px;
}
.retry-btn:hover { background: var(--surface-container-high); }

.terminal-notice {
  padding: 0.75rem 1rem;
  background: var(--surface-container-high);
  border-radius: 6px;
  font-size: 0.875rem;
  color: var(--muted);
  text-align: center;
}

/* ─── Toasts ───────────────────────────────────────────────────────────── */
.toast {
  position: fixed;
  bottom: 1.5rem;
  right: 1.5rem;
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.875rem 1rem;
  border-radius: 8px;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.15);
  font-size: 0.875rem;
  max-width: 400px;
  z-index: 200;
  animation: slide-up 0.2s ease-out;
}
@keyframes slide-up {
  from { transform: translateY(1rem); opacity: 0; }
  to   { transform: translateY(0); opacity: 1; }
}
.toast-success {
  background: #f0fdf4;
  border: 1px solid #86efac;
  color: #166534;
}
.toast-error {
  background: #fef2f2;
  border: 1px solid #fca5a5;
  color: #991b1b;
}
.toast-close {
  background: none;
  border: none;
  cursor: pointer;
  font-size: 1rem;
  color: inherit;
  opacity: 0.6;
  min-height: 44px;
  min-width: 44px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 4px;
  flex-shrink: 0;
}
.toast-close:hover { opacity: 1; background: rgba(0,0,0,0.05); }

/* Responsive */
@media (max-width: 768px) {
  .page-layout { flex-direction: column; }
  .filters-panel { max-width: 100%; width: 100%; }
  .detail-panel { max-width: 100%; }
}
</style>
