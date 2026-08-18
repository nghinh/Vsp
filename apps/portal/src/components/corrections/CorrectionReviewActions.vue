<template>
  <section class="correction-review-actions" aria-label="Thao tác xử lý">
    <h3 class="section-title">Thao tác xử lý</h3>

    <!-- Current status indicator -->
    <div class="current-status">
      <span class="status-label">Trạng thái hiện tại:</span>
      <CorrectionStatusBadge :status="currentStatus" />
    </div>

    <!-- Action buttons -->
    <div class="action-buttons" role="group" aria-label="Thao tác xử lý">
      <button
        class="action-btn approve-btn"
        @click="showApproveDialog = true"
        :disabled="actionLoading"
      >
        <span aria-hidden="true">✅</span>
        Duyệt
      </button>

      <button
        class="action-btn reject-btn"
        @click="showRejectDialog = true"
        :disabled="actionLoading"
      >
        <span aria-hidden="true">❌</span>
        Từ chối
      </button>

      <button
        class="action-btn request-info-btn"
        @click="showRequestInfoDialog = true"
        :disabled="actionLoading"
      >
        <span aria-hidden="true">💬</span>
        Yêu cầu bổ sung
      </button>

      <button
        class="action-btn convert-btn"
        @click="showConvertDialog = true"
        :disabled="actionLoading"
      >
        <span aria-hidden="true">📝</span>
        Chuyển thành nháp
      </button>
    </div>

    <!-- Global error -->
    <div v-if="globalError" class="action-error" role="alert">
      <span>⚠</span> {{ globalError }}
    </div>

    <!-- ─── Approve Dialog ─────────────────────────────────────────── -->
    <CorrectionApproveDialog
      v-if="showApproveDialog"
      title="Duyệt báo lỗi"
      message="Confirm that this correction is valid and should be applied. An audit entry will be created."
      confirm-label="Approve"
      :loading="actionLoading"
      @confirm="handleApprove"
      @cancel="showApproveDialog = false"
    />

    <!-- ─── Reject Dialog ─────────────────────────────────────────── -->
    <CorrectionRejectDialog
      v-if="showRejectDialog"
      :loading="actionLoading"
      @confirm="handleReject"
      @cancel="showRejectDialog = false"
    />

    <!-- ─── Request Info Dialog ──────────────────────────────────── -->
    <CorrectionRequestInfoDialog
      v-if="showRequestInfoDialog"
      :loading="actionLoading"
      @confirm="handleRequestInfo"
      @cancel="showRequestInfoDialog = false"
    />

    <!-- ─── Convert to Draft Dialog ──────────────────────────────── -->
    <CorrectionConvertToDraftDialog
      v-if="showConvertDialog"
      :loading="actionLoading"
      @confirm="handleConvertToDraft"
      @cancel="showConvertDialog = false"
    />
  </section>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import type { CorrectionStatusValue, CorrectionReviewActionValue } from '@/types/correction';
import { correctionApi } from '@/api/correction';
import CorrectionStatusBadge from './CorrectionStatusBadge.vue';
import CorrectionApproveDialog from './CorrectionApproveDialog.vue';
import CorrectionRejectDialog from './CorrectionRejectDialog.vue';
import CorrectionRequestInfoDialog from './CorrectionRequestInfoDialog.vue';
import CorrectionConvertToDraftDialog from './CorrectionConvertToDraftDialog.vue';

const props = defineProps<{
  correctionId: number;
  currentStatus: CorrectionStatusValue;
  authToken: string;
}>();

const emit = defineEmits<{
  (e: 'reviewed', action: CorrectionReviewActionValue): void;
  (e: 'error', message: string): void;
}>();

// Dialog visibility
const showApproveDialog = ref(false);
const showRejectDialog = ref(false);
const showRequestInfoDialog = ref(false);
const showConvertDialog = ref(false);

// Loading and error state
const actionLoading = ref(false);
const globalError = ref<string | null>(null);

async function submitAction(action: CorrectionReviewActionValue, reason = '', note = '') {
  actionLoading.value = true;
  globalError.value = null;
  try {
    await correctionApi.review(props.authToken, props.correctionId, {
      action,
      reason: reason || undefined,
      note: note || undefined,
    });
    emit('reviewed', action);
  } catch (err: unknown) {
    const apiErr = err as { message?: string };
    const msg = apiErr?.message ?? 'Thao tác xem xét thất bại. Hãy thử lại.';
    globalError.value = msg;
    emit('error', msg);
  } finally {
    actionLoading.value = false;
    // Close all dialogs
    showApproveDialog.value = false;
    showRejectDialog.value = false;
    showRequestInfoDialog.value = false;
    showConvertDialog.value = false;
  }
}

function handleApprove(note: string) {
  submitAction('APPROVE', '', note);
}

function handleReject(reason: string, note: string) {
  submitAction('REJECT', reason, note);
}

function handleRequestInfo(message: string, note: string) {
  submitAction('REQUEST_INFO', message, note);
}

function handleConvertToDraft(note: string) {
  submitAction('CONVERT_TO_DRAFT', '', note);
}
</script>

<style scoped>
.correction-review-actions {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.section-title {
  font-size: 0.9375rem;
  font-weight: 700;
  color: var(--on-surface);
  margin: 0;
  padding-bottom: 0.5rem;
  border-bottom: 1px solid var(--surface-container-highest);
}

/* Current status */
.current-status {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.625rem 0.875rem;
  background: var(--surface-container);
  border-radius: 6px;
  border: 1px solid var(--surface-container-highest);
}

.status-label {
  font-size: 0.8125rem;
  color: var(--muted);
  font-weight: 500;
}

/* Action buttons */
.action-buttons {
  display: flex;
  flex-wrap: wrap;
  gap: 0.75rem;
}

.action-btn {
  flex: 1;
  min-width: 120px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.4rem;
  padding: 0.625rem 1rem;
  border-radius: 8px;
  border: 1px solid;
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  min-height: 48px;
  transition: background 0.15s;
}
.action-btn:disabled { opacity: 0.5; cursor: not-allowed; }

.approve-btn {
  background: rgba(34, 197, 94, 0.12);
  border-color: #2f6f4a;
  color: #6ee7a8;
}
.approve-btn:hover:not(:disabled) { background: rgba(34, 197, 94, 0.22); }

.reject-btn {
  background: rgba(239, 68, 68, 0.12);
  border-color: #7a3838;
  color: #fca5a5;
}
.reject-btn:hover:not(:disabled) { background: rgba(239, 68, 68, 0.22); }

.request-info-btn {
  background: rgba(124, 58, 237, 0.16);
  border-color: #4c3a7a;
  color: #c4b5fd;
}
.request-info-btn:hover:not(:disabled) { background: rgba(124, 58, 237, 0.26); }

.convert-btn {
  background: rgba(20, 184, 166, 0.12);
  border-color: #2b6560;
  color: #7fe0d4;
}
.convert-btn:hover:not(:disabled) { background: rgba(20, 184, 166, 0.22); }

/* These four kept their hue but sat on near-white fills, which read as a
   light-theme widget dropped into the dark review panel. Same hues, dark
   surfaces. */

/* Error */
.action-error {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem;
  background: rgba(239, 68, 68, 0.12);
  border: 1px solid #7a3838;
  border-radius: 6px;
  font-size: 0.875rem;
  color: #fca5a5;
}
</style>
